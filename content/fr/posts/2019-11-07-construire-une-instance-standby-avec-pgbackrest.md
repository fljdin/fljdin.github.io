---
title: "Construire une instance standby avec pgBackRest"
date: 2019-11-07 16:00:00 +0200
categories: [postgresql]
tags: [sauvegarde,replication]
---

Pour cette démonstration, j'utilise le système Debian et dispose de deux instances 
en version 12, d'un serveur de sauvegarde et du paquet `pgbackrest` pour mettre
en place une réplication et observer les nouveautés concernant la [disparition][1]
du fichier `recovery.conf`.

[1]: https://paquier.xyz/postgresql-2/postgres-12-recovery-change/

<!--more-->

Pour faciliter le transfert des WAL et des sauvegardes PITR, j'ajoute un compte 
utilisateur `pgbr` sur le serveur de sauvegarde, accessible à partir des deux 
instances avec un partage de clé SSH. _(Conseil : toujours externaliser les 
sauvegardes de bases de données sur un système et un stockage indépendant de 
l'infrastructure de production PostgreSQL…)_

```sh
sudo useradd -s /bin/bash -md /etc/pgbackrest pgbr
sudo mv /etc/pgbackrest.conf /etc/pgbackrest/
sudo chown pgbr: /etc/pgbackrest/pgbackrest.conf \
  /var/log/pgbackrest /var/lib/pgbackrest
```

La réplication par flux (_streaming_) est assurée par un compte dédié nommé 
`streamer`, autorisé à se connecter sur les instances PostgreSQL du sous-réseau 
grâce à l'ajout d'une entrée dans le fichier `pg_hba.conf`.

```sh
sudo -u postgres createuser --replication --pwprompt streamer
```

```ini
# pg_hba.conf
# Allow replication connections from trusted subnet, by a user with the
# replication privilege.
host    replication     streamer        10.1.0.0/28             md5
```

_Le fichier `.pgpass` est déposé sur chaque serveur pour le compte `postgres`, 
afin d'assurer la connexion du compte `streamer` sans saisie de mot de passe._


---

Dans ce scénario, les archives générées par l'instance primaire seront déplacées 
sur le serveur de sauvegarde et l'instance standby les consultera au besoin. La 
planification des sauvegardes sera sous la responsabilité de l'utilisateur `pgbr` 
avec une administration distante. La configuration fine se découpe dans les 
fichiers suivants.

```ini
# /etc/pgbackrest/bkp1.conf
[lab]
pg1-host=lab1
pg2-host=lab2
pg1-host-user=postgres
pg2-host-user=postgres
pg1-path=/var/lib/postgresql/12/lab1
pg2-path=/var/lib/postgresql/12/lab2
pg1-host-config=/etc/pgbackrest/lab1.conf
pg2-host-config=/etc/pgbackrest/lab2.conf

[global]
start-fast=y
log-level-console=info
repo1-retention-full=2
repo1-path=/var/lib/pgbackrest

# /etc/pgbackrest/lab1.conf
[lab]
pg1-path=/var/lib/postgresql/12/lab1

[global]
repo1-host=bkp1
repo1-host-user=pgbr

# /etc/pgbackrest/lab2.conf
[lab]
pg1-path=/var/lib/postgresql/12/lab2
recovery-option=recovery_target_timeline=latest
recovery-option=primary_conninfo=host=lab1 port=5432 user=streamer

[global]
repo1-host=bkp1
repo1-host-user=pgbr
```

Avant de pouvoir créer la stanza, il est nécessaire de démarrer l'instance standby 
en mode `recovery` ; il suffit de positionner un fichier `standby.signal` dans 
le répertoire de données et de redémarrer l'instance :

```sh
sudo pg_ctlcluster stop 12 lab2
sudo -u postgres touch /var/lib/postgresql/12/lab1/standby.signal
sudo pg_ctlcluster start 12 lab2
```

À partir de ce moment, et même si les deux instances ne partagent pas les mêmes 
données, je peux créer la stanza avec l'outil `pgbackrest` sur mon serveur de 
sauvegarde avec l'utilisateur dédié.

```sh
sudo -u pgbr pgbackrest stanza-create \
  --stanza=lab --config=/etc/pgbackrest/bkp1.conf
```

Dès ce moment, mon instance, consciente de l'espace de stockage distant, peut 
envoyer ses archives de WAL _via_ la commande `archive-push` de `pgbackrest`. 
Un redémarrage est requis pour activer le mode archive.

```sql
ALTER SYSTEM SET archive_mode = on;
ALTER SYSTEM SET archive_command = 
  'pgbackrest archive-push %p --stanza=lab --config=/etc/pgbackrest/lab1.conf';
```

Et pour finir, une première sauvegarde complète peut être lancée sur le serveur 
de sauvegarde pour assurer la construction de l'instance standby.

```sh
sudo -u pgbr pgbackrest backup --stanza=lab --config=/etc/pgbackrest/bkp1.conf
sudo -u pgbr pgbackrest info

# stanza: lab
#  status: ok
#  cipher: none
#
#  db (current)
#   wal archive min/max (12-1): 000000010000000000000008/000000010000000000000008
#
#   full backup: 20191107-103443F
#    timestamp start/stop: 2019-11-07 10:34:43 / 2019-11-07 10:35:09
#    wal start/stop: 000000010000000000000008 / 000000010000000000000008
#    database size: 23.5MB, backup size: 23.5MB
#    repository size: 2.8MB, repository backup size: 2.8MB
```

La sauvegarde de l'instance primaire peut être restaurée sur la seconde instance 
avec les options `--delta` et `--type=standby` pour écraser les fichiers erronés 
et ajouter le descripteur `standby.signal` dans le répertoire de données. pgBackRest 
se charge de configurer les options de réplication dans le fichier
`postgresql.auto.conf`

```sh
sudo pg_ctlcluster stop 12 lab2
sudo -u postgres pgbackrest restore --stanza=lab \
  --delta --type=standby --config=/etc/pgbackrest/lab2.conf 
sudo pg_ctlcluster start 12 lab2
```

Tadaa ! Une connexion est alors établie entre les deux nœuds et l'on constate 
que l'utilisateur `streamer` rejoue en asynchrone les transactions de l'instance 
primaire vers l'instance standby.

```sql
select * from pg_stat_replication;

-- -[ RECORD 1 ]----+------------------------------
-- pid              | 8893
-- usesysid         | 16384
-- usename          | streamer
-- application_name | 12/lab2
-- client_addr      | 10.1.0.1
-- client_hostname  | 
-- client_port      | 38820
-- backend_start    | 2019-11-07 10:50:22.424464+00
-- backend_xmin     | 
-- state            | streaming
-- sent_lsn         | 0/A000060
-- write_lsn        | 0/A000060
-- flush_lsn        | 0/A000060
-- replay_lsn       | 0/A000060
-- write_lag        | 00:00:00.001095
-- flush_lag        | 00:00:00.004415
-- replay_lag       | 00:00:00.004696
-- sync_priority    | 0
-- sync_state       | async
-- reply_time       | 2019-11-07 12:39:59.595595+00
```

{{< message >}}
Pour la rédaction de cet article, je n'ai pas véritablement utilisé trois serveurs, 
mais bien un seul en réalité. L'astuce pour faire tourner deux instances sur le 
même port 5432 consiste à ajouter des IP virtuelles sur l'interface du serveur 
et de faire résoudre les noms de machines par le fichier `/etc/hosts` local.

```text
sudo ip add add 10.1.0.1/28 dev ens6
sudo ip add add 10.1.0.2/28 dev ens6
sudo ip add add 10.1.0.3/28 dev ens6
```

Les instances doivent ensuite être installées/configurées avec les bons paramètres 
`listen_addresses` et `unix_socket_directories` comme suivent :

```text
sudo apt-get install -y postgresql-common
sudo vim /etc/postgresql-common/createcluster.conf
sudo apt-get install -y postgresql-12

sudo -u postgres mkdir -p /var/run/postgresql/lab{1,2}
sudo pg_createcluster 12 lab1 \
  --pgoption listen_addresses=10.1.0.1 --pgoption port=5432 \
  --pgoption unix_socket_directories=/var/run/postgresql/lab1
sudo pg_createcluster 12 lab2 \
  --pgoption listen_addresses=10.1.0.2 --pgoption port=5432 \
  --pgoption unix_socket_directories=/var/run/postgresql/lab2

sudo pg_ctlcluster start 12 lab1
sudo pg_ctlcluster start 12 lab2
```

Quelques ajustements de droits sur le répertoire `/tmp/pgbackrest` pour les 
fichiers de verrous (paramètre `--lock-path`) et le tour est joué !
{{< /message >}}