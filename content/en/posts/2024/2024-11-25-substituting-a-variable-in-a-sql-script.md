---
title: "Substituting a variable in a SQL script"
categories: [postgresql]
tags: [developpement, migration]
date: "2024-11-25 09:00:00 +0100"
translationKey: "substituting-a-variable-in-a-sql-script"
---

In a world where we constantly seek to automate repetitive tasks, it is common
to write down a query in a script, make it more convenient, and eventually
integrate the whole thing into a project's codebase. Tools like SQL*Plus and
psql can be powerful allies in this game, as relevant as Bash or Python
interpreters.

In several projects I have been involved in, I have come across a large number
of those kinds of scripts. Some of them have the particularity of offering input
parameters, processed by SQL*Plus with the very comfortable mechanism named
variable substitution. In this article, I share some tips to convert them to an
equivalent syntax that PostgreSQL's psql tool can parse and manage.

<!--more-->

---

## Substituting a variable...

As a starting point, let's look at the syntax supported by Oracle's tool with a
progressive example. We stand in the shoes of a user who wants to get the result
of sales from a dummy company, applying two filters based on a product
identifier and two dates passed as parameters.

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

As shown above, the substitution takes place in SQL*Plus as soon as the `&`
symbol is encountered, whether its content is surrounded by single quotes or
not. At the beginning of the script, I applied a simple strategy by defining
each variable with a meaningful name, to facilitate the readability and
maintenance of the script. We don't want to rely on variables named according to
their position in the list of arguments.

---

psql can provide a similar feature, but the syntax is slightly different. We
have to [assign][1] variables outside the script, using the `-v` or `--set`
option. These variables will then be substituted in the script using the
[interpolation][2] system.

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

From this point, we can see that the conversion is quite straightforward. The
substitution syntax is similar with the `:` character instead of `&`. However,
if the variable states as a literal string, we must use the `:` character
outside the quotes and not inside.

---

## ... in an anonymous block

Things get complicated when the script becomes more complex and requires us to
manipulate our previous variables in an anonymous PL/SQL block. Let's take our
script back to enhance it with a personalized message if the requested product
does not exist. A first read on the `products` table should eventually raise the
`NO_DATA_FOUND` exception that we want to catch.

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

Unfortunately, our beloved psql command-line interface does not support the
ubstitution of variables in an anonymous block and any attempt to do so will
result in a syntax error.

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

Do not panic! psql provides us with a way to achieve the same result, with a
deeper rewrite of the script. We will use the `\gset` meta-command to store the
product state and then the `\if` meta-command to perform the control.

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

## ... at any costs

In the wild, it may happen that psql meta-commands are not enough to handle all
the intricacies (and absurdities) that SQL*Plus-compatible scripts can present.
Let's move on with a more complex need we want to address.

Our user now wants to get a performance score for the sales period of his
product, comparing it with the previous period. We would need a cursor here to
reuse the same sales calculation query multiple times and a function to compute
a score by handling the possible division by zero.

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

Of course, the example is deliberately simplistic and could be addressed by a
[window function][3] (fr), but we will play the game of converting the script as
close as possible to its original syntax. To do this, let's identify the
weaknesses of PL/pgSQL.

[3]: /2023/02/10/le-fenetrage-a-la-rescousse/

---

**Temporary routines are not supported**

PL/pgSQL language does not allow the declaration of stored functions or storeed
procedures inside an anonymous block. The only alternative is to define it
globally, so that it is known to the parser and executed correctly. In this
present case, I do not want the function to persist after the call of my script.
No problem, we can create a temporary function in the `pg_temp` schema!

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

The `pg_temp.score(numeric, numeric)` function is now accessible within the
block, and only for the duration of the session. Exception handling respects the
expressed need. We just had to replace `ZERO_DIVIDE` with `division_by_zero` as
describe in the [documentation][4].

[4]: https://www.postgresql.org/docs/current/errcodes-appendix.html

**SQL substitution is not supported**

Our main issue strikes back: substitution does not occur when we are in a
PL/pgSQL block. To work around this limitation, we will have to use the [custom
session variables][5] made available for the PostgreSQL extension ecosystem.

[5]: https://www.postgresql.org/docs/current/runtime-config-custom.html

Those variables can be manipulated as well in psql with the `SET` keyword as in
SQL or PL/pgSQL with the [`current_setting`][6] and [`set_config`][7] functions.
The only constraint is to define a prefix that does not conflict with that of
other variables already declared in our instance.

[6]: https://pgpedia.info/c/current_setting.html
[7]: https://pgpedia.info/s/set_config.html

It means that our parameters can be set as session variables in the very
beginning of the script. As soon as we are in an anonymous block, we must then
assign them back to regular variables as shown in the following code:

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

**Full conversion**

A new version of the script, converted from PL/SQL to PL/pgSQL, can be obtained
with all previous tricks put together:

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

This kind of rewriting becomes affordable when we know the right tricks, without
losing sight of the initial goal. Of course, a one-to-one translation, by
preserving the syntax and the original intent, could be more challenging than
that blog post example.

I'm a bit skeptical about those who want to keep such development practices.
They seem outdated to me. Isn't migrating to PostgreSQL an opportunity to
modernize our codebase or to question our relationship with technology? In our
example, as I previously mentioned, it is possible to get the same result in a
single SQL, combining meta-commands, variables substitution, common-table
expressions, and a the `LAG` window function.

In that way, we throw away the PL/pgSQL block and its limitations.

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
You can find all the scripts of this article, as well as the DDL commands to
the data model, at this [address][8].

[8]: https://gist.github.com/fljdin/45d9ece1c9aba054c85cfbede09c95fd
{{< /message >}}
