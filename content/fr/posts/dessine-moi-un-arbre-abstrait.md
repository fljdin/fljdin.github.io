---
title: "Dessine-moi un arbre (abstrait)"
translationKey: draw-me-a-abstract-tree
slug: dessine-moi-un-arbre-abstrait
categories: [postgresql]
tags: [developpement]
date: 2022-06-28
draft: true
---

> L'étape d'analyse crée un arbre d'analyse qui n'utilise que les règles fixes 
> de la structure syntaxique de SQL. Il ne fait aucune recherche dans les 
> catalogues système. Il n'y a donc aucune possibilité de comprendre la sémantique
> détaillée des opérations demandées.
> 
> (Documentation : [Processus de transformation][1])

[1]: https://docs.postgresql.fr/14/parser-stage.html#id-1.10.3.6.4

Que se passe-t-il entre l'instant où une requête SQL est soumise par l'utilisateur
et l'envoi du résultat sous forme de lignes par le serveur PostgreSQL ? Cette 
question passionnante (pour une poignée de personnes, ne nous le cachons pas) a
été étudiée par Stefan Simkovics durant [sa thèse][2] pour l'université de 
technologie de Vienne en 1998.

Ces travaux ont notamment permis d'enrichir la [documentation officielle][3] avec
le chapitre « Présentation des mécanismes internes de PostgreSQL », qui reprend
assez largement les observations de Simkovics de manière simplifiée pour en
faciliter l'accès au plus grand nombre. 

Dans cet article, je souhaite présenter de récentes découvertes sur l'une de ces 
phases internes, l'étape d'analyse, qui permet de manipuler une requête SQL sous 
une forme d'arbre et qui respecte un pattern de développement avancé nommé [AST][4]
(_abstract syntax tree_).

[2]: https://archive.org/details/Enhancement_of_the_ANSI_SQL_Implementation_of_PostgreSQL/
[3]: https://docs.postgresql.fr/14/overview.html
[4]: https://fr.wikipedia.org/wiki/Arbre_de_la_syntaxe_abstraite

<!--more-->

---

## Du code à la machine

Exprimer une instruction sous forme de mots comme le propose le langage SQL
implique que le moteur responsable du traitement de ladite instruction soit
capable de l'interpréter. Une analogie très simple peut être faite avec le
langage commun, où des règles de grammaire fixent l'ordre des adjectifs, noms 
et pronoms pour que deux interlocuteurs puissent s'exprimer et se comprendre.

En informatique, ce processus s'appelle la [compilation][5] et fait le lien entre
les instructions du code source et leurs opérations équivalentes soumise à la
machine qui exécutera le code compilé. Depuis l'aube du numérique, une poignée
de logiciels sont chargés d'analyser les instructions, que l'on pourra distinguer
en plusieurs familles :

[5]: https://fr.wikipedia.org/wiki/Compilateur

* L'[analyse lexicale][6] prend en charge la détection des mots-clés ou _lexème_,
  ainsi que les espacements ou les blocs de commentaires. Les analyseurs
  lexicaux (_scanners_) les plus connus sont [Lex][7] et [Flex][8] (la version
  GNU de Lex) ;
* L'[analyse syntaxique][9] énonce les règles qui permet de rattacher les lexèmes
  avec des relations de dépendances, que l'on nomme _syntagmes_, afin d'en sortir
  une représentation de l'instruction sous forme d'arbre d'analyse. Les analyseurs
  syntaxiques (_parsers_) sont fréquemment [Yacc][10] et [Bison][11] (la version
  GNU de Yacc) ;
* L'[analyse sémantique][12] s'assure que les éléments définis par les étapes 
  précédentes soient suffisamment complets et contrôle le bon usage des lexèmes
  dans leur contexte (déclaration de variable, correspondance de type lors d'une 
  affectation, etc.)

[6]: https://fr.wikipedia.org/wiki/Analyse_lexicale
[7]: https://fr.wikipedia.org/wiki/Lex_(logiciel)
[8]: https://fr.wikipedia.org/wiki/Flex_(logiciel)
[9]: https://fr.wikipedia.org/wiki/Analyse_syntaxique
[10]: https://fr.wikipedia.org/wiki/Yacc_(logiciel)
[11]: https://fr.wikipedia.org/wiki/GNU_Bison
[12]: https://fr.wikipedia.org/wiki/Analyse_s%C3%A9mantique

Cet enchainement d'étapes est scrupuleusement implémentée dans PostgreSQL 
lorsqu'il s'agit d'interpréter une requête SQL soumise par un utilisateur. Le
rapport de thèse de Simkovics prend en exemple la requête suivante :

```sql
SELECT s.sname, se.pno
  FROM supplier s, sells se
 WHERE s.sno > 2 AND s.sno = se.sno;
```

L'étape d'analyse ou _parsing_ va donc découper chaque mot de l'instruction et
les regrouper en lexèmes (mots-clé du langage, identifiants, opérateurs, 
littéraux). Dès qu'une erreur de syntaxe est rencontrée, comme une virgule juste
avec le mot-clé `FROM`, le traitement de la requête est interrompu et un message
d'erreur explicite est retourné à l'utilisateur :

```text
ERROR:  syntax error at or near "FROM"
LINE 2:   FROM supplier s, sells se
```

Dans le cas où la requête est syntaxiquement correcte, l'arbre d'analyse est 
consolidé en mémoire pour lier les lexèmes selon les règles de grammaire du
langage. Ainsi, les tables de la clause `FROM` sont rattachées en tant que nœuds
`RangeVar` à l'attribut `fromClause` de nœud principal `SelectStmt`. Il en va de
même pour la représentation des colonnes et de la clause `WHERE` de la requête
à travers les nœuds `targetList` et `whereClause` respectivement.

![Représentation d'un arbre d'analyse](/img/fr/query-tree-representation.png)

Cet arbre est ensuite transformé par une nouvelle étape de réécriture, chargée
de réaliser des optimisations entre les nœuds et retirer les branches superflues.
Entre alors en scène deux autres mécanismes, à savoir l'**optimiseur** (_planner_)
et l'**exécuteur** (_executor_), que je n'aborderais pas dans cet article, qui
consommeront l'arbre ainsi finalisé pour construire le résultat de données à
transmettre à l'utilisateur.

---

## Reconstruire un arbre abstrait

J'ai récemment écrit des requêtes SQL dynamiques dans le cadre d'un projet PL/pgSQL.
Cette pratique est assez courante, il s'agit d'accoler plusieurs bouts d'expressions
pour écrire une requête SQL dont les parties (colonnes, tables, conditions) peuvent
varier. Voici en substance, le prototype de ce code :

<!--
create table config (name text, value text);
insert into config values 
  ('column_name', 'name'),
  ('column_name', 'value'),
  ('table_name', 'config');
-->

```sql
DO $prototype$
DECLARE
  r record;
  v_columns text;
  v_tabname text;
  v_values text := $$ 1, 'test' $$;
BEGIN
  SELECT value INTO v_tabname
    FROM config WHERE name = 'table_name';

  SELECT string_agg(value, ',') INTO v_columns
    FROM config WHERE name = 'column_name';

  EXECUTE format(
    'INSERT INTO %s (%s) VALUES (%s);',
    v_tabname, v_columns, v_values
  );
END;
$prototype$;
```

Ici, le contenu de la table `config` est déterminant pour que ce code construise
une requête `INSERT` syntaxiquement correcte. De plus, dans l'éventualité plus que
probable où la fonctionnalité ait besoin de s'enrichir, ledit code se complexifie
et rencontrera très certainement des difficultés de maintenances et d'évolution.

Parlant à l'un de mes [collègues][13] des complications évidentes que j'allais 
rencontrer dans mon développement, ce dernier m'oriente vers un pattern plus
avancé pour rendre le code plus modulable à l'aide d'une abstraction supplémentaire,
le susnommé **AST**. Cette méthode repose intégralement sur la représentation en
arbre d'un objet complexe qu'il devient possible de manipuler et de modeler
librement.

[13]: https://github.com/dlax

Dans le cas de mon exemple, il s'agissait de : 

* Construire la requête SQL sous la forme d'un arbre syntaxique ;
* Rendre à la requête sa forme textuelle pour l'exécuter sans faute lexicale ni
  syntaxique.

Dans les semaines qui suivirent, la [solution][14] se présentait à moi avec 
l'extension `postgres-ast-deparser`, dédiée à la construction d'arbres d'analyse
et la réécriture au format SQL de la requête (_deparsing_). Après quelques échanges
avec son contributeur Dan Lynch, je me suis servi d'une des nombreuses méthode 
pour simplifier mon prototype.

[14]: https://twitter.com/fljdin/status/1538972129156337666
[15]: https://github.com/pyramation/postgres-ast-deparser

```sql
DO $prototype$
DECLARE
  v_relation jsonb;
  v_columns jsonb;
  v_values jsonb := to_jsonb(ARRAY[ARRAY[
    ast.a_const(v_val := ast.integer(1)),
    ast.a_const(v_val := ast.string('test'))
  ]]);
BEGIN
  SELECT ast_helpers.range_var(
      v_schemaname := 'public', 
      v_relname := value) INTO v_relation
    FROM config WHERE name = 'table_name';

  SELECT jsonb_agg(ast.res_target(
      v_name := value)) INTO v_columns
    FROM config WHERE name = 'column_name';

  RAISE NOTICE '%', deparser.expression(ast.insert_stmt(
    v_relation := v_relation,
    v_cols := v_columns,
    v_selectStmt := ast.select_stmt(
      v_valuesLists := v_values,
      v_op := 'SETOP_NONE'
    )
  )) FROM config WHERE name = 'table_name';
END;
$prototype$;
```

<!--

https://pganalyze.com/blog/parse-postgresql-queries-in-ruby
https://github.com/pganalyze/libpg_query
https://github.com/pganalyze/pg_query
https://twitter.com/pyramation/status/1526241931704950784

-->

---

## Conclusion