---
title: "Les corruptions silencieuses"
categories: [postgresql]
tags: [administration]
date: 2021-09-28
draft: true
---

Parmi les drames universellement reconnus, les corruptions de données sont des
événements mécaniques ou logiques qui surviennent à des moments imprévisibles.
Tantôt il s'agira de l'âge avancé des secteurs disques, tantôt il s'agira d'une
extinction inopinée d'un composant électrique ou d'une perte de paquet dans les
protocoles de cache.

Bien que peu de personnes peuvent se vanter d'en avoir observé au cours de leur
carrière, les corruptions sont particulièrement dévastatrices lorsqu'elles se
sont propagées sur les supports de sauvegardes et détectées bien des jours, voire
des semaines après l'incident. Les moteurs de bases de données sont très résilients
face à ces destructions de données, en proposant des mécanismes de journalisation
adaptés. Malgré cela, des précautions sont de mises.

<!--more-->

<!--
https://thebuild.com/presentations/worst-day-fosdem-2014.pdf
https://postgreshelp.com/postgresql-checksum/
-->

---

## La surcorruption

La détection d'une corruption n'est jamais très claire, ni très précise. Dans 
la majorité des situations, il s'agit d'un utilisateur qui reporte une erreur
lors de la lecture d'une ligne dans la base de données et ne parvient pas à
finaliser son traitement. Avec PostgreSQL, la première source exploitable reste
le journal de l'instance, dans lequel l'anomalie sera flagrante avec des
messages d'erreur de type `could not read block xxx in file` ou `invalid page
(header) in block xxx of relation`.

Les corruptions peuvent aussi bien [toucher les index][1] que les tables. Les
premières peuvent provoquer des ralentissements pour certaines requêtes, voire
remonter des données erronées, alors que les secondes sont bien plus
problématiques avec la destruction simple d'une partie des données utilisateurs.

[1]: https://www.enterprisedb.com/blog/how-to-fix-postgresql-index-corruption-deal-repair-rebuild

Après un constat désarmant de corruption, la sueur perle probablement sur le 
front des équipes techniques, si tant est que l'information leur ait été remontée
dans un court laps de temps. La corruption est-elle réversible avec une copie
quelconque de la table dans une instance secondaire, ou dans une sauvegarde ?
La corruption est-elle présente depuis longtemps ? Le système présente-t-il des
messages alarmants sur l'état des écritures sur le volume ?
 
Le meilleur des conseils que trop peu se permettent, serait de se prévenir d'une
surcorruption en {{< u >}}arrêtant les écritures le plus tôt possible{{< /u >}}.
Le temps d'identifier l'origine de la corruption, en mobilisant plusieurs équipes
pour éplucher les logs des hyperviseurs, des baies de stockages ou du fournisseur
Cloud, il se peut (statistiquement) qu'une autre corruption atteinte à la vie des
données saines du système.

Il est aussi [indispensable][2] de procéder à une copie bas niveau du répertoire
de données de l'instance et de travailler exclusivement sur un exemplaire de ladite
copie, _a minima_ sur des disques différents, au mieux, sur un serveur secondaire.

[2]: https://wiki.postgresql.org/wiki/Corruption

---

## Récupérer ce qui peut l'être

Pour illustrer la complexité que peut devenir la récupération de données saines
sur une base corrompue, j'ai malmené une instance jetable en version 13 dont
les données de la table `pgbench_accounts` ont été partiellement détruites avec
l'outil `fallocate`.

Élargir la recherche des corruptions est possible en forçant la lecture intégrale
des données contenues dans les tables. Avec PostgreSQL, le plus simple consiste
à exporter les bases avec `pg_dump`, de surveiller la sortie d'erreurs… et 
d'espérer qu'aucune donnée ne soit perdue.

```text
$ pg_dump demo 1> /dev/null

Dumping the contents of table "pgbench_accounts" failed: PQgetResult() failed.
Error message from server: 
  ERROR:  invalid page in block 20 of relation base/16997/17010
The command was: 
  COPY public.pgbench_accounts (aid, bid, abalance, filler) TO stdout;
```

L'incertitude s'installe à l'issue de la commande. L'une des pages de la table
`pgbench_accounts` présente une malformation, rendant impossible la lecture de
8 ko de données. La récupération des données encore exploitable peut être possible,
notamment à travers l'index de clé primaire et une recherche par dichotomie sur
les valeurs disponibles dans le fichier corrompu.

```sql
SET enable_seqscan = off;

COPY (SELECT aid, bid, abalance, filler 
        FROM public.pgbench_accounts WHERE aid < 1221)
  TO stdout;

COPY (SELECT aid, bid, abalance, filler 
        FROM public.pgbench_accounts WHERE aid > 1281) 
  TO stdout;
```

Si tant est que cette table soit concernée par une contrainte de clé étrangère, 
l'ensemble du modèle devient alors partiellement incohérent et les données
orphelines sont destinées à être détruites explicitement pour valider la 
contrainte.

```sql
ALTER TABLE pgbench_history
  ADD FOREIGN KEY (aid) REFERENCES pgbench_accounts(aid);

-- ERROR: insert or update on table "pgbench_history" violates 
--        foreign key constraint "pgbench_history_aid_fkey"
-- DETAIL: Key (aid)=(1276) is not present in table "pgbench_accounts".

DELETE FROM pgbench_history h 
 WHERE NOT EXISTS
   (SELECT aid FROM pgbench_accounts WHERE aid = h.aid);

ALTER TABLE pgbench_history
  ADD FOREIGN KEY (aid) REFERENCES pgbench_accounts(aid);

-- ALTER TABLE
```

---

## Se protéger des corruptions

Comme précisé en introduction, la plupart des moteurs de bases de données sont
[résilients][3] et articulent leurs écritures autours de la journalisation. 
Chaque modification est assurée d'être écrite sur un stockage non volatile à la
réception du `COMMIT` de la transaction. Cela implique une synchronisation des
blocs en mémoire vers le stockage du système comme je l'avais illustré dans un
[précédent article][4].

[3]: https://www.postgresql.org/docs/current/wal-reliability.html
[4]: /2021/01/19/la-breve-histoire-du-fichier-backup_label/#il-était-une-fois-la-journalisation

Des précautions sont bien sûr nécessaires, et Craig Ringer avait compilé dans 
un [article][5] en 2012, des recommandations toujours pertinentes pour réduire
le risque de corruptions.

[5]: http://blog.ringerc.id.au/2012/10/avoiding-postgresql-database-corruption.html

* **Mettre à jour** votre instance à la dernière version mineure disponible ;
* **Ne pas désactiver** `fsync` et privilégier les paramètres `asynchronous_commit`
  et `commit_delay` ;
* **Ne pas tuer** les processus PostgreSQL et utiliser les fonctions système
  `pg_cancel_backend` et `pg_terminate_backend` pour arrêter une requête longue ;
* **Ne pas supprimer** le contenu du répertoire de données, à l'exception des
  traces d'activité au format texte ;
* **Ne pas modifier** le catalogue système (`pg_catalog.*`) ;
* **Conserver les sauvegardes sur de longues périodes** à raison d'une par semaine,
  une par mois, voire une par année pour reconstruire les données corrompues
  (avec un peu de chance tout de même) ;
* Mettre en place de la réplication et des sauvegardes physiques, avec un politique
  de rétention des journaux de transactions sur de longues périodes ;
* **Éviter les disques en RAID5** et privilégier le RAID10 pour les disques mécaniques ;
* **Ne pas utiliser** les systèmes de fichiers exotiques comme ZFS, BTRFS ou FAT32 ;
* **Ne pas stocker les fichiers** de l'instance sur une clé USB ou un montage
  réseau.

Malgré toutes ces protections, une autre forme de corruption peut encore survenir.
Une donnée erronée peut être retournée au client sans message d'erreur. On parle
alors de [corruption silencieuse][6]. 

Prenons l'exemple d'une donnée dans la table `pgbench_branches` :

[6]: https://wiki.postgresql.org/wiki/Corruption_Detection_and_Containment

```sql
UPDATE pgbench_branches SET filler = 'florent';
SELECT pg_relation_filepath('pgbench_branches');

--  pg_relation_filepath 
-- ----------------------
--  base/17100/17179
```

À l'aide d'un éditeur hexadécimal, je suis libre d'émuler une corruption
silencieuse en ciblant précisément une donnée de type `text`. Ici, je remplace
quelques octets pour transformer `florent` en `fl4r%nt`.

```text
hexedit base/17100/17179

00001F64   00 00 00 00  00 00 00 00  00 00 00 00  ............
00001F70   02 00 03 80  02 29 18 00  01 00 00 00  .....)......
00001F7C   00 00 00 00  B3 66 6C 34  72 25 6E 74  .....fl4r%nt
00001F88   20 20 20 20  20 20 20 20  20 20 20 20
00001F94   20 20 20 20  20 20 20 20  20 20 20 20
00001FA0   20 20 20 20  20 20 20 20  20 20 20 20
00001FAC   20 20 20 20  20 20 20 20  20 20 20 20
```

Pour cette démonstration, ce changement a été fait à froid, c'est-à-dire instance
arrêtée et fichiers fermés. Une copie du bloc pouvant encore être dans le cache
mémoire de PostgreSQL, le prochain `CHECKPOINT` ou synchronisation préventive
aurait réécrit le bloc sain à l'intérieur du fichier.

Au redémarrage de l'instance, le contenu de la table est erroné, mais PostgreSQL
n'aura détecté aucune anomalie de corruption dans le bloc de fichier.

```sql
SELECT * FROM pgbench_branches;

-- -[ RECORD 1 ]---------
-- bid      | 1
-- bbalance | 0
-- filler   | fl4r%nt
```

Depuis la version 9.3 de PostgreSQL, publiée en septembre 2013, il est possible
d'activer les [sommes de contrôles][7] pour les données d'une instance afin de
contrôler l'état d'un bloc entre son écriture et ses futures lectures, évitant
alors tout risque de corruption silencieuse.

[7]: https://paquier.xyz/postgresql-2/postgres-9-3-feature-highlight-data-checksums/

Cette opération nécessite pour les versions 11 et inférieures, que l'instance
soit créée avec ce mode particulier. Depuis la [version 12][8], l'utilitaire 
`pg_checksums` permet d'activer et de désactiver le mécanisme de sommes de 
contrôle sur le répertoire de données d'une instance arrêtée, sans besoin de 
migrer vers une nouvelle instance comme il était nécessaire dans les versions
précédentes.

[8]: https://pgpedia.info/d/data-page-checksums.html

```sh
$ pg_checksums --pgdata=$PGENV_ROOT/pgsql/data --enable

Checksum operation completed
Files scanned:  3097
Blocks scanned: 109156
pg_checksums: syncing data directory
pg_checksums: updating control file
Checksums enabled in cluster
```

Dans ce nouveau contexte, je réalise à une nouvelle fois un `UPDATE` sur la table…

```sql
UPDATE pgbench_branches SET filler = 'florent';
CHECKPOINT;
```

… et je corrompts la donnée de la table `pgbench_branches`. Au redémarrage,
PostgreSQL remonte correctement une anomalie de sommes de contrôle sur le bloc
qui contient la donnée corrompue :

```sql
SELECT * FROM pgbench_branches;

-- WARNING: page verification failed, calculated checksum 35393 but expected 2501
-- ERROR: invalid page in block 0 of relation base/17100/17179
```

---

## Conclusion

Les corruptions sont des événements rarissimes et imprévisibles. Il est 
communément admis que les dégâts sont irréversibles dans un grand nombre de
situations, en l'absence de contre-mesures suffisantes. 

À moins d'avoir une confiance aveugle dans l'infrastructure matérielle qui
héberge vos instances, l'activation des sommes de contrôle représente à ce jour
le mécanisme le plus complet pour identifier rapidement toutes les formes de
corruptions sur les données de vos bases.

**Mauvaise nouvelle : ce mécanisme n'est pas actif par défaut.**

À vous d'intégrer l'option `--data-checksums` de l'utilitaire `initdb` lors du
provisionnement de toutes vos nouvelles instances. Enfin, privilégiez une
version 12 ou supérieure, car vous ne regretterez pas le gain de temps que
vous apportera `pg_checksums` !