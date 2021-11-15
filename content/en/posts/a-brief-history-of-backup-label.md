---
title: "A brief history of backup label"
date: 2021-04-02
draft: true
categories: [postgresql]
tags: [backup]
translationKey: "la-breve-histoire-du-fichier-backup_label"
trad: https://pad.education/p/a-brief-history-of-backup-label
---

For a long time, I remained ignorant about [transaction logging mechanisms][1] 
and PITR in PostgreSQL, although they were crucial in data durability. A better
understanding of these concepts would have helped me in a previous life, to be
more confident during a backup configuration and, well, during after-crash
intervention!

[1]: http://www.interdb.jp/pg/pgsql09.html

By reading this post, I will come back to an amusing file that used to be a
topic of discussion over the past decade: the backup label file. What is it and
what is it used for? How has it be enhanced from its origin with PostgreSQL 8.0
and what could be expected from him over the next years?

<!--more-->

---

## Once upon a time there was transaction logging

As an introduction and to better understand this post, it seems good to me to 
explain that each changing operation in PostgreSQL, like an `UPDATE` or an `INSERT`, 
is written a first time on `COMMIT` in a group of files, which is called _WAL_ 
or **transaction logs**. Taken together, these changes represent a low cost to 
disk activity compared to random writings of others processes at work in PostgreSQL.

Among them, the `checkpointer` process ensures that new data in memory is permanently 
synchronized in the data files and that at regular times called `CHECKPOINT`. This 
on-disk two-step writing provides excellent performance and ensures that modified 
blocks are not lost when a transaction ends successfully.

![Asynchroneous writes on disks](/img/en/2021-04-asynchronous-writes.png)

<!-- https://mermaid-js.github.io/mermaid-live-editor
sequenceDiagram
    participant b as Backend
    participant w as WAL Buffer
    participant s as Shared Buffer
    participant d as Disks

    rect rgb(236,236,255)
        note right of b: INSERT
        d->>s: load table
        b->>w: wal record
        activate b
        b->>s: dirty page
        deactivate b
    end

    rect rgb(236,236,255)
        note right of b: COMMIT
        w->>d: sync to wal files
        activate b
        d--\>>b: ack
        deactivate b
    end

    rect rgb(236,236,255)
        note right of s: CHECKPOINT
        s->>d: sync to data files
    end
-->

Because of transaction logging, all data files of our cluster are late on real
transactional workload, until the next `CHECKPOINT` moment. In case of an unexpected
interruption (like a memory crash), dirty pages will be lost and data files are
called **inconsistents**, as they contain data that can be too old or uncommitted.

In such situations, cluster service will be able to restart by applying losted
changes thanks to transaction logs written in WAL files. This rebuilding process
of data files to their consistent state is simply called **crash recovery**.

{{< message >}}
In PostgreSQL 8.0 and above, this mecanism laid the foundation for priceless
functionalities, like Point In Time Recovery or standby replication with Log
Shipping to a secondary cluster.
{{< /message >}}

Whether after a crash or data restoration, data files must be consistent during
the startup stage in order to accept write access to data again. What a terrible
surprise when the startup fails with the following error:

```PANIC: could not locate a valid checkpoint record```

At this moment of startup stage, the cluster does not find any consistent point 
between data files and fails to look after the nearest checkpoint record. Without
transactions logs, crash recovery fails and stops. At this point, your nerves and 
your backup policy are put to the test.

To put it another way: in lacks of WAL or theirs archives, {{< u >}}your most 
recent data are losts{{< /u >}}.

… And [pg_resetwal][2] will not bring them back to you.

[2]: https://pgpedia.info/p/pg_resetwal.html

---

## And comes backup label

After this lovely warning, we will consider that the archiving of transaction logs
is no longer an option when you are making backups. Make sure that these archives 
are stored in a secure place, or even a decentralized area so that they are 
accessible by all standby clusters when you need to trigger your failover plan.

For those who have reached this part of the post, you should not be too lost if 
I tell you that the _backup label_ file is a component of a larger concept called:
backup.

> The backup history file is just a small text file. It contains the label string
> you gave to `pg_basebackup`, as well as the starting and ending times and WAL 
> segments of the backup. If you used the label to identify the associated dump 
> file, then the archived history file is enough to tell you which dump file to 
> restore.
> 
> Source: [Making a Base Backup][4]

[4]: https://www.postgresql.org/docs/13/continuous-archiving.html#BACKUP-BASE-BACKUP

Let’s see the simplest behavior of this documentation-praised tool [pg_basebackup][5]
by creating a `tar` archive of my running cluster.

[5]: https://www.postgresql.org/docs/13/app-pgbasebackup.html

```text
$ pg_basebackup --label=demo --pgdata=backups --format=tar \
    --checkpoint=fast --verbose
pg_basebackup: initiating base backup, waiting for checkpoint to complete
pg_basebackup: checkpoint completed
pg_basebackup: write-ahead log start point: 0/16000028 on timeline 1
pg_basebackup: starting background WAL receiver
pg_basebackup: created temporary replication slot "pg_basebackup_15594"
pg_basebackup: write-ahead log end point: 0/16000100
pg_basebackup: waiting for background process to finish streaming ...
pg_basebackup: syncing data to disk ...
pg_basebackup: renaming backup_manifest.tmp to backup_manifest
pg_basebackup: base backup completed
```

Since version 10, option `--wal-method` is setted on `stream` by default, which
means that all present and future WAL segments in subdirectory `pg_wal` will be
written in a dedicated archive next to the backup, thanks to a temporary
replication slot.

Since version 13, this tool creates a new manifest backup file in order to verify 
the integrity of our backup with [pg_verifybackup][6]. Let's explore our working
directory to find our long awaited backup label.

[6]: https://pgpedia.info/p/pg_verifybackup.html

```text
$ tree backups/
backups/
├── backup_manifest
├── base.tar
└── pg_wal.tar
```

```text
$ tar -xf backups/base.tar --to-stdout backup_label
START WAL LOCATION: 0/16000028 (file 000000010000000000000016)
CHECKPOINT LOCATION: 0/16000060
BACKUP METHOD: streamed
BACKUP FROM: master
START TIME: 2021-01-18 15:22:52 CET
LABEL: demo
START TIMELINE: 1
```

This file is located in root's archive and will be usefull in startup process of
our cluster, since it contains the checkpoint information needed on a recovery
situation. In above example, the sequence number (LSN) is `0/16000060` and will
be found in WAL `000000010000000000000016`. In a lack of a backup label file,
startup process will only have the [control file][7] to obtain the most recent
checkpoint, with no guarantee that it is the right one.

[7]: https://pgpedia.info/p/pg_control.html

---

## The glory age

You will agree with me that content and interest of the backup label file are
anecdotal (though essential) in backup architecture with PostgreSQL. It is (just)
a few-lines text file, only needed in some recovery processes.

And yet, this small revolution caused by version 8.0 in January 2005 with its 
new functionnality, continuous archiving and PITR mecanism, aroused the
creativity of development team in the years that followed. The backup label
evolved to gain modularity and stability.

At this time, `pg_backbackup` was not yet available, and only an explicit call
to the function [pg_start_backup()][9] allowed you to generate the `backup_label` 
file in which were the [following][8] four entries to support hot backup:

[8]: https://github.com/postgres/postgres/blob/REL8_0_STABLE/src/backend/access/transam/xlog.c#L5411
[9]: https://pgpedia.info/p/pg_start_backup.html

```c
# backend/access/transam/xlog.c
fprintf(fp, "START WAL LOCATION: %X/%X (file %s)\n",
        startpoint.xlogid, startpoint.xrecoff, xlogfilename);
fprintf(fp, "CHECKPOINT LOCATION: %X/%X\n",
        checkpointloc.xlogid, checkpointloc.xrecoff);
fprintf(fp, "START TIME: %s\n", strfbuf);
fprintf(fp, "LABEL: %s\n", backupidstr);
```

All next versions brought various fixes or enhancements. Among the notable
contributions, I selected for you:

- [Contribution][10] from Laurenz Albe (commit [c979a1fe])

  [10]: https://www.postgresql.org/message-id/flat/D960CB61B694CF459DCFB4B0128514C201ED284B%40exadv11.host.magwien.gv.at
  [c979a1fe]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=c979a1fefafcc83553bf218c7f2270cad77ea31d

  Published with 8.4 version, `xlog.c` codefile is extended with an internal
  method to cancel a running backup. Calling the `pg_ctl stop` command in _fast_
  mode renames the file to `backup_label.old`;

- [Contribution][11] from Dave Kerr (commit [0f04fc67])

  [11]: https://www.postgresql.org/message-id/flat/20120624213341.GA90986%40mr-paradox.net
  [0f04fc67]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=0f04fc67f71f7cb29ccedb2e7ddf443b9e52b958
  
  Appeared with 9.0.9 minor version, the `pg_start_backup()` method includes a
  `fsync()` call ensures the backup label to be written to disk. This commit 
  guarantees the consistency of the backup during an external snapshot;

- [Contribution][12] from Heikki Linnakangas (commit [41f9ffd9])

  Proposed in 9.2, this patch fix abnormal behaviors on restauration from
  the streaming backup functionnality. Backup label contains a new line that
  specify the method used between `pg_start_backup` or `streamed`;

  [12]: https://www.postgresql.org/message-id/flat/4E40F710.6000404%40enterprisedb.com
  [41f9ffd9]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=41f9ffd928b6fdcedd685483e777b0fa71ece47c

- [Contribution][13] from Jun Ishizuka and Fujii Masao (commit [8366c780])

  [13]: https://www.postgresql.org/message-id/flat/201108050646.p756kHC5023570%40ccmds32.silk.ntts.co.jp
  [8366c780]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=8366c7803ec3d0591cf2d1226fea1fee947d56c3

  With 9.2 and above, `pg_start_backup()` can be executed on a secondary
  cluster. The role (`standby` or `master`) of the instance from which the backup
  comes is retained in the backup label; 

- [Contribution][14] from Michael Paquier (commit [6271fceb])

  [14]: https://www.postgresql.org/message-id/flat/CAB7nPqRosJNapKVW2QPwkN9%2BypfL4yiR4mcNFZcjxS2c8m%2BVkw%40mail.gmail.com
  [6271fceb]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=6271fceb8a4f07dafe9d67dcf7e849b319bb2647

  Added in 11, a new _timeline_ entry in backup label file joined the
  previous information to compare its value with thoses contained in WAL needed
  by a data recovery;

As you may understand, during an amount of years, the ability to take a consistent
backup leaded on two distinct ways: `pg_start_backup()` and `pg_basebackup`. The
first and historical one was deeply impacted by regular commentaries about an
unwanted behavior with it "exclusive" mode.

Let us look at an example with PostgreSQL 13:

```sql
SELECT pg_start_backup('demo');
--  pg_start_backup 
-- -----------------
--  0/1D000028
```
```text
$ kill -ABRT $(head -1 data/postmaster.pid)
$ cat data/backup_label
START WAL LOCATION: 0/1D000028 (file 00000001000000000000001D)
CHECKPOINT LOCATION: 0/1D000060
BACKUP METHOD: pg_start_backup
BACKUP FROM: master
START TIME: 2021-01-18 16:49:57 CET
LABEL: demo
START TIMELINE: 1
```

The `ABRT` signal interrupts the `postmaster` process of the cluster in the
violent way and an internal routine, called `CancelBackup`, won't be triggered
correctly in order to rename our backup label to `backup_label.old`. On a normal
production workload, all transactions logs are recycled or even archived as
activity involves more new transactions. On restart of our interrupted instance,
the backup label inside data directory will be read by mistake with an errouneous
checkpoint record requested by the recovery process.

```text
LOG:  database system was shut down at 2021-01-18 17:08:43 CET
LOG:  invalid checkpoint record
FATAL:  could not locate required checkpoint record
HINT:  If you are restoring from a backup, touch "data/recovery.signal" 
		and add required recovery options.
	If you are not restoring from a backup, try removing the file
		"data/backup_label".
	Be careful: removing "data/backup_label" will result in a corrupt
		cluster if restoring from a backup.
LOG:  startup process (PID 19320) exited with exit code 1
LOG:  aborting startup due to startup process failure
LOG:  database system is shut down
```

The complete message only appeared with PostgreSQL 12 as an [explicite warning][15]
in documentation of the backup label, following long discussions on throwing away
this particular mode or not. In one of theses threads, we can read a remarquable
[advocacy][16] written by Robert Haas who looks back on the success of this
feature since its creation and points out the frequent confusion encountered by
users who do not understand either complexity or clear instructions from the
documentation.

[15]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=c900c15269f0f900d666bd1b0c6df3eff5098678
[16]: https://www.postgresql.org/message-id/CA+TgmoaGvpybE=xvJeg9Jc92c-9ikeVz3k-_Hg9=mdG05u=e=g@mail.gmail.com

From these days of darkness, a dedicated note has been added.

> This type of backup can only be taken on a primary and does not allow concurrent
> backups. Moreover, because it creates a backup label file, as described below,
> it can block automatic restart of the master server after a crash. On the other
> hand, the erroneous removal of this file from a backup or standby is a common
> mistake, which can result in serious data corruption.
>
> Source: [Making an Exclusive Low-Level Backup][17]

[17]: https://www.postgresql.org/docs/12/continuous-archiving.html#BACKUP-LOWLEVEL-BASE-BACKUP-EXCLUSIVE

---

## Place à la relève

Cette limitation était connue de longue date et l'équipe de développement
proposa une [alternative][18] en septembre 2016 avec la sortie de la version 9.6 
et l'introduction de la sauvegarde dite « concurrente ». Depuis ce jour, la 
sauvegarde exclusive est annoncée obsolète par les développeurs et pourrait être
supprimée dans les versions à venir.

[18]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=7117685461af50f50c03f43e6a622284c8d54694

Le fichier `backup_label` ne disparaît pas en soi. Ses informations sont toujours
requises pour la restauration PITR mais le fichier n'a plus d'état transitoire sur
le disque et n'est plus écrit dans le répertoire de l'instance par la méthode
`pg_start_backup()`. En remplacement, l'administrateur ou le script de sauvegarde
doit être en capacité d'exécuter la commande `pg_stop_backup()` dans la même
connexion à l'instance pour y récupérer les éléments et reconstruire le fichier
au moment de la restauration.

```sql
SELECT pg_start_backup(label => 'demo', exclusive => false, fast => true);
--  pg_start_backup 
-- -----------------
--  0/42000028

SELECT labelfile FROM pg_stop_backup(exclusive => false);
--                            labelfile                            
-- ----------------------------------------------------------------
-- START WAL LOCATION: 0/42000028 (file 000000010000000000000042)+
-- CHECKPOINT LOCATION: 0/42000060                               +
-- BACKUP METHOD: streamed                                       +
-- BACKUP FROM: master                                           +
-- START TIME: 2021-01-18 18:17:16 CET                           +
-- LABEL: demo                                                   +
-- START TIMELINE: 1                                             +
```

Une autre méthode nous permet de retrouver facilement le contenu du fichier, 
d'autant plus si l'archivage est en place sur l'instance. En effet, à l'annonce
de la fin d'une sauvegarde, les éléments précédents sont écrits dans un fichier
d'historique `.backup` au sein des journaux de transactions et un fichier `.ready`
est ajouté dans le répertoire `archive_status` à destination du processus 
d'archivage. Une recherche rapide sur le dépôt des archives plus tard, et nous 
sommes en possession du fichier prêt à l'emploi pour une restauration.

```text
$ find archives -type f -not -size 16M
archives/000000010000000000000016.00000028.backup

$ grep -iv ^stop archives/000000010000000000000016.00000028.backup 
START WAL LOCATION: 0/42000028 (file 000000010000000000000042)
CHECKPOINT LOCATION: 0/42000060
BACKUP METHOD: streamed
BACKUP FROM: master
START TIME: 2021-01-18 18:17:16 CET
LABEL: demo
START TIMELINE: 1
```

La venue d'une brique complète pour la sauvegarde concurrente a permis l'émergence
de nouvelles solutions de sauvegardes, plus performantes et plus modulaires que
`pg_basebackup`. Dans le paysage des outils tiers, vous entendriez peut-être parler
de [pgBackRest] écrit en C, [Barman] écrit en Python ou [pitrery] écrit en Bash.
En outre, ces outils soulagent l'administrateur de la rédaction de scripts devenus 
trop complexes et loin d'être immuable dans les années à venir.

[pgBackrest]: https://pgbackrest.org/
[Barman]: https://www.pgbarman.org/
[pitrery]: https://dalibo.github.io/pitrery/

---

##  Morale de l'histoire

Au fil des versions, le fichier `backup_label` a enduré de nombreuses tempêtes
et rebondissements pour aboutir à une forme plus aboutie de la sauvegarde et de
la restauration physique dans PostgreSQL.

Si vous êtes responsable de la maintenance d'instances, particulièrement dans
un environnement virtualisé, je ne peux que vous recommander de contrôler vos 
politiques de sauvegarde et l'outillage associé. Il n'est pas rare de voir des 
hyperviseurs réaliser des instantanées des machines virtuelles avec des appels de 
la méthode `pg_start_backup()` en mode exclusif.

Les outils spécialisés cités plus haut peuvent/doivent être étudiés. S'ils ne
correspondent pas très bien à vos besoins, il est toujours possible de
bénéficier des mécanismes de la sauvegarde concurrente à l'aide d'un [fichier 
temporaire][19] sous Linux et sa commande `mkfifo`. 

[19]: https://www.commandprompt.com/blog/postgresql-non-exclusive-base-Backup-bash/

La décision de supprimer définitivement la sauvegarde exclusive n'est actuellement
plus débattue et a été retirée du _backlog_ de développement lors du Commitfest
de [juillet 2020][20]. Lors des derniers échanges, le contributeur David Steele
(auteur de pgBackRest notamment) [annonçait][21] qu'une sauvegarde exclusive pourrait
stocker son fichier `backup_label` directement en mémoire partagée plutôt que sur 
le disque et ainsi corriger sa principale faiblesse :

[20]: https://commitfest.postgresql.org/28/1913/
[21]: https://www.postgresql.org/message-id/d4da3456-06a0-b790-fb07-036d0bd4bf0d%40pgmasters.net

> It might be easier/better to just keep the one exclusive slot in shared 
> memory and store the backup label in it. We only allow one exclusive 
> backup now so it wouldn't be a loss in functionality.

La suite au prochain épisode !