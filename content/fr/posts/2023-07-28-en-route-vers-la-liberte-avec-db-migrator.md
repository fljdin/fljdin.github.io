---
title: "En route vers la liberté avec db_migrator"
categories: [postgresql]
tags: [sqlmed, developpement, migration]
date: 2023-07-28
translationKey: "en-route-vers-la-liberte-avec-db-migrator"
---

J'ai passé plusieurs semaines ces derniers mois à contribuer à l'extension
[db_migrator]. Rédigée uniquement en PL/pgSQL, elle permet de migrer les schémas
et les données d'un système de bases de données vers PostgreSQL à l'aide des
données externes que j'avais déjà présentées il y a [quelques années][1].

[db_migrator]: https://github.com/cybertec-postgresql/db_migrator
[1]: /2021/07/16/parlons-un-peu-des-donnees-externes/

Dans cet article, je présente le fonctionnement de l'outil, sa philosophie et la
raison d'être que je lui ai trouvée, alors même qu'il rejoint l'écosystème des
projets libres déjà bien installés dans le paysage de la migration. Que vaut-il
aux côtés d'[Ora2Pg] ou de [pgloader] ?

[Ora2Pg]: https://ora2pg.darold.net/
[pgloader]: https://pgloader.io/

<!--more-->

---

## db_migrator entre dans l'arène

Mon intérêt pour ce projet remonte à décembre dernier, alors qu'un [collègue de
chez Dalibo][2] nous laissait en héritage un [outil similaire][3] avec lequel il
lui était possible de copier les données d'instances Oracle ou Sybase à l'aide
de la technologie des _Foreign Data Wrappers_ (FDW). Bien que cet outil soit
resté en alpha, beaucoup de bonnes idées y ont été expérimentées en interne.

[2]: https://blog.dalibo.com/2022/12/21/depart_philippe.html
[3]: https://github.com/dalibo/data2pg

La promesse des FDW réside dans le respect de la norme SQL/MED, à savoir qu'une
instance PostgreSQL puisse s'interfacer sur un autre système de stockage et en
manipuler les données à travers les tables externes avec de simples requêtes
SQL. Ainsi, pour peu qu'une communauté ait développé le _wrapper_, il est
possible de consulter un catalogue distant, reproduire la structure des tables,
ses relations et ses contraintes, et de [rapatrier les données][4] vers
PostgreSQL.

[4]: /2021/12/06/migrer-vers-postgresql/

Et [db_migrator] entre dans l'arène.

Rendue publique en novembre 2019 par Laurenz Albe, connu pour sa contribution
active sur PostgreSQL depuis des décennies et également pour le développement de
[oracle_fdw], l'extension se présente comme un outil générique avec lequel il
faut employer des _plugins_ pour la prise en charge des FDW. Il est aisé d'en
créer de nouveaux, comme j'ai pu m'en rendre compte avec le plugin
[mysql_migrator], écrit en quelques jours, grâce à la documentation très
complète de l'[API des plugins][5].

[oracle_fdw]: https://github.com/laurenz/oracle_fdw
[mysql_migrator]: https://github.com/fljdin/mysql_migrator
[5]: https://github.com/cybertec-postgresql/db_migrator#plugin-api

Après avoir installé les extensions avec `make install` ainsi que le FDW du bon
système, il est nécessaire de créer les objets dans la base de données qui va
contenir les futurs schémas et leurs données.

```sql
CREATE EXTENSION mysql_fdw;
CREATE EXTENSION mysql_migrator CASCADE;

CREATE SERVER mysql FOREIGN DATA WRAPPER mysql_fdw
   OPTIONS (host 'mysql_db', fetch_size '1000');
CREATE USER MAPPING FOR PUBLIC SERVER mysql
   OPTIONS (username 'root', password 'password');
```

L'opération de migration peut être réalisée en une seule commande pour les cas
les plus simples (pas de procédure stockée, ni de types de colonnes exotiques)
avec la méthode `db_migrate()`. Sinon, en plusieurs étapes, s'il est nécessaire
de faire des ajustements comme le changement du type de colonne ou le retrait
d'une table dans le schéma cible.

Lors du développement de l'extension `mysql_migration`, je suis parti de la base
d'exemple [Sakila][6] fournie par MySQL afin d'avoir une complexité exhaustive.
La première étape consiste à créer deux schémas internes, l'un avec des tables
externes fournies par le plugin, l'autre avec des tables de catalogue que l'on
peut éditer avant que l'extension ne poursuive la migration.

[6]: https://dev.mysql.com/doc/sakila/en/

```sql
SELECT db_migrate_prepare(
   plugin => 'mysql_migrator',
   server => 'mysql',
   only_schemas => '{sakila}'
);
```

Cette partie peut être relativement longue, puisqu'elle va permettre de
rapatrier le modèle de données, que j'appelle le catalogue, sous la forme de
plusieurs tables qui décrivent la structure des tables, le nom des colonnes ou
les contraintes qui leur sont associées. L'extension importe également les
sources de toutes les procédures stockées, les fonctions, les vues, mais ne
réalise pas leur conversion en PL/pgSQL (vous ne vous rendez pas compte du
[travail que cela représente][7]).

[7]: https://blog.dalibo.com/2020/12/21/migration_oracle_vers_postgresql.html

Dans le cas de la migration de la base Sakila, il est nécessaire de faire
plusieurs modifications du catalogue. Comme le reste avec cette extension, toute
la préparation se réalise en SQL, ce qui rend facile l'automatisation avec un
unique script en guise de configuration.

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

On pourrait bien sûr aller plus loin, comme réinjecter la définition des vues
réécrites dans la table `pgsql_stage.views` ou activer la migration des
procédures en changeant la colonne `migrate` de la table
`pgsql_stage.functions`. Mais progressons avec l'étape suivante.

```sql
SELECT db_migrate_mkforeign(
   plugin => 'mysql_migrator',
   server => 'mysql'
);

SELECT db_migrate_tables(
   plugin => 'mysql_migrator'
);
```

La première méthode `db_migrate_mkforeign()` va se charger de créer les schémas
et les séquences, puis les tables étrangères avec les colonnes au regard des
ajustements précédents. Ensuite, l'étape la plus cruciale, on exécute la
fonction `db_migrate_tables()` : les tables vierges sont créées avec leurs
partitions si besoin, et pour chacune d'entre elles, débute alors la copie des
données avec l'instruction `INSERT INTO SELECT *`.

Les autres objets, tels que les index ou les contraintes, disposent de leur
propre méthode. Il est nécessaire de créer les fonctions avant ces derniers si
vous êtes confronté à des index fonctionnels ou que sais-je.

```sql
SELECT db_migrate_functions(plugin => 'mysql_migrator');
SELECT db_migrate_triggers(plugin => 'mysql_migrator');
SELECT db_migrate_views(plugin => 'mysql_migrator');
SELECT db_migrate_indexes(plugin => 'mysql_migrator');
SELECT db_migrate_constraints(plugin => 'mysql_migrator');
```

{{< message >}}
Il se pourrait que ce mécanisme change à l'avenir, notamment si je parviens à
concrétiser cette [issue][8] qui permettrait de découper les méthodes
`db_migrate_*()` en de plus petites étapes.

[8]: https://github.com/cybertec-postgresql/db_migrator/issues/26
{{< /message >}}

La fin de la migration consiste à supprimer les schémas temporaires dans
lesquels se trouvaient les tables du catalogue.

```sql
SELECT db_migrate_finish();
```

---

## Raison d'être de l'extension

Comme je le disais en introduction, c'est assez surprenant de voir un nouvel
outil de migration émerger en 2023 (la version 1.0.0 est [sortie en janvier][9]
avec mon patch sur l'ajout du partitionnement). Dans le paysage open-source, nous
pouvons parler d'**Ora2Pg** qui a sorti en juillet sa [version 24.0][10] avec
le support de SQL Server ou bien de **pgloader** qui a une excellente réputation.

[9]: https://github.com/cybertec-postgresql/db_migrator/blob/master/CHANGELOG.md
[10]: https://github.com/darold/ora2pg/releases/tag/v24.0

De très nombreux projets sont listés sur le [wiki communautaire][11]. Certains
sont spécialisés pour un seul système, d'autres en migrent plusieurs. Une très
grande majorité d'entre eux sont propriétaires ou n'ont plus de contribution
récente. La plupart sont des boîtes noires et leur documentation peut paraître
cryptique, voire quasi inexistante.

[11]: https://wiki.postgresql.org/wiki/Converting_from_other_Databases_to_PostgreSQL

L'écosystème est riche, je ne prétends pas tous les connaître, mais j'ai une
intuition que je me forge depuis quelques années. L'économie mondiale est en
surchauffe. Certaines sociétés se portent bien, d'autres font des coupes
budgétaires. La transition vers un système libre et sans licence commerciale
comme PostgreSQL est toujours d'actualité, peut-être même plus urgente
aujourd'hui en comparaison à la décennie qui vient de s'écouler.

Et pourtant, avec mes lunettes de DBA, je ne me satisfais pas encore des outils
qui existent. J'aimerais qu'il y ait une nouvelle alternative, quelque chose
d'universel et à portée de tout le monde. Si je me tourne aujourd'hui vers
**db_migrator**, ce serait pour les principaux atouts suivants :

* Une implémentation bas niveau au plus près de l'instance : avec le PL/pgSQL
  comme langage exclusif. Cela n'aurait pas été possible bien sûr sans le
  développement prolifique des _[Foreign Data Wrappers][12]_ pour un grand
  nombre de systèmes ;

* Une très grande flexibilité de configuration : puisque les ajustements se font avec
  des requêtes `UPDATE` ou `DELETE` sur le catalogue. Pour peu que l'on soit à l'aise
  avec le modèle de ce dernier, il devient facile de changer un comportement sans
  consulter une documentation technique sur les options qui se présentent à nous ;

* Une liberté dans l'orchestration : à ce jour, les exécutions sont déclenchées de
  façon séquentielle pour les index et les contraintes, mais l'architecture de l'outil
  pourrait permettre que des outils externes soient responsables de consommer les
  résultats de l'extension et de déclencher les opérations en parallèle ;

* Les plugins sont libres d'enrichir la migration : si une opération n'est pas
  générique, il est tout à fait possible de fournir une méthode supplémentaire à
  l'aide du plugin. C'est le cas de la copie incrémentale (et ses [fonctions de
  réplication][13]) du plugin **ora_migrator** ou bien la conversion des
  auto-incréments en colonnes d'identité avec le plugin **mysql_migrator**.

[12]: https://wiki.postgresql.org/wiki/Foreign_data_wrappers
[13]: https://github.com/cybertec-postgresql/ora_migrator#replication-functions

Le chemin vers la liberté me semble encore long pour prétendre faire la moitié
de ce que propose déjà Ora2Pg, à commencer par la conversion automatique qui
n'est pas du tout à l'ordre du jour. Mais avec de petites avancées, régulières
et réfléchies, qui sait ?
