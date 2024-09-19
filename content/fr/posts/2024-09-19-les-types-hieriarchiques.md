---
title: "Les types hiérarchiques"
categories: [postgresql]
tags: [developpement]
date: "2024-09-19 13:20:00 +0200"
translationKey: "hierachical-data-types"
---

Bien que la norme SQL définisse un ensemble de règles pour que les systèmes de bases
de données puissent être interchangeables, il existe de petites singularités dans la
nature. À ce titre, le type de données `hierarchyid` fourni par SQL Server est un
exemple flagrant. Si vous êtes amené à basculer vers PostgreSQL, deux solutions s'offrent
à vous.

Une première et plus simple consiste à lier chaque nœud à son parent à l'aide d'une nouvelle
colonne `parentid` et d'y appliquer une contrainte de clé étrangère. Une autre approche,
plus complète, consiste à utiliser l'extension `ltree`. Cet article traite de ce dernier
cas.

<!--more-->

---

## À la recherche de ses descendants

Conçu pour représenter une [relation hiérarchique][1] sous la forme d'un arbre binaire, le
type `hierarchyid` a la particularité de stocker la liste des nœuds successifs jusqu'à
la racine dans une seule colonne. Ainsi, le nœud `/1/1/2/` représente un nœud de niveau
3, enfant du nœud `/1/1/`, lui-même enfant du nœud `/1/`, lui-même enfant de la racine `/`.

[1]: https://learn.microsoft.com/en-us/sql/relational-databases/hierarchical-data-sql-server

Plusieurs méthodes sont fournies avec le langage Transact-SQL pour manipuler les données et
toutes parcourent l'arbre binaire pour en extraire rapidement l'information souhaitée sans
avoir à joindre les nœuds de la table entre eux.

- [`ToString()`][2] : retourne la représentation textuelle du nœud courant.
- [`GetLevel()`][3] : retourne le niveau de profondeur du nœud courant.
- [`GetAncestor(n)`][4] : retourne le nœud de niveau `n` dans l'arbre.
- [`GetDescendant(c1, c2)`][5] : retourne un nouveau nœud enfant entre deux nœuds.

[2]: https://learn.microsoft.com/en-us/sql/t-sql/data-types/tostring-database-engine
[3]: https://learn.microsoft.com/en-us/sql/t-sql/data-types/getlevel-database-engine
[4]: https://learn.microsoft.com/en-us/sql/t-sql/data-types/getancestor-database-engine
[5]: https://learn.microsoft.com/en-us/sql/t-sql/data-types/getdescendant-database-engine

L'extension [ltree][6], disponible depuis le paquet `contrib` de PostgreSQL, est aussi complète,
voire plus, que le type `hierarchyid`. Elle fournit un type de données complexe, nommé `ltree`,
et permet de stocker des labels de 1 000 caractères alphanumériques séparés par des points. Le
chemin (`path`) ainsi constitué, peut lui-même contenir jusqu'à 65 635 labels.

[6]: https://www.postgresql.org/docs/current/ltree.html

```sql
CREATE EXTENSION ltree;

CREATE TABLE locations (
    id ltree PRIMARY KEY,
    location text NOT NULL,
    locationtype text NOT NULL
);

INSERT INTO locations VALUES
    ('1', 'Earth', 'Planet'),
    ('1.1', 'Europe', 'Continent'),
    ('1.1.1', 'France', 'Country'),
    ('1.1.1.1', 'Paris', 'City'),
    ('1.1.2', 'Spain', 'Country'),
    ('1.1.2.1', 'Madrid', 'City'),
    ('1.2', 'South-America', 'Continent'),
    ('1.2.1', 'Brazil', 'Country'),
    ('1.2.1.1', 'Brasilia', 'City'),
    ('1.2.2', 'Bahia', 'State'),
    ('1.2.2.1', 'Salvador', 'City'),
    ('1.3', 'Antarctica', 'Continent'),
    ('1.3.1', 'McMurdo Station', 'City');
```

Obtenir le niveau de profondeur d'un nœud devient trivial avec la fonction `nlevel()`
fournie par l'extension `ltree`.

```sql
SELECT id, location, locationtype, nlevel(id) AS level
  FROM locations ORDER BY id;
```
```console
   id    |    location     | locationtype | level
---------+-----------------+--------------+-------
 1       | Earth           | Planet       |     1
 1.1     | Europe          | Continent    |     2
 1.1.1   | France          | Country      |     3
 1.1.1.1 | Paris           | City         |     4
 1.1.2   | Spain           | Country      |     3
 1.1.2.1 | Madrid          | City         |     4
 1.2     | South-America   | Continent    |     2
 1.2.1   | Brazil          | Country      |     3
 1.2.1.1 | Brasilia        | City         |     4
 1.2.2   | Bahia           | State        |     3
 1.2.2.1 | Salvador        | City         |     4
 1.3     | Antarctica      | Continent    |     2
 1.3.1   | McMurdo Station | City         |     3
 2.1.1   | unknown         | State        |     3
(14 rows)
```

Une autre méthode nommée `subpath()` permet de récupérer une partie du chemin d'un nœud.
Voyons comment obtenir le nœud parent de chaque nœud de la table.

```sql
SELECT id, location, locationtype, subpath(id, 0, nlevel(id) - 1) AS parentid
  FROM locations ORDER BY id;
```
```console
   id    |    location     | locationtype | parent
---------+-----------------+--------------+--------
 1       | Earth           | Planet       |
 1.1     | Europe          | Continent    | 1
 1.1.1   | France          | Country      | 1.1
 1.1.1.1 | Paris           | City         | 1.1.1
 1.1.2   | Spain           | Country      | 1.1
 1.1.2.1 | Madrid          | City         | 1.1.2
 1.2     | South-America   | Continent    | 1
 1.2.1   | Brazil          | Country      | 1.2
 1.2.1.1 | Brasilia        | City         | 1.2.1
 1.2.2   | Bahia           | State        | 1.2
 1.2.2.1 | Salvador        | City         | 1.2.2
 1.3     | Antarctica      | Continent    | 1
 1.3.1   | McMurdo Station | City         | 1.3
 2.1.1   | unknown         | State        | 2.1
(14 rows)
```

Enfin, la recherche des nœuds enfants depuis un nœud donné est possible grâce aux
opérateurs de comparaison spécialisés. Pour favoriser les performances, il est recommandé
de créer un index GIST sur la colonne de clé primaire `id`.

```sql
CREATE INDEX ON locations USING GIST (id);
```

La requête suivante liste toutes les villes d'Europe.

```sql
SELECT l1.*
  FROM locations l1
  JOIN locations l2 ON l1.id <@ l2.id
 WHERE l1.locationtype = 'City' AND l2.location = 'Europe';

```
```console
   id    | location | locationtype
---------+----------+--------------
 1.1.1.1 | Paris    | City
 1.1.2.1 | Madrid   | City
(2 rows)
```

---

## Travailler sous contraintes

La contrainte de clé primaire m'empêche actuellement d'insérer un chemin déjà existant.
Par contre, il est bien possible d'ajouter une nouvelle ligne dont le chemin ne présente
pas d'ancêtre dans la table.

```sql
INSERT INTO locations VALUES ('2.1.1', 'Unknown', 'Continent');
```
```console
INSERT 0 1
```

À ce jeu, SQL Server et PostgreSQL n'ont plus trop de différences, il devient nécessaire
d'ajouter une [colonne supplémentaire][7], nommée `parentid` par exemple, pour ajouter la
contrainte de clé étrangère. La requête suivante réutilise la fonction `subpath()` en
s'assurant qu'une valeur nulle soit insérée s'il s'agit d'un nœud racine.

[7]: https://learn.microsoft.com/en-us/sql/relational-databases/hierarchical-data-sql-server#enforce-a-tree

```sql
DELETE FROM locations WHERE id <@ '2';

ALTER TABLE locations ADD COLUMN parentid ltree
    REFERENCES locations (id)
    GENERATED ALWAYS AS (
        CASE subpath(id, 0, nlevel(id) - 1)
            WHEN '' THEN null
            ELSE subpath(id, 0, nlevel(id) - 1)
        END
    ) STORED;
```

À présent, dès qu'une nouvelle ligne est insérée, la contrainte de clé étrangère est
automatiquement vérifiée.

```sql
INSERT INTO locations VALUES ('2.1.1', 'Unknown', 'Continent');
```
```console
ERROR:  insert or update on table "locations" violates
        foreign key constraint "locations_parentid_fkey"
DETAIL:  Key (parentid)=(2.1) is not present in table "locations".
```

---

## Une solution parmi d'autres

La méthode de stockage des données hiérarchiques sous forme de chemin est une solution
ingénieuse et disponible facilement avec PostgreSQL. Cependant, il s'agit d'une extension
du langage SQL et chaque moteur peut proposer une implémentation qui peut radicalement
changer d'un système à l'autre.

Comme je l'indiquais en introduction, la réponse universelle reste la reconstruction d'une
relation hiériarchique à l'aide d'une requête récursive et la syntaxe `WITH RECURSIVE`. Pour
reprendre l'exemple de la table `locations`, la liste des villes présentes en Europe pourrait
être obtenue de la manière suivante.

<!--
CREATE TABLE locations (
    id bigint PRIMARY KEY,
    parentid bigint REFERENCES locations (id),
    location text NOT NULL,
    locationtype text NOT NULL
);

INSERT INTO locations VALUES
    (1, null, 'Earth', 'Planet'),
    (2, 1, 'Europe', 'Continent'),
    (3, 2, 'France', 'Country'),
    (4, 3, 'Paris', 'City'),
    (5, 2, 'Spain', 'Country'),
    (6, 5, 'Madrid', 'City'),
    (7, 2, 'Portugal', 'Country'),
    (8, 7, 'Lisbon', 'City'),
    (9, 1, 'South-America', 'Continent'),
    (10, 9, 'Brazil', 'Country'),
    (11, 10, 'Brasilia', 'City'),
    (12, 10, 'Bahia', 'State'),
    (13, 12, 'Salvador', 'City'),
    (14, 1, 'Antarctica', 'Continent'),
    (15, 14, 'McMurdo Station', 'City');
-->

```sql
WITH RECURSIVE loc AS (
    SELECT id, parentid, location, locationtype
      FROM locations
     WHERE location = 'Europe'
     UNION ALL
    SELECT l.id, l.parentid, l.location, l.locationtype
      FROM locations l
      JOIN loc r ON l.parentid = r.id
)
SELECT * FROM loc
 WHERE locationtype = 'City';
```
```console
 id | parentid | location | locationtype
----+----------+----------+--------------
  4 |        3 | Paris    | City
  6 |        5 | Madrid   | City
(2 rows)
```
