---
title: "A brief history of backup label"
date: 2021-04-02
draft: true
categories: [postgresql]
tags: [backup]
translationKey: "la-breve-histoire-du-fichier-backup_label"
trad: https://pad.education/p/a-brief-history-of-backup-label
---

Je suis resté longtemps ignorant des mécanismes de [journalisation][1] et de _PITR_ 
avec PostgreSQL alors même qu'il s'agit d'un des fonctionnements critiques pour
la durabilité des données d'une instance. Mieux comprendre ces concepts m'aurait
permis à une époque, d'être plus serein lors de la mise en place de sauvegardes
et surtout au moment de leur restauration !

[1]: https://public.dalibo.com/archives/publications/glmf108_postgresql_et_ses_journaux_de_transactions.pdf

Dans cet article, je vous propose de revenir sur un fichier anecdotique qui a
fait parlé de lui pendant plusieurs années : le fichier `backup_label`. 
Qui est-il et à quoi sert-il ? Comment a-t-il évolué depuis sa création en 
version 8.0 de PostgreSQL et qu'adviendra-t-il de lui dans les prochaines années ?

<!--more-->

---

## Il était une fois la journalisation

En guise d'introduction pour mieux comprendre cet article, il est bon d'expliquer 
que chaque opération d'écriture dans PostgreSQL comme un `UPDATE` ou un `INSERT`,
est écrite une première fois au moment du `COMMIT` de la transaction dans un groupe 
de fichiers, que l'on appelle _WAL_ ou **journaux de transactions**. Ajoutées les
unes à la suite des autres, ces modifications représentent un faible coût pour
l'activité des disques par rapport aux écritures aléatoires d'autres processus
de synchronisation à l'œuvre dans PostgreSQL.

Parmi l'un d'eux, le processus `checkpointer` s'assure que les nouvelles données
en mémoire soient définitivement synchronisées dans les fichiers de données à des
moments réguliers que l'on appelle `CHECKPOINT`. Cette écriture en deux temps sur 
les disques apporte d'excellentes performances et garantit qu'aucun bloc modifié 
ne soit perdu lorsqu'une transaction se termine correctement.

![Écriture différée sur les disques](/img/fr/2021-01-19-ecriture-differee-sur-disque.png)

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

Par ce mécanisme de journalisation, les fichiers de données de notre instance
sont constamment en retard sur la véritable activité transactionnelle, et ce, 
jusqu'au prochain `CHECKPOINT`. En cas d'arrêt brutal du système, les blocs en 
attente de synchronisation (_dirty pages_) présents dans la mémoire _Shared Buffer_
sont perdus et les fichiers de données sont dit **incohérents** car ils mixent 
des données de transactions anciennes, nouvelles, valides ou invalides.

In such situations, cluster service will be able to restart by applying losted
changes thanks to transaction logs written in WAL files. This rebuilding process
of data files to their consistent state is simply called **crash recovery**.

{{< message >}}
In PostgreSQL 8.0 and above, this mecanism laid the foundation for priceless
functionalities, like Point In Time Recovery or standby replication with Log
Shipping to a secondary cluster.
{{< /message >}}

Que ce soit à la suite d'un crash ou dans le cadre d'une restauration de 
sauvegarde, les fichiers de données doivent être cohérents pour assurer le retour
du service et l'accès en écriture aux données. Quelle mauvaise surprise n'a-t-on 
pas lorsqu'une instance PostgreSQL interrompt son démarrage avec le message
suivant :

```PANIC: could not locate a valid checkpoint record```

At this moment of startup stage, the cluster does not find any consistent point 
between data files and fails to look after the nearest checkpoint record. Without
transactions logs, crash recovery fails and stops. At this point, your nerves and 
your backup policy are put to the test.

Pour le dire encore autrement : en l'absence des journaux de transactions ou de 
leurs archives, {{< u >}}vos plus récentes données sont perdues{{< /u >}}.

… Et l'outil [pg_resetwal][2] ne les récuperera pas pour vous.

[2]: https://pgpedia.info/p/pg_resetwal.html

---

## And comes backup label

After this lovely warning, we will consider that the archiving of transaction logs
is no longer an option when you are making backups. Make sure that these archives 
are stored in a secure place, or even a decentralized area so that they are 
accessible by all standby clusters when you need to trigger your failover plan.

[3]: /2019/12/19/le-jour-ou-tout-bascule

Pour ceux ayant atteint cette partie de l'article, vous ne devriez pas être
trop perdus si je vous annonce que le fichier `backup_label` est un composant
d'un plus large concept, à savoir : la sauvegarde.

> Le fichier historique de sauvegarde est un simple fichier texte. Il contient 
> le label que vous avez attribué à l'opération `pg_basebackup`, ainsi que les
> dates de début, de fin et la liste des segments WAL de la sauvegarde. Si vous
> avez utilisé le label pour identifier le fichier de sauvegarde associé, alors
> le fichier historique vous permet de savoir quel fichier de sauvegarde vous
> devez utiliser pour la restauration.
> 
> Source : [Réaliser une sauvegarde de base][4]

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

Depuis la version 10, l'option `--wal-method` est définie 
sur `stream` par défaut, ce qui indique que tous les journaux de transactions 
présents et à venir dans le sous-répertoire `pg_wal` de l'instance seront 
également sauvegardés dans une archive dédiée, notamment grâce à la création
d'un slot de réplication temporaire.

Since version 10, option `--wal-method` is setted on `stream` by default, which
means that all present and future WAL segments in subdirectory `pg_wal` will be
written in a dedicated archive next to the backup, thanks to a temporary
replication slot.

Depuis la version 13, l'outil embarque le fichier manifeste dans la sauvegarde
afin de pouvoir contrôler l'intégrité de la copie par la commande
[pg_verifybackup][6]. Contrôlons le contenu du répertoire de sauvegarde et
recherchons le tant attendu `backup_label`.

[6]: /2020/11/18/quelques-outils-meconnus/#pg_verifybackup

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

Ce dernier se trouve à la racine de notre archive et joue un rôle très
particulier dans le processus de démarrage `startup` puisqu'il renseigne le point
de reprise à partir duquel rejouer les journaux. Dans notre exemple, il s'agit
de la position `0/16000060` présente dans le journal `000000010000000000000016`.
En cas d'absence du `backup_label`, le processus de démarrage consultera à la 
place le [fichier de contrôle][7] afin de déterminer le plus récent point de
reprise sans garantie qu'il soit le bon.

[7]: https://pgpedia.info/p/pg_control.html

---

## L'heure de gloire

Vous conviendrez que la forme et l'intérêt du fichier `backup_label` sont
anecdotiques (bien qu'essentiels) dans l'architecture de sauvegarde avec PostgreSQL.
Il ne s'agit que d'un fichier texte de quelques lignes, requis exclusivement pour
assurer certains contrôles lors d'une restauration.

Et pourtant, la petite révolution que provoqua la version 8.0 en janvier 2005
avec l'archivage continu et la restauration PITR suscita naturellement la
créativité de l'équipe de développement au cours des années qui suivirent. Le
fichier `backup_label` évolua pour gagner en modularité et en stabilité.

À l'origine, l'outil `pg_basebackup` n'était pas encore disponible et seul l'appel
à la méthode [pg_start_backup()][9] permettait de générer le fichier dans lequel
se trouvaient les quatres informations [suivantes][8] pour accompagner la
sauvegarde à chaud :

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

Les versions majeures se sont enchaînées avec son lot de corrections ou 
d'améliorations. Parmi les contributions notables, j'ai relevé pour vous :

- [Contribution][10] de Laurenz Albe (commit [c979a1fe])

  [10]: https://www.postgresql.org/message-id/flat/D960CB61B694CF459DCFB4B0128514C201ED284B%40exadv11.host.magwien.gv.at
  [c979a1fe]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=c979a1fefafcc83553bf218c7f2270cad77ea31d

  Publié avec la version 8.4, le code `xlog.c` se voit enrichir d'une méthode 
  interne pour annuler la sauvegarde en cours. L'exécution de la commande 
  `pg_ctl stop` en mode _fast_ renomme le fichier en `backup_label.old` ;

- [Contribution][11] de Dave Kerr (commit [0f04fc67])

  [11]: https://www.postgresql.org/message-id/flat/20120624213341.GA90986%40mr-paradox.net
  [0f04fc67]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=0f04fc67f71f7cb29ccedb2e7ddf443b9e52b958

  Apparue avec la version mineure 9.0.9, la méthode `pg_start_backup()` inclut
  un appel `fsync()` pour forcer l'écriture sur disque du fichier `backup_label`.
  Cette sécurité garantit la consistance d'un instantané matériel ;

- [Contribution][12] de Heikki Linnakangas (commit [41f9ffd9])

  Proposé en version 9.2, ce patch corrige des comportements anormaux de
  restauration à partir de la nouvelle méthode de sauvegarde par flux. Le fichier
  `backup_label` précise la méthode employée entre `pg_start_backup` ou `streamed` ;

  [12]: https://www.postgresql.org/message-id/flat/4E40F710.6000404%40enterprisedb.com
  [41f9ffd9]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=41f9ffd928b6fdcedd685483e777b0fa71ece47c

- [Contribution][13] de Jun Ishizuka et Fujii Masao (commit [8366c780])

  [13]: https://www.postgresql.org/message-id/flat/201108050646.p756kHC5023570%40ccmds32.silk.ntts.co.jp
  [8366c780]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=8366c7803ec3d0591cf2d1226fea1fee947d56c3

  Depuis la version 9.2, la méthode `pg_start_backup()` peut être exécutée sur
  une instance secondaire. Le rôle de l'instance d'où provient la sauvegarde est
  renseignée dans le fichier `backup_label` ;

- [Contribution][14] de Michael Paquier (commit [6271fceb])

  [14]: https://www.postgresql.org/message-id/flat/CAB7nPqRosJNapKVW2QPwkN9%2BypfL4yiR4mcNFZcjxS2c8m%2BVkw%40mail.gmail.com
  [6271fceb]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=6271fceb8a4f07dafe9d67dcf7e849b319bb2647

  Ajoutée en version 11, l'information _timeline_ dans le fichier `backup_label`
  rejoint les précédentes pour comparer sa valeur avec celles des journaux à 
  rejouer lors d'une récupération de données ;

Vous l'aurez compris, pendant de nombreuses années, la capacité de faire une
sauvegarde dite consistante, reposait sur les deux méthodes vues précédemment.
La fonction historique `pg_start_backup()` fut particulièrement touchée
par d'incessantes critiques au sujet d'un comportement non souhaité, notamment
son mode « exclusif ».

Voyons cela ensemble sur une instance récente en version 13 :

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

Le signal `ABRT` interrompt sans préavis le processus `postmaster` de l'instance
et la routine d'arrêt `CancelBackup` n'est pas appelée pour renommer le fichier
en `backup_label.old`. Avec une activité classique de production, les journaux 
sont recyclés et archivés à mesure que les transactions s'enchaînent. Au démarrage
de l'instance, le fichier `backup_label` présent dans le répertoire de données
est lu par erreur et n'indique plus le bon point de reprise pour la récupération 
des données.

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

Ce message complet n'est apparu qu'à partir de la version 12 avec un [avertissement][15]
plus prononcé dans la documentation au sujet du fichier, faisant suite à de longs
échanges sur la possibilité de se séparer ou non de cette méthode. Dans l'un 
d'eux, on peut lire la remarquable [intervention][16] de Robert Haas qui revient
sur le succès de cette fonctionnalité depuis ses débuts et la confusion fréquente 
que rencontrent les utilisateurs qui ne comprennent ni la complexité ni les
instructions claires de la documentation.

[15]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=c900c15269f0f900d666bd1b0c6df3eff5098678
[16]: https://www.postgresql.org/message-id/CA+TgmoaGvpybE=xvJeg9Jc92c-9ikeVz3k-_Hg9=mdG05u=e=g@mail.gmail.com

À présent, une note y clarifie les choses.

> Ce type de sauvegarde peut seulement être réalisé sur un serveur primaire et 
> ne permet pas des sauvegardes concurrentes. De plus, le fichier backup_label 
> créé sur un serveur primaire peut empêcher le redémarrage de celui-ci en cas 
> de crash. D'un autre côté, la suppression à tord de ce fichier d'une sauvegarde 
> ou d'un serveur secondaire est une erreur fréquente qui peut mener à de 
> sérieuses corruptions de données.
>
> Source : [Créer une sauvegarde exclusive de bas niveau][17]

[17]: https://docs.postgresql.fr/12/continuous-archiving.html#BACKUP-LOWLEVEL-BASE-BACKUP-EXCLUSIVE

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