---
layout: post
title: "La boîte à outils du DBA"
date: 2019-06-24 12:00:00 +0100
tags: dba
---

J'aimerais qu'on s'arrête un instant sur un aspect méconnu du travail de DBA.

L'inestimable fichier qui contient la totalité des requêtes SQL indispensables à la survie (et crédibilité) du susnommé et qui ne le quitte jamais.

Vous savez ? Ce fichier qui se passe de main en main, qu'on alimente de missions en missions, selon les demandes ou les incidents rencontrés au cours d'une vie longue et palpitante. Ce fichier, que même l'Internet entier ne pourra remplacer car il s'est avéré être la mémoire, le trésor de l'administrateur lorsqu'il en a le plus besoin. Sans lui, c'est comme s'il se retrouvait nu dans l'arène.

Accrochez-vous, j'ai encore beaucoup de choses à dire à son sujet !
<!--more-->

Je me souviens de mes débuts de DBA lorsque je travaillais en binôme ou en équipe avec des expérimentés du métier, où l'on se demandait sans cesse : «&nbsp;Tu n'aurais pas une requête pour extraire la taille des tables ?&nbsp;» ou alors «&nbsp;Comment tu fais pour obtenir l'état de la réplication sur un Dataguard ?&nbsp;». La réponse évidente qui viendrait à l'esprit de n'importe quel professionnel de l'IT, et notamment les développeurs, serait «&nbsp;Recherche sur Google !&nbsp;» ou, sa variante en 2019 : «&nbsp;C'est certainement sur StackOverflow.&nbsp;» Mais non, entre DBA, on s'échange des requêtes SQL comme on se raconte des histoires.

C'est volontairement caricatural, et notre beau métier ne s'arrête pas à fournir une requête SQL dans chaque situation, mais c'est une dérive fréquente. Comment en est-on arrivé là ?

L'administration d'un produit requiert une API (application programming interface) ou une CLI (command line interface) pour questionner l'état du système, ses métriques ou sa configuration. Interragir sur un serveur *nix nécessite pour tout néophyte d'appréhender les commandes _shell_ usuelles ; idem pour un administrateur réseau avec les équipements. En ce qui nous concerne dans cet article, c'est le langage SQL permettant la projection de données stockées dans une base au format tableau ; ainsi, une application ou un être humain peut consolider les réponses à ses questions à l'aide d'une syntaxe universelle et commune à toutes les bases de données relationnelles (_exit_ le NoSQL).

Très bien, c'est universel. Le langage est donc le même entre le moteur MySQL et SQL Server ? Et bien oui. Mais aucun ne partage le même fonctionnement et l'on distingue dès lors un référentiel (ou catalogue) propre à chaque moteur. Ce référentiel est l'élément central, il contient nos fameuses données systèmes : les métriques et la configuration.

Et c'est là que ça se complique. ☺

Selon le besoin exprimé, il y aura donc une requête SQL adaptée à un moteur exclusif. Prenons l'exemple de la taille de notre base de données, dans sa forme la plus simple.

| Moteur      | Requête |
| ----------- | ------- |
| Oracle      | `SELECT SUM(bytes) AS size FROM dba_data_files;` |
| PostgreSQL  | `SELECT SUM(pg_database_size(datname)) AS size FROM pg_database;` |
| SQL Server  | `SELECT SUM(size) AS size FROM sys.master_files;` |
| MySQL       | `SELECT SUM(data_length + index_length) AS size FROM information_schema.tables;` |

À moins de connaître par cœur les tables du catalogue et leur constitution, l'interpellé se retrouve très vite sur son moteur de recherche favori. Je vous mets donc à contribution un instant, et vous encourage à trouver par vous-même la requête permettant d'afficher l'espace occupé et l'espace disponible dans une base Oracle, puis de vous rendre compte que son équivalent sous PostgreSQL est beaucoup moins évident.

Blogs, wiki, espaces communautaires, StackOverflow, Github... Fort d'une patience admirable et après trois-quatre découvertes passablement hors-sujet, le DBA finit invariablement par adapter une des innombrables requêtes pour se l'approprier avant de l'intégrer dans sa boîte à outils personnelle.

C'est à partir de cet instant que j'essaie d'être pragmatique. Pourquoi ne pas avoir une collection commune et participative de requêtes, correctement indexée sur les moteurs de recherche, afin de faire gagner du temps au plus grand nombre ?

Certains l'ont fait.[^1] [^2]

Bien que ce soit exemplaire, ce n'est malheuresement ni suffisant, ni efficient. Trouver les sessions bloquantes et les sessions bloquées ? Onglet Oracle, page avec le logo carré, lien du bas pour les performances, ctrl+F «&nbsp;verrou&nbsp;», quatrième bloc de code, copier/coller. 

J'insiste et je caricature. Mais il m'est véritablement arrivé de procéder ainsi sur un wiki d'entreprise, lorsque les collègues rangeaient leurs scripts dans un dédale de pages. Nous pourrions également parler de la variante au format texte : Dossier script, Oracle, version 9i, numéro 115, verrou.sql, copier/coller. J'épargnerai à l'auditoire la version fichier Excel qui m'ait été donné de rencontrer dans ma carrière.

---

L'histoire pourrait s'en arrêter là et l'on pourrait me rétorquer «&nbsp;L'essentiel, c'est le résultat&nbsp;», mais on se retrouve confronter à des délais de réponses variables d'un DBA à un autre, où même le plus expérimenté pourrait perdre un temps considérable à identifier la requête la plus appropriée à la demande et la retrouver dans son extension de mémoire, sa fameuse boîte à outils.

Moi-même, je ne suis pas parfait ; dans un soucis d'efficacité et de productivité, j'ai observé mes propres dérives dans la gestion de mes requêtes, glannées sur l'Internet ou les wiki d'entreprises. Qu'aurions-nous besoin pour accélérer notre recherche et assurer l'ajout permanent de nouvelles requêtes ?

Liste exhaustive pour ma part :

- Stockage externalisé et disponible, synchronisation avec GitHub
- Indexation des mots-clés ou d'une méta-description
- Copier en un clic (_copy to clipboard_)
- Éditeur intégré
- Colorisation syntaxique

À cette époque, et très naturellement, je me suis mis à stocker mes propres _snippets_ (le mot est lâché !) dans Github avec la très appréciable gestion des _gists_[^3]. L'interface, quoique sobre et fonctionnelle, ne permet pas la recherche dans son propre inventaire. Il existe plusieurs solutions tierces, avec des usages bien différents.

- client web avec offre payante : [cacher.io](https://www.cacher.io/)
- open-source, client lourd : [Lepton](https://hackjutsu.com/Lepton/)
- client web, gratuit, blockchain: [DECS](https://app.decs.xyz/)

J'utile à ce jour la version gratuite de _Cacher_ pour toutes les raisons exprimées plus haut, l'expérience est très complète et les fonctionnalités de bases très suffisantes. Anciennement nommé GistBox, ce service de snippets se synchronise très rapidement avec son propre compte GitHub et me permet en quelques mots clés d'identifier les gists le plus pertinents dans une interface agréable.

Cependant, l'outil n'est pas open-source et propose des limitations pour un usage gratuit (pas de label, pas de gists privés, peu d'extensions IDE et non adapté au contexte d'équipes en entreprise). J'ai donc cherché d'autres alternatives, avec notamment Lepton[^4] qui propose la même navigation et les mêmes fonctionnalités, en mode client lourd basé sur le framework Node.js Electron[^5], et donc compatible avec Linux et Windows. 

La deuxième alternative, que je n'ai pas encore testé, repose sur le réseau décentralisé de blockchain Blockstack[^6] (open-source quant à lui, je ferai volontiers un retour sur cette technologie à l'avenir).

---

A travers cet article, je voulais proposer une autre lecture du métier du DBA, tout en conseillant vivement une prise de conscience sur les tâches qui nous font perdre du temps et de la productivité au quotidien.

J'invite tous les DBA, notamment s'ils se sont reconnus dans la caricature que j'ai dépeint, à admettre que nos habitudes du passé peuvent nous rendre la vie dure. Nous avons la chance, aujourd'hui, de disposer de l'outil Internet à tout moment et dans toutes les situations de production alors, pourquoi s'en priver ?

[^1]: https://oracle-base.com/dba/scripts
[^2]: https://wiki.postgresql.org/wiki/Category:Snippets
[^3]: https://gist.github.com/fljdin
[^4]: https://github.com/hackjutsu/Lepton
[^5]: https://electronjs.org/
[^6]: https://blockstack.org/