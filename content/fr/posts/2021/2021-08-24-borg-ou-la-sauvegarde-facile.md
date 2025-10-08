---
title: "BorgBackup ou la sauvegarde facile"
slug: "borg-ou-la-sauvegarde-facile"
categories: [linux]
tags: [sauvegarde,opensource]
date: 2021-08-24
---

Jusqu'à très récemment, je ne me préoccupais pas de la pertinence de mes
sauvegardes de fichiers personnels réalisées naïvement avec un script `rsync`.
C'est honteux dans nos métiers, mais l'adage du cordonnier s'est vérifié avec
moi lors de l'exécution d'un vulgaire `find $NOVAR/ -delete` durant des tests.

Après cet épisode et l'amertume d'avoir perdu quelques travaux, ou la surprise
de découvrir les ravages de leur disparition plusieurs semaines après ma fatale
erreur, je me suis tourné vers l'outil incontournable dont tous mes collègues me
parlaient : [BorgBackup][1]

[1]: https://borgbackup.readthedocs.io/en/stable/

<!--more-->

---

## Des atouts séduisants

Cela fait à présent deux années que je travaille au quotidien sur Linux pour mon
activité professionnelle. Étant responsable de mon matériel et des données que
je manipule, il n'existe pas de politique particulière pour les sauvegardes
régulières ni le stockage de celles-ci.

Mon précédent script était passablement trivial, à savoir :

* Sauvegarder une copie unique des documents courants ;
* Sauvegarder une liste des fichiers de configuration, appelés _dotfiles_ ;
* Exclure les projets contenant un répertoire `.git` ;
* Exclure les fichiers de plus de 200 Mo.

Le tout sur une clé USB de 8 Go, chiffrée avec le système [LUKS][2] pour se
prévenir de la perte ou du vol dans un espace public dudit support.

[2]: https://fr.wikipedia.org/wiki/LUKS

Borg (son petit nom), permet de répondre correctement à l'ensemble de ces
points, et le fait à merveille.  En bénéficiant de la déduplication et de la
compression, j'ai pu conserver ma clé USB et m'engager dans la rédaction d'un
[nouveau script][3] plus complet.

[3]: https://gist.github.com/fljdin/de46c7c8d18cc37e591cb8364ecf8eef

**Exclusion de fichiers et de répertoires**

Certains fichiers ou répertoires cachés vivent leur vie sur nos postes, et un
fichier d'exclusion peut être transmis à Borg pour ne pas les inclure dans la
routine de sauvegarde. Le mien est relativement léger pour le moment, et
pourrait s'enrichir avec l'expérience.

```sh
# ~/.config/borg/exclude.list
/home/**/.git
/home/**/.vagrant
/home/*/.local
/home/*/.cache
/home/*/.mozilla
/home/*/.thunderbird
/home/*/.config/chromium
/home/*/.config/discord
/home/*/.npm
/home/*/.cpan
```
**Déduplication et rétention d'une semaine**

Le gain remarquable entre mon script et la nouvelle solution que m'offre Borg
réside dans son algorithme de déduplication, où la version d'un fichier n'est
stockée qu'une seule fois jusqu'à une éventuelle modification, permettant de ne
conserver qu'une copie de mes documents sur une bien plus longue période avec
un coût de stockage ridiculement faible.

À chaque exécution, je demande le rapport de sauvegarde avec l'option `--stats`
dont voici un exemplaire sur l'exécution de ce matin.

```sh
------------------------------------------------------------------------------
Archive name: florent-2021-08-24T08:42:05
Archive fingerprint: be38707dd52f5a86f8e75fe3ad4997aae58b3016366a988b7cb37ce3b
Time (start): Tue, 2021-08-24 08:42:06
Time (end):   Tue, 2021-08-24 08:42:06
Duration: 0.96 seconds
Number of files: 3720
Utilization of max. archive size: 0%
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
This archive:                2.11 GB              1.78 GB            480.51 kB
All archives:               12.63 GB             10.67 GB              1.75 GB
                       Unique chunks         Total chunks
Chunk index:                    3974                25888
------------------------------------------------------------------------------
```

Pour une semaine de rétention, l'espace total consommé sur le montage USB
n'excède pas (encore) les 1,75 Go alors que les images décompressées pèsent au
total 12,63 Go que ne parvennait pas à stocker mon ancien script sur plusieurs
jours.

Au passage, la durée d'exécution est significativement réduite chaque jour grâce
à ce mécanisme, qui ne sélectionne que les nouveautés d'une exécution à l'autre.

**Un montage virtuel pour naviguer dans le temps**

L'outil propose deux options pour la restauration :

* `extract` pour restaurer le contenu d'une archive dans le répertoire courant
([doc][5]) ;
* `mount` pour visualiser les fichiers ou dossiers à restaurer, voire les
déplacer manuellement dans le répertoire cible avec un outil graphique
([doc][6]).

[5]: https://borgbackup.readthedocs.io/en/stable/usage/extract.html
[6]: https://borgbackup.readthedocs.io/en/stable/usage/mount.html

Cette seconde proposition est particulièrement utile pour naviguer d'une archive
à une autre, à la recherche d'un fichier perdu dans le temps. Le montage
s'effectue à l'aide du système de fichiers [FUSE][7] qui ne nécessite aucun
droit administrateur.

[7]: https://www.kernel.org/doc/html/latest/filesystems/fuse.html

Pour être utilisé à partir de Borg, le paquet `python-llfuse` sera requis selon
votre distribution.

## Planification avec systemctl

Ce fut une découverte lors de mes lectures émerveillées de la [documentation][3]
et des [ressources][4] de la communauté française d'Archlinux. N'étant pas
particulièrement fan de `cron` pour un usage personnel, j'ai suivi à la lettre
la configuration d'un service utilisateur et du _timer_ associé pour garantir le
lancement de la sauvegarde chaque jour, 30 minutes après le démarrage de mon
système.

[3]: https://borgbackup.readthedocs.io/en/stable/quickstart.html#automating-backups
[4]: https://wiki.archlinux.org/title/Borg_backup_(Fran%C3%A7ais)

```ini
# .config/systemd/user/borg.service
[Unit]
Description=Borg backup

[Service]
Type=oneshot
ExecStart=%h/.bin/borg-create.sh
```
```ini
# .config/systemd/user/borg.timer
[Unit]
Description=Daily Borg backup
Documentation=man:borg

[Timer]
OnBootSec=30min
OnUnitActiveSec=1d

[Install]
WantedBy=timers.target
```

Une fois le service activé, je n'ai qu'à attendre chaque matin la notification
de fin de sauvegarde pour consulter les rapports avec la commande `journalctl`.

```sh
journalctl --user -xeu borg.service
```
```sh
août 24 08:42:02 florent systemd[877]: Starting Borg backup...
août 24 08:42:27 florent systemd[877]: Finished Borg backup.
août 24 08:42:27 florent systemd[877]: borg.service: Consumed 1.535s CPU time.
```

## Conclusion

De trop nombreux utilisateurs (Windows notamment) comptent sur leur miraculeuse
corbeille, jusqu'à ce qu'une véritable suppression ne survienne ou qu'un disque
défaillant fasse des siennes. Pour s'assurer qu'une donnée ne disparaisse pas
définitivement, la sauvegarde doit être correctement mise en place, idéalement
sur plusieurs périodes et sur plusieurs supports.

Le conseil vaut aussi bien pour les bases de données que pour les fichiers
personnels : une sauvegarde n'est fiable que si la restauration de son
contenu est possible. Une corruption de l'archive, une erreur dans l'exécution
du script ou une mise à jour majeure de l'outil de sauvegarde sont autant de
situations qui peuvent rendre vos sauvegardes irrécupérables.

Prenez soin de vos sauvegardes.
