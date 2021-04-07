---
title: "Écrire ses tests unitaires en SQL"
date: 2020-05-14 17:30:00 +0200
categories: [postgresql]
tags: [developpement]
---

Je ne suis qu'un piètre développeur et je n'écris pas de tests unitaires. En 
réalité, ce n'est ni ma spécialité ni mon cœur de métier. Et pourtant, ma 
curiosité m'a mené à découvrir bien tardivement la mouvance [TDD][1] dans la 
conception logicielle et la rigueur d'écrire chaque test avant l'implémentation 
d'une fonctionnalité.

Ce fut par hasard et avec grand étonnement, que je suis tombé sur l'extension 
[pgTAP][2] il y a plusieurs mois, et l'idée de la mettre en application sur une 
instance PostgreSQL me hantait. Je vous propose dans cet article d'aborder ce 
_framework_ de tests avec un cas d'usage amusant.

[1]: https://fr.wikipedia.org/wiki/Test_driven_development
[2]: https://pgtap.org/

<!--more-->

---

{{< message >}}
Dans le cadre de ma rapide démonstration, j'utilise un conteneur docker dont le 
Dockerfile provient des [travaux](https://github.com/dalibo/docker-pgtap/blob/master/Dockerfile) 
de Damien Clochard. 
{{< /message >}}


## Appliquons une démarche de développement par les tests

En France, le mois de mai dispose du plus grand nombre de jours fériés, fait 
qu'apprécient grandement les salariés. Comment détermine-t-on en avance la liste 
des jours fériés d'une année ? Le jour courant est-il ou non férié ? Pourrait-on 
appliquer une contrainte de colonne pour qu'aucune date fériée ne soit insérée 
dans une table en base de données ?

Ces questions peuvent être celles qui émergent de la tête d'un développeur ou 
d'un membre de son équipe, et sont ainsi les premières étapes de la conception 
logicielle avec la rédaction de ces dernières sous la forme de tests unitaires. 
Le principe ultime à respecter dans un développement orienté tests (_TDD_) repose 
sur les quelques règles suivantes :

- Écrire un test qui échoue
- Écrire l'implémentation minimale et s'assurer que le test réussisse
- [Réusiner][4] l'ensemble du code (… oui, c'est la traduction du terme _refactorer_)

[4]: https://fr.wikipedia.org/wiki/R%C3%A9usinage_de_code

Fort de vouloir respecter cette boucle vertueuse, je rédige dans un fichier 
`test.sql` mon premier test unitaire. Il s'agit là d'utiliser la méthode 
`has_function()` fournie par pgTAP pour m'assurer qu'une fonction est présente 
dans la base de données.

```sql
-- Nous démarrons une transaction pour l'annuler en fin de test
BEGIN
SELECT plan(1);

-- premier tests
SELECT has_function(
  'is_public_holiday',
  array[ 'date' ],
  'Function is_public_holiday(date) should exist'
);

-- On affiche la synthèse de l'exécution des tests et on annule la transaction 
SELECT * FROM finish();
ROLLBACK;
```

À travers mon conteneur, je lance la commande `pg_prove` nécessaire pour 
l'extension et l'exécution des tests renseignés dans le fichier `test.sql`. Je 
constate bel et bien un test en erreur : la fonction `is_public_holiday` n'existe 
pas encore dans mon cycle de développement.

```text
$ docker exec -it pgdemo pg_prove -U postgres test.sql
test.sql .. 1/1 
# Failed test 1: "Function is_public_holiday(date) should exist"
# Looks like you failed 1 test of 1
test.sql .. Failed 1/1 subtests 

Test Summary Report
-------------------
test.sql (Wstat: 0 Tests: 1 Failed: 1)
  Failed test:  1
Files=1, Tests=1,  1 wallclock secs 
  ( 0.04 usr  0.01 sys +  0.04 cusr  0.01 csys =  0.10 CPU)
Result: FAIL
```

Je m'attèle donc à la rédaction de ma fonction, que j'ajoute dans un nouveau 
fichier `is_public_holiday.sql`. La méthode TDD implique qu'un effort minimal 
soit fourni pour passer le test.

```sql
CREATE OR REPLACE FUNCTION is_public_holiday(day date)
  RETURNS boolean LANGUAGE plpgsql
AS $$
BEGIN
  RETURN false;
END; 
$$;
```

```text
$ docker exec -it pgdemo psql -U postgres -f is_public_holiday.sql
CREATE FUNCTION

$ docker exec -it pgdemo pg_prove -U postgres test.sql
test.sql .. ok   
All tests successful.
Files=1, Tests=1,  0 wallclock secs 
  ( 0.02 usr  0.01 sys +  0.05 cusr  0.01 csys =  0.09 CPU)
Result: PASS
```

## Sommes-nous un jour férié ?

Bien.

Pour dépasser le syndrôme de la page blanche, pourquoi ne pas tenter de s'assurer 
que notre fonction retourne parfaitement la valeur `true` ou `false` selon le jour 
qu'on lui passerait en paramètre ? Écrivons un test pour la date du 
1{{< sup >}}er{{< /sup >}} mai 2020 et un autre pour celle du 12 mai 2020.

```sql
-- [...]
SELECT is(
  is_public_holiday('2020-05-01'::date),
  true,
  '2020-05-01 is a public holiday'
);

SELECT is(
  is_public_holiday('2020-05-12'::date),
  false,
  '2020-05-12 is not a public holiday'
);
--- [...]
```

Lançons à présent les tests.

```text
$ docker exec -it pgdemo pg_prove -U postgres test.sql
test.sql .. 1/3 
# Failed test 2: "2020-05-01 is a public holiday"
#         have: false
#         want: true
# Looks like you failed 1 test of 3
test.sql .. Failed 1/3 subtests 

Test Summary Report
-------------------
test.sql (Wstat: 0 Tests: 3 Failed: 1)
  Failed test:  2
Files=1, Tests=3,  1 wallclock secs
  ( 0.02 usr  0.02 sys +  0.05 cusr  0.01 csys =  0.10 CPU)
Result: FAIL
```

L'un de nos tests est donc en erreur, il faut apporter une évolution à notre 
fonction principale pour tâcher d'y remédier. Je suis partisan du moindre effort, 
une comparaison du mois et du jour de notre date suffira. Je me permets donc le 
luxe d'un `IF` au sein du code.

```sql
BEGIN
  IF extract(month from day) = 5 AND
     extract(day from day) = 1
  THEN
    RETURN true;
  END IF;

  RETURN false;
END;
```

C'est simple, efficace… et subjectivement très mauvais. Le résultat escompté est 
atteint avec 100% des tests réussis. Mais je commence à entrevoir des problèmes 
de maintenance de code. Poussons les tests plus loin.

```text
$ docker exec -it pgdemo psql -U postgres -f is_public_holiday.sql
CREATE FUNCTION

$ docker exec -it pgdemo pg_prove -U postgres test.sql
test.sql .. ok   
All tests successful.
Files=1, Tests=3,  0 wallclock secs
  ( 0.03 usr  0.00 sys +  0.04 cusr  0.02 csys =  0.09 CPU)
Result: PASS
```

## Un peu de réusinage, parbleu !

Non content d'avoir trouvé une solution fiable pour les jours fériés fixes, je 
poursuis avec un nouveau test pour le 1{{< sup >}}er{{< /sup >}} janvier.

```sql
SELECT is(
  is_public_holiday('2020-01-01'::date),
  true,
  '2020-01-01 is a public holiday'
);
```

Et j'ajoute au code de ma fonction `is_public_holiday`, une nouvelle condition 
`IF`. Je me retrouve avec cette immondice, qui me rappelle certaines règles 
logiques issues de (trop) longues procédures stockées PL/SQL, que j'eus croisées 
dans une précédente vie.

```sql
BEGIN
  IF extract(month from day) = 1 AND
     extract(day from day) = 1
  THEN
    RETURN true;
  END IF;

  IF extract(month from day) = 5 AND
     extract(day from day) = 1
  THEN
    RETURN true;
  END IF;

  RETURN false;
END;
```

Mes tests passent correctement mais il est aproprié de s'arrêter sur l'un des 
principes du développement TDD : le _refactoring_, ou l'art de simplifier le 
code pour le rendre plus lisible et maintenable. L'idée est donc de proposer une 
réécriture de notre fonction `is_public_holiday` sans altérer l'état des tests. 
C'est parti !

```sql
-- Type month_day
DROP TYPE IF EXISTS month_day;
CREATE TYPE month_day AS (month int, day int);

-- Function is_public_holiday(date)
CREATE OR REPLACE FUNCTION is_public_holiday(day date)
  RETURNS boolean LANGUAGE plpgsql
AS $$
DECLARE
  m int := extract(month from day);
  d int := extract(day from day);
  holidays month_day[] := array[
    (1,1), (5,1)
  ];
BEGIN
  RETURN (m,d) = ANY (holidays);
END;
$$;
```

Dans cette version améliorée, je prends la décision de créer le type `month_day` 
qui représente le couple mois/jour afin de réaliser des comparaisons ensemblistes 
avec le mot clé `ANY` fourni par le standard SQL. La variable `holidays` devient 
alors mon tableau de références contenant les jours fériés fixes de l'année.

Mes tests restent inchangés pour les dates de 1{{< sup >}}er{{< /sup >}} janvier 
et du 1{{< sup >}}er{{< /sup >}} mai.

```text
$ docker exec -it pgdemo psql -U postgres -f is_public_holiday.sql
DROP TYPE
CREATE TYPE
CREATE FUNCTION

$ docker exec -it pgdemo pg_prove -U postgres test.sql
test.sql .. ok   
All tests successful.
Files=1, Tests=4,  1 wallclock secs
  ( 0.05 usr  0.00 sys +  0.06 cusr  0.01 csys =  0.12 CPU)
Result: PASS
```

Pour m'assurer que tous les jours fériés fixes restants dans une année soient bien 
testés, je peux proposer un nouveau test qui les englobe. Par exemple, pour l'année 
2020 :

```sql
SELECT is( 
  is_public_holiday(x::date),
  true,
  format('%s is as public holiday', x)
) FROM unnest(array[
  '2020-05-08', '2020-07-14', '2020-08-15',
  '2020-11-01', '2020-11-11', '2020-12-25'
    --, '2020-12-26' -- si vous vivez en Alsace-Moselle
]) x;
```

Sans trop de difficulté, et parce que nous avions réalisé avec succès la phase de 
réusinage du code, je peux ajouter l'implémentation des nouveaux jours fériés 
dans ma fonction et passer les tests avec succès.

```sql
DECLARE
  m int := extract(month from day);
  d int := extract(day from day);
  holidays month_day[] := array[
    (1,1), (5,1), (5,8), (7,14),
    (8,15), (11,1), (11,11), (12,25)
    --, (12,26) -- si vous vivez en Alsace-Moselle
  ];
BEGIN
  RETURN (m,d) = ANY (holidays);
END;
```

## Les jours incroyables de la mort du Christ

Si vous avez bien suivi, il ne manque plus que l'implémentation des fameux jours 
du [lundi de Pâques][5], du [jeudi de l'Ascension][6] et du [lundi de Pentecôte][7], 
voire du [Vendredi Saint][8] pour mes lecteurs assidus du Grand Est. Ces jours 
religieux ont la grande particularité d'être différents chaque année mais 
relativisons rapidement, les trois derniers dépendent de la date du lundi de 
Pâques. Rédigeons dès à présent les tests avant d'attaquer la partie épineuse de 
mon aventure.

[5]: https://fr.wikipedia.org/wiki/Lundi_de_P%C3%A2ques
[6]: https://fr.wikipedia.org/wiki/Ascension_(f%C3%AAte)
[7]: https://fr.wikipedia.org/wiki/Pentec%C3%B4te
[8]: https://fr.wikipedia.org/wiki/Vendredi_saint

Pour la rédaction de ces tests, je souhaiterais m'assurer qu'une série de lundis 
de Pâques piochés au cours du dernier siècle soient bien identifiés comme des 
jours fériés par ma fonction.

```sql
SELECT is( 
  is_public_holiday(x::date),
  true,
  format('%s is an easter monday', x)
) FROM unnest(array[
  '1931-04-06', '1945-04-02', '1968-04-15',
  '1989-03-27', '2000-04-24', '2020-04-13'
]) x;
```

Je ne vous le cache pas, j'ai découvert le calcul du jour de Pâques il y a 
plusieurs années, alors même que je devais écrire une fonction en PL/pgSQL selon 
la [méthode de Gauss][9] pour un système de planification embarqué dans une base
PostgreSQL. Avec cet article, c'est l'occasion de la dépoussiérer et lui donner 
l'occasion d'être mise en lumière. J'ajoute à mon code initial, la définition de
cette nouvelle fonction qui prendra une année en paramètre, requise pour 
déterminer « le [dimanche][10] qui suit la première pleine lune du printemps ».

[9]: https://fr.wikipedia.org/wiki/Calcul_de_la_date_de_P%C3%A2ques_selon_la_m%C3%A9thode_de_Gauss
[10]: https://fr.wikipedia.org/wiki/Calcul_de_la_date_de_P%C3%A2ques

```sql
CREATE OR REPLACE FUNCTION easter_date(year int)
  RETURNS date LANGUAGE plpgsql
AS $$
DECLARE
  g integer := year % 19;
  c integer := year / 100;
  h integer := (c - c/4 - (8*c+13)/25 + 19*g + 15) % 30;
  i integer := h - h/28 * (1 - h/28 * (29/(h + 1)) * (21 - g)/11);
  j integer := (year + year/4 + i + 2 - c + c/4) % 7;
  l integer := i - j;
  m integer := 3 + (l + 40)/44;
  d integer := l + 28 - 31 * (m/4);
BEGIN
  RETURN format('%s-%s-%s', year, m, d);
END;
$$;
```

Il s'agit à présent d'intégrer ce calcul dans notre fonction `is_public_holiday` 
et satisfaire la comparaison avec nos dates de tests. Nous souhaitons connaître 
la date du lundi de Pâques, et non celle du dimanche fournie par l'algorithme 
précédent.

```sql
DECLARE
  y int := extract(year from day);
  m int := extract(month from day);
  d int := extract(day from day);

  easter date := easter_date(y);
  holidays month_day[] := array[
    (1,1), (5,1), (5,8), (7,14),
    (8,15), (11,1), (11,11), (12,25)
  ];
BEGIN
  IF (m,d) = (
    extract(month from easter+1),
    extract(day from easter+1)
  )
  THEN
    RETURN true;
  END IF;

  RETURN (m,d) = ANY (holidays);
END;
```

Encore une fois, j'implémente cette nouvelle règle de comparaison avec le minimum 
d'efforts et un bloc `IF` comme la fois passée. Les tests se réalisent sans accroc
pour la sélection préalable des lundis de Pâques.

```sh
# docker exec -it pgdemo psql -U postgres -f is_public_holiday.sql
DROP TYPE
CREATE TYPE
CREATE FUNCTION
CREATE FUNCTION
# docker exec -it pgdemo pg_prove -U postgres test.sql
test.sql .. ok
All tests successful.
Files=1, Tests=16,  0 wallclock secs
  ( 0.04 usr  0.01 sys +  0.05 cusr  0.00 csys = 0.10 CPU)
Result: PASS
```

---

Je poursuis les étapes itératives de développement, à savoir : écrire un test en 
erreur, écrire l'implémentation, simplifier le code. J'en viens à écrire une 
séries de tests pour les dates de l'Ascension et de la Pentecôte.

```sql
SELECT is(
  is_public_holiday(x::date),
  true,
  format('%s is as ascension day', x)
) FROM unnest(array[
  '1921-05-05', '1940-05-02', '1960-05-26',
  '1998-05-21', '2011-06-02', '2020-05-21'
]) x;

SELECT is(
  is_public_holiday(x::date),
  true,
  format('%s is pentecost', x)
) FROM unnest(array[
  '1910-05-16', '1928-05-28', '1955-05-30',
  '1984-06-11', '2003-06-09', '2020-06-01'
]) x;
```

Plutôt que d'employer une succession de `IF` pour valider ces nouvelles règles, 
je réécris la fonction `is_public_holiday` pour enrichir mon tableau de références 
`holidays` avec trois nouvelles dates, déterminées à partir du jour de Pâques. 
L'astuce consiste à ajouter `+1` pour obtenir le lundi de Pâques, `+39` pour le 
jeudi de l'Ascension et `+50` pour le lundi de la Pentecôte. _(Pour les régions 
exotiques, le Vendredi Saint aura lieu 2 jours avant Pâques.)_

```sql
DECLARE
  y int := extract(year from day);
  m int := extract(month from day);
  d int := extract(day from day);
  h month_day;

  easter date := easter_date(y);
  holidays month_day[] := array[
    (1,1), (5,1), (5,8), (7,14),
    (8,15), (11,1), (11,11), (12,25)
  ];
BEGIN
  FOR h IN (
    SELECT extract(month from easter+i) "month",
           extract(day from easter+i) "day"
      FROM unnest(array[1, 39, 50]) i
  ) LOOP
    holidays := array_append(holidays, h);
  END LOOP;

  RETURN (m,d) = ANY (holidays);
END;
```

Et cette fois-ci, nous sommes assurés par nos tests que l'ensemble des jours 
fériés seront correctement identifiés par la fonction.

```text
$ docker exec -it pgdemo pg_prove -U postgres test.sql
test.sql .. ok     
All tests successful.
Files=1, Tests=28,  0 wallclock secs
  ( 0.04 usr  0.00 sys +  0.04 cusr  0.02 csys =  0.10 CPU)
Result: PASS
```

## La contrainte d'intégrité pour les jours fériés

Pour en finir avec une dernière réflexion, le _framework_ pgTAP peut également 
être employé pour réaliser des tests de non régression au niveau du modèle de 
données. C'est même sa fonction première avec une série de méthodes permettant 
de questionner le catalogue système de la base.

Voyons quelques unes d'entre-elles avec les exemples suivants.

```sql
-- Contrôler la présence et bonne définition d'un type
SELECT has_type('month_day');
SELECT col_type_is('month_day', 'month', 'integer');
SELECT col_type_is('month_day', 'day', 'integer');

-- Contrôler qu'une contrainte est bien définie sur une table
CREATE TABLE t (
  id int, task varchar,
  planned date check (not is_public_holiday(planned)) 
);
SELECT col_has_check('t', 'planned');

-- Contrôler qu'une erreur d'intégrité est bien levée
SELECT throws_ok(
  $$insert into t values (1, 'travailler', '2020-05-21')$$,
  23514 -- code d'erreur check_violation
);
```

---

Le _framework_ existe depuis 2008 et continue son bonhomme de chemin auprès de 
la communauté. Ce n'est clairement pas un outil pour un environnement de production, 
mais peut s'avérer un bel atout pour les chaînes de développement continu afin 
de s'assurer que les migrations applicatives n'oublient pas un objet ou une 
relation dans son livrable, ou pire, n'en suppriment pas par erreur.

{{< message >}}
J'espère que l'exemple léger sélectionné par mes soins vous aura plu, et vous 
aura permis de découvrir comme moi un _framework_ de tests orienté SQL. Si vous 
souhaitez parcourir les fichiers de ma démonstration, ils sont en accès libre sur 
[gist.github.com/fljdin](https://gist.github.com/fljdin/4e4e5257667b3dca7278b05a31751fc3).
{{< /message >}}