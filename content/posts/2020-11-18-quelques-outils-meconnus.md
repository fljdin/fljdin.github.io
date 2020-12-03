---
layout: post
title: "Quelques outils méconnus"
date: 2020-11-18
tags: [postgresql,administration]
---

Cette semaine, passait sur [mon fil d'actualité Twitter](https://twitter.com/CookSoft_TR/status/1328293682731245568/retweets/with_comments) une simple URL pointant sur le site <https://pgpedia.info>. Non loin d'être le seul à l'avoir remarqué, nous en parlions entre collègues pour constater avec surprise que nous ne connaissions pas cette mine d'or d'informations sur PostgreSQL. Après y avoir perdu plusieurs heures, je me suis dit qu'un article sur les quelques utilitaires que j'estime méconnus, pourrait être une bonne conclusion de la semaine.

<!--more-->
---

## pg_controldata

_Source : <https://pgpedia.info/p/pg_controldata.html>_

Ce premier outil est un _must-have_ pour tous les administrateurs de base de données. Il permet de dresser les principales informations de l'instance, qu'elle soit en cours d'exécution ou arrêtée. Ces dernières sont en partie extraites du fichier `pg_control`<sup>[1]</sup> contenu dans le répertoire `PGDATA/global`, dont notamment, les informations sur les toutes dernières actions du processus `checkpointer`. On y retrouve aussi quelques configurations fixes et variables de l'instance.

[1]: https://pgpedia.info/p/pg_control.html

Lorsque j'interviens durant un audit, plusieurs lignes m'interessent pour orienter mes analyses. En voici quelques exemples :

* `Database cluster state` : pour déterminer l'état de l'instance et savoir si j'interviens sur une instance principale ou secondaire. La liste des états est précisée dans le fichier `src/include/catalog/pg_control.h`<sup>[2]</sup>.

```c
 typedef enum DBState
 {
     DB_STARTUP = 0,
     DB_SHUTDOWNED,
     DB_SHUTDOWNED_IN_RECOVERY,
     DB_SHUTDOWNING,
     DB_IN_CRASH_RECOVERY,
     DB_IN_ARCHIVE_RECOVERY,
     DB_IN_PRODUCTION
 } DBState;
```

[2]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=blob;f=src/include/catalog/pg_control.h

* `REDO WAL file` et `REDO location` : pour connaître le fichier WAL le plus proche du dernier _checkpoint_ requis pour la récupération des transactions suite à un _crash_, dans des situations extrêmes où l'archivage n'est pas en place. Dans le cas d'une restauration, ces éléments peuvent me permettre d'identifier le bon fichier `backup_label` à positionner dans le `PGDATA`.

* `Data page checksum version` : parfaitement incontournable, cette valeur m'indique si les sommes de contrôle<sup>[3]</sup> sont actives pour l'instance. Ce mécanisme va permettre de suivre l'évolution des données d'une page en calculant une somme de contrôle (_checksum_) afin de régulièrement s'assurer qu'aucune corruption matérielle n'ait provoqué un changement de cette page. Par défaut, l'outil `initdb` ne l'active pas et c'est bien dommage !

[3]: https://pgpedia.info/d/data-page-checksums.html

## pg_waldump

_Source : <https://pgpedia.info/p/pg_waldump.html>_

Anciennement connu sous le nom de `pg_xlogdump`, avant que n'ait eu lieu la campagne de renommage de `xlog` en `wal` initiée avec PostgreSQL 10, cet utilitaire permet de parcourir le contenu des journaux de transactions. Jusqu'à présent, je ne m'en sers qu'à des fins pédagogiques, bien qu'il puisse s'avérer redoutable dans un cas de débogage de haute voltige.

```sql
BEGIN;
SELECT txid_current();
--  txid_current 
-- --------------
--          1315

CREATE TABLE test(id int);
INSERT INTO test VALUES (1);
COMMIT;
```

Cette simple transaction provoque plusieurs transformations dans les pages de l'instance, notamment dans le catalogue de la base qui reçoit les instructions SQL, que je cache volontairement dans l'exemple suivant :

```text
$ pg_waldump -p data/pg_wal --start=0/52CA530 --xid=1315

rmgr: Storage     desc: CREATE base/16384/24399
rmgr: Standby     desc: LOCK xid 1315 db 16384 rel 24399 
rmgr: Heap        desc: INSERT+INIT off 1 flags 0x00 
  blkref #0: rel 1663/16384/24399 blk 0
rmgr: Transaction desc: COMMIT 2020-11-18 11:48:23.229489 CET
```

L'outil fourni également un vue synthétique avec l'option `--stats` si l'on souhaite connaître la quantité d'opérations (en nombre et taille en octets) à rejouer lors d'une restauration ou d'une initialisation des données dans le cadre d'une réplication logique.

```text
$ pg_waldump -p data/pg_wal --start=0/52CA530 --end=0/52F8EE8 --stats

Type      N    Combined size 
----      -    ------------- 
Total   243           189643 
```

## pg_test_fsync

_Source : <https://pgpedia.info/p/pg_test_fsync.html>_

Alors, celui-là, je ne le connaissais pas avant hier ! Il s'avère être un compagnon appréciable lorsqu'on déploit une instance de production sur un système dont on a peu ou pas connaissance des performances d'écriture. Bien qu'à l'origine, cet outil ait été conçu pour comparer les différentes méthodes de synchronisation sur disques et de correctement positionner le paramètre `wal_sync_method` pour l'instance, il permet de connaître très facilement le débit du disque qui contiendra les journaux de transactions.

```text
$ pg_test_fsync --filename=data/pg_wal/testfile

5 seconds per test
O_DIRECT supported on this platform for open_datasync and open_sync.

Compare file sync methods using one 8kB write:
  open_datasync               1705,357 ops/sec     586 usecs/op
  fdatasync                   1624,232 ops/sec     616 usecs/op
  fsync                       1155,152 ops/sec     866 usecs/op
  fsync_writethrough                       n/a
  open_sync                   1177,778 ops/sec     849 usecs/op

Compare file sync methods using two 8kB writes:
  open_datasync                830,826 ops/sec    1204 usecs/op
  fdatasync                   1631,562 ops/sec     613 usecs/op
  fsync                        367,584 ops/sec    2720 usecs/op
  fsync_writethrough                       n/a
  open_sync                    115,385 ops/sec    8667 usecs/op

Compare open_sync with different write sizes:
   1 * 16kB open_sync write     47,843 ops/sec   20902 usecs/op
   2 *  8kB open_sync writes    20,899 ops/sec   47850 usecs/op
   4 *  4kB open_sync writes   126,572 ops/sec    7901 usecs/op
   8 *  2kB open_sync writes   180,532 ops/sec    5539 usecs/op
  16 *  1kB open_sync writes    96,373 ops/sec   10376 usecs/op

Test if fsync on non-write file descriptor is honored:
  write, fsync, close         1395,592 ops/sec     717 usecs/op
  write, close, fsync         1432,511 ops/sec     698 usecs/op

Non-sync'ed 8kB writes:
  write                     257485,249 ops/sec       4 usecs/op
```

J'ai ainsi appris que les méthodes variaient, selon les implémentations de chaque système<sup>[4]</sup>. Sous Linux, nous aurons par défault la méthode `fdatasync` alors qu'elle sera `open_datasync` sous Windows.

Dans la même veine, il existe un autre outil de _benchmark_ nommé `pg_test_timing`<sup>[5]</sup>, mais cette fois-ci, pour contrôler que l'horloge du système ne dérive pas lors d'une instruction chronométrée telle que la commande `EXPLAIN ANALYZE`.

[4]: https://www.postgresql.org/docs/13/wal-reliability.html
[5]: https://www.postgresql.org/docs/13/pgtesttiming.html

## pg_verifybackup

_Source : <https://pgpedia.info/p/pg_verifybackup.html>_

Ce petit dernier est arrivé en octobre de cette année avec la sortie de PostgreSQL 13. La communauté a mis à disposition un nouveau fichier appelé « manifeste de sauvegarde » (_backup manifest_) qui a pour rôle de lister l'ensemble des fichiers contenu dans une sauvegarde physique, ainsi que leur signature par sommes de contrôle.

À présent, l'outil `pg_basebackup` créé le fichier `backup_manifest` au sein de son archive, dont la représentation est au format JSON. 

```json
{
  "PostgreSQL-Backup-Manifest-Version": 1,
  "Files": [
    {
      "Path": "backup_label",
      "Size": 224,
      "Last-Modified": "2020-11-18 15:25:39 GMT",
      "Checksum-Algorithm": "CRC32C",
      "Checksum": "fc2f12b1"
    },
    ...
    {
      "Path": "postgresql.conf",
      "Size": 27981,
      "Last-Modified": "2020-10-12 10:28:25 GMT",
      "Checksum-Algorithm": "CRC32C",
      "Checksum": "d8ad53d1"
    },
    {
      "Path": "global/pg_control",
      "Size": 8192,
      "Last-Modified": "2020-11-18 15:25:39 GMT",
      "Checksum-Algorithm": "CRC32C",
      "Checksum": "43872087"
    }
  ],
  "WAL-Ranges": [
    {
      "Timeline": 1,
      "Start-LSN": "0/5400028",
      "End-LSN": "0/5400100"
    }
  ],
  "Manifest-Checksum": "f5cf47bdfbfc0641c...5317932c41"
}
```

Alors que l'outil tier `pgbackrest`<sup>[6]</sup> proposait son propre système de contrôle, ce nouveau fichier manifeste pourrait permettre à d'autres solutions de sauvegardes comme `pitrery`<sup>[7]</sup> de bénéficier d'une vérification à moindre coût.

[6]: https://pgbackrest.org/
[7]: https://github.com/dalibo/pitrery/issues/125

En effet, à l'aide de l'outil `pg_verifybackup`, il est possible de s'assurer qu'une sauvegarde physique n'a pas subi de corruption ou de transformation avant de la restaurer.

```text
$ pg_verifybackup basebackup

error: "global/pg_control.moved" is present on disk but not in the manifest
error: "global/pg_control" is present in the manifest but not on disk

$ mv basebackup/global/pg_control.moved basebackup/global/pg_control
$ pg_verifybackup basebackup
backup successfully verified
```

## Conclusion

La page de documentation « _PostgreSQL Server Applications_ »<sup>[8]</sup> recense les utilitaires maintenus par la communauté. L'histoire du projet a montré que nombre d'entre eux étaient issus d'une contribution avant d'y être intégrés et démocratisés.

Le site <https://pgpedia.info> est un excellent complément à la documentation car il retrace avec fidélité les changements survenus pour chaque aspect, méthode, outil présent dans le projet PostgreSQL. Ajoutez-le à vos favoris !

[8]: https://www.postgresql.org/docs/13/reference-server.html