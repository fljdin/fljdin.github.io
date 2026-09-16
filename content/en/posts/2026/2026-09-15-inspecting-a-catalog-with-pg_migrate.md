---
title: "Inspecting a catalog with pg_migrate"
categories: [postgresql]
tags: [migration]
date: "2026-09-16 09:00:00 +0200"
translationKey: "inspecting-a-catalog-with-pg-migrate"
---

Over the past few years, I have been working on assessing the strengths and
weaknesses of PostgreSQL migration tools. Several articles [published by yours
truly][1] led to the ambitious project I have been pursuing since 2024 with my
colleagues [Étienne Bersac][bersace] and [Pierre-Louis Gonon][pirlgon].

[1]: /en/tags/migration/
[bersace]: https://bersace.cae.li/
[pirlgon]: https://gitlab.com/pirlgon

… And the fisrt stable version of PostgreSQL Migrator [was released on September
4th][2]. This is an opportunity to showcase features I use daily and what
advantages they offer over other tools. In this article, I want to focus on one
of them, particularly valuable when preparing a migration: the **offline
catalog**.

[2]: https://www.postgresql.org/about/news/postgresql-migrator-10-first-stable-release-3377/

<!--more-->

---

## Inspecting the Oracle catalog

The catalog of a relational database contains the structure of the data model,
table column names and data types, constraint definitions, the definition of a
view or a function, and so on. Everything declared by the user with DDL (_Data
Definition Language_) is stored in the catalog as the single source of truth.

In systems like PostgreSQL, MySQL or MSSQL Server, the standard provides a
universal catalog, the `information_schema` schema. For example, table names can
be retrieved there with the same query:

```sql
SELECT table_name FROM information_schema.tables 
 WHERE table_schema = 'scott'
 ORDER BY table_name;
```

However, this is not the ideal solution to reconstruct a data model. Each of these
systems conforms to the SQL standard as best it can but very often enriches it
with language extensions or takes liberties with the implementation of a
feature. As a result, the `information_schema` catalog is not the universal
source, little more than a set of views on top of each system's proprietary
system catalog.

Turning to Oracle and Ora2Pg. If we want to recreate the structure of a table in
the Oracle ecosystem, several methods exist and they all rely on the catalog
views which I cover last.

**The DESCRIBE command**

By far the least informative of the solutions but the fastest for a first
inspection. It is analogous to the `\d` meta-command in psql or the `pragma
table_info` in SQLite.

```sql
DESCRIBE SCOTT.EMP;

-- Name     Null?    Type         
-- -------- -------- ------------ 
-- EMPNO    NOT NULL NUMBER(4)    
-- ENAME             VARCHAR2(10) 
-- JOB               VARCHAR2(9)  
-- MGR               NUMBER(4)    
-- HIREDATE          DATE         
-- SAL               NUMBER(7,2)  
-- COMM              NUMBER(7,2)  
-- DEPTNO            NUMBER(2)    
```

**The DBMS_METADATA package**

You can use a very handy Oracle package to extract the DDL of a table as SQL
text. The equivalents in other systems are the `SHOW CREATE TABLE` statement in
MySQL or `.schema` in SQLite.

```sql
SET pagesize 0
SET long 20000
SELECT dbms_metadata.get_ddl(
          object_type => 'TABLE', 
          schema => 'SCOTT', 
          name => 'EMP');

--  CREATE TABLE "SCOTT"."EMP"
--   (	"EMPNO" NUMBER(4,0),
--	"ENAME" VARCHAR2(10),
--	"JOB" VARCHAR2(9),
--	"MGR" NUMBER(4,0),
--	"HIREDATE" DATE,
--	"SAL" NUMBER(7,2),
--	"COMM" NUMBER(7,2),
--	"DEPTNO" NUMBER(2,0),
--	 CONSTRAINT "PK_EMP" PRIMARY KEY ("EMPNO")
--  USING INDEX PCTFREE 10 INITRANS 2 MAXTRANS 255
--  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
--  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
--  TABLESPACE "SYSTEM"  ENABLE,
--	 CONSTRAINT "FK_DEPTNO" FOREIGN KEY ("DEPTNO")
--	  REFERENCES "SCOTT"."DEPT" ("DEPTNO") ENABLE
--   ) PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
--  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
--  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
--  TABLESPACE "SYSTEM"
```

**Catalog views**

The previous results are derived from several system views. Unsurprisingly,
classic GUI tools like SQL Developer or DBeaver, as well as Ora2Pg and
PostgreSQL Migrator, query these views directly to get the full DDL.

Ora2Pg fetches the table list from the `ALL_OBJECTS` view and stores it in
memory in a hash `$self->{tables}`. Then, it iterates over `ALL_TAB_COLUMNS` to
collect the details of each table and attach them as a nested level of that same
global hash `$self->{tables}{$table}{column_info}{$column}`.

```sql
SELECT A.OWNER,A.OBJECT_NAME,A.OBJECT_TYPE FROM ALL_OBJECTS A
 WHERE A.OBJECT_TYPE IN ('TABLE','VIEW') AND A.OWNER='SCOTT';

SELECT A.COLUMN_NAME, A.DATA_TYPE, A.DATA_LENGTH, A.NULLABLE, A.DATA_DEFAULT,
       A.DATA_PRECISION, A.DATA_SCALE, A.CHAR_LENGTH, A.TABLE_NAME, A.OWNER
  FROM ALL_TAB_COLUMNS A
 WHERE A.TABLE_NAME NOT LIKE 'BIN$%' AND A.TABLE_NAME='EMP'
 ORDER BY A.COLUMN_ID
```

The in-memory `$self` structure maintained by Ora2Pg does not persist across
runs. **The source catalog must be re-read on every run**. By contrast, I came
across an alternative named [db_migrator][3], based on Foreign Data Wrapper
(FDW). With db_migrator, the catalog is stored in a PostgreSQL database.

[3]: https://github.com/cybertec-postgresql/db_migrator

It was then easy to snapshot the remote catalog with the `db_migrate_refresh()`
function and to query it offline, without reconnecting to the Oracle instance.
This discovery led to the first prototypes of the JSON catalog of PostgreSQL
Migrator.

---

## Querying the JSON catalog

Storing the catalog requires a structured, stable and flexible format.
In practice, storing the data in PostgreSQL tables seemed elegant to DBA eyes
but proved unsuitable. The PostgreSQL Migrator tool is designed to be portable
and we did not want to pollute the final PostgreSQL instance with a temporary
schema.

Like Ora2Pg, pg_migrate initializes a `Catalog` in-memory structure
(`internal/catalog/catalog.go`) at the start of the inspection. This catalog can
be extended to support Oracle or MySQL/MariaDB sources, to collect
engine-specific objects such as packages or synonyms. Once the remote catalog
has been read, it is then serialized to a JSON file. Currently, version 1.0 uses
the [sonic](https://github.com/bytedance/sonic) library.

Inspection is the first step to kick off a project with `pg_migrate`, the
nickname for the command-line interface (_CLI_) of PostgreSQL Migrator. After
initializing an empty directory and checking access to the remote Oracle
database, the logs prompt us to run the `pg_migrate inspect` command.

```console
$ ora-scott && cd ora-scott
$ pg_migrate init --source "oracle://system:manager@localhost:1521/freepdb1"
14:55:28 INFO   Databases connections closed.    source=1 target=0
14:55:28 INFO   Initialized migration project.   source="Oracle Database 23ai Free"
14:55:28 INFO   Inspect source catalog using pg_migrate inspect.
$ pg_migrate --verbose inspect
14:56:03 DEBUG  Cache miss.                      name=Source
14:56:03 INFO   Inspecting source database.      driver=oracle
14:56:03 INFO   This may take some time.
14:56:04 DEBUG  Inspected schemas.               count=1 duration=84.735201ms
14:56:05 DEBUG  Inspected roles.                 count=6 duration=465.814794ms
14:56:06 DEBUG  Inspected sequences.             count=0 duration=1.050025889s
14:56:07 DEBUG  Inspected routines.              count=0 duration=2.794483231s
14:56:07 DEBUG  Inspected views.                 count=0 duration=2.63147026s
14:56:21 DEBUG  Inspected tables.                count=4 duration=15.720365706s
14:56:31 DEBUG  Inspected columns.               count=18 duration=10.735219841s
14:56:41 DEBUG  Inspected keys.                  count=2 duration=19.945416304s
14:56:44 DEBUG  Inspected tables-indexes.        count=0 duration=23.287211484s
14:56:48 DEBUG  Inspected foreign-keys.          count=1 duration=6.525976802s
14:56:58 DEBUG  Inspected checks.                count=0 duration=10.622190194s
14:56:58 INFO   Inspected schema.                name=SCOTT
14:56:58 DEBUG  Inspection completed.            duration=54.968668546s
...
14:57:12 INFO   Inspection terminated.           errs=0 online=true
14:57:12 INFO   Execute pg_migrate ui to browse project.
14:57:12 INFO   Execute pg_migrate dump to migrate for PostgreSQL.
```

On first run, the local catalog does not exist (`Cache miss. name=Source`),
which connects to the remote database to build it from scratch. Cache files are
written to the hidden `.pg_migrate` directory. The source catalog is simply
named `Source.json`.

```console
$ tree .pg_migrate/
.pg_migrate
├── Info.json
├── Map.json
├── Source.json
├── Stats.json
└── Target.json
```

I then had to set aside my beloved SQL to learn the `jq` language in order to
query the JSON files in a `pg_migrate` project. For example, the following
filter lists all columns and their types for the `SCOTT.EMP` table:

```console
$ set filter '.Tables[] | select (.Name == "EMP") | .Columns[] | .objectDefinition'
$ jq -r $filter < .pg_migrate/Source.json
EMPNO NUMBER(4, 0) NOT NULL
ENAME VARCHAR2(10)
JOB VARCHAR2(9)
MGR NUMBER(4, 0)
HIREDATE DATE
SAL NUMBER(7, 2)
COMM NUMBER(7, 2)
DEPTNO NUMBER(2, 0)
```

Of course, the tool has come a very long way since 2024 and this offline catalog
architecture has become the backbone of the product. These files opened up use
cases previously out of reach with Ora2Pg, in addition to the offline mode.

* Conversion transforms a `Source.json` file into a `Target.json` file by
  applying generic and specific conversion rules;
* An audit phase traverses every node to assign a score, plus annotations about
  conversion pitfalls;
* A single-page (SPA) web interface lets you browse both models (source and
  target) without writing `jq` filters.

The tool ships with a `dump` command, which can also be used to display the DDL
for an object stored in `Target.json`. Currently, the full command is as
follows:

```console
$ pg_migrate dump --force --section=pre-data Tables/scott.emp 2>/dev/null | cat
--
-- Name: emp; Type: TABLE; Schema: scott; Owner: scott
--

CREATE TABLE "scott"."emp" (
  "empno" smallint NOT NULL,
  "ename" varchar(10),
  "job" varchar(9),
  "mgr" smallint,
  "hiredate" timestamp,
  "sal" numeric(7, 2),
  "comm" numeric(7, 2),
  "deptno" smallint
);

ALTER TABLE "scott"."emp" OWNER TO "scott";
```

---

## Conclusion

I am deeply proud of the work accomplished with this first stable release. With
my colleagues at Dalibo, we are wrapping up a thrilling adventure, more than two
years spent developing a free, libre and open-source tool meant to surpass its
illustrious predecessor Ora2Pg. The [roadmap][4] is clear. Starting this fall,
we begin the next phase: procedural code conversion. The foundations are solid,
the Go language lets us address real needs for simplification and modernity.

[4]: https://postgresql-migrator.readthedocs.io/en/latest/references/features/

At a time when digital empires harvest our operational data, capturing the value
of our companies' work, it is urgent to react and to believe that another
digital world is possible. Migration projects are becoming complex and
demanding, involving very diverse roles and skills, and we aim to provide an
alternative that does not rely exclusively on LLM agents or American services.

Free software has shown the way for decades; what we lack is the bridges to move
away from these technologies that deprive us of freedom, innovation and means.
At my level as a DBA and Product Owner, committed to the Dalibo cooperative, I
contribute to this collective effort.
