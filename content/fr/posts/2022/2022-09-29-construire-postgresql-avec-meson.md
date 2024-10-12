---
title: "Construire PostgreSQL avec Meson"
categories: [postgresql, linux]
tags: [opensource, automatisation]
date: 2022-09-29
---

Alors que la version 15 de PostgreSQL se prépare à sortir dans les [prochains
jours][0], le groupe de développement du projet communautaire ont intégré [leurs
récents travaux][1] pour accélérer les tâches d'automatisation et de compilation
à l'aide du système de construction [Meson][2].

[0]: https://www.postgresql.org/about/news/postgresql-15-rc-1-released-2516/
[1]: https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=e6927270cd18d535b77cbe79c55c6584351524be
[2]: https://mesonbuild.com/

Ce chantier n'est pas anodin et redessine les contours de l'écosystème du moteur
de bases de données open-source le plus avancé au monde. Depuis sa forme libre
publiée en 1998, PostgreSQL repose sur des solutions robustes et éprouvées, mais
de plus en plus complexes à maintenir pour les nouvelles générations de
contributeur·rices. En proposant de se tourner vers un logiciel comme Meson, ces
amoureux et amoureuses du libre se tournent résolument vers l'avenir.

<!--more-->

![patch](/img/fr/2022-09-29-andres-freund-e692323.png)

---

## En finir avec autoconf

Un système de construction ou _build system_ (ne vous y trompez pas, j'ai une
préférence pour la dénomination anglaise) est un ensemble d'instructions dans
une syntaxe qui lui est propre, qui facilite la compilation d'un logiciel. Les
ramifications d'un projet, les dépendances et les librairies ou tout simplement
l'outillage interne, deviennent inexorablement la rançon d'une complexité après
plusieurs décennies d'existence.

Le système le plus répandu est sans conteste [Make][3] et son fichier déclaratif
_Makefile_ qui contiendra les instructions de compilation. Son principe absolu
consiste à transformer un fichier source (le code) en un autre fichier cible (le
binaire). Dans un projet minimaliste, le _Makefile_ suivant permet de générer le
binaire `foo` si le code source `foo.c` ou son en-tête `foo.h` contiennent des
nouveautés.

[3]: https://en.wikipedia.org/wiki/Make_(software)

```make
# ./Makefile
CC=gcc
CFLAGS=-I.

foo: foo.c foo.h
    $(CC) -o foo foo.c
```

À l'appel de la commande `make` à la racine du projet, le fichier _Makefile_
sera parcouru pour détecter les cibles du projet et suivre les instructions
selon les règles qui y sont renseignées pour construire les fichiers binaires.

<!--
graph LR
    M[Makefile] --\>|make| >B[Binary]

mogrify -shave 0x300 -resize x55 makefile-workflow.png
-->

![Compilation par Makefile](/img/fr/2022-09-29-makefile-workflow.png)

Une [pratique plus sophistiquée][4] propose de générer ces instructions dans un
format compatible avec le système de construction, lorsque celles-ci sont
nombreuses, évolutives voire dépendantes d'un contexte ou d'un environnement tel
que le système d'exploitation ou l'utilisation d'une option spécifique.

[4]: https://en.wikipedia.org/wiki/List_of_build_automation_software#Build_script_generation

Dans le cas du projet PostgreSQL, c'est la suite [GNU Autotools][5] qui a été
partiellement retenue pour faciliter la création des binaires sur un ensemble de
systèmes compatibles Unix. La génération repose sur les composants _Autoconf_
(fichier `configure.ac`) et _Automake_ (fichier `Makefile.am`) pour aboutir au
même résultat que la commande `make` de notre précédent exemple. Dans les faits,
seul le premier composant est véritablement employé pour préparer le script
`configure` lors de la compilation de PostgreSQL.

[5]: https://en.wikipedia.org/wiki/GNU_Autotools

<!--
graph LR
    Ac[configure.ac] --\>|aclocal| M4[aclocal.m4]
    Ac --\>|autoconf| C[configure]
    Ac --\>|autoheader| Ch[config.h.in]
    M4 --\>|autoconf| C

    Am[makefile.am] --\>|automake| Mi[Makefile.in]
    Ch --\>|automake| Mi

    C --\> Cs[config.status]
    Ch --\> Cs
    Mi --\> Cs

    Cs --\> M[Makefile]
    Cs --\> Chi[config.h]
    M --\>|make| B[Binary]
    Chi --\>|make| B

mogrify -shave 0x245 mermaid-diagram-2022-09-28-160932{,-1}.png
-->

![Génération avec Autotools](/img/fr/2022-09-29-autotools-workflow.png)

Comme le montre le diagramme ci-dessus, les étapes avant d'obtenir le fichier
binaire sont un peu plus nombreuses, et dépendent d'un ensemble de fichiers
d'instructions qui deviennent complexes à rédiger sans introduire d'incohérences
ou de bogues.

C'est d'ailleurs l'un des constats de la communauté qui, depuis fin 2021, a
questionné la possibilité de passer sur un autre système de construction.

> Autoconf is showing its age, fewer and fewer contributors know how to wrangle
> it. Recursive make has a lot of hard to resolve dependency issues and slow
> incremental rebuilds.

Le principal moteur de la réflexion, Andres Freund, annonçait dans un
[message][6] sur _pgsql-hackers_ qu'il observait de bien meilleures performances
avec une alternative bien plus moderne. Il y énonçait par ailleurs ses arguments
pour en finir avec _Autoconf_ :

[6]: https://www.postgresql.org/message-id/20211012083721.hvixq4pnh2pixr3j%40alap3.anarazel.de

* « _Autoconf_ et _make_ ne sont plus activement maintenus. Notamment _autoconf_
  qui reçoit à peine quelques correctifs mineurs. C'est également des
  technologies que peu de monde veut utiliser -- m4 d'autoconf est effrayant et
  effraie les personnes qui démarrent bien plus récemment que nous autres, les
  _committers_ » ;

* « _make_ en mode récursif comme nous l'utilisons n'est pas aussi bien employé
  que ce qu'il devrait être. L'une des raisons pour laquelle le nettoyage du
  _build_ est si lent est que nous devons retrouver les dépendances dans un
  paquet d'endroits. En malgré cela, il m'arrive régulièrement de voir des
  _builds_ incrémentaux échouer et nécessitant un nouveau _rebuild_ » ;

* « Et nous n'avons pas uniquement un système de _build_ basé sur _autoconf_ et
  _make_, il y a surtout le projet de génération MSVC (_Microsoft Visual C++_)
  -- ce machin que la plupart d'entre nous ne veut pas toucher. Je pense qu'en
  plus du fait qu'il n'y est pas facile de dérouler tous les tests, ce système
  est juste tout simplement différent de l'autre, ce qui ne favorise pas l'intérêt
  des développeurs sous Windows (et indirectement, la qualité de PostgreSQL sur
  Windows) » ;

* « Le dernier gros problème que je vois avec la situation actuelle est qu'il
  n'y a aucun bon test d'intégration. Le résultat de `make check-world` est très
  majoritairement illisible et impossible à analyser automatiquement. Ce qui 
  impose à la _[buildfarm][7]_ de traiter les tests séparément afin que les 
  erreurs puissent être repérées et tracées correctement. Cette approche n'est
  malheureusement pas adaptée aux processeurs multicœurs et ralentit considérablement
  l'ensemble des serveurs ».

[7]: https://buildfarm.postgresql.org/cgi-bin/show_status.pl

---

## Meson, une alternative moderne

À l'image des _Autotools_, [Meson][2] est un système qui génère les instructions
de compilation. Ce fut le choix qu'a proposé Andres Freund à la communauté après
l'avoir analysé aux côtés de [CMake][8] et [Bazel][9], deux autres compétiteurs
bien connus du monde libre. Meson est écrit en Python et son but premier est de
réduire la part d'efforts des développeurs dans la rédaction d'instructions au
profit d'une plus grande productivité sur le logiciel en tant que tel.

[8]: https://cmake.org/cmake/help/book/mastering-cmake/chapter/Why%20CMake.html#
[9]: https://bazel.build/about/vision

Le projet Meson s'appuie sur un système de construction bas niveau appelé
[ninja][10] qui se veut, d'après son auteur [Evan Martin][11], être minimaliste
et bien plus performant que `make`. Les instructions de compilation sont
renseignées automatiquement par Meson dans le fichier `build.ninja` qui sera
ensuite parcouru par la commande `ninja` pour compiler les sources en un fichier
binaire.

[10]: https://ninja-build.org/
[11]: https://neugierig.org/software/chromium/notes/2011/02/ninja.html

<!--
graph LR
    mb[meson.build] --\>|meson setup| bn[build.ninja]
    bn --\>|meson compile| B[Binary]

mogrify -shave 0x370 x55 makefile-workflow.png
-->

![Génération avec Meson](/img/fr/2022-09-29-meson-workflow.png)

Pour reprendre mon projet minimaliste `foo`, le fichier _Makefile_ est remplacé
par le fichier `meson.build`, en y renseignant les méta-données du projet, le
point d'entrée du programme et le fichier binaire souhaité.

```rb
# ./meson.build
project('foo', 'c')
executable('foo', 'foo.c')
```

Meson est un jeune projet, dont la première sortie date de 2013. Bien qu'il
rougît de son âge face à CMake, il n'en reste pas moins un concurrent qui ne
cesse de [gagner du terrain][12] depuis la dernière décennie. Parmi les
[projets][13] qui s'appuient désormais sur Meson, je peux citer de très connus
comme : `systemd`, Gnome et GTK+, QEMU, Xorg et Wayland... De quoi se parer
d'une forte communauté d'utilisateurs dans les prochaines années !

[12]: https://gms.tf/the-rise-of-meson.html
[13]: https://mesonbuild.com/Users.html

Sur la page « [Use of Python][14] » du projet, les créateurs de Meson se
défendent d'un reproche souvent adressé aux technologies modernes et affirment
ne reposer que sur `python3` tout en interdisant l'usage de modules externes,
en gages de qualité et de compatibilité. Ainsi, le projet se veut accessible
pour tous les systèmes d'exploitation, faisait un pied de nez au mastodonte
_Autotools_ qui était très couplé au _shell_ Unix dans son implémentation.

[14]: https://mesonbuild.com/Use-of-Python.html

La décision pour le projet PostgreSQL de progressivement glisser vers Meson est
le fruit de plusieurs mois de réflexion, avec pour ambition notamment de se
passer du système [MSVC][15], un ensemble de scripts Perl maison maintenus par
une poignée de personnes pour compiler le logiciel sous Windows. En prime, les
travaux d'Andres démontrent un gain significatif dans les temps de _build_, ce
qui ne paraît pas surprenant au regard du _[benchmark][16]_ entre les deux
systèmes sur une architecture ARM.

[15]: https://github.com/postgres/postgres/tree/master/src/tools/msvc
[16]: https://mesonbuild.com/ARM-performance-test.html

![Benchmark sur le temps de configuration](/img/fr/2022-09-29-meson-autotools-benchmark-conf.png)

![Benchmark sur le temps de configuration](/img/fr/2022-09-29-meson-autotools-benchmark-build.png)

> In any case, using Autotools for a modern C/C++ project in 2021 is like using
> CVS for source code version control in 2021: there are better tools available
> and thus it isn't very interesting to still consider the legacy solutions.
> 
> _Citation de [Georg Sauthoff, The Rise of Meson][12]._

---

## Conclusion

La route empruntée semble la bonne, bien que le chemin soit encore long pour se
débarrasser définitivement des résidus historiques d'_Autoconf_ dans le projet
PostgreSQL. Lors de la dernière _[Developer Unconference][17]_ qui s'est tenue
en ligne le 25 mai 2022 lors de l'événement annuel du PgCon, les membres de la
communauté ont statué sur les efforts à fournir pour porter ce chantier
titanesque.

[17]: https://wiki.postgresql.org/wiki/PgCon_2022_Developer_Unconference#Meson_new_build_system_proposal

Avec ce récent [patch][1] rattaché à présent à la branche _master_, la
construction des binaires sur la plupart des systèmes d'exploitation est
implémentée, avec notamment la compilation de PostgreSQL sur Windows à travers
`ninja`. C'est une première pierre qui est posée pour la prochaine version 16 en
cours de développement et l'émergence d'une architecture qui grandira avec
d'autres améliorations dans un avenir proche.