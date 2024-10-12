---
title: "Hierarchical data types"
categories: [postgresql]
tags: [developpement]
date: "2024-09-19 13:20:00 +0200"
translationKey: "hierachical-data-types"
---

The SQL standard defines a set of rules so that database systems can be interchangeable,
but there are small singularities in the wild. In this regard, the `hierarchyid` data type
provided by SQL Server is a striking example. If you are switching to PostgreSQL, two
solutions are available to you.

A first and simpler solution consists in linking each node to its parent using a new
`parentid` column and applying a foreign key constraint. Another, more complete approach
consists in using the `ltree` extension. This article deals with the latter case.

<!--more-->

---

## Searching for descendants

The `hierarchyid` type is designed to represent a [hierarchical relationship][1] as a binary
tree. It stores the list of successive nodes up to the root in a single column. Thus, the
node `/1/1/2/` represents a level 3 node, child of the node `/1/1/`, itself child of the
node `/1/`, itself child of the root `/`.

[1]: https://learn.microsoft.com/en-us/sql/relational-databases/hierarchical-data-sql-server

Many built-in methods are part of the Transact-SQL language to manipulate the data. They all
traverse the binary tree to quickly extract the desired information without having to join
the nodes of the table together.

- [`ToString()`][2] : returns the textual representation of the current node.
- [`GetLevel()`][3] : returns the depth level of the current node.
- [`GetAncestor(n)`][4] : returns the `n`-level node in the tree.
- [`GetDescendant(c1, c2)`][5] : returns a new child node between two nodes.

[2]: https://learn.microsoft.com/en-us/sql/t-sql/data-types/tostring-database-engine
[3]: https://learn.microsoft.com/en-us/sql/t-sql/data-types/getlevel-database-engine
[4]: https://learn.microsoft.com/en-us/sql/t-sql/data-types/getancestor-database-engine
[5]: https://learn.microsoft.com/en-us/sql/t-sql/data-types/getdescendant-database-engine

PostgreSQL brings us a new data type, `ltree`, to store hierarchical data. It is a complex data
type that can store labels up to 1,000 characters long, separated by dots. The path can contain
up to 65,635 labels.

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

Looking for the depth level of a node becomes trivial with the `nlevel()` function provided
by the `ltree` extension.

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

Another method named `subpath()` allows you to retrieve a part of the path of a node. Let's
see how to get the parent node of each node in the table.

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

Least but not last, the search for child nodes from a given node is possible thanks to
specialized comparison operators. To improve performance, it is recommended to create a
GIST index on the primary key column `id`.

```sql
CREATE INDEX ON locations USING GIST (id);
```

All cities in Europe can be retrieved with the following query.

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

## Working under constraints

The declared primary key constraint prevents me from inserting an existing path. However, it
is still possible to add a new row whose path does not have any ancestor in the table.

```sql
INSERT INTO locations VALUES ('2.1.1', 'Unknown', 'Continent');
```
```console
INSERT 0 1
```

Things does not change much between SQL Server and PostgreSQL, it is necessary to add an
[additional column][7], named `parentid` for instance, to enforce the foreign key constraint.
The following query reuses the `subpath()` function ensuring a null value is inserted if it
is a root node.

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

By now, whenever a new row is inserted, the foreign key constraint is automatically checked.

```sql
INSERT INTO locations VALUES ('2.1.1', 'Unknown', 'Continent');
```
```console
ERROR:  insert or update on table "locations" violates
        foreign key constraint "locations_parentid_fkey"
DETAIL:  Key (parentid)=(2.1) is not present in table "locations".
```

---

## Just one solution among others

This kind of data type is a clever solution to store hierarchical data and is easily
available with PostgreSQL. However, it is an extension of the SQL language and each
database engine can propose an implementation that can radically change from one system
to another.

As I mentioned in the introduction, the universal answer is to rebuild a hierarchical
relationship using a recursive query and the `WITH RECURSIVE` syntax. To take the example
of the `locations` table, the list of cities in Europe could be obtained as follows.

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
