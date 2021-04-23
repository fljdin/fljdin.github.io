---
title: "Le partitionnement par hachage"
categories: [postgresql]
tags: [maintenance,performance]
date: 2021-04-23
---

Le partitionnement déclaratif a été une véritable révolution à la sortie de la
version 10 de PostgreSQL en octobre 2017. La gestion des sous-tables devenait
alors bien plus aisée au quotidien, simplifiant leur mise en place et leur
maintenance.

Sans cesse amélioré au cours des dernières années, je me souviens encore de mon 
émerveillement devant la magie du partitionnement par hachage, [apparu][1] en 
version 11. Comment le déployer et que permet-il ? J'ai voulu m'en rendre compte 
dans une rapide démonstration sur le type [UUID][2] en étudiant les fonctions
d'appui qui se cachent derrière le hachage des valeurs.

[1]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=1aba8e651ac3e37e1d2d875842de1e0ed22a651e
[2]: https://fr.wikipedia.org/wiki/Universally_unique_identifier

<!--more-->

---

## Un très bon choix de repli

Dès lors qu'une ou plusieurs tables dépasse le milliard de lignes, il y a fort
à parier que les problèmes de performance ou de maintenance soient au rendez-vous :
index volumineux, fragmentation importante, gel de l'activité pour cause de
[rebouclage des identifiants de transactions][3], difficultés à purger les données.
L'apparition du partitionnement déclaratif dans PostgreSQL a permis d'y adresser
des solutions avec un minimum de complexité.

[3]: https://blog.crunchydata.com/blog/managing-transaction-id-wraparound-in-postgresql

La clé de partitionnement peut être définie par trois méthodes (_range_, _list_,
_hash_) qui présentent chacunes des réponses appropriées aux besoins d'une table
ou d'une fonctionnalité. Nous privilégierons une clé répartie sur un intervalle
de temps pour l'archivage de données sur une date, ou bien une clé dont les valeurs
sont régulées dans une liste lorsque l'on souhaite maîtriser la répartition et
pouvoir la faire évoluer simplement. 

La dernière méthode _hash_ est intéressante à plusieurs égards par la confusion 
de la clé primaire avec la clé de partionnement et par une répartition équilibrée
des données sur l'ensemble des sous-tables définie à l'avance. De manière générale,
si vous n'avez pas idée de votre clé de partitionnement et que vous lisez 
principalement vos données sur leur clé primaire, la méthode par hachage peut être
un très bon choix de repli.

Prenons une table très simple que nous découpons en cinq partitions à partir des
valeurs de la clé primaire dont le type est `uuid`.

```sql
CREATE TABLE t1 (
  tid uuid PRIMARY KEY,
  tchar text, 
  tdate timestamp without time zone
) PARTITION BY HASH (tid);

CREATE TABLE t1_0_5 PARTITION OF t1
  FOR VALUES WITH (modulus 5, remainder 0);

CREATE TABLE t1_1_5 PARTITION OF t1
  FOR VALUES WITH (modulus 5, remainder 1);

CREATE TABLE t1_2_5 PARTITION OF t1
  FOR VALUES WITH (modulus 5, remainder 2);

CREATE TABLE t1_3_5 PARTITION OF t1
  FOR VALUES WITH (modulus 5, remainder 3);

CREATE TABLE t1_4_5 PARTITION OF t1
  FOR VALUES WITH (modulus 5, remainder 4);
```

Avec cette configuration, l'identifiant de chaque ligne sera haché et réduit 
par l'opérateur modulo pour obtenir une valeur entière comprise entre `0` et `4`.
Insérons un petit million de lignes et observons leur répartition.

```sql
INSERT INTO t1
SELECT gen_random_uuid(), md5(g::varchar),
       current_timestamp - g * interval '1 hour'
  FROM generate_series(1, 1e6) g;

-- INSERT 0 1000000
```

{{< message >}}
À partir de la version 13 de PostgreSQL, la fonction `gen_random_uuid()` est 
intégrée dans le catalogue et il n'est plus nécessaire de passer par des 
extensions comme `pgcrypto` ou `uuid-ossp` pour générer un `uuid` aléatoire.
{{< /message >}}

La vue `pg_stat_user_tables` nous indique bien un nombre de tuples équitablement
insérés dans les partitions.

```sql
SELECT relname, SUM(n_live_tup) n_live_tup
  FROM pg_stat_user_tables
 GROUP BY cube(relname) ORDER BY relname;
```
```text
 relname | n_live_tup 
---------+------------
 t1_0_5  |     200148
 t1_1_5  |     200123
 t1_2_5  |     199964
 t1_3_5  |     200184
 t1_4_5  |     199581
         |    1000000
```

---

Le nombre de partitions est un choix crucial lors de l'initialisation de
la table, ou lors de sa transformation en table partitionnée, car l'ajout de
nouvelles partitions nécessite de remplacer une des sous-tables existantes par
un nouvel ensemble de partitions dont le diviseur doit être un multiple du
précédent.

Voyons comment scinder l'une des partitions en deux.

```sql
BEGIN;
ALTER TABLE t1 DETACH PARTITION t1_0_5;

CREATE TABLE t1_0_10 PARTITION OF t1
  FOR VALUES WITH (modulus 10, remainder 0);

CREATE TABLE t1_5_10 PARTITION OF t1
  FOR VALUES WITH (modulus 10, remainder 5);

INSERT INTO t1 SELECT * FROM t1_0_5;
-- INSERT 0 200148

DROP TABLE t1_0_5;
COMMIT;
```

Le contenu de l'ancienne partition `t1_0_5` est déversée dans la table partitionnée
et l'opérateur modulus `10` permet la redistribution des lignes dans les deux
nouvelles partitions, respectivement celles dont les restes de la division sont `0`
et `5`. On garantit ainsi que les autres partitions ne deviennent pas leur nouvelle
destination.

```sql
SELECT relname, SUM(n_live_tup) n_live_tup
  FROM pg_stat_user_tables WHERE relname like 't1%10' 
 GROUP BY cube(relname) ORDER BY relname;
```
```text
 relname | n_live_tup 
---------+------------
 t1_0_10 |      99960
 t1_5_10 |     100188
         |     200148
```

Cette opération est lourde sur des données vivantes, avec des verrous de type
`Access Exclusive` qui interdisent toutes consultations ou modifications de la
table partitionnée. Les sous-tables non impliquées dans la transformation restent
accessibles en lecture, pour peu qu'on puisse réaliser les `SELECT` sur leur 
nom exact de partition.

---

## Les fonctions d'appui

La plupart des types de données sont supportés par la méthode `hash` à l'aide
notamment des classes d'opérateur et des fonctions d'appui fournies par PostgreSQL.
Par exemple, pour connaître la liste de types compatibles avec le partitionnement
par hachage, il suffit de consulter le catalogue.

```text
demo=# \dAc hash
                         List of operator classes
  AM  |       Input type      | Storage type |   Operator class    | Default? 
------+-----------------------+--------------+---------------------+----------
 hash | aclitem               |              | aclitem_ops         | yes
 hash | anyarray              |              | array_ops           | yes
 hash | anyenum               |              | enum_ops            | yes
 hash | anyrange              |              | range_ops           | yes
 ...
 hash | uuid                  |              | uuid_ops            | yes
 hash | xid                   |              | xid_ops             | yes
 hash | xid8                  |              | xid8_ops            | yes
(46 rows)
```

Lors de l'élaboration du partitionnement par hachage, la communauté a étendu les
fonctions d'appui en [proposant][4] que la valeur hâchée soit encodée sur 64 bits 
(`bigint`) et mélangée par [salage][5]. Dans le cas du type `uuid`, la fonction 
d'appui est `uuid_hash_extended` pour laquelle le deuxième argument vaut 
`HASH_PARTITION_SEED` en dur [dans le code][6] de PostgreSQL.

[4]: https://www.postgresql.org/message-id/CA%2BTgmoZSTkD8ZazeXefmHFMKNG8U8sap-DbKkwVM%2BBw223mkVQ%40mail.gmail.com
[5]: https://fr.wikipedia.org/wiki/Salage_(cryptographie)
[6]: https://github.com/postgres/postgres/blob/REL_13_2/src/backend/partitioning/partbounds.c#L4560

```text
demo=# \dAp hash uuid*
                List of support functions of operator families
  AM  | Operator family | Left type | Right type | Number |      Function      
------+-----------------+-----------+------------+--------+--------------------
 hash | uuid_ops        | uuid      | uuid       |      1 | uuid_hash
 hash | uuid_ops        | uuid      | uuid       |      2 | uuid_hash_extended

demo=# \df uuid_hash*
                               List of functions
   Schema   |           Name     | Result data type | Argument data types | Type 
------------+--------------------+------------------+---------------------+------
 pg_catalog | uuid_hash          | integer          | uuid                | func
 pg_catalog | uuid_hash_extended | bigint           | uuid, bigint        | func
```

Pour bien me rendre compte de la bonne utilisation d'une fonction d'appui pour
le hachage d'une colonne particulière, j'ajoute à mon catalogue une nouvelle
fonction `uuid_hash_noseed` qui repose sur la méthode classique `uuid_hash` sans
salage.

```sql
CREATE OR REPLACE FUNCTION uuid_hash_noseed(value uuid, seed bigint)
  RETURNS bigint AS $$
SELECT abs(uuid_hash(value));
$$ LANGUAGE sql IMMUTABLE;

CREATE OPERATOR CLASS uuid_noseed_ops FOR TYPE uuid 
 USING hash AS
  OPERATOR 1 =,
  FUNCTION 2 uuid_hash_noseed(uuid, bigint);
```

Le nouvel opérateur `uuid_noseed_ops` est défini pour utiliser la fonction créée
précédemment en spécifiant le numéro d'appui `2`, correspondant à la génération
d'un _hash_ encodé sur 64 bits ([doc][7]) requis pour le partitionnement. Pour 
valider mes hypothèses sur la distribution des lignes en fonction de leur reste 
de division, je crée une table `t2` avec une clé primaire au format `uuid` dans
laquelle je sépare les valeurs de _hash_ paires et impaires.

[7]: https://www.postgresql.org/docs/current/xindex.html#XINDEX-HASH-SUPPORT-TABLE

```sql
CREATE TABLE t2 (
  tid uuid PRIMARY KEY
) PARTITION BY HASH (tid uuid_noseed_ops);

CREATE TABLE t2_0_2 PARTITION OF t2
  FOR VALUES WITH (modulus 2, remainder 0);

CREATE TABLE t2_1_2 PARTITION OF t2
  FOR VALUES WITH (modulus 2, remainder 1);

INSERT INTO t2
SELECT gen_random_uuid() FROM generate_series(1, 1e6) g;
-- INSERT 0 1000000
```

La suite de mon expérience m'a mené un peu plus loin que ce que j'imaginais à
l'origine. Même en l'absence d'un salage avec la constante `HASH_PARTITION_SEED`,
une [autre opération][8] au cœur de la méthode de hachage survient : 
`hash_combine64()`.

[8]: https://github.com/postgres/postgres/blob/REL_13_2/src/include/common/hashfn.h#L80

```c
/*
 * Combine two 64-bit hash values, resulting in another hash value, using the
 * same kind of technique as hash_combine().  Testing shows that this also
 * produces good bit mixing.
 */
static inline uint64
hash_combine64(uint64 a, uint64 b)
{
    /* 0x49a0f4dd15e5a8e3 is 64bit random data */
    a ^= b + UINT64CONST(0x49a0f4dd15e5a8e3) + (a << 54) + (a >> 7);
    return a;
}
```

Ce salage supplémentaire est fiable pour le sous-partitionnement, où l'on souhaite
obtenir un hachage de plusieurs colonnes pour établir la distribution des lignes 
dans les partitions. Dans mon cas de test, puisque ma clé de partitionnement est
seule, l'opération ne fait que commuter les bits du résultat. Ce constat avait été
partagé entre [deux développeurs][9], ce qui m'a donné la requête finale 
ci-dessous afin de retrouver le reste de division et de le comparer avec les noms
de partitions de ma table `t2`.

[9]: https://www.postgresql.org/message-id/CAMG7%3DyUde-E%2B4Fd0w%3DVU7VsgiL0yqpVB6uCi5drs5KLDyOCzFQ%40mail.gmail.com

```sql
SELECT tid, tableoid::regclass partname, 
       (uuid_hash_noseed(tid, 0)::bit(64) # x'49a0f4dd15e5a8e3')::bigint % 2 
         AS remainder
  FROM t2 ORDER BY tid LIMIT 10;
```
```text
                 tid                  | partname | remainder 
--------------------------------------+----------+-----------
 000012e3-bf3e-4895-8dc4-adf25649680a | t2_0_2   |         0
 00003fd4-b941-4c49-afcb-6449f2ddd169 | t2_1_2   |         1
 000068b2-ce2d-4e13-9586-1ad986d31737 | t2_0_2   |         0
 00006999-696e-4c15-ac94-d1de23b89c73 | t2_1_2   |         1
 000085cb-e666-4ecb-a886-09ae86fc7d55 | t2_1_2   |         1
 00008675-2291-4c49-afd1-4b55ccbd50c1 | t2_0_2   |         0
 0000c8a1-a0fb-4e53-882d-ed9c11aba44c | t2_1_2   |         1
 0000d1fd-759a-47c5-8e87-284455b36478 | t2_0_2   |         0
 0000d3af-64da-427c-815d-b7d32f62d7a6 | t2_1_2   |         1
 0000f608-f4a2-43dd-8483-94bb317e0c95 | t2_0_2   |         0
```

---

## Conclusion

Avec l'apparition du partitionnement par hachage, PostgreSQL s'est doté d'une
nouvelle méthode permettant de bénéficier de tous les avantages du partitionnement
déclaratif sans se soucier de la distribution logique des valeurs de la clé de
partitionnement.

Bien que l'élagage de partition lors de la planification ne soit pas l'objectif
de la manœuvre puisque la clé de partitionnement est par nature indexée, il 
devient très intéressant de bénéficier notamment d'une maintenance par `VACUUM` 
accélérée en subdivisant les données et les index sur le disque. La distribution
des opérations de lecture et d'écriture sur plusieurs disques à l'aide des 
tablespaces est également possible [depuis la version 12][10] et apporte son lot 
de solutions pour les tables très volumineuses.

[10]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=ca4103025dfe26eaaf6a500dec9170fbb176eebc