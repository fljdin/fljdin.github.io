---
title: "Les colonnes générées"
categories: [postgresql]
tags: [developpement]
date: 2023-03-22
---

La norme ISO SQL/Foundation ([ISO/IEC 9075-2:2016][1]) fait partie du standard
SQL et définit les règles pour la définition des relations et la manipulation
des données. En adoptant cette norme, les moteurs de bases de données
garantissent une interopérabilité avec leurs concurrents et permettent aux
entreprises de bénéficier d'une plus grande flexibilité lorsqu'elles souhaitent
passer de l'un à l'autre sans (trop) réécrire leur modèle de données ou leurs
requêtes SQL.

[1]: https://www.iso.org/standard/63556.html

Dans sa publication SQL:2003, la norme a introduit le concept de **colonnes
générées** comme nouvelle spécification technique. Parfois appelées _colonnes
calculées_ ou _colonnes virtuelles_, leurs valeurs dérivent de celles des autres
colonnes de la table. [Un des articles][2] de Markus Winand passe au crible les
différents systèmes du marché pour voir s'ils respectent ce standard.

[2]: https://modern-sql.com/caniuse/generated-always-as

<!--more-->

---

## Une apparition tardive dans PostgreSQL

Une analogie issue de la [documentation][3] permet de se faire une idée assez
précise de ce que les deux types de colonnes générées peuvent nous apporter :

[3]: https://www.postgresql.org/docs/12/ddl-generated-columns.html

> Une colonne générée virtuelle n'occupe pas d'espace et est calculée à la
> lecture. Une colonne générée virtuelle est donc équivalente à une vue, et une
> colonne générée stockée est équivalente à une vue matérialisée (sauf qu'elle
> sera toujours mise à jour automatiquement).

Les cas d'utilisations sont multiples et permettent de définir au plus proche de
la structure de la table, les informations transformées que les utilisateurs
peuvent consulter sans se soucier des règles métiers nécessaires pour les
obtenir. Par exemple :

* Calcul arithmétique sur une ou plusieurs valeurs de la ligne, comme
  l'application d'une taxe sur le tarif d'un produit ;
* Calcul de la distance entre deux points géométriques à l'aide de l'extension
  PostGIS ;
* Calcul de l'intervalle entre deux données temporelles, par exemple la durée
  d'exécution d'une tâche sur la base du début et de la fin de son exécution ;
* Contrôle de la validité d'une ligne en retournant `true` ou `false` ;
* Extraction d'un élément depuis un type complexe comme `JSON` ou `ARRAY`,
  notamment pour bénéficier de mécanismes comme la collecte de statistiques ou
  l'indexation.

Il fallut attendre la version 12 de PostgreSQL, sortie en octobre 2019, pour
pouvoir bénéficier de la syntaxe standardisée `GENERATED ALWAYS AS`, bien que le
respect de la norme soit partiel. Dans la course à la normalisation, les
systèmes DB2 d'IBM et Oracle Database sont les plus avancés comme le montre
l'illustration ci-dessous, issue de l'article de Markus Winand.

![](/img/fr/2023-03-22-generated-columns-support.png)

À ce jour, PostgreSQL n'implémente que les colonnes générées dites **stockées**.
Ces dernières sont calculées lorsqu'une modification de la ligne a lieu
(`INSERT` et `UPDATE`) et leurs valeurs sont stockées au même titre que les
autres colonnes dans le fichier de la table.

---

## Une colonne haute en couleur

Prenons l'exemple d'une table `colors` qui reprend la [palette][4] de
140 couleurs disponibles avec les classes CSS. Nous souhaitons que les valeurs
décimales du mode RGB (_Red_, _Green_, _Blue_) soient pré-calculées à partir de
la valeur hexadécimale de la couleur.

[4]: https://www.w3schools.com/colors/colors_names.asp

```sql
CREATE TABLE colors (
  name varchar(50) PRIMARY KEY,
  code_hex char(6) NOT NULL CHECK (code_hex ~* '^[0-9A-F]{6}$')
);
```

{{< message >}}
Les instructions `INSERT` sont disponibles sur mon [dépôt Github][5].

[5]: https://github.com/fljdin/database-samples/blob/master/en-colors-code-hex.sql
{{</ message >}}

Cette transformation nécessite de manipuler la colonne `code_hex` dans sa
représentation hexadécimale grâce à une conversion en `bytea`. Ensuite, la
fonction `get_byte` de PostgreSQL permet d'obtenir la valeur de chaque octet en
valeur décimale. Pour ma démonstration, je vais m'appuyer sur une fonction SQL
qui sera responsable de l'extraction des trois octets et me retournera un type
personnalisé `rgb`.

```sql
CREATE DOMAIN color AS smallint CHECK (VALUE BETWEEN 0 AND 255);
CREATE TYPE rgb AS (red color, green color, blue color);

CREATE OR REPLACE FUNCTION hex_to_rgb(code char(6))
RETURNS rgb LANGUAGE sql IMMUTABLE PARALLEL SAFE
RETURN (
  get_byte(concat('\x', code)::bytea, 0),
  get_byte(concat('\x', code)::bytea, 1),
  get_byte(concat('\x', code)::bytea, 2)
);
```

Enfin, je peux ajouter une nouvelle colonne générée à ma table `colors` :

```sql
ALTER TABLE colors 
  ADD COLUMN code_rgb rgb 
    GENERATED ALWAYS AS (hex_to_rgb(code_hex)) STORED;
```

Attention : lors de l'ajout de cette colonne, PostgreSQL va réécrire la table
intégralement vers un nouveau fichier. Il profite alors de cette étape pour
calculer les données de la colonne générée et les stocker aux côtés des autres
colonnes de chaque ligne.

```sql
SELECT * FROM colors LIMIT 5;
```
```text
      name      | code_hex |   code_rgb    
----------------+----------+---------------
 AliceBlue      | F0F8FF   | (240,248,255)
 AntiqueWhite   | FAEBD7   | (250,235,215)
 Aqua           | 00FFFF   | (0,255,255)
 Aquamarine     | 7FFFD4   | (127,255,212)
 Azure          | F0FFFF   | (240,255,255)
```

---

## Émuler des colonnes virtuelles

Comme nous venons de le voir, PostgreSQL ne supporte que le mode stocké des
colonnes générées à l'heure de la rédaction de cet article. Plusieurs
inconvénients découlent de son implémentation :

* L'ajout d'une nouvelle colonne générée implique la réécriture de la table,
  avec des verrous passablement contraignants sur des tables fortement
  sollicitées ;
* À l'image d'un mauvais usage des triggers, les colonnes générées peuvent
  ralentir les opérations d'écriture (`INSERT` et `UPDATE`).
* Si le corps de la fonction est modifié, la transformation des données ne
  s'appliquera qu'à la prochaine modification des lignes ;

S'engager sur la voie des colonnes générées ainsi proposées par PostgreSQL peut
se révéler rédhibitoire pour certains besoins. Dans la continuité de ma
démonstration avec la table `colors`, je souhaite l'étendre pour prendre en
charge la [représentation HSV][6], réputée pour son approche par la perception
d'une couleur.

[6]: https://en.wikipedia.org/wiki/HSL_and_HSV

Le calcul de la teinte, de la saturation et de la luminosité repose sur
l'intensité des couleurs rouge, verte et bleue que l'on connait déjà grâce à
notre colonne générée `code_rgb`. Je me lance alors dans l'implémentation de la
formule permettant de convertir un objet `rgb` en un nouvel objet `hsv`. 


```sql
CREATE DOMAIN degree AS smallint CHECK (VALUE BETWEEN 0 AND 360);
CREATE DOMAIN percent AS smallint CHECK (VALUE BETWEEN 0 AND 100);
CREATE TYPE hsv AS (hue degree, saturation percent, value percent);

CREATE OR REPLACE FUNCTION rgb_to_hsv(code rgb)
RETURNS hsv LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$
  WITH color AS (
    SELECT 
      (code).red / 255.0 AS red, 
      (code).green / 255.0 AS green,
      (code).blue / 255.0 AS blue
  ), math AS (
    SELECT 
      least(red, green, blue) AS min,
      greatest(red, green, blue) AS max,
      greatest(red, green, blue) - least(red, green, blue) AS dist
    FROM color
  )
  SELECT
    CASE WHEN dist = 0 THEN 0
      ELSE (CASE max
        WHEN red THEN (green - blue) / dist
             + (CASE WHEN green < blue THEN 6 ELSE 0 END)
        WHEN green THEN (blue - red) / dist + 2
        WHEN blue THEN (red - green) / dist + 4
      END) * 60
    END AS hue,
    (CASE WHEN max = 0 THEN 0 ELSE dist / max END) * 100 AS saturation,
    max * 100 AS value
  FROM color, math;
$$;
```

Puisque notre formule repose sur la colonne générée `code_rgb`, il nous est
impossible de procéder comme dans l'exemple précédent. Le message d'erreur
est assez explicite :

```sql
ALTER TABLE colors 
  ADD COLUMN code_hsv hsv 
    GENERATED ALWAYS AS (rgb_to_hsv(code_rgb)) STORED;
```
```text
ERROR: cannot use generated column "code_rgb" in column generation expression
DETAIL: A generated column cannot reference another generated column.
```

Pour contourner ce problème, il devient nécessaire de construire une vue étendue
de la table `colors` afin d'exposer l'information aux utilisateurs. Et comme
PostgreSQL reste fondamentalement un système relationnel orienté objet, j'en
profite pour créer la fonction `code_hsv` qui prend en argument une ligne de la
table `colors` et qui sera appelée dans la vue comme s'il s'agissait d'un
attribut de la relation.

```sql
CREATE OR REPLACE FUNCTION code_hsv(color colors)
RETURNS hsv LANGUAGE sql IMMUTABLE PARALLEL SAFE
RETURN rgb_to_hsv(color.code_rgb);

CREATE OR REPLACE VIEW colors_with_hsv AS
SELECT name, code_hex, code_rgb, colors.code_hsv
  FROM colors;
```

---

## Conclusion

Les colonnes générées ne sont qu'une forme de plus pour transformer et présenter
les données d'une table. Avec la syntaxe introduit dans PostgreSQL 12 et son
mode stocké (`STORED`), l'accès aux données ne nécessite plus de calculer chaque
valeur à la volée, au prix d'un coût de stockage plus élevé. C'est une histoire
de compromis à trouver en fonction de ses besoins et de l'activité sur
l'instance.

Pour en finir avec ma démonstration, la table `colors` a été enrichie des deux
nouvelles représentations RGB et HSV. La requête suivante me permet de retrouver
les noms de toutes les couleurs qui se rapprochent de notre perception du bleu.
Avec le modèle HSV, il s'agit des couleurs dont la teinte est située entre 190°
et 250° sur le [cercle chromatique][7] et dont la saturation est supérieure à 10.

[7]: https://fr.wikipedia.org/wiki/Cercle_chromatique

```sql
SELECT * FROM colors_with_hsv 
 WHERE (code_hsv).hue BETWEEN 190 AND 250
   AND (code_hsv).saturation > 10
 ORDER BY name LIMIT 5;
```

```text
      name      | code_hex |   code_rgb    |   code_hsv    
----------------+----------+---------------+---------------
 Blue           | 0000FF   | (0,0,255)     | (240,100,100)
 CornflowerBlue | 6495ED   | (100,149,237) | (219,58,93)
 DarkBlue       | 00008B   | (0,0,139)     | (240,100,55)
 DarkSlateBlue  | 483D8B   | (72,61,139)   | (248,56,55)
 DeepSkyBlue    | 00BFFF   | (0,191,255)   | (195,100,100)
```