---
title: "Halte aux régressions"
date: 2022-04-21
categories: [postgresql]
tags: [developpement,tests]
---

Pour garantir la qualité du code d'un logiciel, rien de mieux que la validation
par les tests. Ces derniers peuvent être de différentes natures (fonctionnels,
intégration, unitaires, performance, etc.) et permettent de respecter une série
d'exigences que s'imposent les développeurs pour maintenir et faire évoluer ledit
logiciel dans la bonne direction.

Dans cet article, je souhaite explorer le système de tests tel qu'il est (et
a été) implémenté dans PostgreSQL et comment le réemployer dans la rédaction d'une
extension communautaire. Si vous ne connaissiez pas l'outil `pg_regress`, il 
n'aura plus de secret pour vous !

<!--more-->

---

## Aux origines des tests de régression

Avant même l'émergence du plus avancé des systèmes de bases de données open-source
du monde que l'on connait, le projet Berkeley [POSTGRES][1] disposait déjà d'un 
répertoire `src/regress/regress` dans sa dernière version connue. Celui-ci fut
définitivement adopté sous la forme de `src/test/regress` lors de la reprise du
projet Postgre95 par les [deux étudiants][2] Andrew Yu et Jolly Chen.

[1]: https://dsf.berkeley.edu/postgres-v4r2/
[2]: https://www.postgresql.org/docs/14/history.html

Ce n'est pas anodin, car ce répertoire existe encore dans les versions modernes
et porte toujours les mêmes responsabilités, à savoir : s'assurer que les
fonctionnalités de PostgreSQL ne présentent aucune régression à chaque patch ou
nouvelle version majeure. Ce système de test est relativement simple à 
appréhender et très répandu dans le milieu du développement des logiciels libres.

Il repose sur les fichiers de tests au format SQL et des fichiers de sorties au
format OUT. L'astuce consiste à exécuter le code SQL sur une instance en cours
d'exécution et de capter la sortie standard dans un fichier de résultat. Pour
chaque test (`sql`), le fichier de résultat (`result`) est ensuite comparé au 
résultat attendu du test (`expected`) à l'aide de la méthode `diff`.

![Fonctionnement du système de tests](/img/fr/2022-04-21-regress-path.png)

<!-- https://mermaid-js.github.io/mermaid-live-editor
{
  "theme": "default"
}
graph LR
    test[test.sql] --\>|runtest| instance[(instance)]
    instance --\> result[result.out] --\> diff
    expected[expected.out] --\> diff{diff}
    diff --\> passed((passed))
-->

Ce traitement est réalisé depuis la version 7.1 par l'utilitaire `pg_regress.sh`.
À l'origine, ce dernier était un [simple script shell][3] responsable de monter 
une instance PostgreSQL temporaire au besoin, de rapprocher les fichiers SQL de 
leurs résultats OUT et de fournir un résumé des tests. Le script fut intégralement
[remplacé][4] par son équivalent `pg_regress` réécrit en C à la sortie de la
version 8.2, pour faciliter notamment :

[3]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=blob;f=src/test/regress/pg_regress.sh;h=323035f0947d44b8102af1afd0d453846cd1073d;hb=6f64c2e54a0b14154a335249f4dca91a39c61c50
[4]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=a38c85bd5d928115fdd22c9e28e0a7eeebc9878e

* La validation des tests sur un environnement Windows sans émulateur de shell
  tel que `mingw`
* La mise à disposition d'un outil prêt à l'emploi avec l'installation de PostgreSQL,
  sans dépendance système requis par l'ancien script
* Apporter de nouvelles améliorations comme l'exécution concurrente des tests
  ou un résultat plus conviviale

Lors d'une compilation des binaires d'une version quelconque de PostgreSQL, il
est possible de valider tout ou partie des fonctionnalités à l'aide de la commande
`make check` ou `make installcheck`. La première des deux commandes créée une
instance temporaire alors que la seconde va exécuter les tests sur une instance
en cours d'exécution.

```sh
make check

PATH="tmp_install/var/lib/pgenv/pgsql-14.2/bin:src/test/regress:$PATH" \
LD_LIBRARY_PATH="tmp_install/var/lib/pgenv/pgsql-14.2/lib:$LD_LIBRARY_PATH" \
../../../src/test/regress/pg_regress \
  --temp-instance=./tmp_check \
  --inputdir=. --bindir= --dlpath=. \
  --max-concurrent-tests=20 \
  --make-testtablespace-dir \
  --schedule=./parallel_schedule
```
```text
============== removing existing temp instance        ==============
============== creating temporary instance            ==============
============== initializing database system           ==============
============== starting postmaster                    ==============
running on port 58082 with PID 24013
============== creating database "regression"         ==============
CREATE DATABASE
ALTER DATABASE
============== running regression test queries        ==============
test tablespace                   ... ok          165 ms
parallel group (20 tests):
     boolean                      ... ok           47 ms
     char                         ... ok           40 ms
     name                         ... ok           41 ms
     varchar                      ... ok           38 ms
     text                         ... ok           34 ms
     int2                         ... ok           24 ms
     int4                         ... ok           23 ms
     int8                         ... ok           55 ms
     oid                          ... ok           43 ms
     float4                       ... ok           60 ms
...
parallel group (2 tests):
     event_trigger                ... ok           59 ms
     oidjoins                     ... ok          119 ms
test fast_default                 ... ok           71 ms
test stats                        ... ok          620 ms

============== shutting down postmaster               ==============
============== removing temporary instance            ==============
...
=======================
 All 210 tests passed. 
=======================
```

---

## Tester son extension avec PGXS

En plusieurs années, l'outil `pg_regress` s'est étendu aux fonctionnalités annexes
du projet PostgreSQL, comme les langages embarqués (`plpgsql`, `plperl`, etc.) ou
les contributions communautaires. 

Le système [PGXS][5] propose aux membres de la communauté d'enrichir leurs
`Makefile` avec des règles de compilation, d'installation et de validation par
`pg_regress`. Dans un projet, il est ainsi recommandé d'inclure les directives 
du PGXS pour bénéficier de la règle `installcheck` responsable des tests.

[5]: https://www.postgresql.org/docs/14/extend-pgxs.html

Prenons l'exemple de la contribution `pgstattuple` avec la définition de son
[Makefile][6]. Ce dernier contient les quelques variables nécessaires pour la
compilation et l'installation, puis inclut les règles `pgxs.mk` si le système
est utilisé.

[6]: https://github.com/postgres/postgres/blob/REL_14_2/contrib/pgstattuple/Makefile

```sh
# contrib/pgstattuple/Makefile
REGRESS = pgstattuple

ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
else
subdir = contrib/pgstattuple
top_builddir = ../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif
```

Avec cette configuration par défaut, l'outil `pg_regress` part à la recherche des
fichiers `sql/` dans le répertoire courant, et les exécute sur l'instance pour
ensuite comparer ses résultats avec les fichiers `expected/`. Le contenu du
fichier `expected/pgstattuple.out` peut être consulté directement dans le [code
source][7] de PostgreSQL.

```text
pgstattuple
├── expected
│   └── pgstattuple.out
├── results
│   └── pgstattuple.out
└── sql
    └── pgstattuple.sql
```

[7]: https://github.com/postgres/postgres/blob/REL_14_2/contrib/pgstattuple/expected/pgstattuple.out


Lançons les tests de l'extension avec le système PGXS :

```sh
cd contrib/pgstattuple
export USE_PGXS=1
make install installcheck
```

```text
./lib/pgxs/src/makefiles/../../src/test/regress/pg_regress \
  --inputdir=./ --bindir='./bin' \
  --dbname=contrib_regression pgstattuple

(using postmaster on Unix socket, default port)
============== dropping database "contrib_regression" ==============
DROP DATABASE
============== creating database "contrib_regression" ==============
CREATE DATABASE
ALTER DATABASE
============== running regression test queries        ==============
test pgstattuple                  ... ok          167 ms

=====================
 All 1 tests passed. 
=====================
```

---

## Pensez-y !

Vous souhaitez développer votre propre extension pour révolutionner PostgreSQL ?
Pensez à écrire vos tests avec le _framework_ PGXS ! La [documentation][8] est
très fournie à ce sujet pour prendre en main les variables d'environnement. De
plus depuis la version PostgreSQL 9.4, il est possible de bénéficier de standard
TAP pour [rédiger vos tests][9]. 

[8]: https://www.postgresql.org/docs/current/regress-run.html
[9]: https://www.2ndquadrant.com/en/blog/using-postgresql-tap-framework-extensions/

Les extensions sont nombreuses et ce n'est jamais une mauvaise idée de s'inspirer
des contributions maintenues dans le projet PostgreSQL. Je recommande également 
la [série d'articles][10] rédigée par Manuel Kniep pour comprendre le processus
complet de l'écriture d'une extension ou la [conférence][11] de Lætitia Avrot
sur l'extension [pgwaffles][12] créée à l'occasion du FOSDEM 2021.

[10]: http://big-elephants.com/2015-10/writing-postgres-extensions-part-i/
[11]: https://l_avrot.gitlab.io/slides/postgres-waffles.html
[12]: https://gitlab.com/l_avrot/pgwaffles