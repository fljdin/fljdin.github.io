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

Les corruptions silencieuses, ainsi les appelle-t-on, peuvent aussi bien [toucher
les index][1] que les tables. Les premières peuvent provoquer des ralentissements
pour certaines requêtes, voire remonter des données erronées, alors que les
secondes sont bien plus problèmatiques avec la destruction simple d'une partie
des données utilisateurs.

[1]: https://www.enterprisedb.com/blog/how-to-fix-postgresql-index-corruption-deal-repair-rebuild

À la vue de ces messages, la sueur perle probablement sur le front des équipes
techniques, si tant est que l'information leur ait été remontée dans un court
laps de temps. La corruption est-elle réversible avec une copie quelconque de la
table dans une instance secondaire, ou dans une sauvegarde ? La corruption
est-elle présente depuis longtemps ? Le système présente-t-il des messages
alarmants sur l'état des écritures sur le volume ?
 
Après ce constat désarmant, que faire ? Le meilleur des conseils que trop peu se
permettent, serait de se prévenir d'une surcorruption en {{< u >}}arrêtant 
les écritures le plus tôt possible{{< /u >}}. Le temps d'identifier l'origine 
de la corruption, en mobilisant plusieurs équipes pour éplucher les logs des 
hyperviseurs, des baies de stockages ou du fournisseur Cloud, il se peut 
(statistiquement) qu'une autre corruption atteinte à la vie des données saines
du système.

Il est aussi [indispensable][2] de procéder à une copie bas niveau du répertoire
de données de l'instance et de travailler exclusivement sur un exemplaire de ladite
copie, _a minima_ sur des disques différents, au mieux, sur un serveur secondaire.

[2]: https://wiki.postgresql.org/wiki/Corruption

---

## Récupérer ce qui peut l'être

Pour illustrer la complexité que peut devenir la récupération de données saines
sur une base corrumpue, j'ai malmené une instance jettable en version 13 dont
les données de la table `pgbench_accounts` ont été partiellement détruites avec
l'outil `fallocate`.

Élargir la recherche des corruptions est possible en forçant la lecture intégrales
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



<!--
* checksums
* supervision
-->

