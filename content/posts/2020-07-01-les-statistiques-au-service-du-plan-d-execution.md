---
layout: post
title: "Les statistiques au service du plan d'exécution"
tags: [postgresql,maintenance,performance]
date: 2020-07-01 20:30:00 +0200
---

La lecture d'un plan d'exécution fait partie des meilleures armes du développeur et de l'administrateur de bases de données pour identifier les problèmes de performances. Dans [un précédent article](/2019/09/27/index-decomplexe), je présentais l'intérêt de positionner un index sur les colonnes d'une table pour faciliter les recherches, notamment avec l'aide de la commande `EXPLAIN`.

À cette époque, je ne m'étais pas attardé sur la notion des statistiques de données, que l'on retrouve dans la plupart des moteurs du marché. Voyons de plus près ce que propose PostgreSQL pour garantir les performances de vos requêtes.

<!--more-->

---

## Estimer ou ne pas estimer

Une statistique de données résulte d'un calcul en arrière plan sur tout ou partie des données d'une table. Il peut s'agir de la quantité de lignes, du nombre distinct de valeurs dans une colonne, ou bien encore de la **distribution** des valeurs sous forme d'histogramme. Ainsi, pour chaque table et chaque colonne, il existe des données supplémentaires qui permettent au moteur d'avoir une juste **estimation** des données qu'il s'apprête à manipuler.

Prenons la table `pgbench_history` sur laquelle j'ai ajouté un index pour la colonne `aid`. Quel plan nous propose le moteur pour récupérer toutes les lignes dont la valeur `aid` est inférieure à 1 000 ?

```sql
EXPLAIN SELECT * FROM pgbench_history WHERE aid < 1000;
```
```text
                      QUERY PLAN
--------------------------------------------------------
 Bitmap Heap Scan on pgbench_history
 (cost=4.34..11.79 rows=9 width=116)
   Recheck Cond: (aid < 1000)
   ->  Bitmap Index Scan on pgbench_history_aid_idx  
       (cost=0.00..4.34 rows=9 width=0)
         Index Cond: (aid < 1000)
```

Le résultat qui s'affiche correspond au meilleur plan connu et repose sur un système de coût d'accès aux lignes. Le plan présentant le coût le plus faible est considéré comme le *meilleur* plan ; l'ensemble des nœuds le composant sera donc respecté pour récupérer le résultat final. Dans le cas de notre requête, le moteur estime que les opérations `Bitmap Index` et `Bitmap Heap` sont les moins coûteuses en performance.

Comment le moteur peut-il être certain que ce plan est le moins coûteux ? Comparons son coût d'accès total (ici `11.79`) avec un autre plan pour lequel nous interdisons l'usage de l'index.

```sql
SET enable_bitmapscan = off;
EXPLAIN SELECT * FROM pgbench_history WHERE aid < 1000;
```
```text
                            QUERY PLAN
------------------------------------------------------------------
 Seq Scan on pgbench_history  (cost=0.00..19.50 rows=9 width=116)
   Filter: (aid < 1000)
```

Le coût de lecture complète de la table (nœud `Seq Scan`) vaut `19.50`, ce qui est supérieur au plan précédent. Lorsque l'on exécute un requête SQL, une partie du moteur, appelé le planificateur consolide en arrière plan une petite quantité de plans avant de ne retourner que le meilleur. Plusieurs paramètres[^1] comme `enable_bitmapscan`, peuvent changer complètement le comportement du planificateur en réduisant le nombre de choix possibles dans l'élaboration de ses plans.

En complément du coût, la commande `EXPLAIN` indique également l'estimation du nombre de lignes que retourneront les nœuds. Dans le cas des deux plans, le planificateur _estime_ qu'il existe 9 lignes répondant au critère de recherche. Cette _statistique_ peut être déduite des vues système `pg_class` et `pg_stats`.

```sql
SELECT s.*, c.relpages, c.reltuples
  FROM pg_stats s JOIN pg_class c ON s.tablename = c.relname
 WHERE tablename = 'pgbench_history' AND attname = 'aid' \gx
```
```text
-[ RECORD 1 ]----------+------------------------------------
schemaname             | public
tablename              | pgbench_history
attname                | aid
inherited              | f
null_frac              | 0
avg_width              | 4
n_distinct             | -0.997
most_common_vals       | {66403,80979,82766}
most_common_freqs      | {0.002,0.002,0.002}
histogram_bounds       | {75,973,1755,… ,98037,98999,99991}
correlation            | 0.047431067
most_common_elems      | 
most_common_elem_freqs | 
elem_count_histogram   | 
relpages               | 7
reltuples              | 1000
```

Sans même consulter le contenu de la table `pgbench_history`, nous sommes en possession d'informations intéressantes. Nous apprenons que la table contient exactement 1 000 lignes (_reltuples_) et que la colonne `aid` présente un nombre de valeurs distinctes (_n\_distinct_) qui tend vers `-1`, c'est-à-dire autant de valeurs uniques que de lignes dans la table.

La distribution des valeurs de la colonne `aid` est représentée par le tableau `histogram_bounds` de 100 éléments[^2]. Ces bornes divisent approximativement les valeurs dans des groupes de même taille ; comprendre que 1 % des lignes ont une valeur de colonne `aid` comprise entre 75 et 972, 1 % des lignes, entre 973 et 1 754, etc. On peut dès lors supposer que les valeurs possibles de la colonne `aid` s'étendent de 75 à 99 991.

Si l'on revient à notre critère de recherche, les lignes dont la valeur `aid` est inférieure à 1 000 représenteraient un peu plus de 1 % des 1000 lignes de la table, soit environ 10 lignes si toutes les valeurs étaient distinctes. L'estimation de 9 lignes proposée par la commande `EXPLAIN` serait donc juste.

<div class="message">La documentation du projet détaille en profondeur le calcul de ces estimations avec de nombreux exemples : <i><a href="https://www.postgresql.org/docs/12/row-estimation-examples.html">How the Planner Uses Statistics: Row Estimation Examples</a></i>.</div>

[^1]: https://www.postgresql.org/docs/12/runtime-config-query.html
[^2]: https://postgresqlco.nf/en/doc/param/default_statistics_target/

---

Tout l'intérêt des statistiques est donc d'apporter suffisamment d'éléments précalculés et économes en espace disque pour que le planificateur puisse faire des estimations les plus justes possibles. Dès lors qu'une estimation est calculée, le choix du plan d'exécution le moins coûteux devient évident. Retenons que le meilleur plan **doit être** le moins coûteux en ressources et donc, le plus optimisé pour la requête SQL.

Qu'advient-il de notre plan si, par erreur ou hasard, les statistiques étaient erronées ou venaient à disparaître pour la colonne `aid` ?

```sql
DELETE FROM pg_statistic s
 WHERE starelid = 'pgbench_history'::regclass AND staattnum = (
   SELECT attnum FROM pg_attribute 
    WHERE attrelid = s.starelid AND attname = 'aid'
 );

RESET enable_bitmapscan;
EXPLAIN SELECT * FROM pgbench_history WHERE aid < 1000;
```
```text
                             QUERY PLAN                             
--------------------------------------------------------------------
 Seq Scan on pgbench_history  (cost=0.00..19.50 rows=333 width=116)
   Filter: (aid < 1000)
```

On constate qu'en l'absence de statistiques sur le critère de sélection, le plan `Bitmap` n'est plus le moins coûteux et n'est donc plus proposé par le planificateur. Le moteur privilégera la lecture complète de la table (`Seq Scan`) dont le coût est invariant.

```sql
SET enable_seqscan = off;
EXPLAIN SELECT * FROM pgbench_history WHERE aid < 1000;
```
```text
                      QUERY PLAN
--------------------------------------------------------
 Bitmap Heap Scan on pgbench_history
 (cost=10.86..22.02 rows=333 width=116)
   Recheck Cond: (aid < 1000)
   ->  Bitmap Index Scan on pgbench_history_aid_idx
       (cost=0.00..10.77 rows=333 width=0)
         Index Cond: (aid < 1000)
```

L'estimation de lignes retournées peut paraître surprenante ! Il s'agit d'un calcul arbitraire défini dans la classe `selfuncs.h`[^3] avec notamment un facteur de sélectivité qui s'applique sur le nombre total de lignes présentes dans la table. Ainsi, pour un critère d'égalité, ce facteur vaudra 0.5 % (`DEFAULT_EQ_SEL=0.005`) alors qu'une comparaison de non-égalité comme celle de notre exemple, vaudra 33.33 % (`DEFAULT_INEQ_SEL=0.3333333333333333`).

Puisque le planificateur estime devoir parcourir 333 entrées dans l'index à défaut de meilleure estimation, le coût total de ce plan est surévalué à `22.02`, au lieu de `11.79` auparavant.

[^3]: https://doxygen.postgresql.org/selfuncs_8h.html#define-members

---

## Collecte automatique des statistiques

Bien entendu, supprimer des statistiques n'est pas une bonne pratique et ne devrait pas être envisagé pour « changer le comportement » du planificateur. Depuis la version 8.3 de PostgreSQL, il n'y a même plus trop de raison de s'inquiéter de l'absence ou de la fraîcheur des statistiques associées à chaque colonne de vos tables : le processus `autovacuum`[^4] (désactivé en 8.1 et 8.2) se charge, entre autres fonctions, de parcourir régulièrement les tables de vos bases pour collecter et consolider la table `pg_statistic`. Il se porte ainsi garant de la pertinence des plans d'exécution.

En réalité, ce processus _observe_ les variations de volumétrie des tables avant de déclencher l'opération `ANALYZE` par un processus de maintenance pour cette table. Ce mécanisme est bien plus pertinent et optimisé qu'une exécution à intervale régulier pour calculer arbitrairement les statistiques de la base.

Le seuil de déclenchement[^5] de l'_autoanalyze_ est obtenu à l'aide d'un calcul trivial impliquant deux paramètres globaux que l'on peut surcharger, `autovacuum_analyze_threshold = 50` et `autovacuum_analyze_scale_factor = 0.1`.

```text
analyze threshold = analyze base threshold + 
                    analyze scale factor * number of tuples
```

Prenons l'exemple de la table `pgbench_accounts` qui contient un million de lignes avec une contrainte de clé primaire sur la colonne `aid`. La vue système `pg_stat_user_tables` dispose d'informations complémentaires à celles des statistiques, notamment la colonne `n_mod_since_analyze` qui indique la quantité de tuples ayant été modifiés depuis la dernière opération de collecte `ANALYZE`. Voyons son contenu après la modification d'une portion de lignes.

```sql
UPDATE pgbench_accounts SET filler = '' WHERE aid <= 10000;
-- UPDATE 10000

SELECT relname, last_autoanalyze, n_live_tup, n_mod_since_analyze 
  FROM pg_stat_user_tables u
 WHERE relname = 'pgbench_accounts' \gx
```
```text
-[ RECORD 1 ]-------+------------------------------
relname             | pgbench_accounts
last_autoanalyze    | 2020-06-18 15:12:55.224493+02
n_live_tup          | 1000000
n_mod_since_analyze | 10000
```

Ici, seul 1 % de la table a subi un changement et le mécanisme de collecte automatique des statistiques semble ne pas s'être déclenché. En effet, le seuil de déclenchement pour cette table serait plutôt de 100 050 lignes (`50 + 0.1 * 1000000`). Recommençons avec un plus large échantillon et observons les traces d'activité du processus `autovacuum`.

```sql
ALTER SYSTEM SET log_min_messages = debug2;
ALTER SYSTEM SET log_autovacuum_min_duration = 0;
SELECT pg_reload_conf();

UPDATE pgbench_accounts SET filler = '' WHERE aid <= 90051;
-- UPDATE 90051

SELECT relname, last_autoanalyze, n_live_tup, n_mod_since_analyze 
  FROM pg_stat_user_tables u
 WHERE relname = 'pgbench_accounts' \gx
```
```text
-[ RECORD 1 ]-------+------------------------------
relname             | pgbench_accounts
last_autoanalyze    | 2020-06-30 17:44:22.424363+02
n_live_tup          | 1000000
n_mod_since_analyze | 0
```

Comme attendu, un traitement `ANALYZE` s'est exécuté et a mis à jour les données de la vue `pg_stat_user_tables`, mettant à zéro la colonne `n_mod_since_analyze` jusqu'au prochain déclenchement. Côté trace d'activité, le mode `debug2` écrit une série d'événements tels que les seuils calculés de la table, le démarrage et la fin du traitement par le _worker_ dédié.

```r
DEBUG:  autovacuum: processing database "demo"
DEBUG:  pgbench_accounts: vac: 100051 (threshold 200050), 
                          anl: 100051 (threshold 100050)
DEBUG:  analyzing "public.pgbench_accounts"
LOG:  automatic analyze of table "demo.public.pgbench_accounts" 
      system usage: CPU: user: 0.09 s, system: 0.00 s, elapsed: 0.25 s
```

[^4]: https://www.postgresql.org/docs/8.3/runtime-config-autovacuum.html
[^5]: https://www.postgresql.org/docs/12/routine-vacuuming.html#AUTOVACUUM

---

## Estimer la prochaine heure de la collecte

Dans la plupart des cas, les paramètres associés au mécanisme d'_autovacuum_ sont adaptés à la plupart des tables et assurent une fréquence correcte du calcul des statistiques. Cependant, au-delà d'une certaine volumétrie, une table peut présenter des incohérences entre son contenu et ses statistiques.

La modification de 10 % de la table `pgbench_accounts` pourrait prendre des jours voire des semaines avant que ne survienne le traitement _autoanalyze_. Il est donc de la responsabilité du développeur ou du DBA de surveiller l'accroissement de l'indicateur `n_mod_since_analyze` pour éviter que les statistiques ne soient trop décorrélées du contenu.

Pour s'en assurer, je crée deux fonctions dans ma base pour récupérer respectivement les options de stockage d'une table (`reloptions`) ou à défaut, les paramètres d'instance, ainsi que le calcul du seuil de déclenchement sur la base de la formule précédente. La seconde fonction s'assure notamment que le mécanisme de collecte automatique n'est pas désactivé (`autovacuum_enabled = off`).

```sql
CREATE OR REPLACE FUNCTION get_reloption(reloptions text[], name text)
RETURNS text LANGUAGE sql
AS $$
  SELECT coalesce(min(option_value), current_setting(name))
    FROM pg_options_to_table(reloptions) WHERE option_name = name;
$$;

CREATE OR REPLACE FUNCTION get_anl_threshold(o oid)
RETURNS float LANGUAGE sql
AS $$
  SELECT get_reloption(reloptions, 'autovacuum_analyze_threshold')::int + 
         get_reloption(reloptions, 'autovacuum_analyze_scale_factor')::float *
            pg_stat_get_live_tuples(oid)
    FROM pg_class c
   WHERE oid = o AND NOT EXISTS (
     SELECT 1 FROM pg_options_to_table(c.reloptions)
      WHERE option_name = 'autovacuum_enabled' AND option_value = 'off'
    )
$$;
```

Avec les résultats de ces fonctions, je peux construire une requête plus évoluée qui estime l'heure du prochain déclenchement en fonction de nombre de modification et de la dernière collecte.

```sql
SELECT relname, n_live_tup, n_mod_since_analyze,
    get_anl_threshold(relid) threshold, last_autoanalyze,
    current_timestamp + 
      (1 - 
        CASE WHEN n_mod_since_analyze = 0 THEN null
             WHEN n_mod_since_analyze > get_anl_threshold(relid) THEN 1
             ELSE n_mod_since_analyze / get_anl_threshold(relid) END) *
      (current_timestamp - last_autoanalyze) next_autoanalyze
FROM pg_stat_user_tables WHERE relname = 'pgbench_accounts' \gx
```
```text
-[ RECORD 1 ]--------+------------------------------
relname              | pgbench_accounts
n_live_tup           | 1000000
n_mod_since_analyze  | 0
threshold            | 100050
last_autoanalyze     | 2020-07-01 15:07:40.134444+02
next_autoanalyze     | 
```
```sql
UPDATE pgbench_accounts SET filler = '' WHERE aid <= 25000;
-- UPDATE 25000
```
```text
-[ RECORD 1 ]--------+------------------------------
relname              | pgbench_accounts
n_live_tup           | 1000000
n_mod_since_analyze  | 25000
threshold            | 100050
last_autoanalyze     | 2020-07-01 15:07:40.134444+02
next_autoanalyze     | 2020-07-01 18:16:43.734491+02
```

La commande `ALTER TABLE` suivante permet de modifier les options de stockage de la table, et d'ajuster le seuil du déclenchement automatique de la collecte. À vous de voir si l'activité sur votre table le justifie !

```sql
ALTER TABLE pgbench_accounts SET (
  autovacuum_analyze_scale_factor = 0.01, 
  autovacuum_analyze_threshold = 0
);
```
```text
-[ RECORD 1 ]--------+------------------------------
relname              | pgbench_accounts
n_live_tup           | 1000000
n_mod_since_analyze  | 25000
threshold            | 10000
last_autoanalyze     | 2020-07-01 15:07:40.134444+02
next_autoanalyze     | 2020-07-01 17:04:34.038917+02

-[ RECORD 1 ]--------+------------------------------
relname              | pgbench_accounts
n_live_tup           | 1000000
n_mod_since_analyze  | 0
threshold            | 10000
last_autoanalyze     | 2020-07-01 17:04:41.987032+02
next_autoanalyze     | 
```

---

## Conclusion

Les statistiques jouent un rôle essentiel dans les performances d'un moteur relationnel comme PostgreSQL. Réussir à les maintenir pertinentes est la clé dans la gestion au quotidien du système. Avec mon exposé, j'espère vous avoir démontré qu'il n'est pas nécessaire de rafraîchir toutes les statistiques, mais seulement celles dont le seuil n'est plus adapté.

Dans un genre similaire, un [récent article] de Hubert « depesz » Lubaczewski présente une série de requêtes permettant d'identifier les tables nécessitant une action de maintenance (`vacuum` ou `analyze`) dans le cas où la routine automatique ne fait pas correctement son travail. Ce genre de petites astuces peuvent sauver des vies… (euh) des plans d'exécution !

[récent article]: https://www.depesz.com/2020/01/29/which-tables-should-be-auto-vacuumed-or-auto-analyzed/