---
title: "On the road to freedom with db_migrator"
categories: [postgresql,migration]
tags: [opensource, sqlmed, developpement]
date: 2023-07-28
translationKey: "en-route-vers-la-liberte-avec-db-migrator"
---

Over the past few months, I have spent several weeks contributing to the
[db_migrator] extension. Written solely in PL/pgSQL, it enables the migration of
schemas and data from a database system to PostgreSQL using the external data I
had previously presented in [another article][1].

[db_migrator]: https://github.com/cybertec-postgresql/db_migrator
[1]: https://fljd-in.translate.goog/2021/07/16/parlons-un-peu-des-donnees-externes/?_x_tr_sl=fr&_x_tr_tl=en&_x_tr_hl=fr&_x_tr_pto=wapp

In this article, I present the functionality of the tool, its philosophy, and
the reason I found for its existence, even though it joins the ecosystem of
well-established open-source projects in the migration landscape. How does it
compare to [Ora2Pg] or [pgloader] in terms of value and capabilities?

[Ora2Pg]: https://ora2pg.darold.net/
[pgloader]: https://pgloader.io/

<!--more-->

---

## db_migrator enters the arena

My interest in this project dates back to last December when a [colleague from
Dalibo][2] left us a [similar tool][3], which allowed copying data from Oracle
or Sybase instances using Foreign Data Wrappers (FDW) technology. Although this
tool remained in alpha, many good ideas were experimented with internally.

[2]: https://blog-dalibo-com.translate.goog/2022/12/21/depart_philippe.html?_x_tr_sl=fr&_x_tr_tl=en&_x_tr_hl=fr&_x_tr_pto=wapp
[3]: https://github.com/dalibo/data2pg

The promise of FDWs lies in adhering to the SQL/MED standard, allowing a
PostgreSQL instance to interface with another storage system and manipulate its
data through external tables using simple SQL queries. Therefore, provided that
a community has developed the wrapper, it becomes possible to query a remote
catalog, replicate the structure of tables, their relationships, and
constraints, and [retrieve data][4] into PostgreSQL.

[4]: https://fljd-in.translate.goog/2021/12/06/migrer-vers-postgresql/?_x_tr_sl=en&_x_tr_tl=fr&_x_tr_hl=fr&_x_tr_pto=wapp

And [db_migrator] enters the arena.

Made public in November 2019 by Laurenz Albe, well-known for his active
contributions to PostgreSQL for decades and also for developing [oracle_fdw],
the extension presents itself as a generic tool where one must use _plugins_ for
FDW support. It is easy to create new plugins, as I discovered with the
[mysql_migrator] plugin, written in just a few days, thanks to the comprehensive
documentation of the [API for plugins][5].

[oracle_fdw]: https://github.com/laurenz/oracle_fdw
[mysql_migrator]: https://github.com/fljdin/mysql_migrator
[5]: https://github.com/cybertec-postgresql/db_migrator#plugin-api

After installing the extensions with `make install` and the appropriate FDW for
the system, it is necessary to create the objects in the database that will hold
the future schemas and their data.

```sql
CREATE EXTENSION mysql_fdw;
CREATE EXTENSION mysql_migrator CASCADE;

CREATE SERVER mysql FOREIGN DATA WRAPPER mysql_fdw
   OPTIONS (host 'mysql_db', fetch_size '1000');
CREATE USER MAPPING FOR PUBLIC SERVER mysql
   OPTIONS (username 'root', password 'password');
```

The migration process can be performed in a single command for the simplest
cases (no stored procedures or exotic column types) using the `db_migrate()`
method. Otherwise, for more complex scenarios requiring adjustments such as
changing column types or removing a table in the target schema, the migration
may involve multiple steps.

During the development of the `mysql_migration` extension, I started with the
sample database [Sakila][6] provided by MySQL to have comprehensive complexity.
The first step involves creating two internal schemas, one with external tables
provided by the plugin and the other with catalog tables that can be edited
before the extension continues the migration.

[6]: https://dev.mysql.com/doc/sakila/en/

```sql
SELECT db_migrate_prepare(
   plugin => 'mysql_migrator',
   server => 'mysql',
   only_schemas => '{sakila}'
);
```

This part can be relatively lengthy, as it involves retrieving the data model,
which I refer to as the catalog, in the form of several tables that describe the
structure of tables, column names, and associated constraints. The extension
also imports the sources of all stored procedures, functions, and views but does
not perform their conversion to PL/pgSQL (you cannot imagine the [amount of work
involved][7]).

[7]: https://blog-dalibo-com.translate.goog/2020/12/21/migration_oracle_vers_postgresql.html?_x_tr_sl=fr&_x_tr_tl=en&_x_tr_hl=fr&_x_tr_pto=wapp

For the migration of the Sakila database, several modifications to the catalog
are necessary. Like the rest of this extension, all the preparation is done in
SQL, making it easy to automate with a single script serving as configuration.

```sql
/* exclude bytea columns from migration */
DELETE FROM pgsql_stage.columns WHERE type_name = 'bytea';

/* quote character expression */
UPDATE pgsql_stage.columns
   SET default_value = quote_literal(default_value)
   WHERE NOT regexp_like(default_value, '^\-?[0-9]+$')
   AND default_value <> 'CURRENT_TIMESTAMP';

/* disable view migration */
UPDATE pgsql_stage.views SET migrate = false;
```

Of course, we could go further, such as reinjecting the definition of rewritten
views into the `pgsql_stage.views` table or enabling the migration of procedures
by changing the `migrate` column of the `pgsql_stage.functions` table. However,
let's proceed with the next step.

```sql
SELECT db_migrate_mkforeign(
   plugin => 'mysql_migrator',
   server => 'mysql'
);

SELECT db_migrate_tables(
   plugin => 'mysql_migrator'
);
```

The first method, `db_migrate_mkforeign()`, is responsible for creating schemas
and sequences, followed by foreign tables with columns based on the previous
adjustments. Next comes the most crucial step, where we execute the function
`db_migrate_tables()`: blank tables are created with their partitions if
necessary, and for each of them, the data copying begins using the `INSERT INTO
SELECT *` statement.

Other objects, such as indexes or constraints, have their own methods. It is
necessary to create the functions before these objects if you encounter
functional indexes or other similar cases.

```sql
SELECT db_migrate_functions(plugin => 'mysql_migrator');
SELECT db_migrate_triggers(plugin => 'mysql_migrator');
SELECT db_migrate_views(plugin => 'mysql_migrator');
SELECT db_migrate_indexes(plugin => 'mysql_migrator');
SELECT db_migrate_constraints(plugin => 'mysql_migrator');
```

{{< message >}} 
It is possible that this mechanism may change in the future, especially if I
manage to realize this [issue][8], which would allow breaking down the
`db_migrate_*()` methods into smaller steps.

[8]: https://github.com/cybertec-postgresql/db_migrator/issues/26
{{< /message >}}

The end of the migration process involves deleting the temporary schemas that
contained the catalog tables.

```sql
SELECT db_migrate_finish();
```

---

## One more migration tool

As I mentioned in the introduction, it is quite surprising to see a new
migration tool emerge in 2023 (the version 1.0.0 was [released in January][9]
with my patch on partitioning). In the open-source landscape, we can mention
**Ora2Pg**, which released its [version 24.0][10] in July with SQL Server
support, and **pgloader**, which has an excellent reputation.

[9]: https://github.com/cybertec-postgresql/db_migrator/blob/master/CHANGELOG.md
[10]: https://github.com/darold/ora2pg/releases/tag/v24.0

A vast number of projects are listed on the [community wiki][11]. Some are
specialized for a single system, while others support migration for multiple
systems. The majority of these projects are either proprietary or lack recent
contributions. Many of them are black boxes, and their documentation may appear
cryptic or almost non-existent.

[11]: https://wiki.postgresql.org/wiki/Converting_from_other_Databases_to_PostgreSQL

The ecosystem is rich, and I do not claim to know all of its aspects, but I have
had an intuition that I have been forming over the past few years. The global
economy is in a state of turmoil. Some companies are doing well, while others
are making budget cuts. The transition to a free and non-commercially licensed
system like PostgreSQL remains relevant, perhaps even more urgent today compared
to the past decade.

And yet, with my DBA perspective, I am not fully satisfied with the existing
tools. I wish for a new alternative, something universal and accessible to
everyone. If I turn to **db_migrator** today, it would be for the following main
advantages:

* A low-level implementation close to the instance: using PL/pgSQL as the
  exclusive language. This would not have been possible without the prolific
  development of [Foreign Data Wrappers][12] for a wide range of systems;

* A high level of configuration flexibility: adjustments are made with `UPDATE`
  or `DELETE` queries on the catalog. Once one is familiar with the model of the
  catalog, it becomes easy to change behavior without consulting technical
  documentation on the available options;

* Freedom in orchestration: currently, executions are triggered sequentially for
  indexes and constraints, but the tool's architecture could allow external
  tools to consume the extension's results and trigger operations in parallel;

* Plugins have the freedom to enrich migration: if an operation is not generic,
  it is entirely possible to provide an additional method through the plugin.
  For example, the incremental copy (and its [replication functions][13]) in the
  **ora_migrator** plugin or the conversion of auto-increments to identity
  columns with the **mysql_migrator** plugin.

[12]: https://wiki.postgresql.org/wiki/Foreign_data_wrappers
[13]: https://github.com/cybertec-postgresql/ora_migrator#replication-functions

The road to freedom still seems long to achieve half of what Ora2Pg already
offers, especially when it comes to automatic conversion, which is not on the
agenda at all. But with small, regular, and thoughtful advancements, who knows?
