---
title: "Migrer vers PostgreSQL"
categories: [postgresql]
tags: [migration, sqlmed, opensource]
date: 2021-11-16
draft: true
---

Le marché de la migration en France est intense. Le Groupe de Travail 
Inter-Entreprises PostgreSQL (PGGTIE) a même publié un [guide de transition][1]
à PostgreSQL à destination des entreprises françaises après plus de cinq années
de rédaction au sein de différents ministères. Il y a quelques semaines, une 
version internationale est [sortie des cartons][2] pour promouvoir davantage
ce mouvement vers le logiciel libre dans les autres pays.

[1]: https://www.postgresql.fr/_media/entreprises/guide-de-transition_v2.0.pdf
[2]: https://twitter.com/nthonynowocien/status/1458065335387578382

<!--more-->

<!--
https://www.migops.com/blog/2021/07/01/ora2pg-now-supports-oracle_fdw-to-increase-the-data-migration-speed/
-->

---

## Une transition à marche forcée

La démarche n'est pas anodine, car depuis 2012, l'État français au travers de ses
différents ministères, tente de contrer l'imposant marché des logiciels 
propriétaires en favorisant leurs remplacements systématiques par une alternative
Open Source. Depuis quelques années, le [socle interministériel des logiciels libres][3]
(SILL) est mis à jour par un groupe de travail pour faire un bilan des choix
structurants engagés sur le territoire français.

[3]: https://www.numerique.gouv.fr/actualites/socle-interministeriel-des-logiciels-libres-sill-2020/

La publication d'un guide de transition pour PostgreSQL aspire à rassurer les 
équipes opérationnelles et décisionnelles en apportant un grand nombre de conseils
et de comparaisons sur ce qu'il est aujourd'hui possible de faire avec PostgreSQL.
Il est mention des trois grandes étapes pour réaliser la migration des données
d'une application vers le moteur open-source :

- migration des données ;
- correction et réécriture des requêtes SQL et des procédures embarquées ;
- recette du système pour écarter les régressions fonctionnelles.

Chacune de ces étapes a un coût, qu'il sera nécessaire de pondérer durant le
chantier de migration. Les logiciels Open Source sont libres, mais ne sont pas
gratuits et c'est un rappel essentiel que propose les conclusions de ce guide.
Les coûts de formation et de prestations externes ne sont également pas 
négligeables…

En 2018, la société française [Dalibo](https://dalibo.com) avait publié un
[livre blanc][4] dans ce même esprit de démagogie sur l'importance des coûts 
d'investissement et de possession. Dans un scénario de migration, acté sur cinq
années de transition, l'étude montre que l'analyse de portabilité vers PostgreSQL
est la principale dépense au cours de la première année, suivi par un 
investissement important pour la recherche et le développement d'un socle d'outils
dédiés aux déploiements, la maintenance et l'administration du parc PostgreSQL.

[4]: https://public.dalibo.com/archives/marketing/livres_blancs/18.10/DLB01_Migrer_Oracle_Postgresql.pdf

![Plan d'investissement](/img/fr/cout-d-investissement.png)

![Plan de possession](/img/fr/cout-de-possession.png)

La seconde courbe peut paraître surprenante pour du logiciel libre, mais la
nécessité de contracter une offre de support reste d'actualité, car trop peu de
services informatiques disposent des compétences internes pour assurer la 
disponibilité et la maintenance des instances. Un effort initial de formation est
requis pour aider les administrateurs en poste à faire également leur transition
vers une autre technologie.

Pour cette raison, de nombreux acteurs se positionnent depuis des décennies pour 
proposer de l'accompagnement opérationnel et technique auprès des entreprises
de toutes tailles qui souhaitent (principalement) réduire les coûts de licence
de logiciels propriétaires. Et bien que la transition pouvait être pénible il y
a dix ans, les dernières versions de PostgreSQL apportent un lot de 
fonctionnalités qui ne rougissent plus devant les atouts phares de certains
mastodontes historiques du marché.

---

## S'armer d'outils et de courage

Réaliser une migration impose de s'équiper d'un panel d'outils pour simplifier
les grandes lignes de la migration et bien sûr, économiser du temps et de l'argent.
Parmi les contributions libres, nous retrouverons l'incontournable [Ora2pg][5],
spécialisé dans la conversion d'un schéma Oracle et la migration de ses données
version une instance PostgreSQL. Pour un base de type SQL Server de Microsoft,
[pgloader][6] sera privilégié. Les deux outils supportent également les données
en provenance de MySQL.


[5]: https://ora2pg.darold.net/
[6]: https://pgloader.io/

En [juillet dernier][7], je partageais mes réflexions sur l'implémentation de la
norme SQL/MED à travers les _foreign data wrappers_, ou connecteurs. Leurs mises
en place permettent d'élargir la liste des systèmes tels que DB2, Sybase ou 
Informix, avec notamment la syntaxe `IMPORT FOREIGN SCHEMA`. L'actualité fut 
particulièrement riche cet été, avec la sortie de la [version 22.0][8] du projet
Ora2Pg, dont le nouveau support de l'extension `oracle_fdw` annonçait des gains
vertigineux sur le temps de copie des données.

[7]: /2021/07/16/parlons-un-peu-des-donnees-externes/
[8]: https://www.migops.com/blog/2021/07/01/ora2pg-now-supports-oracle_fdw-to-increase-the-data-migration-speed/

L'installation des deux outils n'est pas triviale. Le connecteur `oracle_fdw`
nécessite d'être compilé à partir des [sources du projet][9] pour prendre en
compte les bibliothèques propriétaires d'Oracle pour l'interface client, garante
des connexions et des échange de données. Dans l'exemple ci-dessous, je dispose
d'un serveur CentOS 7 avec une instance PostgreSQL 14 et j'ai installé
l'_InstantClient_ 19, [disponible][10] sur la plateforme de téléchargement d'Oracle.

[9]: https://github.com/laurenz/oracle_fdw/
[10]: https://www.oracle.com/database/technologies/instant-client/downloads.html

```bash
yum install -y postgresql14-devel
export ORACLE_HOME=/usr/lib/oracle/19.13/client64
export LD_LIBRARY_PATH=$ORACLE_HOME/lib
export PATH=$PATH:$ORACLE_HOME/bin

cd ORACLE_FDW_2_4_0/
make PG_CONFIG=/usr/pgsql-14/bin/pg_config
make PG_CONFIG=/usr/pgsql-14/bin/pg_config install
ln -s $LD_LIBRARY_PATH/libclntsh.so.19.13 /usr/pgsql-14/lib/
```

Pour résoudre des éventuels problèmes de détection des librairies, il peut être
requis de propager les variables d'environnement pour l'instance PostgreSQL au
niveau de son service :

```bash
systemctl edit postgresql-14
```
```ini
[Service]
Environment=ORACLE_HOME=/usr/lib/oracle/19.13/client64
Environment=LB_LIBRARY_PATH=$ORACLE_HOME/lib
Environment=PATH=$PATH:$ORACLE_HOME/bin
```

L'extension peut ainsi être créée dans la base qui accueillera les données finale.

```bash
createdb --owner=hr hr
psql -c "CREATE EXTENSION oracle_fdw" hr
psql -c "GRANT USAGE ON FOREIGN DATA WRAPPER oracle_fdw TO hr" hr
```

---

Concernant Ora2Pg, l'outil repose sur plusieurs dépendances Perl, notamment le
pilotes `DBD::Perl` et `DBD::Oracle`, avec un passage obligé par une compilation
des sources ou grâce à l'utilitaire `cpan`.

```bash
yum install -y cpan perl-DBD-Pg
export ORACLE_HOME=/usr/lib/oracle/19.13/client64
export LD_LIBRARY_PATH=$ORACLE_HOME/lib
cpan install DBD::Oracle

cd ora2pg-23.0/
unset PERL_MM_OPT
perl Makefile.PL
make
make install
```

```bash
ORACLE_HOME   /opt/oracle/product/18c/dbhomeXE
ORACLE_DSN    dbi:Oracle://centos7:1521/hr
ORA2PG_USER   hr
ORA2PG_PASSWD hr
SCHEMA        HR

PG_DSN        dbi:Pg:dbname=hr;host=localhost;port=5432
PG_USER       hr
PG_PWD        hr
PG_VERSION    14

FDW_SERVER          hr_fdw
DROP_FOREIGN_SCHEMA 0
```

```bash
ora2pg --conf hr.conf --type TABLE --out tables.sql
ora2pg --conf hr.conf --type SEQUENCE --out sequences.sql
ora2pg --conf hr.conf --type FDW --out foreign-tables.sql

# désactiver les contraintes
ora2pg -d --conf hr.conf --type COPY
```