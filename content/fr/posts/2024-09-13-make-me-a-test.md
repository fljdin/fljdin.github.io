---
title: "Make me a test"
categories: []
tags: []
date: 2024-09-11
---

<!--

À explorer dans cet article :
- définir test de régression et test de non régression
  * https://testgrid.io/blog/non-regression-testing/
  * https://fr.wikipedia.org/wiki/Test_de_r%C3%A9gression
- diff comme méthode simple de détection de régression
- mon intêret pour le fonctionnement de la commande make
- les limites de pg_regress ou de pgtap dans mes projets simples
  * https://github.com/cybertec-postgresql/db_migrator/blob/master/test/Makefile
  * bats https://gitlab.com/dalibo/transqlate/-/blob/master/test/oracle.bats
- écrire un TNR avec make
  * https://stackoverflow.com/a/27838026
  * https://github.com/fljdin/fdw-assistant/blob/main/Makefile
- utiliser make pour exécuter des tests en parallèle

-->

Depuis de nombreuses années, je ne sais plus séparer la conception logicielle d'une bonne
architecture de tests qui en garantit sa qualité. Les stratégies et les outils sont nombreux,
mais dans mon quotidien de DBA où il m'arrive d'écrire des bouts de scripts Bash ou des requêtes
SQL, je me retrouve fréquemment au pied du mur de la complexité.

Quelles formes peuvent-ils prendre et sur quels outils se basent-ils ? Je ne prétends pas avoir
la réponse ultime, et il y aura toujours à redire sur les choix qui se présentent à nous. Dans
cet article, je reviens sur les techniques employées pour tester le projet [fdw-assistant][1],
dont j'avais déjà parlé dans un [précédent article][2].

[1]: https://github.com/fljdin/fdw-assistant
[2]: /2024/05/28/un-assistant-pour-copier-les-donnees-distantes/

<!--more-->

---

## L'art d'être reproductible

> While regression testing aims to ensure that a software bug has been successfully corrected by
> retesting the modified software, the goal of non-regression testing is to ensure that no new
> software bugs have been introduced after the software has been updated.

Source : <https://testgrid.io/blog/non-regression-testing/>

J'apprécie cette citation. Elle m'a permis de voir qu'il existe une distinction entre les tests
de régression et de non-régression. Pendant un temps, j'étais confus et persuadé qu'ils étaient
synonymes. En ce qui me concerne, j'écris des tests pour m'assurer que le comportement de mes
scripts est invariant à mesure que je l'enrichis ou que je corrige des bogues.

Leur point commun réside dans leur capacité à reproduire l'exécution du script avec une série
de données d'entrées (_inputs_) dont on connaît les résultats attendus (_outputs_).

FIXME
- pourquoi ne pas utiliser pgxs et pg_regress
- pourquoi ne pas utiliser pgtap
- pourquoi ne pas utiliser bats
