---
date: 2020-12-10
title: "Lumière sur : pgenv"
categories: [postgresql]
tags: [administration,opensource]
draft: true
---

Parmi les quelques outils de mon quotidien, il y en a un très sobre et bigrement
efficace répondant au nom de [pgenv][1], un gestionnaire des versions PostgreSQL.
Ce projet est publié sous licence MIT par David E. Wheeler, auteur de l'extension 
pgTAP dont j'avais déjà vanté les mérites dans un [autre article].

Cet outil concerne principalement les contributeur⋅rices au projet PostgreSQL et les 
quelques DBA féru⋅es d'expérimentations, car `pgenv` permet de compiler et 
d'exécuter toutes les versions majeures et mineures du système de base de données
open-source le plus avancé du monde.

[1]: https://github.com/theory/pgenv
[autre article]: /2020/05/14/ecrire-ses-tests-unitaires-en-sql

<!--more-->

---

PostgreSQL est parciulièrement simple à compiler.

Pour bien commencer, je souligne qu'il est recommandé d'avoir un poste de travail 
sous Unix, GNU/Linux ou BSD afin d'avoir les dépendances principale, à savoir
`bash`, `make`, `patch`, `curl` et les usuels `grep`, `sed`, `cat` ou `tail`.

```sh
git clone git://git.postgresql.org/git/postgresql.git

cd postgresql
./configure --prefix=$HOME/postgres/devel
make && make install

cd contrib
make && make install
```

Le faire à la main m'a amusé quelques heures et écrire un script pour automatiser
le déploiement des versions mineures à la demande m'a vite traverser l'esprit. 
Un gestionnaire pour garantir un contrôle acceptable des répertoires de sources, 
d'installation, de données d'instance, de configuration…

Ne réinventons pas la roue et voyons ce que propose `pgenv` !

---

## Votre première instance personnelle

Après avoir cloner le dépôt dans votre sous-répertoire `~/.pgenv`, il est temps 
de télécharger et de compiler la version qui vous interesse.