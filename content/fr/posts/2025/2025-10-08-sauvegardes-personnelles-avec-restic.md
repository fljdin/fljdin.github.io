---
title: "Sauvegardes personnelles avec Restic"
categories: [linux]
tags: [sauvegarde,opensource]
date: "2025-10-08 16:00:00 +0200"
---

Ces derniers temps, j’ai mis fin à une histoire d’amour avec Debian qui aura
duré près de trois ans. Pas que je n’aime plus le système, oh non, je le préfère
toujours à sa cousine Ubuntu. Mais voilà, j’ai un attachement particulier à
Archlinux depuis, wouh, au moins les bancs de l’école d’ingénieur où nous
l’installions sur des machines virtuelles et où nous nous adonnions à la
pratique du [linux ricing][1] pour passer le temps.

[1]: https://github.com/fosslife/awesome-ricing

Après une expérimentation de [Manjaro i3][2] entre 2019 et 2022 sur mon poste
professionnel, je me suis convaincu qu’il me fallait retourner à l’essentiel. Au
début du mois de septembre, j’ai réussi le portage de ma [config Sway][3] de
Debian Trixie vers Archlinux. L’occasion parfaite pour requestionner mes
pratiques en matière de sauvegarde de poste et de remplacer [BorgBackup][4] par
Restic.

[2]: https://manjaro.org/
[3]: https://gitlab.com/fljdin/dotfiles/-/tree/main/sway
[4]: /2021/08/24/borg-ou-la-sauvegarde-facile/

<!--more-->

---

## Prise en main éclair

J’ai lu plusieurs articles et avis au sujet de Restic. Je l’avais vite identifié
comme un outil équivalent à BorgBackup, mais je ne m’étais pas pressé de le
tester. Quelle erreur ! J’ai été déconcerté par la facilité d’utilisation, par
son interface en ligne de commande claire et complète, et par sa
[documentation][5] de qualité.

[5]: https://restic.readthedocs.io/en/stable/010_introduction.html

Pour avoir régulièrement vécu des dégâts sur des clés de mauvaise qualité avec
ma pratique exotique sur BorgBackup, je m’étais penché sur la possibilité de
sauvegarder vers un dossier distant avec SSH. J’ai du insisté deux bonnes heures
à l’époque sans parvenir à quoique ce soit avec Borg.

Avec Restic, ce n’est pas moins de 13 types différents de dépôts supportés, dont
le [SFTP][6]. Il ne m’en fallait pas plus pour tourner le dos à son homologue. La
mise en place d’un dépôt est simplifiée à l’extrême :

[6]: https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html#sftp

```fish
set -x RESTIC_REPOSITORY "sftp:<server>:<directory>"
restic init
restic backup ~ \
  --dry-run \
  --exclude-file ~/.config/restic/excludes.txt
```

Je ne suis pas en reste avec une gestion poussée des stratégies de rétention des
instantanés. Pour l’exemple, je maintiens une sauvegarde par semaine, pendant
trois mois.

```fish
restic forget --prune --keep-within-weekly 3m
```

La technique d’exploration d’un instantané est identique à Borg, avec un montage
[FUSE][7] sous Linux. Une fois encore, la [documentation][8] est limpide à ce
sujet.

[7]: https://www.kernel.org/doc/html/latest/filesystems/fuse.html
[8]: https://restic.readthedocs.io/en/stable/050_restore.html#restore-using-mount

```fish
sudo install -o $USER -g $USER -d /mnt/restic
restic mount /mnt/restic
```

## Planification avec systemd

Je me suis prêté au même jeu qu’avec BorgBackup sur ma précédente installation
Debian. En lieu et place de `cron`, je planifie mes sauvegardes avec un _timer_
utilisateur pour déclencher une tâche deux fois par jour sur mes journées de
travail.

```toml
# ~/.config/systemd/user/restic.timer
[Unit]
Description=Daily Restic backup
Documentation=man:restic

[Timer]
OnCalendar=Mon..Fri 09:30
OnCalendar=Mon..Fri 16:30
Persistent=true

[Install]
WantedBy=timers.target
```

La tâche consiste à appeler `restic` avec mon fichier d’exclusion, suivi d’une
purge des vieux instantanés présents sur le dépôt.

```toml
# ~/.config/systemd/user/restic.service
[Unit]
Description=Restic backup

[Service]
Type=oneshot
ExecStart=restic backup %h --exclude-file $RESTIC_EXCLUDE_FILE
ExecStartPost=restic forget --prune --keep-within-weekly 3m
```

Pour la configuration, je déclare les variables dans un fichier d’environnement
pour que `restic` sache identifier et déchiffrer correctement les instantanés.

```ini
# ~/.config/environment.d/restic.conf
RESTIC_REPOSITORY=sftp:<server>:<directory>
RESTIC_PASSWORD_FILE=$HOME/.config/restic/pass
RESTIC_EXCLUDE_FILE=$HOME/.config/restic/excludes.txt
```

Pour armer la planification, il suffit de recharger `systemd`.

```fish
systemctl --user daemon-reload
```

En exportant les bonnes variables dans votre shell, la consultation des
instantanés se fait sobrement avec la commande suivante.

```fish
restic snapshots
```
```console
repository 3db74709 opened (version 2, compression level auto)
ID        Time                 Host            Tags        Paths          Size
-----------------------------------------------------------------------------------
f7bb4fea  2025-09-16 11:50:18  florent-dalibo              /home/florent  4.309 GiB
5a4dbf59  2025-09-19 09:30:01  florent-dalibo              /home/florent  5.639 GiB
1012f0ab  2025-09-27 19:28:38  florent-dalibo              /home/florent  5.871 GiB
629c2687  2025-10-03 09:30:00  florent-dalibo              /home/florent  6.006 GiB
98b32adb  2025-10-08 10:00:08  florent-dalibo              /home/florent  4.677 GiB
-----------------------------------------------------------------------------------
5 snapshots
```

## Conclusion

Restic est un bon outil. Tellement bon, que la communauté Gnome l’utilise à
présent comme _backend_ pour l’interface Déjà Dup dans leur dernière version
49.0 sortie le [mois dernier][10].

[10]: https://discourse.gnome.org/t/deja-dup-49-0-released/31441

Pour ma part, tout se déroule bien depuis presque un mois. Il ne manque plus
qu’à sécuriser le serveur distant qui fait office de dépôt avec ses propres
sauvegardes ! Pour ce faire, j’envisage de mettre en place Restic sur la plupart
des répertoires d’importances de mon serveur multimédia, en gardant bien en
mémoire le principe 3-2-1 de la sauvegarde réussie.

Prenez soin de vos sauvegardes.
