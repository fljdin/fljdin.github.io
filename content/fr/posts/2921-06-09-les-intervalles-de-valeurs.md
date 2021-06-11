---
title: "Les intervalles de valeurs"
categories: [postgresql]
tags: [developpement]
date: 2021-06-09
aliases: 
  - "/2021/05/09/les-intervalles-de-valeurs/"
---

Ce mois-ci, je vous propose de réviser un peu le langage SQL en l'appliquant pour
des cas d'usage assez fréquents qui mettent en scène des types temporels, notamment
les intervalles de dates. Ce sera l'occasion également de revenir sur l'implémentation
très originale qu'en a fait PostgreSQL avec les types d'intervalle de valeurs, ou 
_[range types][1]_ dans la documentation.

[1]: https://www.postgresql.org/docs/13/rangetypes.html

<!--more-->

---

Les intervalles de valeurs sont des types dits complexes, au même titre que les 
[tableaux][2], le [JSON][3] ou les [types géométriques][4]. Chacun propose une
réponse plus adaptée à un problème donné, bien plus confortable que les types 
numériques, temporels ou textuels présents dans tous les sytèmes de bases de
données.

[2]: https://www.postgresql.org/docs/13/arrays.html
[3]: https://www.postgresql.org/docs/13/datatype-json.html
[4]: https://www.postgresql.org/docs/13/datatype-geometric.html

Par défaut, PostgreSQL supporte les intervalles de types numériques (`int4`, `int8`
et `numeric`), horodatés (`timestamp` avec sans _timezone_) et datés (`date`).
Pour l'exemple, nous pouvons prendre le dernier de ces trois types pour répondre 
à la question suivante : « Lesquels de mes salariés (dans un table _staff_) est
en activité aujourd'hui ? »

Mon [jeu de données][sample] présente deux types de contrat de travail, durée 
déterminée et durée indéterminée, il faut donc que je gère les bornes supérieures
pouvant être nulles. En l'absence d'intervalle de valeurs, il est possible de
définir deux colonnes de types `date` avec une série de condition sur le début 
et la fin de contrat d'un⋅e salarié⋅e, comme suit :

[sample]: https://gist.github.com/fljdin/293984e0f3e55817257cf65d1bb85e5b

```sql
SELECT id, name, start, finish FROM staff
 WHERE current_date BETWEEN start AND finish
    OR (current_date >= start AND finish IS NULL);
```
```text
 id |   name   |   start    |   finish   
----+----------+------------+------------
  1 | Élodie   | 2020-05-01 | 
  3 | Stéphane | 2021-01-04 | 2021-07-01
  5 | Martine  | 2021-02-01 | 
  6 | Philippe | 2021-02-20 | 2021-07-02
  7 | Jean     | 2021-06-01 | 
```

Ici, nous cherchons donc à retrouver les lignes dont la date du jour `current_date`
est comprise **dans un intervalle** borné par deux dates. Ces deux colonnes peuvent
se fusionner en un type dédié à l'aide de la fonction `daterange()`. Son troisième 
argument correspond à l'inclusion de valeurs des bornes basses et hautes au sein
de l'intervalle. Dans le cas de notre table _staff_, les deux bornes sont incluses.

```sql
SELECT name, start, finish, daterange(start, finish, '[]') AS period
  FROM staff WHERE id IN (1,2);
```
```text
  name  |   start    |   finish   |         period          
--------+------------+------------+-------------------------
 Élodie | 2020-05-01 |            | [2020-05-01,)
 Louise | 2021-01-04 | 2021-02-25 | [2021-01-04,2021-02-26)
```

Ainsi, il devient plus aisé d'écrire la recherche des salariés actifs à l'aide 
de l'[opérateur][5] d'inclusion `@>` sur ce nouveau champ. Dans le cas d'un 
contrat à durée indéterminée, la borne haute avec une valeur nulle représente 
l'infini et sera parfaitement interprétée par la clause d'inclusion de notre 
recherche.

[5]: https://www.postgresql.org/docs/13/functions-range.html#RANGE-OPERATORS-TABLE

```sql
SELECT id, name, period FROM staff 
 WHERE period @> current_date;
```
```text
 id |   name   |         period          
----+----------+-------------------------
  1 | Élodie   | [2020-05-01,)
  3 | Stéphane | [2021-01-04,2021-07-02)
  5 | Martine  | [2021-02-01,)
  6 | Philippe | [2021-02-20,2021-07-03)
  7 | Jean     | [2021-06-01,)
```

Une variante plus poussée serait de demander la liste des salariés pleinement 
actifs durant le mois de mars. L'opérateur est tout à fait capable de déterminer
si l'un des deux intervalles est inclus dans le second.

```sql
SELECT id, name, period FROM staff
 WHERE period @> daterange('2021-03-01', '2021-04-01');
```
```text
 id |   name   |         period          
----+----------+-------------------------
  1 | Élodie   | [2020-05-01,)
  3 | Stéphane | [2021-01-04,2021-07-02)
  5 | Martine  | [2021-02-01,)
  6 | Philippe | [2021-02-20,2021-07-03)
```

Il peut être possible que nous cherchions également à comparer deux intervalles,
par exemple pour le calcul d'une intersection ou la recherche de chevauchement.
Prenons le nouveau problème suivant : « Quels sont les salariés qu'Édouard est
susceptible d'avoir connu durant la durée de son contrat de travail ? »

Dans ce cas de figure, nous cherchons le chevauchement entre les dates de début
et de fin de contrat entre deux ensembles. Les requêtes suivantes sont 
équivalentes afin de comprendre ce que réalise l'opérateur `&&` entre deux
intervalles.

```sql
SELECT s1.id, s1.name FROM staff s1 JOIN staff s2 
    ON (s1.start <= s2.finish OR s2.finish IS NULL)
   AND (s1.finish >= s2.start OR s1.finish IS NULL)
 WHERE s1.name <> s2.name AND s2.name = 'Édouard';
```

```sql
SELECT s1.id, s1.name FROM staff s1 JOIN staff s2
    ON s1.period && s2.period
 WHERE s1.name <> s2.name AND s2.name = 'Édouard';
```
```text
 id |   name   
----+----------
  1 | Élodie
  3 | Stéphane
  5 | Martine
  6 | Philippe
  7 | Jean
```

---

Au délà des opérateurs qui permettent de réduire notre ensemble de données, il
existe également une série de [fonctions dédiées][6] aux intervalles comme celle
citée plus haut, `daterange()`. Grâce à certaines d'entre elles, il devient possible
de répondre à une question plus large que la première de cet article, à savoir :
« Quels salariés font ou feront partie de mes effectifs à compter d'aujourd'hui ? »

[6]: https://www.postgresql.org/docs/13/functions-range.html#RANGE-FUNCTIONS-TABLE

Les méthodes `upper()` et `upper_inf()` permettent de traiter l'intervalle sur la
seule borne haute comme une simple date, respectivement l'une extrait la dernière
date de l'intervalle, quant à l'autre, elle détermine si la borne haute correspond
à l'infini (et retourne un `bool`). Les deux expressions suivantes sont ainsi
équivalentes.


```sql
SELECT id, name, start, finish FROM staff
 WHERE current_date < finish OR finish IS NULL;
```
```sql
SELECT id, name, period FROM staff
 WHERE current_date < upper(period) OR upper_inf(period);
```
```text
 id |   name   |         period          
----+----------+-------------------------
  1 | Élodie   | [2020-05-01,)
  3 | Stéphane | [2021-01-04,2021-07-02)
  5 | Martine  | [2021-02-01,)
  6 | Philippe | [2021-02-20,2021-07-03)
  7 | Jean     | [2021-06-01,)
  9 | Lucas    | [2021-07-01,2021-09-01)
 10 | Mickaël  | [2021-07-01,)
```

À partir de la version 14, actuellement en [beta1] au moment où j'écris ces lignes,
il sera possible de réaliser des aggrégations d'ensemble sur les intervalles de
valeurs. Les [méthodes][7] `range_agg()` et `range_intersect_agg()` ont été pensées 
pour les requêtes de regroupement avec `GROUP BY` à l'image de la fonction
`range_merge()` et de l'opérateur `*`, respectivement l'union et l'intersection 
des données. Ces fonctions ont vu le jour grâce au support des multi-intervalles 
publié en [décembre dernier][8].

[beta1]: https://www.postgresql.org/about/news/postgresql-14-beta-1-released-2213/
[7]: https://www.postgresql.org/docs/14/functions-aggregate.html
[8]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=6df7a9698bb036610c1e8c6d375e1be38cb26d5f

La requête suivante permet de résoudre le problème : « Quels jours seraient
propice à un rassemblement général avec l'ensemble des salariés dans un avenir
proche ? »

```sql
SELECT range_intersect_agg(period) FROM staff
 WHERE current_date < upper(period) OR upper_inf(period);
```
```text
   range_intersect_agg   
-------------------------
 [2021-07-01,2021-07-02)
```

Parmi les salariés actuels et futurs, l'intersection de toutes les périodes 
d'activité ne laisse que la date du 1{{< sup >}}er{{< /sup >}} juillet pour 
organiser une rencontre. Ce résultat peut devenir incertain, si un contrat était
interrompu avant la date ou qu'une nouvelle personne venait à rejoindre les
effectifs au-delà de cette date.

```sql
INSERT INTO staff (name, start, finish)
VALUES ('Marie', '2021-08-01', null);

SELECT range_intersect_agg(period) FROM staff
 WHERE current_date < upper(period) OR upper_inf(period);
```
```text
 range_intersect_agg 
---------------------
 empty
```

La valeur `empty` correspond à l'intervalle nul, celui qui ne contient aucune
valeur. Il n'y aurait donc dans notre ensemble de données, aucune date possible
pour faire converger le planning de tout le personnel.

---

## Conclusion

Manipuler les dates en tant qu'intervalles permet de résoudre des situations
cocasses tels que les chevauchements de planning ou les réservations de salle.
Il s'agit d'ailleurs d'un des cas d'usage promu par la [documentation][9], avec 
la gestion des contraintes et de la méthode d'accès [GiST][10] au service de la 
cohérence des données.

[9]: https://www.postgresql.org/docs/13/rangetypes.html#RANGETYPES-CONSTRAINT
[10]: https://www.postgresql.org/docs/13/gist-intro.html

```sql
CREATE TABLE reservation (
    during tsrange,
    EXCLUDE USING GIST (during WITH &&)
);
INSERT INTO reservation VALUES
    ('[2010-01-01 14:45, 2010-01-01 15:45)');
```
```text
ERROR:  conflicting key value violates exclusion constraint
DETAIL:  Key (during)=(["2010-01-01 14:45:00","2010-01-01 15:45:00")) 
         conflicts with existing key 
         (during)=(["2010-01-01 11:30:00","2010-01-01 15:00:00")).
```