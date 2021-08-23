---
title: "De L Interet Des Fonctions Sql"
categories: []
tags: []
date: 2021-08-18
draft: true
---

<!--

* il n'y a pas que le pl/pgsql
https://www.postgresql.org/docs/devel/xfunc-sql.html

* différence procédure et fonction 
gestion des transactions COMMIT ROLLBACK
CALL vs. SELECT / PERFORM

* sql-standard body
Dependencies between the function and the objects it uses are fully tracked.
https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=e717a9a18b2e34c9c40e5259ad4d31cd7e420750

* simplifier la vie de l'optimiseur
set-returning function https://www.postgresql.org/docs/devel/functions-srf.html
execution_cost https://www.postgresql.org/docs/devel/sql-createfunction.html

* mode d'une fonction
immutable pour l'indexation
stable pour la lecture seule
volatile pour le reste

-->