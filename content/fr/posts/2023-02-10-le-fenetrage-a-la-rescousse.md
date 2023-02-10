---
title: "Le fenêtrage à la rescousse"
categories: [postgresql]
tags: [developpement]
date: 2023-02-10
---

PostgreSQL propose un certain nombre de fonctions qui permettent de calculer des
valeurs agrégées ou relatives sur un ensemble de lignes qui se situent dans une
« fenêtre » autours de la ligne courante.  En utilisant de telles fonctions,
n'importe qui peut créer des requêtes plus avancées et plus efficaces pour
l'analyse de leur base de données.

Depuis plusieurs semaines, je contribue à un projet de conversion de modèles de
données vers PostgreSQL, appelé [db_migrator][1]. À cette occasion, j'ai
(re)découvert la puissance de ces [fonctions de fenêtrage][2] avec le langage
SQL. Dans cet article, je reviens sur un [cas concret][3] de transformation des
bornes supérieures d'une table partitionnée en tableau de valeur.

[1]: https://github.com/cybertec-postgresql/db_migrator
[2]: https://www.postgresql.org/docs/current/functions-window.html
[3]: https://github.com/cybertec-postgresql/db_migrator/pull/11

<!--more-->

---

## À travers une fenêtre

On ne va pas se le cacher, l'utilisation d'une fenêtre dans une requête n'est
(vraiment) pas fréquente. Le fenêtrage est particulièrement utile pour effectuer
des analyses de données en décalage temporel, telles que les totaux cumulatifs,
les moyennes mobiles, les tendances, etc.

Les fonctions de fenêtrage les plus couramment utilisées dans PostgreSQL
sont `first_value()`, `last_value()`, `rank()`, `row_number()` et `lag()`.
Ces fonctions peuvent être combinées avec des fonctions d'agrégation telles que
`sum()`, `avg()`, `count()`, `min()` et `max()` pour produire des résultats
encore plus utiles.

<!--
DROP TABLE IF EXISTS partitions;
CREATE TABLE partitions (
    table_name text,
    partition_name text,
    upper_bound text,
    position int
);
INSERT INTO partitions VALUES 
    ('tab', 'less_than_10', '10', 1),
    ('tab', 'less_than_20', '20', 2),
    ('tab', 'less_than_30', '30', 3),
    ('tab', 'less_than_40', '40', 4),
    ('tab', 'less_than_max', 'MAXVALUE', 5);
-->

Prenons l'exemple de la méthode `first_value()` qui permet d'identifier la
première ligne de la fenêtre rattachée à chaque ligne. Avec le cas concret du
partitionnement, on souhaite connaître la première partition définie pour la
table pour chaque ligne d'une table nommée `partitions` :

```sql
SELECT table_name, partition_name, upper_bound, position,
       first_value(partition_name) OVER (
           PARTITION BY table_name 
           ORDER BY position
       ) AS first_partition 
FROM partitions;
```
```text
 table_name | partition_name | upper_bound | position | first_partition 
------------+----------------+-------------+----------+-----------------
 tab        | less_than_10   | 10          |        1 | less_than_10
 tab        | less_than_20   | 20          |        2 | less_than_10
 tab        | less_than_30   | 30          |        3 | less_than_10
 tab        | less_than_40   | 40          |        4 | less_than_10
 tab        | less_than_max  | MAXVALUE    |        5 | less_than_10
```

Une fonction de fenêtrage est employée en conjonction avec la clause `OVER` pour
spécifier les limites de la fenêtre, en déterminant la colonne commune aux
lignes sur lesquelles la fonction de fenêtrage s'applique. Ici, la fenêtre
regroupe les données de partitionnement selon le nom de la table (`table_name`)
en les triant avec la clause `ORDER BY`.

Une fenêtre se déplace pour chaque ligne, en élargissant ses bornes en fonction
des nouvelles lignes qu'elle parcourt dans l'ordre de tri des données. Si on
souhaite récupérer la dernière partition définie pour la table de chaque ligne,
il est nécessaire d'**inverser le tri** de la fenêtre, afin de démarrer la
lecture par le bas jusqu'à la ligne courante et de **trier à nouveau** le
résultat.

```sql
SELECT table_name, partition_name, upper_bound, position,
       first_value(partition_name) OVER (
           PARTITION BY table_name 
           ORDER BY position DESC
       ) AS last_partition 
FROM partitions ORDER BY position;
```
```text
 table_name | partition_name | upper_bound | position | last_partition 
------------+----------------+-------------+----------+----------------
 tab        | less_than_10   | 10          |        1 | less_than_max
 tab        | less_than_20   | 20          |        2 | less_than_max
 tab        | less_than_30   | 30          |        3 | less_than_max
 tab        | less_than_40   | 40          |        4 | less_than_max
 tab        | less_than_max  | MAXVALUE    |        5 | less_than_max
```

---

## Déterminer la borne inférieure

Avec Oracle ou même MySQL, le partitionnent par intervalles ne prend en compte
que la borne supérieure pour répartir les données dans les partitions. Ainsi, la
création d'une table partitionnée est semblable à l'exemple suivant :

```sql
CREATE TABLE tab (
    id INT NOT NULL,
    junk TEXT NOT NULL
)
PARTITION BY RANGE (id) (
    PARTITION less_than_10 VALUES LESS THAN (10),
    PARTITION less_than_20 VALUES LESS THAN (20),
    PARTITION less_than_30 VALUES LESS THAN (30),
    PARTITION less_than_40 VALUES LESS THAN (40),
    PARTITION less_than_max VALUES LESS THAN MAXVALUE
);
```

PostgreSQL est plus strict sur la définition des partitions de type `RANGE` avec
l'utilisation des bornes inférieures et supérieures, comme ceci :

```sql
CREATE TABLE tab (
    id INT NOT NULL,
    junk TEXT NOT NULL
)
PARTITION BY RANGE (id);

CREATE TABLE less_than_10 
    PARTITION OF tab FOR VALUES FROM (MINVALUE) TO (10);
CREATE TABLE less_than_20 
    PARTITION OF tab FOR VALUES FROM (10) TO (20);
CREATE TABLE less_than_30 
    PARTITION OF tab FOR VALUES FROM (20) TO (30);
CREATE TABLE less_than_40 
    PARTITION OF tab FOR VALUES FROM (30) TO (40);
CREATE TABLE less_than_max 
    PARTITION OF tab FOR VALUES FROM (40) TO (MAXVALUE);
```

Avec le jeu de données précédent, il devient nécessaire de faire le
rapprochement entre une partition et celle qui la précède pour reconstruire les
bornes inférieure et supérieure. La fonction de fenêtrage `lag()` permet
justement d'extraire la donnée d'une autre ligne placée au-dessous d'elle dans
la fenêtre courante.

```text
lag (value anycompatible [, offset integer [, default anycompatible ]]) 
   → anycompatible
```

> Renvoie `value` évaluée à la ligne qui se trouve à `offset` lignes avant la
> ligne actuelle dans la fenêtre ; si une telle ligne n'existe pas, renvoie
> `default` à la place.

La requête suivante répond à ce problème :

```sql
SELECT table_name, partition_name, 
       ARRAY[
           lag(upper_bound, 1, 'MINVALUE') OVER (
               PARTITION BY table_name 
               ORDER BY position
           ),
           upper_bound
       ]::text[] as boundaries
FROM partitions;
```
```text
 table_name | partition_name |  boundaries   
------------+----------------+---------------
 tab        | less_than_10   | {MINVALUE,10}
 tab        | less_than_20   | {10,20}
 tab        | less_than_30   | {20,30}
 tab        | less_than_40   | {30,40}
 tab        | less_than_max  | {40,MAXVALUE}
```

Une autre requête avec `first_value()` avait été employée avant que `lag()`
n'ait été proposée par Laurenz Albe dans la forme définitive de mes travaux.
Pour un résultat équivalent, elle a été jugée moins adaptée en s'appuyant
inutilement sur des clauses plus poussées telles que `RANGE BETWEEN` et
`EXCLUDE`. Je vous laisse apprécier la syntaxe complète.

[4]: https://www.postgresql.org/docs/current/sql-expressions.html#SYNTAX-WINDOW-FUNCTIONS

```sql
SELECT table_name, partition_name,
       ARRAY[
           coalesce(first_value(upper_bound) OVER (
              PARTITION BY table_name ORDER BY position
              RANGE BETWEEN 1 PRECEDING AND CURRENT ROW
              EXCLUDE CURRENT ROW
           ), 'MINVALUE'),
           upper_bound
       ]::text[] as boundaries
FROM partitions;
```

---

## Conclusion

Le fenêtrage n'est pas évident à se représenter mentalement, d'autant plus que
les cas concrets et pertinents ne se rencontrent pas fréquemment. Sans pour
autant en maîtriser les subtilités, il est utile d'en connaître la finalité, ou
tout du moins l'existence. Il aurait été tentant de faire des jointures, des CTE
ou des sous-requêtes mais en payant le prix fort d'une lisibilité amoindrie et
de potentielles barrières à l'optimisation.