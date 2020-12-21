---
date: 2020-12-21
title: "Compiler et patcher avec pgenv"
categories: [postgresql]
tags: [administration,opensource]
---

Parmi les quelques outils de mon quotidien, il y en a un très sobre et bigrement
efficace répondant au nom de [pgenv][1], un gestionnaire des versions PostgreSQL.
Ce projet est publié sous licence MIT par David E. Wheeler, auteur de l'extension 
pgTAP dont j'avais déjà vanté les mérites dans un [autre article].

Cet outil concerne principalement les contributeur⋅rices au projet PostgreSQL et les 
quelques DBA féru⋅es d'expérimentations, car `pgenv` permet de compiler et 
d'exécuter toutes les versions majeures et mineures du système de base de données
open-source le plus avancé du monde.

[1]: https://github.com/theory/pgenv
[autre article]: /2020/05/14/ecrire-ses-tests-unitaires-en-sql

<!--more-->

---

## À l'épreuve de la compilation

PostgreSQL est particulièrement simple à compiler. Avec un poste de travail
sous Unix, GNU/Linux ou BSD et quelques dépendances, à savoir `gcc`, `make`,
`patch` et `git`, il est facile d'exécuter une instance dans la version cible de son 
choix.

```bash
$ git clone git://git.postgresql.org/git/postgresql.git
$ cd postgresql
$ git checkout REL_13_1

$ export PREFIX=/tmp/postgres/devel
$ ./configure --prefix=$PREFIX
$ make && make install

$ cd contrib
$ make && make install
```

Dès lors que les librairies et les binaires sont disponibles, il est très aisé
de contruire sa première instance et de s'y connecter !

```bash
$ export PATH=$PREFIX/bin:$PATH
$ export LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH
$ export PGDATA=/tmp/postgres/data

$ initdb --username $(whoami) --auth=peer --data-checksums
$ pg_ctl start --log=$PGDATA/server.log

$ createdb $(whoami)
$ psql -tc "select version()"
 PostgreSQL 13.1 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 10.2.0, 64-bit

$ pg_ctl stop
```

Le faire à la main m'a amusé quelques minutes et écrire un script pour automatiser
le déploiement des versions mineures à la demande m'a vite traversé l'esprit.
Ne réinventons pas la roue et voyons ce que propose `pgenv` !

---

## Un script pour les compiler tous

La [page d'accueil][1] du projet reprend l'installation rapide du script dans votre
sous-répertoire `~/.pgenv`. Téléchargeons et compilons la version qui nous interesse.

```text
$ pgenv available
             Available PostgreSQL Versions
================================================
                      ...
                  PostgreSQL 10
------------------------------------------------
  10.0    10.1    10.2    10.3    10.4    10.5  
  10.6    10.7    10.8    10.9    10.10   10.11 
  10.12   10.13   10.14   10.15  

                  PostgreSQL 11
------------------------------------------------
  11.0    11.1    11.2    11.3    11.4    11.5  
  11.6    11.7    11.8    11.9    11.10  

                  PostgreSQL 12
------------------------------------------------
  12.0    12.1    12.2    12.3    12.4    12.5  

                  PostgreSQL 13
------------------------------------------------
  13beta1  13beta2  13beta3  13rc1   13.0  13.1
```

Comme pour mon précédent exemple, je réinstalle une version 13.1 avec `pgenv`
à l'aide de l'option `build`. Le script déploie également les librairies de _contrib_
et la documentation.

```bash
$ export PGENV_ROOT=/var/lib/pgenv
$ export PATH=$PGENV_ROOT/pgsql/bin:$PATH
$ export LD_LIBRARY_PATH=$PGENV_ROOT/pgsql/lib:$LD_LIBRARY_PATH

$ pgenv build 13.1
PostgreSQL, contrib, and documentation installation complete.
pgenv configuration written to file /var/lib/pgenv/.pgenv.13.1.conf
PostgreSQL 13.1 built
```

On retrouve dans l'arborescence `$PGENV_ROOT`, la présence de l'archive `.tar.bz2`
du projet, requise pour l'étape de compilation. Le `$PREFIX` quant à lui, est
automatiquement positionné sur le répertoire `$PGENV_ROOT/pgsql-13.1`.

```text
/var/lib/pgenv
├── .pgenv.13.1.conf
├── pgsql-13.1
│   ├── bin
│   ├── include
│   ├── lib
│   └── share
└── src
    ├── postgresql-13.1
    └── postgresql-13.1.tar.bz2
```

Pour être fidèle avec ma première partie, je vais configurer correctement les
paramètres de la commande `initdb` dans le fichier de configuration dédié à la
version 13.1.

```bash
$ pgenv config edit 13.1
# Path to the cluster log file (mandatory)
PGENV_LOG="$PGENV_ROOT/pgsql/data/server.log"

# Initdb flags
PGENV_INITDB_OPTS="--usernddame $(whoami) --auth=peer --data-checksums"
```

Ainsi, lors de la première utilisation de cette version 13.1, `pgenv` va lancer
la commande `initdb` pour alimenter le répertoire de données avec mon compte
comme propriétaire et démarrer le processus `postgres`.

```bash
$ pgenv use 13.1
Using PGENV_ROOT /var/lib/pgenv
Data page checksums are enabled.
Success. You can now start the database server using:
  /var/lib/pgenv/pgsql/bin/pg_ctl -D /var/lib/pgenv/pgsql/data -l logfile start

PostgreSQL 13.1 started
Logging to /var/lib/pgenv/pgsql/data/server.log

$ createdb $(whoami)
$ psql -tc "select version()"
 PostgreSQL 13.1 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 10.2.0, 64-bit
```

---

## Et avec ceci ?

Comme indiqué en introduction, l'intérêt d'un tel gestionnaire réside dans sa 
capacité d'installer plusieurs versions différentes dans la même arborescence
et de basculer de l'une à l'autre. 

Imaginons que nous souhaitons disposer d'une version 10 de PostgreSQL avec le
même genre de configuration que la version 13 précédente. `pgenv` supporte un
fichier d'environnement global, nommé `.pgenv.conf`, que je reconstruis à
partir de mon précédent fichier d'instance 13.1.

```bash
$ cp $PGENV_ROOT/.pgenv.13.1.conf $PGENV_ROOT/.pgenv.conf
$ pgenv build 10.15
$ pgenv use latest 10

$ createdb $(whoami)
$ psql -c "show data_checksums"

 data_checksums 
 ----------------
  on
 (1 row)
```

Nous nous retrouvons bien avec un instance dont les sommes de contrôle ont été
activées, grâce à l'option `PGENV_INITDB_OPTS` citée plus haut.

Je m'étais questionné sur la capacité de `pgenv` de lancer simultanément deux
environnements pour mettre en place de la réplication logique, par exemple.
Conclusion, il s'agit d'une des limites de l'outil, puisque ce n'est pas
son but premier. Et pour cause, à chaque fois que l'on appelle la commande
`pgenv use`, le script arrête l'instance courante avant de basculer sur la
deuxième.

```bash
$ pgenv use latest 10
Using PGENV_ROOT /var/lib/pgenv
PostgreSQL 13.1 stopped
PostgreSQL 10.15 started
Logging to /var/lib/pgenv/pgsql/data/server.log
```

En complément, `pgenv` met en place un lien symbolique dans la racine `$PGENV_ROOT`
à chaque changement de version courante. Ce lien a été ajouté au préalable
dans la variable `$PATH` pour garantir la bonne compatibilité des binaires avec
les données.

```text
/var/lib/pgenv
├── .pgenv.13.1.conf
├── .pgenv.conf
├── pgsql -> pgsql-10.15
├── pgsql-10.15
├── pgsql-13.1
└── src
```

Ce lien symbolique nous oblige à manipuler toutes autres les instances avec des
chemins absolus, une surcharge de leurs paramètres `port` ou `listen_address` et
de faire appel à la bonne version de la commande `pg_ctl`. Il est donc possible
de faire de la réplication, mais oubliez `pgenv` pour la gestion des processus
d'instances.

---

## Dans la cour des grands

Nous sommes en décembre 2020 à l'heure de la rédaction de cet article, et la
communauté PostgreSQL travaille activement sur le développement de la prochaine
version 14 du logiciel. Chaque année, les contributeur⋅rices du monde entier
se retrouvent en ligne autours du _[Commitfest][2]_ pour étudier les nouvelles
propositions de fonctionnalités ou de correction de bogues.

[2]: https://commitfest.postgresql.org/

En août dernier, Tatsuro Yamada proposait d'[enrichir][3] les méta-commandes de
l'invite `psql` afin de lister les [statistiques étendues][4] rattachées aux 
tables de la base courante. Cette fonctionnalité est donc étudiée à travers les 
échanges électroniques et suivie sur [une page dédiée][5] du _Commitfest_.

[3]: https://www.postgresql.org/message-id/flat/c027a541-5856-75a5-0868-341301e1624b@nttcom.co.jp_1
[4]: https://www.postgresql.org/docs/12/planner-stats.html#PLANNER-STATS-EXTENDED
[5]: https://commitfest.postgresql.org/31/2801/

<!--
option patch
pgxn
-->

Le contributeur produit alors un fichier `.patch` qu'il obtient avec la commande
`git diff` et dont le résultat est compatible avec la commande [patch][6]. Ainsi,
n'importe quel relecteur peut l'intégrer dans son projet et dérouler ses tests sur
la nouvelle instance compilée.

[6]: https://www.man7.org/linux/man-pages/man1/patch.1.html

C'est là qu'intervient une chouette fonctionnalité de l'outil `pgenv`. Ce dernier
propose d'appliquer une série de patchs dans une phase préliminaire dès lors qu'on
lui présente un fichier d'index pour la version associée, qui contiendra le chemin
absolu des fichiers à parcourir.

```text
/var/lib/pgenv
└── patch
    ├── 13
    │   └── 0001-Add-dX-command-on-psql-rebased-on-7e5e1bba03.patch
    └── index
        └── patch.13
```

Comme on le voit dans mon arborescence, j'ai téléchargé la dernière version
communiquée par le développeur et je l'ai déclarée dans le fichier `index.13`.
Lors de la recompilation de la version concernée, on constate que le patch
est bien pris en compte.

```bash
$ export PGENV_DEBUG=1
$ pgenv clear
$ pgenv rebuild 13.1
Using PGENV_ROOT /var/lib/pgenv
[DEBUG] Patch index file [/var/lib/pgenv/patch/index/patch.13]
[DEBUG] Applying patch [0001-Add-dX-command-on-psql-rebased-on-7e5e1bba03.patch]
        into source tree /var/lib/pgenv/src/postgresql-13.1
Applied patch 13/0001-Add-dX-command-on-psql-rebased-on-7e5e1bba03.patch 
PostgreSQL 13.1 built
```

Et la fonctionnalité devient disponible sur l'instance !

```text
florent=# \dX
                    List of extended statistics
 Schema | Name  |  Definition  | Ndistinct | Dependencies |   MCV   
--------+-------+--------------+-----------+--------------+---------
 public | stts1 | a, b FROM t1 |           | defined      | 
 public | stts2 | a, b FROM t1 | defined   | defined      | 
 public | stts3 | a, b FROM t1 | defined   | defined      | defined
 public | stts4 | b, c FROM t2 | defined   | defined      | defined
(4 rows)
```

Le retrait des patchs n'est pas supporté par `pgenv` mais l'opération reste
triviale avec la commande `patch` et son option `--reverse`. Cela nous permet
de conserver les sources sans devoir les télécharger à nouveau !

```bash
$ cd $PGENV_ROOT/src/postgresql-13.1
$ index=$PGENV_ROOT/patch/index/patch.13
$ for f in $(cat $index); do patch --reverse -p1 < $f; done

patching file doc/src/sgml/ref/psql-ref.sgml
Hunk #1 succeeded at 1903 (offset -15 lines).
patching file src/bin/psql/command.c
Hunk #1 succeeded at 929 (offset 1 line).
patching file src/bin/psql/describe.c
Hunk #1 succeeded at 4377 (offset -24 lines).
patching file src/bin/psql/describe.h
patching file src/bin/psql/help.c
patching file src/bin/psql/tab-complete.c
Hunk #1 succeeded at 1479 (offset -21 lines).
Hunk #2 succeeded at 3771 (offset -127 lines).
```

---

## Conclusion

Pour tout vous dire, je ne sais plus me séparer de `pgenv` sauf en de rares
exceptions où mes tests nécessitent une distribution GNU/Linux spécifique, comme
CentOS ou Debian. Une machine virtuelle fournie par [Vagrant][7] est tout aussi
fiable, notamment lorsqu'il s'agit de déboguer un paquet d'installation ou
une dépendance particulière.

[7]: https://www.vagrantup.com/docs/boxes

```text
$ sudo vagrant box list
centos/7         (libvirt, 2004.01)
debian/buster64  (libvirt, 10.4.0)
debian/stretch64 (libvirt, 9.12.0)
```
