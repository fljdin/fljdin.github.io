---
title: "Window functions to the rescue"
categories: [postgresql]
tags: [developpement]
date: "2024-12-17 14:00:00 +0200"
translationKey: "window-functions-to-the-rescue"
---

PostgreSQL comes with a variety of functions that allow you to group rows into a
"window" and perform calculations on that window. By using these functions, you
can create more advanced and efficient queries for analyzing your database.

In early 2023, I contributed to a project that converts data models to
PostgreSQL, called [db_migrator][1]. On this occasion, I (re)discovered the
power of these [window functions][2] with the SQL language. In this article, I
revisit a [specific case][3] of transforming the upper bounds of a partitioned
table into an array of boundaries.

[1]: https://github.com/cybertec-postgresql/db_migrator
[2]: https://www.postgresql.org/docs/current/functions-window.html
[3]: https://github.com/cybertec-postgresql/db_migrator/pull/11

<!--more-->

---

## Through a window

We do not hide it, the use of a window in a query is (really) not usual.
Windowing is a particularly useful technique for performing time-shifted data
analysis, like cumulative totals, moving averages, trends, etc.

The most commonly used windowing functions in PostgreSQL are `first_value()`,
`last_value()`, `rank()`, `row_number()`, and `lag()`. These functions can be
combined with aggregation functions such as `sum()`, `avg()`, `count()`,
`min()`, and `max()` to produce even more useful results.

<!--
DROP TABLE IF EXISTS partitions;
-->

Let us see a practical example with the `first_value()` method that presents the
first line of the window attached to each line. With the concrete case of
partitioning, we want to know the first partition defined for the table for each
line of a table named `partitions`:

```sql
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

A window function is used in conjunction with the `OVER` clause to specify the
window boundaries, determining column key on which the window function applies.
Here, the window groups the partition data by the table name (`table_name`) by
sorting them with the `ORDER BY` clause.

A window moves for each line, expanding its boundaries according to the new
lines it reads in the declared order. If we want to retrieve the last partition
defined for the table of each line, it is necessary to **reverse the sorting**
of the window, in order to start reading from the bottom up to the current line
and **sort again** the result.

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

## Looking for the lower bound

With Oracle or even MySQL, partitioning by `RANGE` only requires the upper bound
to be defined to distribute the data into the partitions. Thus, creating a
partitioned table is similar to the following example:

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

PostgreSQL is slightly more strict on the definition of `RANGE` partitions with
the use of lower and upper bounds, like this:

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

We want to build an array of lower and upper bounds from multiple rows of our
previously defined `partitions` table. The `lag()` function is the perfect
candidate for this task, as it allows us to access the value of a previous row
in the same window.

```text
lag (value anycompatible [, offset integer [, default anycompatible ]])
   → anycompatible
```

> Returns `value` evaluated at the row that is `offset` rows before the current
> row within the partition; if there is no such row, instead returns `default`
> (which must be of a type compatible with value).

The new query looks like this:

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

Another query with `first_value()` had been used before `lag()` was proposed by
Laurenz Albe in the final form of my work. For an equivalent result, it was
considered less suitable by relying unnecessarily on more advanced clauses such
as `RANGE BETWEEN` and `EXCLUDE`. I let you appreciate the full syntax.

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

Windowing is not a easy concept to grasp, especially since concrete and relevant
cases are not encountered frequently. Without mastering its subtleties, it is
useful to know its purpose, or at least its existence. It would have been
tempting to make joins, CTEs, or subqueries but at the cost of reduced
readability and potential optimization barriers.
