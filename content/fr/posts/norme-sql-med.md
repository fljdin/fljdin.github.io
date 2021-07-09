---
title: "Parlons un peu des données externes"
categories: [postgresql]
tags: [sqlmed,developpement]
date: 2021-06-24
draft: true
---

Depuis plusieurs semaines, j'étudie les nouveautés de la [prochaine version majeure][1]
de PostgreSQL avec un intérêt grandissant pour le connecteur [postgres_fdw][2].
Cette extension assez folle n'a pas son équivalent sur les autres systèmes de 
bases de données du marché, et pour cause, PostgreSQL est l'un des rares à respecter
la norme SQL/MED, sous-partie du langage SQL tel que défini par le standard 
[ISO/IEC 9075-9][3].

[1]: https://www.postgresql.org/docs/14/release-14.html
[2]: https://www.postgresql.org/docs/13/postgres-fdw.html
[3]: https://www.iso.org/fr/standard/63476.html

<!--more-->

---

## Une langage pour les manipuler tous

<!--

* norme sql/med rév. 2016
https://wiki.postgresql.org/wiki/SQL/MED
https://wiki.postgresql.org/wiki/SqlMedConnectionManager
ISO/IEC 9075-9:2008 https://www.iso.org/fr/standard/38643.html

* conférences
https://www.pgcon.org/2009/schedule/attachments/133_pgcon2009-sqlmed.pdf
https://www.percona.com/live/e18/sites/default/files/slides/PostgreSQL-%20SQL-MED%20(FDW)%20-%20FileId%20-%20146376.pdf

* articles
https://rhaas.blogspot.com/2011/01/why-sqlmed-is-cool.html
https://blog.ansi.org/2018/10/sql-standard-iso-iec-9075-2016-ansi-x3-135/
https://pgsnake.blogspot.com/2011/04/tinkering-with-sqlmed.html

* fonctionnalités phare

Importing Foreign Schemas
> IMPORT FOREIGN SCHEMA someschema
>  LIMIT TO (tab, tab, tab)
>  FROM SERVER extradb
>  INTO myschema;

Datalink

* évolutions au cours des versions

* Nouveautés PG 14

TRUNCATE https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=8ff1c94649f5c9184ac5f07981d8aea9dfd7ac19
Async Append https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=27e1f14563cf982f1f4d71e21ef247866662a052

* les connexions sont maintenue 'idle' sur les postgresql distants
* dblink
* plproxy https://plproxy.github.io/

-->