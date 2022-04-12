---
title: "Halte aux regressions"
date: 2022-03-29
categories: [postgresql]
tags: [developpement,tests]
draft: true
---

Pour garantir la qualité du code d'un logiciel, rien de mieux que la validation
par les tests. Ces derniers peuvent être de différentes natures (fonctionnels,
intégration, unitaires, performance, etc…) et permettent de respecter une série
d'exigences que s'imposent les développeurs pour maintenir et faire évoluer ledit
logiciel dans la bonne direction.

Dans cette article, je souhaite explorer le système de tests tel qu'il est (et
a été) implémenté dans PostgreSQL et comment le réemployer dans la rédaction d'une
extension communautaire. Si vous ne connaissiez pas l'outil `pg_regress`, il 
n'aura plus de secret pour vous !

<!--more-->

---

## Aux origines des tests de régression

Avant même l'émergence du plus avancé des systèmes de bases de données open-source
du monde que l'on connait, le projet Berkeley [POSTGRES][1] disposait déjà d'un 
répertoire de `src/regress/regress` dans sa dernière version connue. Ce dernier 
fut définitivement adopté sous la forme de `src/test/regress` lors de la reprise 
du projet Postgre95 par les [deux étudiants][2] Andrew Yu et Jolly Chen.

[1]: https://dsf.berkeley.edu/postgres-v4r2/
[2]: https://www.postgresql.org/docs/14/history.html

Ce n'est pas anodin, car ce répertoire existe encore dans les versions modernes
et porte toujours les mêmes responsabilités, à savoir : s'assurer que les
fonctionnalités de PostgreSQL ne présentent aucune régression à chaque patch ou
nouvelles versions majeures. Ce système de test est relativement simple à 
appréhender et très répandu dans le milieu du développement des logiciels libres.

Il repose sur les fichiers de tests au format SQL et des fichiers de sorties au
format OUT. L'astuce consiste à exécuter le code SQL sur une instance en cours
d'exécution et de capter la sortie standard dans un fichier de résultat. Pour
chacun test (`sql`), le fichier de résultat (`result`) est ensuite comparé au 
résultat attendu du test (`expected`) à l'aide de la méthode `diff`.

![Fonctionnement du système de tests](/img/fr/mermaid-diagram-20220330173642.png)

<!-- https://mermaid-js.github.io/mermaid-live-editor
{
  "theme": "default"
}
graph LR
    test[test.sql] --\>|runtest| instance[(instance)]
    instance --\> result[result.out] --\> diff
    expected[expected.out] --\> diff{diff}
    diff --\> passed((passed))
-->


<!--

PG 2.0 https://github.com/postgres/postgres/tree/REL2_0/src/test/regress

PG 6.1 https://github.com/postgres/postgres/blob/REL6_1/src/test/regress
  The regression tests have been adapted and extensively modified for the
  v6.1 release of PostgreSQL.

PG 7.1
  New unified regression test driver 
  https://www.postgresql.org/message-id/Pine.LNX.4.21.0009291921150.363-100000%40peter
  https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=6f64c2e54a0b14154a335249f4dca91a39c61c50

PG 8.2
  Rewrite pg_regress as a C program instead of a shell script.
  https://www.postgresql.org/message-id/6BCB9D8A16AC4241919521715F4D8BCEA0FAFD%40algol.sollentuna.se
  https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=a38c85bd5d928115fdd22c9e28e0a7eeebc9878e
-->

---

## makefile pgxn

<!--

https://www.postgresql.org/docs/current/regress.html
https://www.postgresql.org/docs/current/extend-pgxs.html
https://wiki.postgresql.org/wiki/Regression_test_authoring
https://manager.pgxn.org/howto
https://www.2ndquadrant.com/en/blog/using-postgresql-tap-framework-extensions/
https://www.2ndquadrant.com/en/blog/a-convenient-way-to-launch-psql-against-postgres-while-running-pg_regress/
http://big-elephants.com/2015-10/writing-postgres-extensions-part-i/

-->