---
title: "La meilleure chose depuis le pain en tranches"
slug: toast-la-meilleure-chose-depuis-le-pain-en-tranches
date: 2020-10-12
categories: [postgresql]
---

Je me souviens de cette époque où j'ai été confronté pour la première fois à la 
notion de TOAST avec PostgreSQL. Je trouvais la dénomination amusante, bien 
qu'étrange, pour nommer le mécanisme de stockage étendu « _The Oversized-Attribute 
Storage Technique_ ». Bien que l'acronyme ne fasse pas de référence culinaire,
on peut retrouver dans la [documentation officielle][1] qu'il s'agissait d'une 
petite révolution et de la meilleure chose depuis le pain en tranches.

[1]: https://www.postgresql.org/docs/13/storage-toast.html

<!--more-->

![Envie d'une tranche de pain ?](/img/fr/2020-10-12-toasted-bread.jpg)

---

## Le seuil de dépassement

Depuis le tout début du projet PostgreSQL, les lignes (ou _tuples_) d'une table 
sont ajoutées dans un ensemble de pages qui composent une table dès qu'un espace 
libre est disponible. Un tuple de données ne peut être écrit dans plusieurs pages, 
en opposition à ce que propose Oracle avec la notion de chaînage de lignes 
(_[row chaining][2]_).

[2]: http://www.orafaq.com/wiki/Chained_row

En version 8.0 apparaît la technique TOAST. Celle-ci est transparente et garantit 
que les champs de tailles variables comme `text`, `jsonb`, `hstore` ou `bytea` 
puissent être écrits en dehors des pages de 8 ko afin de lever la contrainte de 
stockage. On peut résumer les quelques éléments théoriques :

* La taille d'un tel champ peut atteindre la taille maximale de 1 Go ;
* Une [compression LZ][3] est éventuellement réalisée pour éviter de _toaster_
la donnée en dehors de la relation principale ;
* PostgreSQL découpe la donnée en morceaux de taille équivalente, appelés _chunks_ 
et les écrit dans une table `pg_toast_xxxxx` indexée ;
* Un pointeur vers l'adresse des _chunks_ est renseigné dans la ligne principale 
en lieu et place de la donnée.

[3]: https://fr.wikipedia.org/wiki/LZ77_et_LZ78

Prenons une table `people` avec une clé primaire et une colonne `jsonb` pour y 
stocker des données dénormalisées. (Oui. Le NoSQL est partout.)

```sql
CREATE TABLE people (
  id BIGINT GENERATED ALWAYS AS IDENTITY,
  details jsonb,
  PRIMARY KEY (id)
);
```

Plus haut, je précisais que la compression est éventuelle : il s'agit de la 
stratégie par défaut avec un mode _extended_ pour le stockage de la colonne 
`details`. Dans cet article, je désactive la compression en changeant le 
[typstorage][4] pour m'assurer que le mécanisme se déclenche correctement. 
Dans un cas réel de production, cette option peut apporter un léger gain en 
vitesse d'exécution au détriment d'une consommation en espace disque plus 
conséquente.

[4]: https://www.postgresql.org/docs/13/catalog-pg-type.html

```sql
ALTER TABLE people ALTER COLUMN details SET STORAGE EXTERNAL;
```

* `p` (plain) : la valeur doit être stockée normalement ;
* `e` (external) : la valeur peut être stockée dans une relation « secondaire » 
* `m` (main) : la valeur peut être stockée compressée sur place ;
* `x` (extended) : la valeur peut être stockée compressée sur place ou stockée 
dans une relation « secondaire ».

À la création de la table `people`, on constate qu'une deuxième relation est 
automatiquement provisionnée pour accueillir les données larges : il s'agit de 
`pg_toast_32865`, que l'on identifie à l'aide de la table système `pg_class`.

```sql
SELECT reltoastrelid::regclass relname,
       pg_relation_filepath(reltoastrelid) filepath,
       pg_size_pretty(pg_relation_size(reltoastrelid)) relsize
  FROM pg_class WHERE relname = 'people';

--          relname         |     filepath     | relsize 
-- -------------------------+------------------+-----------
--  pg_toast.pg_toast_32865 | base/13393/32868 | 0 bytes
```

Dans l'exemple qui suit, je souhaite démontrer que ce mécanisme ne se déclenche 
qu'au-delà d'un certain seuil. Si une ligne est plus grande que la constante 
interne `TOAST_TUPLE_THRESHOLD`, le moteur tentera de réduire sa taille à l'aide 
de la compression. Si la taille est toujours supérieure à la variable de stockage 
`TOAST_TUPLE_TARGET`, la donnée sera alors déportée dans une table secondaire. 
Par défaut, ces deux seuils valent à peu près 2 ko.

J'utilise l'extension [postgresql_faker][5] pour alimenter ma table avec des 
noms et des prénoms aléatoires au format JSON. Une idée originale de Damien 
Clochard, contributeur de l'incroyable extension [pg_anonymizer][6]. C'est fun, 
rapide et prend en considération la langue de son choix.

[5]: https://gitlab.com/dalibo/postgresql_faker
[6]: https://labs.dalibo.com/postgresql_anonymizer

```sql
SELECT faker.faker('FR_fr');

INSERT INTO people (details) 
SELECT format(
         '{"firstname":"%s","lastname":"%s"}', 
         faker.first_name(), faker.last_name()
       )::json 
FROM generate_series(1,10);

SELECT ctid, pg_size_pretty(pg_column_size(details)::bigint) colsize,
       id, details->>'lastname' lastname, details->>'firstname' firstname       
  FROM people;

--   ctid  | colsize  | id | lastname  | firstname  
-- --------+----------+----+-----------+------------
--  (0,1)  | 51 bytes |  1 | Godard    | Jacques
--  (0,2)  | 52 bytes |  2 | Richard   | Martine
--  (0,3)  | 57 bytes |  3 | Lemonnier | Théophile
--  (0,4)  | 51 bytes |  4 | Perrin    | Gérard
--  (0,5)  | 50 bytes |  5 | Alves     | Gilbert
--  (0,6)  | 49 bytes |  6 | Aubry     | Louise
--  (0,7)  | 52 bytes |  7 | Garnier   | Gérard
--  (0,8)  | 49 bytes |  8 | Ruiz      | Cécile
--  (0,9)  | 53 bytes |  9 | Herve     | Stéphanie
--  (0,10) | 51 bytes | 10 | Jacques   | Pierre
```

Les données de la colonne `details` au format JSON ont une taille moyenne de 
52 octets. C'est bien inférieure à la limite de 2 ko, il est juste de penser 
qu'aucune de ces valeurs n'ait été _toastée_ dans la relation secondaire. La 
requête plus haut m'indique que la taille de la relation secondaire est toujours 
nulle.

Procédons à l'ajout d'un commentaire volontairement volumineux pour l'un des 
tuples de ma table. Disons une succession de 1000 mots aléatoires. Nous observons 
à l'aide de la méthode `pg_column_size` que la donnée présente une taille de 10 ko.

```sql
UPDATE people 
   SET details = details || jsonb_build_object(
         'comment', faker.text(1e4::int, '')
       )
 WHERE id = 1;

VACUUM people;
SELECT ctid, pg_size_pretty(pg_column_size(details)::bigint) colsize,
       id, details->>'lastname' lastname, details->>'firstname' firstname       
  FROM people WHERE id = 1;

--   ctid  | colsize  | id | lastname  | firstname  
-- --------+----------+----+-----------+------------
--  (0,11) | 10 kB    |  1 | Godard    | Jacques
```

À l'issue de l'ordre `UPDATE`, la ligne dont l'adresse physique était `(0,1)` 
a été dupliquée dans un nouvel emplacement du même bloc `(0,11)`. Je force un 
`VACUUM` pour nettoyer le bloc afin que la précédente version ne soit plus 
visible par la suite.

Si je consulte la table système `pg_class`, j'observe que le fichier secondaire 
rattaché à notre table a pris du poids. Pour accueillir le commentaire au sujet 
de M. Godard, PostgreSQL a alloué deux blocs de 8 ko, soit 16 ko en tout.

```sql
SELECT reltoastrelid::regclass relname,
       pg_relation_filepath(reltoastrelid) filepath,
       pg_size_pretty(pg_relation_size(reltoastrelid)) relsize
  FROM pg_class WHERE relname = 'people';

--          relname         |     filepath     | relsize 
-- -------------------------+------------------+-----------
--  pg_toast.pg_toast_32865 | base/13393/32868 | 16 kB
```

Nous nous retrouvons avec un fichier de dépassement, réservé aux données 
volumineuses. PostgreSQL parvient à reconstruire silencieusement la ligne 
complète en mettant bout à bout les données stockées dans le fichier principal 
et celles du fichier secondaire. On parle alors de _detoasting_. Une requête 
`SELECT` sur la colonne `people.details` fournira la donnée réelle sans que 
l'utilisateur n'ait connaissance de l'emplacement physique des informations.

---

## Structure du pointeur de TOAST

Comme présenté dans l'introduction, PostgreSQL va devoir maintenir un lien entre 
une ligne et son contenu _toasté_, notamment grâce à un pointeur dont la structure
est encodé sur 18 octets, comme le précise la documentation.

> Allowing for the varlena header bytes, the total size of an on-disk TOAST 
> pointer datum is therefore 18 bytes regardless of the actual size of the 
> represented value.

Ni une ni deux, je saute sur l'extension [pageinspect][8] afin de décoder le 
contenu de la nouvelle ligne `(0,11)` et de voir la représentation de ce fameux 
pointeur. Pour cela, je joins la table système `pg_attribute` et le tableau 
`t_attrs` fourni par la méthode `heap_page_item_attrs()` de l'extension.

[8]: https://www.postgresql.org/docs/13/pageinspect.html

```sql
SET bytea_output = 'hex' ;

SELECT p.t_ctid, pg_size_pretty(length(r.data)::bigint) colsize,
       a.attname, r.data
  FROM heap_page_item_attrs(get_raw_page('people', 0), 'people'::regclass) p
  JOIN LATERAL unnest(p.t_attrs) 
  WITH ORDINALITY AS r(data, attnum) ON true
  JOIN pg_attribute a ON a.attnum = r.attnum 
   AND a.attrelid = 'people'::regclass AND a.attnum > 0
 WHERE t_ctid = '(0,11)';

--  t_ctid | colsize  | attname |                  data                  
-- --------+----------+---------+----------------------------------------
--  (0,11) | 8 bytes  | id      | \x0100000000000000
--  (0,11) | 18 bytes | details | \x011225280000212800006980000064800000
```

La donnée `details` est bien encodée sur 18 octets. Dans le cas qui nous concerne, 
le premier octet `0x01` indique qu'il s'agit bien d'un pointeur d'adresse pour 
une donnée externe, comme l'explique un commentaire dans le fichier 
`src/include/postgres.h` pour la définition de structure `varattrib_1b_e`
([source][9]). 
Dans cette démonstration, la distribution Linux est un Debian (_little endian_) 
et la lecture des octets de données est inversée. Je vous renvoie à l'explication 
du [boutisme][10] (ou _endianness_) si besoin.

[9]: https://doxygen.postgresql.org/structvarattrib__1b__e.html
[10]: https://fr.wikipedia.org/wiki/Boutisme

Pour ne rien vous cacher, mes recherches à ce sujet m'ont amené sur des blogs 
chinois récents où les [explications][11] et [démonstrations][12] ont été très 
instructives. Pour en faire la synthèse, le pointeur se découpe donc en 2 octets 
d'état (_mark bits_) et quatres informations de 4 octets chacune.

[11]: https://translate.google.com/translate?hl=en&sl=zh-CN&tl=en&u=https%3A%2F%2Fzhmin.github.io%2F2020%2F08%2F30%2Fpostgresql-varlena%2F
[12]: https://translate.google.com/translate?hl=en&sl=auto&tl=en&u=https://www.cnblogs.com/6yuhang/p/12045666.html

| Taille | Description | Représentation | Valeur |
|-|-|-|-|
| 1 octet | Bit d'état pour un stockage little-endian | 0x01 | 1 |
| 1 octet | Type du pointeur défini par l'énumération `vartag_external` | 0x12 | 18 |
| 4 octets | Taille de la donnée avec les en-têtes | 0x25280000 | 10277 |
| 4 octets | Taille de la donnée externe sans les en-têtes | 0x21280000 | 10273 |
| 4 octets | Identifiant unique à l'intérieur de la table TOAST | 0x69800000 | 32873 |
| 4 octets | Identifiant de la table TOAST | 0x64800000 | 32868 |

L'ensemble de ces éléments nous fournit à présent l'emplacement de la donnée à 
décoder. Sans surprise, la relation ayant l'identifiant `32868` s'avère être le 
fichier secondaire de la table `people`. Toutes les relations TOAST présentent 
un identifiant, une séquence et une donnée binaire, le tout parfaitement indexé 
pour garantir les meilleures performances d'accès lors de la reconstitution de 
la ligne.

```sql
select 32868::regclass;

--         regclass
-- -------------------------
--  pg_toast.pg_toast_32865

\d pg_toast.pg_toast_32865

-- TOAST table "pg_toast.pg_toast_32865"
--    Column   |  Type   
-- ------------+---------
--  chunk_id   | oid
--  chunk_seq  | integer
--  chunk_data | bytea
-- Owning table: "public.people"
-- Indexes:
--   "pg_toast_32865_index" PRIMARY KEY, btree (chunk_id, chunk_seq)

```

À l'aide du deuxième identifiant interne `32873`, communément appelé `chunk_id`, 
nous sommes libre de consulter le contenu de la relation secondaire avec une 
requête classique. Évidemment, cette relation n'est jamais manipulée directement 
mais elle nous permet de diagnostiquer l'état d'un bloc de données si un message 
de corruption s'est jeté à l'écran d'un utilisateur.

```sql
SELECT ctid, chunk_id, chunk_seq,
       pg_size_pretty(octet_length(chunk_data)::bigint) chunk_size,
       substring(chunk_data for 10) preview
  FROM pg_toast.pg_toast_32865
 WHERE chunk_id = 32873;

--  ctid  | chunk_id | chunk_seq | chunk_size |        preview         
-- -------+----------+-----------+------------+------------------------
--  (0,1) |    32873 |         0 | 1996 bytes | \x03000020070000800800
--  (0,2) |    32873 |         1 | 1996 bytes | \x20646f63746575722e20
--  (0,3) |    32873 |         2 | 1996 bytes | \x656e64656d61696e206c
--  (0,4) |    32873 |         3 | 1996 bytes | \xa7612070726f6d656e65
--  (1,1) |    32873 |         4 | 1996 bytes | \x204dc3a96d6f69726520
--  (1,2) |    32873 |         5 | 293 bytes  | \x6c6572206e6f74652e20
```

Une donnée est découpée en petites tranches de 2 ko environ et sa taille complète 
renseignée au sein du pointeur, permet à PostgreSQL d'appliquer un _offset_ de 
lecture au moment de l'opération de _detoasting_. Dans l'exemple ci-dessus, la 
somme des six _chunks_ correspond bien à la taille de 10 273 octets maintenue 
par le pointeur.

## Conclusion

Dans cet article, je voulais comprendre le fonctionnement interne du stockage
étendu et ce qui se cachait derrière les fichiers secondaires `pg_toast_xxxxx`. 
Des outils simples comme le catalogue (`pg_class`, `pg_attribute`) et l'extension 
`pageinspect` ont suffi à remonter jusqu'au pointeur d'une donnée large et de 
retrouver l'adresse de son stockage dans une relation TOAST.

Ce mécanisme encourage l'emploi des champs de taille variable, si l'on ne connait 
pas les besoins métiers au début d'un projet. On bénéficie des fonctionnalités 
de compression voire de dépassement si le seuil est atteint. Malgré ces avantages, 
nous ne sommes pas à l'abri d'une forte fragmentation lors de mises à jour 
intensives de ces données _toastées_. Un `VACUUM FULL` peut devenir la seule 
solution de maintenance lorsque l'on ne maîtrise plus leur taille sur les disques.

Également, le choix de stocker des données volumineuses apporte son lot de 
complexité avec des algorithmes d'indexation à connaître et maîtriser. On peut
parler du HASH ou du [GiST][13] pour s'assurer des performances adaptées, et aussi 
du [GIN][14], dans le cadre de recherche spécialisée JSON ou peut-être pour faire 
de la recherche plein-texte.

[13]: https://www.postgresql.org/docs/13/gist-implementation.html
[14]: https://www.postgresql.org/docs/13/gin-implementation.html