---
title: "Jette ton instance à la poubelle"
date: 2019-06-20 13:00:00 +0100
categories: [postgresql]
tags: [administration]
---

À des fins de qualité ou de formation, il est très souvent nécessaire d'avoir 
une instance PostgreSQL d'une version particulière sur un environnement non 
critique, que l'on peut malmener à souhait et à l'infini. La communauté Debian 
propose l'outil `pg_virtualenv` ([manpage][manpage-pg_virtualenv]) pour démarrer
une instance jettable, tout à fait compatible avec des tests de régression ou
l'exécution de scripts lors d'une démonstration.

[manpage-pg_virtualenv]: https://manpages.debian.org/testing/postgresql-common/pg_virtualenv.1.en.html
<!--more-->

Le package `postgresql-common` est une des dépendances du package postgresql toutes 
versions confondues. Par exemple, sur un Ubuntu 16.04 pour la version 11, on peut 
lister les packages qui seront installés en plus de notre instance :

```text
$ sudo apt-cache depends postgresql-11
  ...
  Depends: postgresql-client-11
    postgresql-client-11:i386
  Depends: postgresql-common
  Depends: ssl-cert
  ...
```

Ce package met donc à disposition une série de scripts – dont le préfixe est
`pg_` – qui s'appuie sur la détection automatique des binaires de la version la 
plus récente installée, en parcourant le répertoire `/usr/lib/postgresql`. On 
retrouve ainsi les script Perl de gestion de clusters propres aux installations
sous Debian/Ubuntu : `pg_lscluster`, `pg_upgradecluster` ou `pg_ctlcluster`.

```text
$ sudo dpkg-query -L postgresql-common
...
/usr/bin/pg_virtualenv
/usr/bin/pg_upgradecluster
/usr/bin/pg_renamecluster
/usr/bin/pg_lsclusters
/usr/bin/pg_dropcluster
/usr/bin/pg_ctlcluster
/usr/bin/pg_createcluster
/usr/bin/pg_conftool
/usr/bin/pg_config
package diverts others to: /usr/bin/pg_config.libpq-dev
...
```

Le script `pg_virtualenv` est la seule exception dans cette série. Il est écrit
en bash et s'appuie sur la commande `mktemp` ([manpage][manpage-mktemp]) pour isoler l'utilisateur afin
qu'il n'interfère avec aucune instance présente sur le serveur. Pour cela, l'outil
surchage plusieurs variables d'environnement (`PG_CLUSTER_CONF_ROOT`, `PGSYSCONFDIR`,
`LOGDIR`, `PWFILE`, `PGUSER`, `PGPASSWORD`) avant d'initialiser une nouvelle
instance via le script `pg_createcluster`.

[manpage-mktemp]: https://manpages.debian.org/testing/coreutils/mktemp.1.en.html

```text
$ bash -x /usr/bin/pg_virtualenv
...
++ mktemp -d -t pg_virtualenv.XXXXXX 
+ WORKDIR=/tmp/pg_virtualenv.XjpJku
+ PG_CLUSTER_CONF_ROOT=/tmp/pg_virtualenv.XjpJku/postgresql
+ PGUSER=fjardin
+ PGSYSCONFDIR=/tmp/pg_virtualenv.XjpJku/postgresql-common
+ mkdir /tmp/pg_virtualenv.XjpJku/postgresql-common /tmp/pg_virtualenv.XjpJku/log
+ PWFILE=/tmp/pg_virtualenv.XjpJku/postgresql-common/pwfile
+ LOGDIR=/tmp/pg_virtualenv.XjpJku/log
++ pwgen 20 1
+ PGPASSWORD=giul8aih3ieviFeef1sh
+ echo giul8aih3ieviFeef1sh
+ pg_createcluster -d /tmp/pg_virtualenv.XjpJku/data/11/regress 
  -l /tmp/pg_virtualenv.XjpJku/log/postgresql-11-regress.log 
  --pgoption fsync=off --start 11 regress -- 
  --username=fjardin --pwfile=/tmp/pg_virtualenv.XjpJku/postgresql-common/pfile 
  --nosync

Creating new PostgreSQL cluster 11/regress ...
/usr/lib/postgresql/11/bin/initdb --data-checksums --encoding=UTF8 
  --username=postgres --pwfile=/var/lib/postgresql/.pwfile
  -D /tmp/pg_virtualenv.XjpJku/data/11/regress --auth-local peer --auth-host md5 
  --username=fjardin --pwfile=/tmp/pg_virtualenv.XjpJku/postgresql-common/pwfile
  --nosync
The files belonging to this database system will be owned by user "fjardin".
This user must also own the server process.

The database cluster will be initialized with locale "en_US.UTF-8".
The default text search configuration will be set to "english".

Data page checksums are enabled.

fixing permissions on existing directory 
  /tmp/pg_virtualenv.XjpJku/data/11/regress ... ok
creating subdirectories ... ok
selecting default max_connections ... 100
selecting default shared_buffers ... 128MB
selecting dynamic shared memory implementation ... posix
creating configuration files ... ok
running bootstrap script ... ok
performing post-bootstrap initialization ... ok

Sync to disk skipped.
The data directory might become corrupt if the operating system crashes.

Success. You can now start the database server using:

    pg_ctlcluster 11 regress start

Ver Cluster Port Status Owner   Data directory
11  regress 5432 online fjardin /tmp/pg_virtualenv.PEkXHz/data/11/regress

Log file
/tmp/pg_virtualenv.PEkXHz/log/postgresql-11-regress.log
```

Et voilà ! Tous les éléments suffisants à l'administration de ce cluster temporaire
`regress` se situent soit dans les variables d'environnement, soit dans le fichier
`pg_service.conf` de l'espace temporaire. Les bases sont donc disponibles par 
l'utilisateur courant jusqu'à ce que ce dernier quitte l'environnement d'exécution
par la commande `exit`.

```text
$ env | grep PG
PGPORT=5432
PGUSER=fjardin
PGPASSWORD=oChuaWa8cho6uK5Goono
PGDATABASE=postgres
PGHOST=localhost
PGSYSCONFDIR=/tmp/pg_virtualenv.PEkXHz/postgresql-common
PG_CLUSTER_CONF_ROOT=/tmp/pg_virtualenv.PEkXHz/postgresql
PG_CONFIG=/usr/lib/postgresql/11/bin/pg_config

$ cat $PGSYSCONFDIR/pg_service.conf
[11]
host=localhost
port=5432
dbname=postgres
user=fjardin
password=oChuaWa8cho6uK5Goono

$ exit
Dropping cluster 11/regress ...
```

N'étant pas (encore) un féru de développement et du [TDD] pour employer l'outil 
dans des tests de régressions, j'utilise la commande sur un poste Debian/Ubuntu 
ou sur Windows WSL de la même famille pour disposer d'une instance prête en
quelques secondes. Pour obtenir un tel résultat, il suffit d'ajouter le bon 
_repository_ officiel et de lancer l'installation dans cet ordre.

```sh
sudo apt-get install -y postgresql-common

sudo mkdir /etc/postgresql-common/createcluster.d
echo create_main_cluster = false | \
 sudo tee /etc/postgresql-common/createcluster.d/ignore_create_cluster.conf

sudo apt-get install -y postgresql-10 postgresql-11
sudo systemctl disable postgresql.service
```

De cette façon, nous disposons rapidement des packages à jour pour les versions 
10 et 11 sur notre distribution. Les possibilités sont donc nombreuses, comme 
illustrer ses propos lors de présentations ou de formations devant un public, 
valider le contenu d'un script SQL livré par son client sur une version spécifique 
ou simplement découvrir les nouvelles fonctionnalités d'une version majeure 
fraîchement compilée ou disponible sur le _repository_ !

[TDD]: https://fr.wikipedia.org/wiki/Test_driven_development