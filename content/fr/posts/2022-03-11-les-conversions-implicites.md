---
title: "Les conversions implicites"
categories: [postgresql]
tags: [developpement]
date: 2022-03-11
---

À l'image d'un langage de programmation classique, le SQL manipule des données 
typées, comme les chaînes de caractères, les dates ou des entiers numériques.
Les opérations de transformations ou de comparaison diffèrent en fonction du
type de données ; il ne sera pas possible de comparer le caractère `A` avec le 
chiffre `4` mais l'opérateur `||` permettra la concaténation des deux éléments.

Dans cet article, je souhaite partager quelques anecdotes et problématiques de
terrain concernant cette particularité logicielle et comprendre les effets de
bord pour mieux les appréhender. Je prendrais un exemple assez spécifique du type
`oid` et d'un risque de transtypage pouvant perturber le stockage de _Large
Objects_ dans une table, voire leur destruction non désirée.

<!--more-->

---

## Aucun résultat surprenant ou imprévisible

PostgreSQL dispose d'un système complet pour la gestion du typage des données.
Chaque donnée est considérée par son type, permettant ainsi de le manipuler à
travers un ensemble d'opérateurs, avec des comportements précis pour chaque type.

Les conversions implicites sont ces mécanismes qui assurent l'alignement de deux
types de données pour réaliser (ou non) l'opération demandée. La [documentation][1]
énumère les trois principes que respectent ces conversions :

[1]: https://www.postgresql.org/docs/14/typeconv-overview.html

* Les conversions implicites ne doivent jamais avoir de résultats surprenants 
  ou imprévisibles.
* Il n'y aura pas de surcharge depuis l'analyseur ou l'exécuteur si une requête
  n'a pas besoin d'une conversion implicite de types. C'est-à-dire que si une
  requête est bien formulée et si les types sont déjà bien distinguables, alors
  la requête devra s'exécuter sans perte de temps supplémentaire et sans
  introduire à l'intérieur de celle-ci des appels à des conversions implicites
  non nécessaires.
* De plus, si une requête nécessite habituellement une conversion implicite pour
  une fonction et si l'utilisateur définit une nouvelle fonction avec les types
  des arguments corrects, l'analyseur devrait utiliser cette nouvelle fonction
  et ne fera plus des conversions implicites en utilisant l'ancienne fonction. 

Il est arrivé par le passé, qu'une version majeure réduise la liste des conversions
implicites pour respecter les principes cités ci-dessus. Ce fut le cas de la
[version 8.3][2] qui interdit (brutalement) le transtypage de données temporelles
(`date`, `time`) ou numérique (`int4`, etc.) en chaîne de caractère (`text`). 
Tom Lane [proposa][3] une nouvelle implémentation de la représentation textuelle
d'une donnée pour limiter le risque de surprise.

[2]: https://www.postgresql.org/docs/8.3/release-8-3.html#AEN88167
[3]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=31edbadf4af45dd4eecebcb732702ec6d7ae1819

Certaines opérations devenaient également impossibles, obligeant les développeurs
à faire preuve de plus de rigueur.  Les expressions suivantes nécessitaient alors
une réécriture pour forcer le transtypage avec l'opérateur `::` ou la fonction 
`CAST()` :

```sql
SELECT substr(current_date, 1, 4) AS "year";
-- ERROR: function substr(date, integer, integer) does not exist
--> devient
SELECT substr(current_date::text, 1, 4) AS "year";

SELECT position(5 IN '1234567890') = '5' AS "5";
-- ERROR: function pg_catalog.position(unknown, integer) does not exist
--> devient
SELECT position('5' IN '1234567890') = '5' AS "5";
```

L'exemple ci-après est inspiré des [tests de regression][4], mettant en jeu deux
tables avec une contrainte étrangère. Depuis la version majeure 8.3, le message
d'erreur `foreign key constraint cannot be implemented` indique que la conversion
implicite n'est plus possible.

[4]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=blobdiff;f=src/test/regress/expected/foreign_key.out;h=3c0dd7f0872df01829d8e5a518c98e4b822a6ff1;hp=41c2f397882daf8d032f0dd12a6b74a4b867cf1b;hb=31edbadf4af45dd4eecebcb732702ec6d7ae1819;hpb=1120b99445a90ceba27f49e5cf86293f0628d06a

```sql
CREATE TEMP TABLE pktable (id1 int4 PRIMARY KEY);
CREATE TEMP TABLE fktable (x1 varchar(4));

ALTER TABLE fktable ADD CONSTRAINT fk_id1_x1
  FOREIGN KEY (x1) REFERENCES pktable(id1);
-- ERROR: foreign key constraint "fk_id1_x1" cannot be implemented
-- DETAIL: Key columns "x1" and "id1" are of incompatible types:
--         integer and character varying.
```

Bien que certains [contournements][5] étaient alors possibles avec l'ajout de
nouveaux opérateurs ou de nouvelles conversions implicites, la réécriture des
requêtes et le bon choix des types de données furent vivement encouragés pour
dépasser les contraintes qu'imposait cette version majeure.

[5]: http://blog.ioguix.net/postgresql/2010/12/11/Problems-and-workaround-recreating-casts-with-8.3+.html

---

## Ouin ouin je préfère Microsoft Access

Pour une partie non-négligeable de la population, le langage SQL est fréquemment
associé à… Microsoft Access. Bien qu'on ait beaucoup à redire sur cette 
affirmation, il est d'usage que les suites Office soient très (trop) majoritaires
sur les postes utilisateurs.

Parmi l'un des besoins de conversion, lorsqu'il est question de migrer vers
PostgreSQL, on retrouve la gestion du type `boolean` qui est représenté par un
entier. La correspondance assez répandue est `0` = `false` et tout le 
reste = `true`. Or, lorsqu'une migration de données a lieu et que la transformation
des entiers `0` et `1` présents dans les tables a été correctement réalisée au
format `boolean`, les requêtes SQL applicatives peuvent rencontrer des soucis
de conversions implicites :

```sql
CREATE TABLE visitor (id int, name text, is_online bool);
INSERT INTO visitor VALUES (1, 'florent', true);

SELECT id, name FROM visitor WHERE is_online = -1;
-- ERROR: operator does not exist: boolean = integer
-- HINT: No operator matches the given name and argument types. 
--       You might need to add explicit type casts.
```

Une fois encore, la correction la plus appropriée serait d'épurer l'expression
booléenne avec uniquement la clause `WHERE is_online`. Pour celles et ceux qui
ne peuvent (ou ne veulent) pas procéder à la réécriture, Sim Zacks proposait sur
la [liste pgsql-general][6] un contournement au niveau des opérateurs dans
PostgreSQL. Dans la version ci-dessus, je m'appuie sur la fonction native `bool()`
pour déterminer la correspondance booléenne d'un entier.

[6]: https://www.postgresql.org/message-id/do4dpl%242f6t%241%40news.hub.org

```sql
CREATE OR REPLACE FUNCTION pg_catalog.booleqint(bool, integer) 
  RETURNS BOOLEAN STRICT IMMUTABLE 
  LANGUAGE SQL AS $$ SELECT bool($2) = $1; $$;

CREATE OPERATOR pg_catalog.= (
  procedure = pg_catalog.booleqint, 
  leftarg = boolean, rightarg = integer, 
  commutator = operator(pg_catalog.=),
  negator = operator(pg_catalog.!=)
);

SELECT id, name FROM visitor WHERE is_online = -1;
--  id |  name   
-- ----+---------
--   1 | florent
```

---

## Précaution pour les Large Objects

Une donnée `oid` ([doc][7]) est depuis peu, un type exclusivement réservé au
fonctionnement interne du catalogue PostgreSQL. Il s'agit très simplement d'un
entier encodé sur 4 bits, exactement comme le type `int4` ou `integer`. Et là
où la conversion implicite nous empêchait de trouver une correspondance entre une
chaîne de caractère et un entier, le type `oid` se comporte bien différement.

[7]: https://www.postgresql.org/docs/14/datatype-oid.html

Démonstration avec deux colonnes, respectivement `text` et `oid`. Lors de l'ajout
d'un enregistrement, le transtypage de la valeur `10000` (`integer`) vers un type
`text` ou `oid` ne pose aucune sorte de difficulté.

```sql
CREATE TABLE test (col1 text, col2 oid);
INSERT INTO test VALUES (10000, 10000);
```

La conversion inverse ne sera pas possible pour le type `text`, comme expliqué
plus haut avec une implémentation plus robuste introduit en version 8.3. 
Cependant, rien n'interdira l'opération inverse pour le type `oid` vers `integer`.

```sql
SELECT col1 FROM test WHERE col1 = 10000;
-- ERROR: operator does not exist: text = integer

SELECT col2 FROM test WHERE col2 = 10000;
--  col2  
-- -------
--  10000
```

Il s'agit d'une conversion implicite basée sur un rapprochement strict de la 
valeur binaire des deux données, que la [documentation][8] décrit comme « deux
types coercibles binairement ».

[8]: https://www.postgresql.org/docs/14/sql-createcast.html

> Deux types peuvent être coercibles binairement, ce qui signifie que le 
> transtypage peut être fait « gratuitement » sans invoquer aucune fonction. 
> Ceci impose que les valeurs correspondantes aient la même représentation interne.
> Par exemple, les types text et varchar sont coercibles binairement dans les 
> deux sens.

C'est avec ce phénomène en tête que je peux vous parler des _Large Objects_ !

À l'instar du [mécanisme de _toasting_][9] permettant le débordement d'une donnée 
supérieure à 8 ko dans un fichier dédié, les _Large Objects_ sont centralisées
dans une table système nommée `pg_largeobject`. Leurs avantages peuvent être
multiples (_streaming_ binaire, stockage au-delà de 1 Go) et peuvent justifier
leur utilisation en lieu et place des types plus standards, comme `text` ou
`bytea`.

[9]: /2020/10/12/toast-la-meilleure-chose-depuis-le-pain-en-tranches/

Sauf que la gestion d'un `lo` (_large object_, vous l'avez ?) se fait grâce au
maintien d'adresses logiques entre la colonne d'un enregistrement et la table
système. Oui, un identifiant unique de type `oid`. Prenons une table `wallet`
dans laquelle nous décidons de stocker des documents volumineux sous forme de 
_large objects_, disons le [dernier rapport du GIEC][10].

[10]: https://www.ipcc.ch/report/ar6/wg2/

```sql
CREATE TABLE wallet (title text, content oid);
INSERT INTO wallet VALUES (
  'Climate Change 2022 - Summary for Policymakers',
  lo_import('IPCC_AR6_WGII_SummaryForPolicymakers.pdf')
);
-- INSERT 0 1
```

La consultation du fichier sera permise qu'à travers des méthodes dédiées, telle
que `lo_get()`. Dans l'exemple ci-dessous, je consulte les 10 premiers octets du
fichier PDF pour m'assurer de son existence dans la base de données.

```sql
SELECT content, lo_get(content, 0, 10) FROM wallet;
--  content |         lo_get         
-- ---------+------------------------
--    16811 | \x255044462d312e360d25
```

L'identifiant `16811` de mon document est unique parmi les _large objects_ et
garantit qu'il puisse être reconstruit à l'aide des méthodes associées. Que se
passe-t-il si l'on change le type de la colonne `content` en autre chose, par
exemple en `integer` ?

```sql
ALTER TABLE wallet ALTER COLUMN content TYPE integer;
-- ALTER TABLE

SELECT content, lo_get(content, 0, 10) FROM wallet;
--  content |         lo_get         
-- ---------+------------------------
--    16811 | \x255044462d312e360d25
```

Puisque le type `oid` est coercible binairement avec le type `integer`, nous 
n'observons pas d'erreur de conversion ni lors du changement du type de la colonne
ni lors de l'appel `lo_get()`. À partir de cet instant, les choses deviennent
dangereuses pour le rapport du GIEC, par ignorance, un administrateur soucieux
des données larges orphelines décide de déclencher la commande `vacuumlo` 
([doc][11]) :

[11]: https://www.postgresql.org/docs/14/vacuumlo.html

```sh
$ vacuumlo --verbose demo          
Connected to database "demo"
Successfully removed 1 large objects from database "demo".
```

Une donnée orpheline est considérée comme telle dès que son OID n'apparaît dans
aucune colonne `oid` de la base de données. Or, avec la modification du type de
la colonne `content`, tous les documents stockés dans la table `pg_largeobject`
sont nettoyés automatiquement, détruits à jamais.

```sql
SELECT content, lo_get(content, 0, 10) FROM wallet;
-- ERROR: large object 16811 does not exist
```

--- 

## Conclusion

Les confusions peuvent être nombreuses avec la conversion implicite d'un type
vers un autre. Les développeurs de PostgreSQL sont parvenus à construire un
système fiable pour interdire les transtypages illogiques, en demandant aux
utilisateurs d'adapter leurs requêtes avec un meilleur usage des types pour
chacune des données à manipuler.

Les exemples cités dans cet article sont de véritables expériences de terrain et
je remercie mon collègue [Philippe][12] d'avoir identifié la faiblesse du typage
`oid` dans le cadre d'une maintenance par `vacuumlo`, et d'avoir rendu possible
ce partage au plus grand nombre.

[12]: https://github.com/beaud76