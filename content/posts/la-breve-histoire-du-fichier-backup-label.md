---
title: "La brêve histoire du fichier backup_label"
date: 2099-01-01
categories: [postgresql]
tags: [sauvegarde]
draft: true
---

Je suis resté longtemps ignorant des mécanismes de journalisation et de _PITR_ avec PostgreSQL<sup>[1]</sup> alors même qu'il s'agit de fonctionnements internes critiques pour la durabilité des données d'une instance. Mieux comprendre ces concepts m'aurait permis à une époque, d'être plus serein lors de la mise en place de sauvegardes et surtout au moment de leurs restaurations !

Dans cet article, je vous propose de revenir sur un fichier méconnu et pourtant indispensable lors d'une restauration d'instance : le fichier `backup_label`. Qui est-il et à quoi sert-il ? Comment a-t-il évolué depuis sa création en version 8.0 de PostgreSQL et qu'adviendra-t-il de lui dans les prochaines années ? 

[1]: https://public.dalibo.com/archives/publications/glmf108_postgresql_et_ses_journaux_de_transactions.pdf

<!--more-->

# Utilité du `backup_label`

En guise de rappel sur la journalisation, il est bon d'expliquer que chaque modification d'une relation dans PostgreSQL, est écrite dans un premier groupe de fichiers, appelés _WAL_ ou **journaux de transactions**, avant d'être définitivement synchronisée dans les fichiers de données. Cette écriture différée sur les disques apporte d'excellentes performances sans perdre le moindre bloc modifié pour une transaction valide.

Ainsi en cas d'arrêt brutal de l'instance, il est possible de _rejouer_ les changements dans l'ordre des transactions en copiant les blocs contenus dans les _WAL_ à l'intérieur des fichiers de données. En version 8.0 et supérieures, ce mécanisme a permis l'émergence des solutions de restauration dans le temps  (_Point In Time Recovery_) et de réplication par récupération des journaux (_Log Shipping_) sur une instance secondaire.

La validité d'une sauvegarde ne tient qu'à une seule condition : la cohérence des fichiers qui la composent. Aussi, réaliser un _snapshot_ ou une copie du répertoire des données `PGDATA` ne garantie absolument pas que la sauvegarde soit fiable en l'état. Quelle mauvaise surprise a-t-on lorsque l'instance restaurée ne parvient pas à démarrer avec le message suivant :

```PANIC: could not locate a valid checkpoint record```

Le point de reprise `CHECKPOINT` est essentiel lors d'un redémarrage. Il s'agit d'un état de cohérence où l'ensemble des modifications en mémoire (représentées par les _dirty blocs_) ont été correctement synchronisées sur le disque, dans les fichiers de données de l'instance. Sans ce point de départ, PostgreSQL ne peut pas deviner à partir de quel journal WAL recommencer les transactions en cours, au moment de la sauvegarde.

- présenter le fonctionnement via une démo de la commande pg_start_backup()
https://www.postgresql.org/docs/current/functions-admin.html

- ce que ne fais pas la commande

- démo sans le backup_label à la restauration

lecture de backup_label prioritaire sur le pg_control pour éviter la corruption d'une instance restaurée si un checkpoint a eu lieu entre la copie du premier et du fichier.

# Origine du backup_label

- trouver l'origine et les échanges mails pour cette contribution

https://git.postgresql.org/gitweb/?p=postgresql.git&a=search&h=HEAD&st=commit&s=backup_label

8.0 https://www.postgresql.org/docs/8.0/backup-online.html
janvier 2005 https://www.postgresql.org/docs/8.0/release-8-0.html 
https://pgpedia.info/p/pg_start_backup.html

PITR: In previous releases there was no way to recover from disk drive failure except to restore from a previous backup or use a standby replication server. Point-in-time recovery allows continuous backup of the server. You can recover either to the point of failure or to some transaction in the past.

8.2 "backup online" devient "continuous archiving"

- retrouver dans le code source la méthode de création du fichier label

https://github.com/postgres/postgres/blob/REL8_0_STABLE/src/backend/access/transam/xlog.c#L5326

https://git.postgresql.org/gitweb/?p=postgresql.git;a=blob;f=src/backend/access/transam/xlog.c;hb=refs/heads/REL8_0_STABLE#l5326

/*
 * pg_start_backup: set up for taking an on-line backup dump
 *
 * Essentially what this does is to create a backup label file in $PGDATA,
 * where it will be archived as part of the backup dump.  The label file
 * contains the user-supplied label string (typically this would be used
 * to tell where the backup dump will be stored) and the starting time and
 * starting WAL offset for the dump.

# Evolutions mineure du fichier

- 9.0.9 Ensure the backup_label file is fsync'd after pg_start_backup() (Dave Kerr)
https://www.postgresql.org/message-id/20120813035616.GA20056%40fetter.org
https://www.postgresql.org/docs/9.0/release-9-0-9.html

- option fast
- option exclusive
- 11.0 ajout de la timeline dans le backup_label  https://www.postgresql.org/docs/release/11.0
2018-01-06 https://www.postgresql.org/message-id/E1eXnWw-0000YY-Bi%40gemulon.postgresql.org

# Problèmatiques

- en quoi la sauvegarde exclusive est problèmatique ?

dépôt d'un fichier dans le data_dir et persiste même au dela d'un arrêt innopiné de la sauvegarde
https://www.cybertec-postgresql.com/en/exclusive-backup-deprecated-what-now/

- considéré obsolète (deprecated) depuis la version 9.6 sortie en septembre 2016

https://www.postgresql.org/message-id/CA+TgmoaGvpybE=xvJeg9Jc92c-9ikeVz3k-_Hg9=mdG05u=e=g@mail.gmail.com

# Solution de contournement

- pg_basebackup apparu en 9.1(9.2?) crée le fichier backup_label à l'extérieur du data_dir dans son répertoire de destination, et introduit la notion de sauvegarde concurrentes
- en version 9.6, la méthode pg_start_backup implémente la sauvegarde concurrente mais requiert une connexion continue à l'instance

- annoncer la disparition du fichier au profit d'une table pour les sauvegardes concurrentes
https://www.postgresql.org/message-id/ac7339ca-3718-3c93-929f-99e725d1172c@pgmasters.net

- considéré obsolète (deprecated) depuis la version 9.6 sortie en septembre 2016

# Revue des outils de sauvegarde

- pgbackrest implémente la sauvegarde concurrente
- script ahdoc en bash de cybertec pour maintenir un watcher connecté à une table https://github.com/cybertec-postgresql/safe-backup
- script bash avec mkfifo https://www.commandprompt.com/blog/postgresql-non-exclusive-base-Backup-bash/