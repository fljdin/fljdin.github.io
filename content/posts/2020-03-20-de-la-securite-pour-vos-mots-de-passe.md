--- 
title: "De la sécurité pour vos mots de passe"
date: 2020-03-20 16:00:00 +0200
tags: [postgresql, securite]
---

La sécurité d'un système d'information prend une multitude de forme. Aussi, 
j'aimerai m'attarder sur une évolution apparue en version 10 de PostgreSQL, 
devenue depuis lors une bonne pratique, bien que très absente dans les 
déploiements des systèmes courants.

<!--more-->

Depuis la version 8.1 de PostgreSQL, les mots de passe de connexion sont hachés 
dans une table système nommée [pg_authid][1] avec l'algorithme MD5. La chaîne 
encodée sur 32 caractères héxadécimaux est le résultat du hachage du mot de passe 
en clair avec le nom de l'utilisateur.

[1]: https://www.postgresql.org/docs/current/catalog-pg-authid.html

```sql
SELECT u, md5('secret' || u) AS hash 
  FROM unnest(array['tom','jerry']) AS u;
   
--    u   |               hash               
-- -------+----------------------------------
--  tom   | c85e6c670e521155c2823ddaa761c1be
--  jerry | df96e7fb3e9b25fda78387096d19aca6
```

Ainsi, pour tout utilisateur présent dans l'instance, il est possible d'obtenir 
le _hash_ avec la requête suivante :

```sql
SELECT rolname, rolpassword FROM pg_authid
 WHERE rolpassword IS NOT NULL;

--  rolname |             rolpassword             
-- ---------+-------------------------------------
--  tom     | md5c85e6c670e521155c2823ddaa761c1be
--  jerry   | md5df96e7fb3e9b25fda78387096d19aca6
```

C'est là que le bât blesse. Depuis plus d'une décennie, nous savons que ce bel 
algorithme n'est [plus assez robuste][2] pour les machines de calcul modernes. Il 
devient possible de retrouver le mot de passe en clair avec des attaques par 
dictionnaire ou de force brute (_brute-forcing_).

[2]: https://fr.wikipedia.org/wiki/MD5

> The method md5 uses a custom less secure challenge-response mechanism. It 
> prevents password sniffing and avoids storing passwords on the server in plain 
> text but provides no protection if an attacker manages to steal the password 
> hash from the server. Also, the MD5 hash algorithm is nowadays no longer 
> considered secure against determined attacks.
> 
> _Source : [Authentication Methods](https://www.postgresql.org/docs/10/auth-methods.html)_

Je vois venir de loin les autres barrages à ce type d'attaque, comme la restriction
des adresses et plages IP dans le fichier `pg_hba.conf` ou la segmentation des 
réseaux qui mitigent parfaitement le scénario de connexion en provenance d'un tier 
non habilité. Mais comme pour toute faille de sécurité, il convient d'étudier 
les faiblesse d'un système pour ensuite décider de les corriger ou de les ignorer.

---

La communauté a ainsi travaillé à la refonte de l'architecture de l'authentification 
dans le cœur de PostgreSQL pour supporter de nouvelles normes de sécurité avec 
l'implémentation de la couche [SASL][3] et a rendu possible l'ajout d'une nouvelle 
méthode de hachage : le SCRAM-SHA-256.

[3]: https://fr.wikipedia.org/wiki/Simple_Authentication_and_Security_Layer

Le mot de passe de l'utilisateur sera toujours stocké dans la table `pg_authid` 
mais sous un format plus robuste, rendant le risque de la captation de la chaîne 
bien moins élevé que précédemment. La transformation de cette chaîne nécessite 
de modifier le paramètre `password_encryption` et de resaisir le mot de passe 
d'un utilisateur.

```sql
-- Surchage de la méthode pour la session en cours
SET password_encryption = 'scram-sha-256';

-- Surcharge de la méthode les prochaines connexions de l'utilisateur
ALTER USER jerry SET password_encryption = 'scram-sha-256';

-- Surcharge de la méthode pour toute l'instance après rechargement
ALTER SYSTEM SET password_encryption = 'scram-sha-256';
SELECT pg_reload_conf();
```

Avec l'outil `psql`, il est recommandé de saisir un mot de passe _via_ la commande 
`\password` qui se chargera de hacher la saisie avec l'algorithme défini 
précédemment et ainsi limiter le transport du mot de passe en clair sur le réseau 
et dans les traces associées à l'activité de l'instance.

```sql
SET log_min_duration_statement = 0;
\password jerry
-- Enter new password: secret
-- Enter it again: secret
```

```r
# Extrain du journal postgresql.log
2020-03-20 10:26:25.286 CET [13500] LOG:
  duration: 0.187 ms  
  statement: SET log_min_duration_statement = 0;
2020-03-20 10:26:46.802 CET [13500] LOG:  
  duration: 58.877 ms  
  statement: ALTER USER jerry PASSWORD 
   'SCRAM-SHA-256$4096:PX5tZa/Z6JpAqz+BamwBsw==$F
    wjepTBG4JK3WnW574IMvujq0FLzfm+yBdz6PORI5dY=:9
    vx8y36/ervWsOqnYsaZQrm49tIy5b8IpgFu3RIyTyg='
```

La génération du _hash_ repose sur le principe [HMAC][4] (norme RFC2104) avec une 
série d'itérations où le mot de passe est mélangé avec plusieurs chaînes (_salt_) 
qui produit un résultat pseudo-aléatoire. L'implémentation avec PostgreSQL peut 
être consultée dans le fichier `src/common/scram-common.c`.

[4]: https://fr.wikipedia.org/wiki/Keyed-hash_message_authentication_code

Enfin, la requête suivante pourrait nous permettre de suivre la migration vers 
l'adoption de la nouvelle méthode pour l'ensemble des utilisateurs de l'instance :

```sql
SELECT lower(regexp_replace(rolpassword, '(md5|SCRAM-SHA-256)(.*)', '\1'))
       AS method, count(oid), string_agg(rolname, ',') AS roles
  FROM pg_authid WHERE rolpassword IS NOT NULL
 GROUP BY method ORDER BY method;

--     method     | count | roles 
-- ---------------+-------+-------
--  md5           |     1 | tom
--  scram-sha-256 |     1 | jerry
```

---

SCRAM signifie _Salted Challenge Response Authentication Mechanism_. Ce mécanisme 
de « [défi-réponse][5] » repose sur l'implémentation côté client {{< u >}}et{{< /u >}} 
côté serveur d'un des algorithmes afin qu'ils puissent se mettre d'accord sur la 
comparaison du _hash_ de mot de passe saisi par l'utilisateur à sa connexion 
avec celui stocké en base de données.

[5]: https://fr.wikipedia.org/wiki/Authentification_d%C3%A9fi-r%C3%A9ponse

À l'heure de la rédaction de cette article, plus de deux années se sont écoulées 
depuis la sortie en octobre 2017 de la version 10 de PostgreSQL et la plupart des 
[pilotes de connexions][6] supportent parfaitement la méthode d'authentication 
SCRAM. L'adoption de cette bonne pratique ne sera globale que le jour où la 
communauté de développeurs l'activera par défaut avec le paramètre 
`password_encryption` positionné à `scram-sha-256` au lieu du `md5` actuellement.

[6]: https://wiki.postgresql.org/wiki/List_of_drivers

Si d'aventure l'une de vos applications ne serait pas encore compatible, il reste 
toujours la possibilité de surcharger le paramètrage de l'instance au niveau de 
la base ou au niveau de l'utilisateur et de conserver un _hash_ en MD5. 

De plus, les règles d'authentication dans le fichier `pg_hba.conf` peuvent vous 
aider à définir des exceptions pour les mauvais élèves.

```ini
# pg_hba.conf
# TYPE  DATABASE   USER        ADDRESS             METHOD
# IPv4 local connections:
host    all        tom         192.168.1.0/24      md5
host    all        all         192.168.1.0/24      scram-sha-256
```