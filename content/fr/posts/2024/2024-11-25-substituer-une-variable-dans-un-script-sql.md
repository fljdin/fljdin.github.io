---
title: "Substituer une variable dans un script SQL"
categories: [postgresql]
tags: [developpement, migration]
date: "2024-11-25 09:00:00 +0100"
translationKey: "substituting-a-variable-in-a-sql-script"
---

Il est fréquent de vouloir automatiser une tâche répétitive en la scriptant
rapidement, puis à force d'itérations, de l'enrichir, voire de l'intégrer dans
la base de code d'un projet. À ce jeu, les outils comme SQL*Plus et psql peuvent
être de puissants alliés et des interpréteurs aussi pertinents que Bash ou
Python.

Dans le cadre des projets de migration que je mène régulièrement, il m'arrive de
tomber sur ces scripts, en grand nombre. Certains ont la particularité de
proposer des paramètres d'entrée, traités par SQL*Plus avec le mécanisme très
confortable de substitution de variables. Dans cet article, je partage quelques
astuces pour convertir certains aspects de ces scripts grâce aux fonctionnalités
équivalentes que l'on retrouve sur l'outil psql de PostgreSQL.

<!--more-->

---

## Substituer une variable...

Comme point de départ, penchons-nous sur la syntaxe supportée par l'outil
d'Oracle avec un exemple fil rouge. Nous incarnons un utilisateur qui souhaite
obtenir le résultat des ventes d'une société factice, en appliquant deux filtres
basés sur un numéro produit et deux dates passées en paramètres.

```sql
-- sqlplus-report-01.sql
CONNECT user/password@database

DEF product_id = '&1'
DEF start_date = '&2'
DEF end_date   = '&3'

SELECT NVL(SUM(amount), 0) AS total_amount
  FROM orders
  JOIN products USING (product_id)
 WHERE product_id = &product_id
   AND order_date BETWEEN TO_DATE('&start_date', 'YYYY-MM-DD')
                      AND TO_DATE('&end_date', 'YYYY-MM-DD');

QUIT
```

```console
$ sqlplus -S /nolog @sqlplus-report-01.sql 20 2024-11-01 2024-11-30
old   3:  WHERE product_id = &product_id
new   3:  WHERE product_id = 20
old   4:    AND order_date BETWEEN TO_DATE('&start_date', 'YYYY-MM-DD')
new   4:    AND order_date BETWEEN TO_DATE('2024-11-01', 'YYYY-MM-DD')
old   5:		      AND TO_DATE('&end_date', 'YYYY-MM-DD')
new   5:		      AND TO_DATE('2024-11-30', 'YYYY-MM-DD')

TOTAL_AMOUNT
------------
     1378.98
```

Comme nous pouvons l'observer, la substitution s'opère en SQL*Plus dès que le
caractère `&` est rencontré, que son contenu soit ou non entouré de guillemets
simples. En début de script, j'ai appliqué une stratégie simple en définissant
une variable avec un nom évocateur, pour faciliter la lisibilité et la
maintenance du script et ne plus s'accommoder des variables nommées selon leur
position dans la liste des arguments.

---

Pour obtenir un résultat équivalent avec psql, nous devons effectuer une
[assignation][1] de variables en dehors du script, avec l'option `-v` ou `--set`
fournie par psql. Ces variables seront alors substituées dans le script à l'aide
du mécanisme d'[interpolation][2].

[1]: https://psql-tips.org/psql_tips_all.html#tip037
[2]: https://www.postgresql.org/docs/current/app-psql.html#APP-PSQL-INTERPOLATION

```sql
-- psql-report-01.sql
\pset footer off

SELECT COALESCE(SUM(amount), 0) AS total_amount
  FROM orders
  JOIN products USING (product_id)
 WHERE product_id = :product_id
   AND order_date BETWEEN :'start_date'::date
                      AND :'end_date'::date;
```

```console
$ psql -f psql-report-01.sql \
$      -v product_id=20 \
$      -v start_date='2024-11-01' -v end_date='2024-11-30'
 total_amount 
--------------
      1378.98
```

La reprise du script original est tout à fait triviale, on y retrouve une
syntaxe similaire avec le caractère `:` en lieu et place de `&`. Toutefois, si
la variable doit être comprise entre deux guillemets simples, nous constatons
que le caractère `:` doit être saisi à l'extérieur et non à l'intérieur.

---

## ... dans un bloc anonyme

Les choses se gâtent lorsque le script devient plus complexe, et nécessite de
manipuler nos précédentes variables dans un bloc anonyme PL/SQL. Reprenons notre
script pour l'enrichir d'un message personnalisé si le produit demandé n'existe
pas. Une première lecture sur la table `products` peut, éventuellement,
retourner l'exception `NO_DATA_FOUND` que nous souhaitons intercepter.

```sql
-- sqlplus-report-02.sql
CONNECT user/password@database

DEF product_id = '&1'
DEF start_date = '&2'
DEF end_date   = '&3'

SET serveroutput ON
SET feedback OFF
SET verify OFF

DECLARE
  p_id    products.product_id%TYPE;
  p_sum   NUMBER;
  p_start DATE := TO_DATE('&start_date', 'YYYY-MM-DD');
  p_end   DATE := TO_DATE('&end_date', 'YYYY-MM-DD');
  
BEGIN
  SELECT product_id INTO p_id
    FROM products
   WHERE product_id = &product_id;
   
  SELECT NVL(SUM(amount), 0) INTO p_sum
    FROM orders
   WHERE product_id = p_id
     AND order_date BETWEEN p_start AND p_end;
      
  DBMS_OUTPUT.PUT_LINE('Total amount: ' || p_sum);

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Product ' || &product_id || ' does not exist');
END;
/

QUIT
```

```console
$ sqlplus -S /nolog @sqlplus-report-02.sql 120 2024-11-01 2024-11-30
Product 120 does not exist
```

---

Du côté de notre alternative PostgreSQL et son invite de commande psql, il
apparaît qu'un bloc anonyme en PL/pgSQL ne permet pas de réaliser la
substitution comme nous le souhaitons. Si nous tentons de réaliser un contrôle
avec le renvoi d'une exception, nous obtenons une erreur de syntaxe, car la
variable n'est pas substituée.

```sql
-- psql-report-02-wrong.sql
DO $$
DECLARE
  p_id    products.product_id%TYPE;
  p_sum   numeric;
  p_start date := :'start_date'::date;
  p_end   date := :'end_date'::date;
  
BEGIN
  SELECT product_id INTO STRICT p_id
    FROM products
   WHERE product_id = :product_id;
   
  SELECT COALESCE(SUM(amount), 0) INTO p_sum
    FROM orders
   WHERE product_id = p_id
     AND order_date BETWEEN p_start AND p_end;

  RAISE NOTICE 'Total amount: %', p_sum;
  
EXCEPTION
  WHEN no_data_found THEN
    RAISE NOTICE 'Product % does not exist', :product_id;
END;
$$;
```

```console
$ psql -f psql-report-02-wrong.sql \
$      -v product_id=120 \
$      -v start_date='2024-11-01' -v end_date='2024-11-30'
psql:psql-report-02-wrong.sql:25: ERROR:  syntax error at or near ":"
LINE 5:   p_start date := :'start_date'::date;
                          ^
```

Fort heureusement, psql ne nous laisse pas sans ressource. Les méta-commandes
qu'il propose peuvent nous permettre d'obtenir le même résultat, moyennant une
réécriture plus profonde du script. Nous allons utiliser la méta-commande
`\gset` pour stocker l'état du produit puis la méta-commande `\if` pour réaliser
le contrôle.

```sql
-- psql-report-02.sql
\pset footer off

SELECT NOT EXISTS(
  SELECT product_id
    FROM products
   WHERE product_id = :product_id
) AS unknown_product \gset

\if :unknown_product
  \echo 'Product' :product_id 'does not exist'
  \quit
\endif

SELECT COALESCE(SUM(amount), 0) AS total_amount
  FROM orders
  JOIN products USING (product_id)
 WHERE product_id = :product_id
   AND order_date BETWEEN :'start_date'::date
                      AND :'end_date'::date;
```

```console
$ psql -f report.sql \
$      -v product_id=120 \
$      -v start_date='2024-11-01' -v end_date='2024-11-30'
Product 120 does not exist
```

---

## ... à tout prix

Il est probable que les méta-commandes de psql ne viennent pas à bout de toutes
les ingéniosités (et aberrations) que peuvent réserver les scripts compatibles
avec SQL*Plus. Progressons encore avec une évolution plus complexe de notre
exemple.

Notre utilisateur souhaite à présent obtenir un score de performance pour la
période de vente de son produit, en comparant avec la période précédente. Nous
aurions besoin ici d'un curseur pour réutiliser plusieurs fois la même requête
de calcul des ventes ainsi que d'une fonction pour calculer le score de
performance en gérant correctement la division possible par zéro.

```sql
-- sqlplus-report-03.sql
CONNECT user/password@database

DEF product_id = '&1'
DEF start_date = '&2'
DEF end_date   = '&3'

SET serveroutput ON
SET feedback OFF
SET verify OFF

DECLARE
  p_id         products.product_id%TYPE;
  p_sum        NUMBER;
  p_prev_sum   NUMBER;
  p_start      DATE := TO_DATE('&start_date', 'YYYY-MM-DD');
  p_end        DATE := TO_DATE('&end_date', 'YYYY-MM-DD');
  p_prev_start DATE := p_start - (p_end - p_start);
  p_prev_end   DATE := p_start - 1;

  CURSOR c_orders (v_start DATE, v_end DATE) IS
    SELECT SUM(amount) AS total_amount
      FROM orders
     WHERE product_id = p_id
       AND order_date BETWEEN v_start AND v_end;

  FUNCTION score(p_sum NUMBER, p_prev_sum NUMBER)
  RETURN NUMBER IS
    v_score NUMBER;
  BEGIN
    RETURN ROUND((p_sum - p_prev_sum) / p_prev_sum * 100, 2);
  EXCEPTION
    WHEN ZERO_DIVIDE THEN
      RETURN NULL;
  END;

BEGIN
  SELECT product_id INTO p_id
    FROM products
   WHERE product_id = &product_id;
   
  OPEN c_orders(p_start, p_end);
    FETCH c_orders INTO p_sum;
  CLOSE c_orders;
      
  OPEN c_orders(p_prev_start, p_prev_end);
    FETCH c_orders INTO p_prev_sum;
  CLOSE c_orders;
      
  DBMS_OUTPUT.PUT_LINE('Total amount: ' || p_sum);
  DBMS_OUTPUT.PUT_LINE('Performance score: ' || score(p_sum, p_prev_sum));

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Product ' || &product_id || ' does not exist');
END;
/

QUIT
```

```console
$ sqlplus -S /nolog @sqlplus-report-03.sql 20 2024-11-01 2024-11-30
Total amount: 1378.98
Performance score: 162.99
```

Bien que l'exemple soit volontairement simpliste et qu'il puisse faire appel à
une [fonction de fenêtrage][3], nous allons jouer le jeu de la conversion du
script au plus proche de sa syntaxe originale. Pour cela, identifions les
faiblesses du PL/pgSQL.

[3]: /2023/02/10/le-fenetrage-a-la-rescousse/

---

**Les routines éphémères ne sont pas prises en charge**

Le langage PL/pgSQL n'autorise pas la déclaration de fonctions ou de procédures
stockées dont la portée serait exclusive au contexte d'exécution. La seule
alternative est de définir globalement la routine, afin qu'elle soit connue de
l'analyseur syntaxique et exécutée correctement. Dans le cas présent, je ne
souhaite pas que la fonction persiste après l'appel de mon script. Qu'à cela ne
tienne, nous pouvons créer une fonction temporaire dans le schéma `pg_temp` !

```sql
-- temp-function.sql
DO $$
BEGIN
  CREATE FUNCTION pg_temp.score(p_sum numeric, p_prev_sum numeric) 
  RETURNS numeric LANGUAGE plpgsql AS $func$
    BEGIN
      RETURN ROUND((p_sum - p_prev_sum) / p_prev_sum * 100, 2);
    EXCEPTION
      WHEN division_by_zero THEN
        RETURN NULL;
    END;
  $func$;
  
  RAISE NOTICE 'Score: %', pg_temp.score(100.0, 50.0);
  RAISE NOTICE 'Score: %', pg_temp.score(100.0, 0);
END;
$$;
```

```console
$ psql -f temp-function.sql
psql:temp-function.sql:16: NOTICE:  Score: 100.00
psql:temp-function.sql:16: NOTICE:  Score: <NULL>
DO
```

La fonction `pg_temp.score(numeric, numeric)` est dès lors accessible dans le
reste de notre bloc anonyme, et ce, uniquement pour la durée de la session. La
gestion des exceptions est conforme au besoin, il a suffit de remplacer
`ZERO_DIVIDE` par `division_by_zero` comme le stipule la [documentation][4].

[4]: https://www.postgresql.org/docs/current/errcodes-appendix.html

**La substitution ne s'applique pas dans un bloc anonyme**

Comme nous l'avons vu précédemment, la substitution n'intervient pas lorsque
nous nous trouvons dans un bloc de code PL/pgSQL. Pour contourner cette
limitation, nous allons devoir utiliser les [variables de session
personnalisées][5] mises à disposition pour l'écosystème d'extensions avec
PostgreSQL.

[5]: https://www.postgresql.org/docs/current/runtime-config-custom.html

Ces variables peuvent être manipulées aussi bien en psql avec le mot-clé `SET`
qu'en SQL ou en PL/pgSQL avec les fonctions [`current_setting`][6] et
[`set_config`][7]. La seule contrainte consiste à leur définir un préfixe qui
n'entre pas en conflit avec celui d'autres variables déjà déclarées dans notre
instance.

[6]: https://pgpedia.info/c/current_setting.html
[7]: https://pgpedia.info/s/set_config.html

Pour revenir à notre exercice de conversion, cela signifie que nos paramètres
de script peuvent être montés en variables de session dans les toutes premières
instructions. Dès que nous sommes dans un bloc anonyme, il convient alors de les
rappeler dans des variables classiques comme le montre le code suivant :

```sql
SET my.product_id = :product_id;
SET my.start_date = :start_date;
SET my.end_date   = :end_date;

DO $$
DECLARE
  my_id   int  := current_setting('my.product_id')::int;
  p_start date := current_setting('my.start_date')::date;
  p_end   date := current_setting('my.end_date')::date;
BEGIN
  ...
END;
$$;
```

**Conversion complète**

Toutes ces astuces mises bout à bout permet d'obtenir une nouvelle version du
script, converti de PL/SQL à PL/pgSQL :

```sql
-- psql-report-03.sql
\set QUIET on

SET my.product_id = :product_id;
SET my.start_date = :'start_date';
SET my.end_date   = :'end_date';

DO $$
DECLARE
  my_id        int := current_setting('my.product_id')::int;
  p_id         products.product_id%TYPE;
  p_sum        numeric;
  p_prev_sum   numeric;
  p_start      date := current_setting('my.start_date')::date;
  p_end        date := current_setting('my.end_date')::date;
  p_prev_start date := p_start - interval '1 day' * (p_end - p_start);
  p_prev_end   date := p_start - interval '1 day';
  
  c_orders CURSOR (v_start date, v_end date) IS
    SELECT COALESCE(SUM(amount), 0)
      FROM orders
     WHERE product_id = p_id
       AND order_date BETWEEN v_start AND v_end;
  
BEGIN
  CREATE FUNCTION pg_temp.score(p_sum numeric, p_prev_sum numeric) 
  RETURNS numeric LANGUAGE plpgsql AS $func$
    BEGIN
      RETURN ROUND((p_sum - p_prev_sum) / p_prev_sum * 100, 2);
    EXCEPTION
      WHEN division_by_zero THEN
        RETURN NULL;
    END;
  $func$;
  
  SELECT product_id INTO STRICT p_id
    FROM products
   WHERE product_id = my_id;
   
  OPEN c_orders(p_start, p_end);
    FETCH c_orders INTO p_sum;
  CLOSE c_orders;
  
  OPEN c_orders(p_prev_start, p_prev_end);
    FETCH c_orders INTO p_prev_sum;
  CLOSE c_orders;
  
  RAISE NOTICE 'Total amount: %', p_sum;
  RAISE NOTICE 'Performance score: %', pg_temp.score(p_sum, p_prev_sum);
   
EXCEPTION
  WHEN no_data_found THEN
    RAISE NOTICE 'Product % does not exist', my_id;
END;
$$;
```

```console
$ psql -f psql-report-03.sql\
$      -v product_id=20 \
$      -v start_date='2024-11-01' -v end_date='2024-11-30' 
psql:psql-report-03.sql:55: NOTICE:  Total amount: 1378.98
psql:psql-report-03.sql:55: NOTICE:  Performance score: 162.99
```

---

## Conclusion

Convertir un script SQL*Plus pour qu'il devienne compatible avec l'outil psql de
PostgreSQL est un exercice surmontable, pour peu que l'on connaisse les bonnes
astuces et alternatives qui répondent au besoin initial. Bien sûr, une
traduction un pour un, en conservant la syntaxe et un semblant de lisibilité,
pourrait s'avérer plus ardue que l'exemple que j'ai concocté.

Je reste toujours sceptique face à celles et ceux qui souhaitent conserver ce
genre de pratiques de développement, que je trouve obsolètes. Migrer vers
PostgreSQL n'est-il pas l'occasion de moderniser sa base de code, ou de
questionner son rapport à la technologie ? Dans notre exemple, comme je l'avais
mentionné, il est possible d'obtenir le même résultat en une seule requête SQL,
sans avoir à recourir à un bloc anonyme PL/pgSQL.

```sql
-- psql-report-04.sql
\pset footer off

SELECT NOT EXISTS(
  SELECT product_id
    FROM products
   WHERE product_id = :product_id
) AS unknown_product \gset

\if :unknown_product
  \echo 'Product' :product_id 'does not exist'
  \quit
\endif

SELECT :'end_date'::date - :'start_date'::date AS days \gset
SELECT :'start_date'::date - :days AS prev_start \gset

WITH periods AS (
  SELECT d AS start_date, d + :days * '1 day'::interval AS end_date
    FROM generate_series(:'prev_start'::date, 
                         :'start_date'::date, 
                         :days * '1 day'::interval) AS s(d)
), amounts AS (
  SELECT start_date, COALESCE(SUM(amount), 0) AS total_amount, 
         LAG(SUM(amount), 1) OVER (ORDER BY start_date) AS prev_total_amount
    FROM orders
    JOIN periods ON order_date BETWEEN start_date AND end_date
   WHERE product_id = :product_id
   GROUP BY start_date
)
SELECT total_amount, 
       ROUND((total_amount - prev_total_amount) / 
              prev_total_amount * 100, 2) AS performance_score
  FROM amounts 
 WHERE prev_total_amount IS NOT NULL;
```

```console
$ psql -f psql-report-04.sql\
$      -v product_id=20 \
$      -v start_date='2024-11-01' -v end_date='2024-11-30' 
 total_amount | performance_score 
--------------+-------------------
      1378.98 |            162.99 
```

{{< message >}}
Tous les scripts de cet article, ainsi que les commandes DDL pour construire
le modèle de données, sont disponibles cette [adresse][8].

[8]: https://gist.github.com/fljdin/45d9ece1c9aba054c85cfbede09c95fd
{{< /message >}}
