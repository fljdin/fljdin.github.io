---
title: "La conviction du dimanche soir"
date: 2019-12-15 08:00:00 +0100
tags: [blog, developpement]
---

Il y a parfois des projets qui émergent de nulle part, d'autres qui mûrissent 
d'années en années. Certains mêmes peuvent être déclenchés par l'heureuse 
rencontre de deux inconnus, ou alors par la simple volonté de combler un vide.
Aussi, dimanche dernier, je me suis plongé dans la lecture d'un [livre technique][1] 
sans raison apparente et me suis donné pour nouvel objectif de réapprendre le 
langage C.

[1]: https://www.oreilly.com/library/view/learn-c-the/9780133124385/

Incongru, n'est-ce pas ? Pourtant, l'idée n'est pas nouvelle, elle a germée
paisiblement jusqu'à plusieurs récents épisodes de mon quotidien. Et si ce langage 
informatique, très bas niveau, dont font l'impasse de nombreux étudiants (dont 
moi durant ma licence), avait des choses à m'apprendre pour progresser dans ma 
compréhension du logiciel libre ?

Je ne sais pas, mais j'ai eu comme la conviction d'être passer à côté d'une 
évidence…

<!--more-->
---

Le [langage C][2] fait partie des fondations de nos logiciels actuels. Il a émergé 
dans les années 1970 sous les mains de l'ingénieur [Dennis Ritchie][3] à l'occasion 
de la réécriture du système d'exploitation UNIX. Ce grand monsieur fut lauréat 
du prix Turing en 1983, rien que ça.

[2]: https://fr.wikipedia.org/wiki/C_(langage)
[3]: https://fr.wikipedia.org/wiki/Dennis_Ritchie

A l'instar du système UNIX qui permit la ramification actuelle que l'on connait
avec GNU/Linux, MacOS/iOS et BSD, ce petit langage fut l'élan nécessaire pour 
l'apparition des générations suivantes des langages, tels que le PHP, Java, C++
et C#, principaux standards de l'industrie d'hier et d'aujourd'hui. Une telle 
prouesse avec peu de moyens, puisqu'à l'époque, la mémoire vive était de l'ordre 
d'une [centaine d'octets][4], les architectures matérielles se faisaient une 
guerre acharnée (oui, Intel x86 n'était pas la référence) et l'Internet 
n'existait pas.

[4]: https://www.thoughtco.com/history-of-computer-memory-1992372

**Mais alors, pourquoi (ré)apprendre le langage C en 2020 ?**

Dans son livre, Zed A. Shaw apporte de premiers éléments de réflexion dont je me 
permets la traduction suivante :

> Aujourd'hui, bien trop de programmeurs assument simplement que tout ce qu'ils 
> écrivent fonctionne, mais qu'un jour tout échouera de façon catastrophique. 
> C'est particulièrement vrai si vous êtes le genre de personne ayant appris la 
> plupart des langages modernes qui résolvent beaucoup de problèmes à votre place. 
>
> Les manquements aux règles de sécurité moderne du langage C vous impose une 
> plus grande vigilance et d'être plus conscient de ce qui se passe. Si vous 
> parvenez à écrire du code C solide et sécurisé, vous pourrez en écrire dans 
> n'importe quel autre langage.
>
> Apprendre le C vous donne un accès direct à une montagne de code _legacy_ et 
> vous enseignera la syntaxe de base d'un grand nombre de langages. Une fois que 
> vous apprenez le C, vous pourrez facilement apprendre C++, Java, Objective-C, 
> Javascript et davantages encore.
>
> C est réellement un langage élégant de bien des façons. Sa syntaxe est 
> incroyablement concise pour la puissance qu'il offre. C'est pour cette raison 
> que de nombreux autres langages le lui ont emprunté depuis plus de 45 ans.
>
> C vous apporte aussi énormement avec peu de moyens technologiques. Lorsque vous
> achevez votre apprentissage du C, vous aurez une opinion plus fine de quelque
> chose qui est tout aussi élégant et déplaisant à la fois. Le langage C est vieux,
> de la même façon qu'un beau monument, il vous semblera fantastique à une 
> distance de 20 pieds, mais si vous vous en approchez, vous vous apercevrez 
> qu'il est recouvert de fissures et de défauts.

Si l'on s'attarde sur la popularité des langages dans le monde du logiciel libre, 
on constate que le langage C arrive en 11{{< sup >}}ème{{< /sup >}} position 
d'après l'[enquête annuelle][5] de StackOverflow et en 9{{< sup >}}ème{{< /sup >}} 
position dans le rapport de l'[Octoverse][6] Github.

[5]: https://insights.stackoverflow.com/survey/2019#technology-_-programming-scripting-and-markup-languages
[6]: https://octoverse.github.com/#top-languages

![Octoverse - Top Languages in 2019][octoverse-programming-langages-img]

Et oui. Rien de plus sexy que le JavaScript ou le Python de nos jours ! Mais pour 
toutes les raisons de design ou de sécurité citées plus haut, la présence du 
langage C dans les plus populaires des langages en 2019 révèle une certaine 
réalité de terrain.

[octoverse-programming-langages-img]: /img/posts/2019-12-15-octoverse-programming-langages.png

---

Ce n'est pas anodin cependant que je me penche à nouveau sur le langage C. Mon 
intérêt pour le projet libre PostgreSQL me fait me questionner sur l'usage des 
langages de bas niveau pour les logiciels d'envergure. Pour de nombreux 
contributeurs, rien de plus fiable et de plus robuste qu'un projet qui repose sur 
des bases connues et reconnues par l'Institut national américain de normalisation 
(ANSI) depuis trois décennies.

Le C est absolument partout. Les systèmes d'exploitation, les sytèmes embarqués, 
les systèmes de bases de données. Mon dernier exemple en date remonte à ce matin, 
lorsque David Steele a [annoncé][7] sur Twitter que le projet _pgBackRest_ venait 
de migrer intégralement en C pur, après des mois de [réécriture][8].

[7]: https://twitter.com/pgBackRest/status/1205632408592297990
[8]: https://github.com/pgbackrest/pgbackrest/commit/f0ef73db7009cd6e08740d270a6ee7565efc9f8c

Je n'ai pas de recul ni d'expérience pour avancer que la portabilité, la performance 
et la longévité impressionnante font de ce langage un choix opportun pour le logiciel, 
qu'il soit libre ou non.

Je ne sais pas, peut-être une intuition.