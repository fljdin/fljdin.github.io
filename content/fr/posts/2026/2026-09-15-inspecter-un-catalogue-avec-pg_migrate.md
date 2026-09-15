---
title: "Inspecter un catalogue avec pg_migrate"
categories: [postgresql, pg_migrate]
tags: [migration]
date: "2026-09-15 16:00:00 +0200"
---

Au cours des dernières années, je me suis engagé à identifier les atouts et
faiblesses d’outils dédiés à la migration vers PostgreSQL. Plusieurs articles
[publiés par mes soins][1] ont pavé le chemin vers une direction ambitieuse que
j’entreprends depuis 2024 avec mes collègues [Étienne Bersac][bersace] et
[Pierre-Louis Gonon][pirlgon].

[1]: /tags/migration/
[bersace]: https://bersace.cae.li/
[pirlgon]: https://gitlab.com/pirlgon

… Et la version stable 1.0 de PostgreSQL Migrator est [sortie le 4 septembre
dernier][2]. L’occasion de présenter des fonctionnalités que j’utilise au
quotidien et ce qu’elles apportent par rapport aux autres outils. Dans cet
article, je souhaite m’attarder sur l’une d’entre elles, particulièrement
précieuse pour préparer une migration : le **catalogue hors-ligne**.

[2]: https://www.postgresql.org/about/news/postgresql-migrator-10-first-stable-release-3377/

<!--more-->

---

## Consulter le catalogue Oracle

Le catalogue d’une base de données relationnelle renferme la structure du
modèle, les noms et le typage des colonnes d’une table, les options de
contraintes, la définition d’une vue ou d’une fonction, etc. Tout ce qui est
déclaré par l’utilisateur avec du DDL (_Data Definition Language_) est maintenu
dans un catalogue comme unique source de vérité.

Sur les systèmes comme PostgreSQL, MySQL ou MSSQL Server, la norme encourage
l’utilisation d’un catalogue universel, l’espace `information_schema`. Par
exemple, on peut y questionner les noms des tables avec la même requête :

```sql
SELECT table_name FROM information_schema.tables 
 WHERE table_schema = 'scott'
 ORDER BY table_name;
```

Cependant, ce n’est pas la solution idéale pour reconstruire un modèle de
données. Chacun des systèmes se conforment au mieux à la norme SQL mais très
fréquemment, ils l’enrichissent avec des extensions du langage ou prennent des
libertés sur l’implémentation d’une fonctionnalité. Il en résulte que le
catalogue `information_schema` n’est pas la source universelle, à peine une
collection d’alias dans un catalogue système propre à chacun.

À présent, parlons d’Oracle et d’Ora2Pg. Si nous souhaitons recréer la structure
d’une table depuis l’écosystème Oracle, plusieurs méthodes existent et toutes
s’appuient sur les vues du catalogue que je présente en dernier.

**L’instruction DESCRIBE**

Certainement la moins riche des solutions mais la plus rapide pour une première
inspection. Il s’agit d’un équivalent de la méta-commande `\d` dans psql ou du
`pragma table_info` pour SQLite.

```sql
DESCRIBE SCOTT.EMP;

-- Name     Null?    Type         
-- -------- -------- ------------ 
-- EMPNO    NOT NULL NUMBER(4)    
-- ENAME             VARCHAR2(10) 
-- JOB               VARCHAR2(9)  
-- MGR               NUMBER(4)    
-- HIREDATE          DATE         
-- SAL               NUMBER(7,2)  
-- COMM              NUMBER(7,2)  
-- DEPTNO            NUMBER(2)    
```

**L’API METADATA**

Il est possible d’employer un package Oracle très utile pour générer la
structure d’une table au format texte SQL. Les équivalents des autres systèmes
seraient l’instruction `SHOW CREATE TABLE` de MySQL ou encore `.schema` de
SQLite.

```sql
SET pagesize 0
SET long 20000
SELECT dbms_metadata.get_ddl(
          object_type => 'TABLE', 
          schema => 'SCOTT', 
          name => 'EMP');

--  CREATE TABLE "SCOTT"."EMP"
--   (	"EMPNO" NUMBER(4,0),
--	"ENAME" VARCHAR2(10),
--	"JOB" VARCHAR2(9),
--	"MGR" NUMBER(4,0),
--	"HIREDATE" DATE,
--	"SAL" NUMBER(7,2),
--	"COMM" NUMBER(7,2),
--	"DEPTNO" NUMBER(2,0),
--	 CONSTRAINT "PK_EMP" PRIMARY KEY ("EMPNO")
--  USING INDEX PCTFREE 10 INITRANS 2 MAXTRANS 255
--  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
--  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
--  TABLESPACE "SYSTEM"  ENABLE,
--	 CONSTRAINT "FK_DEPTNO" FOREIGN KEY ("DEPTNO")
--	  REFERENCES "SCOTT"."DEPT" ("DEPTNO") ENABLE
--   ) PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
--  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
--  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
--  TABLESPACE "SYSTEM"
```

**Les vues du catalogue**

Les résultats précédents sont compilés depuis plusieurs vues systèmes. Sans
surprise, les explorateurs classiques comme SQL Developer ou DBeaver, ainsi
qu’Ora2Pg et PostgreSQL Migrator, consultent directement les données des
différentes vues pour obtenir le DDL complet.

Ora2Pg obtient la liste des tables depuis la vue `ALL_OBJECTS` et le stocke en
mémoire dans un tableau associatif `$self->{tables}`. Puis, il itère sur
`ALL_TAB_COLUMNS` pour collecter le détail de chaque table et les rattacher avec
une nouvelle profondeur de ce même tableau global
`$self->{tables}{$table}{column_info}{$column}`.

```sql
SELECT A.OWNER,A.OBJECT_NAME,A.OBJECT_TYPE FROM ALL_OBJECTS A
 WHERE A.OBJECT_TYPE IN ('TABLE','VIEW') AND A.OWNER='SCOTT';

SELECT A.COLUMN_NAME, A.DATA_TYPE, A.DATA_LENGTH, A.NULLABLE, A.DATA_DEFAULT,
       A.DATA_PRECISION, A.DATA_SCALE, A.CHAR_LENGTH, A.TABLE_NAME, A.OWNER
  FROM ALL_TAB_COLUMNS A
 WHERE A.TABLE_NAME NOT LIKE 'BIN$%' AND A.TABLE_NAME='EMP'
 ORDER BY A.COLUMN_ID
```

La structure en mémoire `$self` que maintient Ora2Pg ne persiste pas entre deux
exécutions. **La lecture du catalogue source est nécessaire à chaque fois**. En
opposition, j’ai eu l’occasion de découvrir une alternative nommée
[db_migrator][3], basée sur les _Foreign Data Wrapper_. Avec cette solution,
le catalogue est stockée dans une base de données PostgreSQL.

[3]: https://github.com/cybertec-postgresql/db_migrator

Il était alors simple de lancer une inspection avec la méthode
`db_migrate_refresh()` pour créer un instantané du catalogue distant et de
pouvoir le questionner hors-ligne, sans se reconnecter à l’instance Oracle. De
cette découverte émergera les premiers tâtonnements du catalogue au format JSON
de PostgreSQL Migrator.

---

## Questionner du JSON

Le stockage du catalogue requiert un format structuré, stable et non
contraignant. _De facto_, le choix de conserver les données dans des tables
PostgreSQL nous est apparu inadapté, bien qu’élégant pour des yeux de DBA.
L’outil PostgreSQL Migrator se vante d’être portable et nous ne souhaitions pas
encombrer l’instance PostgreSQL finale d’un schéma transitoire.

Comme Ora2Pg, une structure mémoire `Catalog` (`internal/catalog/catalog.go`)
est initialisée au début de l’inspection. Ce catalogue peut être étendu en
fonction que la source soit une base Oracle ou MySQL/MariaDB, pour collecter les
objets spécifiques du moteur, comme les _packages_ ou les synonymes. Dès lors
que la lecture du catalogue distant est réalisée, il suffit de sérialiser la
structure dans un fichier JSON. Actuellement, la version 1.0 s’appuit sur le
module [sonic](https://github.com/bytedance/sonic).

L’inspection est la première étape pour démarrer un projet avec `pg_migrate`, le
petit nom de l’interface en ligne de commande (_CLI_) de PostgreSQL Migrator.
Après avoir initialisé un dossier vide et valider l’accès à la base distante
Oracle, les traces nous invitent à exécuter la commande `pg_migrate inspect`.

```console
$ ora-scott && cd ora-scott
$ pg_migrate init --source "oracle://system:manager@localhost:1521/freepdb1"
14:55:28 INFO   Databases connections closed.    source=1 target=0
14:55:28 INFO   Initialized migration project.   source="Oracle Database 23ai Free"
14:55:28 INFO   Inspect source catalog using pg_migrate inspect.
$ pg_migrate --verbose inspect
14:56:03 DEBUG  Cache miss.                      name=Source
14:56:03 INFO   Inspecting source database.      driver=oracle
14:56:03 INFO   This may take some time.
14:56:04 DEBUG  Inspected schemas.               count=1 duration=84.735201ms
14:56:05 DEBUG  Inspected roles.                 count=6 duration=465.814794ms
14:56:06 DEBUG  Inspected sequences.             count=0 duration=1.050025889s
14:56:07 DEBUG  Inspected routines.              count=0 duration=2.794483231s
14:56:07 DEBUG  Inspected views.                 count=0 duration=2.63147026s
14:56:21 DEBUG  Inspected tables.                count=4 duration=15.720365706s
14:56:31 DEBUG  Inspected columns.               count=18 duration=10.735219841s
14:56:41 DEBUG  Inspected keys.                  count=2 duration=19.945416304s
14:56:44 DEBUG  Inspected tables-indexes.        count=0 duration=23.287211484s
14:56:48 DEBUG  Inspected foreign-keys.          count=1 duration=6.525976802s
14:56:58 DEBUG  Inspected checks.                count=0 duration=10.622190194s
14:56:58 INFO   Inspected schema.                name=SCOTT
14:56:58 DEBUG  Inspection completed.            duration=54.968668546s
...
14:57:12 INFO   Inspection terminated.           errs=0 online=true
14:57:12 INFO   Execute pg_migrate ui to browse project.
14:57:12 INFO   Execute pg_migrate dump to migrate for PostgreSQL.
```

Lors d’une première exécution, le catalogue local est inexistant (`Cache miss.
name=Source`), ce qui provoque une connexion à la base distante pour le créer de
toute pièce. Les fichiers de cache sont écrits dans le dossier caché
`.pg_migrate`. Le catalogue de la source se nomme sobrement `Source.json`.

```console
$ tree .pg_migrate/
.pg_migrate
├── Info.json
├── Map.json
├── Source.json
├── Stats.json
└── Target.json
```

Il a alors fallu me faire violence pour mettre de côté mes précieuses
connaissances en SQL pour apprendre le langage `jq` afin de questionner les
fichiers JSON d’un projet `pg_migrate`. Par exemple, le filtre suivant liste
toutes les colonnes et leurs types de la table `SCOTT.EMP` :

```console
$ set filter '.Tables[] | select (.Name == "EMP") | .Columns[] | .objectDefinition'
$ jq -r $filter < .pg_migrate/Source.json
EMPNO NUMBER(4, 0) NOT NULL
ENAME VARCHAR2(10)
JOB VARCHAR2(9)
MGR NUMBER(4, 0)
HIREDATE DATE
SAL NUMBER(7, 2)
COMM NUMBER(7, 2)
DEPTNO NUMBER(2, 0)
```

Bien évidemment, l’outil a fait un très long chemin depuis 2024 et cette
architecture de catalogue hors-ligne est devenue la colonne vertébrale du
produit. Ces fichiers ont permis d’explorer des possibilités jusqu’ici
inatteignables avec Ora2Pg, en plus du mode hors-ligne.

* La conversion passe d’un fichier `Source.json` à un fichier `Target.json` en
  lui appliquant des règles de conversion génériques et spécifiques ;
* Une phase d’audit parcourt tous les nœuds pour appliquer un score, voire des
  annotations sur les difficultés de conversion ;
* Une interface Web de type SPA (_single page app_) permet d’explorer les deux
  modèles (source et cible) pour se passer des filtres `jq`.

L’outil vient avec une commande `dump`, que l’on peut détourner pour récupérer
la forme DDL d’un objet stocké dans le `Target.json`. Pour le moment, la
commande complète est la suivante :

```console
$ pg_migrate dump --force --section=pre-data Tables/scott.emp 2>/dev/null | cat
--
-- Name: emp; Type: TABLE; Schema: scott; Owner: scott
--

CREATE TABLE "scott"."emp" (
  "empno" smallint NOT NULL,
  "ename" varchar(10),
  "job" varchar(9),
  "mgr" smallint,
  "hiredate" timestamp,
  "sal" numeric(7, 2),
  "comm" numeric(7, 2),
  "deptno" smallint
);

ALTER TABLE "scott"."emp" OWNER TO "scott";
```

---

## Conclusion

Je suis profondément fier du travail accompli avec cette première version
stable. Nous concluons une aventure palpitante avec mes collègues chez Dalibo,
celle de plus de deux ans de développement d’un outil libre et gratuit et qui a
vocation à dépasser son illustre prédécesseur Ora2Pg. La [feuille de route][4]
est claire. Nous avons un retard métier conséquent sur la référence open-source
de la migration, mais nous ne rougissont pas. Les fondations sont solides, le
langage Go permet de répondre à de véritables besoins de simplification et de
modernité. 

[4]: https://postgresql-migrator.readthedocs.io/en/latest/references/features/

À l’heure où les empires du numérique se gavent de nos données métiers, qu’ils
siphonnent la valeur travail de nos entreprises, il est urgent de réagir et de
croire qu’un autre numérique est possible. Les projets de migration deviennent
complexes, exigeants, avec des profils très variés, nous tentons d’apporter une
réponse qui ne repose pas exclusivement sur des agents LLM ou des services
américains.

La voie du logiciel libre est devant nous depuis des décennies, il ne manque que
les passerelles qui permettent de tourner le dos à ces technologies privatives
de liberté, d’innovation et de moyens. À mon échelle de DBA et de _Product
Owner_, engagé dans la coopérative Dalibo, j’œuvre pour cette urgence
collective.
