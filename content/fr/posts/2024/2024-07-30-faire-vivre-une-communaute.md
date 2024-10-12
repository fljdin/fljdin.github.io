---
title: "Faire vivre une communauté"
categories: [postgresql]
tags: [opensource, conferences]
date: "2024-07-30 09:30:00"
translationKey: "how-to-keep-a-community-alive"
---

Le [PG Day France](https://pgday.fr/) s'est tenu les 11 et 12 juin derniers à Lille, ma ville natale.
Il s'agit de l'événement de la communauté française de PostgreSQL qui pose ses valises dans une
ville différente chaque année. L'occasion était trop belle pour moi et j'y ai rencontré de nombreuses
personnes venant de toute la France et de ses alentours, pour discuter de PostgreSQL au cours
de deux jours d'ateliers et de conférences.

Pour cette édition, j'ai eu le plaisir de prendre la parole et de faire un retour d'expérience
sur l'animation du groupe Meetup local dont j'ai repris les rennes il y a maintenant quatre ans.
Dans cet article, je souhaite retranscrire les principaux points abordés lors de cette présentation,
en attendant que la vidéo de la conférence soit mise en ligne.

<!--more-->

{{< message >}}
Le support de ma présentation est [disponible à cette adresse](/documents/pgdayfr-faire-vivre-une-communaute.pdf).
{{< /message >}}

---

## Qu'est-ce qu'un PUG ?

Un « PUG » est un groupe d'utilisateur·rices de PostgreSQL, ou « PostgreSQL User Group » en anglais.
Réunis régulièrement pour échanger autour de PostgreSQL, les PUGs sont des lieux de rencontres
et d'apprentissage pour les personnes intéressées par ce système de gestion de base de données. Ces
communautés locales sont fréquentes, particulièrement pour les logiciels libres, et permettent de
fédérer les utilisateurs et utilisatrices autour d'un même outil.

À Lille, nous avons la chance d'avoir un tissu économique très dynamique, avec de nombreuses communautés,
telles que le [Ch'ti JUG][1] (_Java User Group_), le [GDG Lille][2] (_Google Developer Group_), [Nord Agile][3]
ou encore [Software Craft Lille][4]. Quoi de plus naturel que de vouloir proposer à une poignée de
ce public des rencontres autour de PostgreSQL ?

[1]: https://www.meetup.com/fr-FR/chtijug/
[2]: https://www.meetup.com/GDG-Lille/
[3]: https://www.meetup.com/fr-FR/nord-agile/
[4]: https://www.meetup.com/Software-Craftsmanship-Lille/

Une [page du projet][5] PostgreSQL recense les différents PUGs à travers le monde, et il est possible
d'y trouver des groupes dans de nombreux pays, dont la France. À l'heure de la rédaction de ma conférence,
je dénombrais 62 groupes mondiaux, dont 5 en France : Paris, Lyon, Nantes (non référencée), Toulouse et Lille.

La plateforme Meetup est souvent utilisée pour organiser les rencontres, et pour preuve, 46 PUGs y sont
affiliés. Il s'agit d'une commodité depuis plus de 10 ans, et la plupart des groupes français y sont inscrits.

[5]: https://www.postgresql.org/community/user-groups/

![Carte de France des PUGs](/img/fr/2024-07-30-carte-de-france-des-pugs.png)

La création d'un PUG reconnu par la communauté internationale est un processus simple, qui nécessite
de constituer un groupe d'organisation et de postuler à l'adresse e-mail `usergroups@postgresql.org`.
Le groupe doit respecter un certain nombre de règles, prévues par la [charte des PUGs][6], et doit
s'engager à respecter les valeurs de la communauté PostgreSQL. En substance, voici les points qu'il
faut retenir :

[6]: https://www.postgresql.org/about/policies/user-groups/

* Le groupe doit être ouvert à tous et toutes, sans discrimination.
* Les rencontres doivent être proposées _a minima_ une fois tous les deux ans.
* Les rencontres ne doivent pas faire l'objet d'un accord de confidentialité (NDA).
* Les rencontres sont rattachées à la zone géographique du groupe.
* Une entreprise ne peut pas être représentée à 50% ou plus dans le comité d'organisation.
* La sélection des conférences est à la discrétion du comité d'organisation.
* Les entreprises peuvent promouvoir leurs produits et leurs services, si leurs activités facilitent
  l'adoption de PostgreSQL et si les contenus présentés sont de nature technique.
* Le groupe doit divulguer le nom des sponsors, et peut les mentionner en introduction des rencontres.
* Le PUG doit adopter un code de conduite et peut utiliser [celui de la communauté PostgreSQL][7].

[7]: https://www.postgresql.org/about/policies/coc/fr/

---

## Genèse du groupe

Le groupe Meetup PostgreSQL Lille a été fondé le 25 février 2016 sur la plateforme éponyme. À l'époque,
l'idée de reproduire le format des Meetup à Paris était partagée entre Guillaume Lelarge et Pierre Hilbert,
deux lillois qui se croisaient régulièrement aux événements. L'une des principales motivations était de
participer à la promotion du logiciel libre avec un partage de retours d'expérience pour inspirer les autres
acteurs locaux.

À cette période, je fréquentais moi-même les événements organisés par le groupe Meetup Oracle Paris et Province,
et je suivais avec attention les conférences autour de PostgreSQL dans ma région. La première rencontre
du groupe PG Lille a eu lieu le [24 juin 2016][8], dans les locaux de Decathlon Campus (Villeneuve D'Ascq, 59).
J'ai été séduit par le format et l'ambiance décontractée, et j'en ai gardé un excellent souvenir.

[8]: https://www.meetup.com/meetup-postgresql-lille/events/231446425/

![Premier Meetup PG Lille](/img/fr/2024-07-30-premier-meetup-pg-lille.png)

Cependant, la régularité des rencontres n'a pas été au rendez-vous du projet. L'événement suivant fut planifié
plus d'une année plus tard, le 17 octobre 2017 et ce fut le seul auquel je n'ai pas pu participer. Les impératifs
professionnels de Guillaume et de Pierre ne leur ont pas permis de maintenir le rythme, et le groupe a été
laissé en sommeil pendant plus de trois années.

C'est en 2019 que j'ai pris la décision de reprendre le flambeau, en proposant à Pierre de me transmettre
les droits d'administration du groupe. Mon arrivée chez Dalibo en tant que consultant PostgreSQL m'a donné
l'opportunité de faire la rencontre d'experts passionnés, notamment Guillaume Lelarge et Stefan Fercot,
qui m'ont encouragé à reprendre le projet.

Fort d'un réseau professionnel de qualité sur Twitter à l'époque, j'ai pu rapidement mobiliser une équipe
de bénévoles pour organiser le Meetup du [28 janvier 2020][9]. J'ai pu compter sur le soutien de Stefan Fercot
(Dalibo), de Stéphane Definin (Think) et de Sébastien Freiss (SFEIR) pour faire de cette reprise un petit
succès.

[9]: https://www.meetup.com/meetup-postgresql-lille/events/267319389/

... Malheureusement, en mars de cette même année, la pandémie de COVID-19 a contraint le groupe à suspendre
ses projets et je n'ai pas eu le courage de proposer des contenus en ligne, au grand dam des membres du groupe.
Pour l'anecdote, aucun autre groupe Meetup de France n'a été épargné par la crise sanitaire et les restrictions
en vigueur.

![Frise chronologiques des Meetup](/img/fr/2024-07-30-frise-chronologique.png)

Une pause de deux années supplémentaires s'est imposée au groupe, avant que ne se stabilise la situation sanitaire.
En 2022, j'ai ainsi contacté Lætitia Avrot, une membre très active de la communauté française, pour relancer les
activités et retrouver une dynamique et un rythme pour ses membres. L'événement du [14 avril 2022][10] fut un
soulagement pour moi, voyant que je pouvais toujours compter sur la participation de la communauté.

[10]: https://www.meetup.com/meetup-postgresql-lille/events/284819405/

À partir de cet instant, aucune nouvelle ombre n'est venue assombrir le tableau, et le groupe a pu reprendre
l'organisation régulière de rencontres, de deux à trois par ans. La communauté s'est élargie, et le comité
d'organisation s'est renforcé avec l'arrivée de Yoann La Cancellera en 2023, qui a permis notamment de déposer
une demande de reconnaissance au sein de la communauté internationale, le 24 février 2023.

---

## How-to Meetup

En guise de conclusion à ce retour d'expérience, j'ai voulu partager toutes les étapes nécessaires pour
organiser un Meetup, en appuyant sur les points cruciaux de réussites et les pièges à éviter.

**Accueil** : trouver le lieu d'accueil de pour l'événement

À l'image du PG Day France qui change de lieu chaque année, le groupe Meetup PG Lille a fait le
choix de varier les lieux d'accueil à chaque rencontre. Cela permet de découvrir de nouveaux espaces
et de stimuler la curiosité inter-communauté. Les entreprises locales sont souvent ravies de pouvoir
accueillir des événements techniques, et cela permet de renforcer les liens entre les acteurs locaux.

La recherche d'un lieu est souvent la première étape de l'organisation d'un Meetup. Il est important
de trouver un espace qui puisse accueillir entre dix et quarante personnes, avec un accès en transports
en commun ou un parking à proximité. Pour cela, j'ai eu l'occasion d'user de plusieurs stratégies :

* Le bouche-à-oreille : demander à ses contacts professionnels s'ils connaissent des lieux d'accueil
  potentiels
* Les réseaux sociaux : publier une annonce sur Twitter ou LinkedIn pour solliciter des propositions
  spontanées ou des pistes à étudier
* La privatisation d'un espace : contacter les espaces de coworking ou les salles de réunion pour
  obtenir un devis de location
* S'allier avec d'autres groupes : proposer un partenariat avec un autre groupe Meetup pour partager
  les frais de location ou pour bénéficier d'un lieu d'accueil déjà identifié

**Intervenant·es** : trouver {{< u >}}deux{{< /u >}} présentations variées

Dès le premier Meetup, Pierre et Guillaume ont fait le choix de proposer deux présentations techniques
pour varier les sujets et les formats. Cela permet de toucher un public plus large et de satisfaire
les attentes des membres du groupe. Cette formule a été reprise pour les rencontres suivantes, et a
été un succès à chaque fois.

La recherche d'intervenant·es est un travail qui demande du temps et de la patience. Souvent, une
rencontre opportune ou une discussion informelle peut déboucher sur une proposition de présentation.
Le mieux est de se constituer un vivier de personnes ressources, qui pourront être sollicitées en cas
de besoin. Ce n'est pas toujours facile, c'est un travail de longue haleine, mais cela en vaut la peine.

Discutez autours de vous, demandez à vos collègues, à vos amis, à vos contacts professionnels s'ils
ne sont pas intéressés pour partager leur expérience ou leur expertise, ou s'ils ne connaissent pas
quelqu'un qui pourrait être intéressé.

**Apéro** : prolonger la soirée avec un temps fort communautaire (_networking_)

Selon moi, c'est l'étape **la plus importante** de l'organisation d'un Meetup. (rires !)

C'est le moment où les membres du groupe peuvent échanger, discuter, partager, et se rencontrer. C'est
un temps fort de la soirée qui me tient particulièrement à cœur, et qui est intimement lié à la réussite
de l'événement. Le _networking_ est ce qui favorise le mieux la sérendipité, la rencontre fortuite, le
partage d'expérience, et la création de liens durables. Je discute des prochains projets du groupe avec
les membres et le comité d'organisation, et je prends des notes sur les attentes de chacun·es et j'écoute
leurs suggestions.

Bien entendu, il est important de prévoir des boissons et des encas pour prolonger la soirée. Il faut
prévoir un espace pour faciliter la circulation et la création naturelle de petits groupes de discussion.
Le choix d'un sponsor est principalement motivé par la prise en charge de ces frais, avec une facture ou
une note de frais à l'appui.

Jusqu'à présent, aucun incident n'est à déplorer, les participants et participantes respectent les quelques
règles de sécurité et de conduite que l'on énonce en début de soirée.

**Communication** : atteindre la jauge d'inscription

Cette étape est à prendre au sérieux un mois avant la tenue de l'événement. Il s'agit de maximiser la
visibilité de l'événement pour atteindre la jauge maximale établie par le lieu qui accueille l'événement.
Pour cela, j'ai eu l'occasion de me doter de plusieurs méthodes :

* Être le plus exhaustif possible dans la description de l'événement (date, lieu, horaires, programme,
  sponsors, visuels, etc.)
* Créer du contenu régulier sur les réseaux sociaux pour rappeler la date de l'événement et les modalités
  d'inscription (LinkedIn majoritaire, Twitter par le passé)
* Solliciter les participants de l'événement pour qu'ils partagent l'événement sur leurs réseaux sociaux ou
  leurs réseaux d'entreprise
* Informer la communauté française avec la liste de diffusion `pgsql-fr-generale` pour toucher un public plus
  large, voire donner envie à d'autres groupes de se lancer dans l'organisation de Meetup (qui sait ?)

**Identité visuelle** (optionnelle)

Au cours des derniers mois, nous avons travaillé avec Yoann, la refonte de l'identité visuelle du groupe Meetup
avec un nouveau logo et une nouvelle charte graphique. C'est cosmétique, mais cela permet de donner une image
plus professionnelle et une identité forte au sein des communautés lilloises existantes. Nous espérons nous
faire une petite place et une petite notoriété dans le paysage local.

Pour avoir délégué par deux fois la création de la vignette de l'événement, je recommande de travailler avec
un graphiste ou un designer pour obtenir un résultat professionnel et soigné. En attendant qu'un des membres
qui m'entoure soit suffisamment qualifié, on fait avec les moyens du bord.

Enfin, et c'était notre petite fierté de l'année, nous nous sommes dotées d'un logo Slonik, la mascotte de
PostgreSQL. La démarche de création s'est appuyée énormément sur les nouveaux outils de génération par intelligences
artificielles, et nous avons été bluffés par la qualité du résultat. Un grand merci à [Isaac](https://www.instagram.com/_ekpyrosis/)
pour son aide précieuse dans les retouches et les ajustements du logo.

![Logo du groupe Meetup PG Lille](/img/fr/2024-07-30-logo-meetup-pg-lille.png)

---

## Remerciements

Au cours de cette conférence, j'ai eu l'occasion de remercier un tas de monde. En particulier, les membres de
l'association PostgreSQL France, pour leur confiance qu'ils nous ont accordée, Matthieu Cornillon et moi-même,
d'avoir accepté notre dossier de candidature pour le choix de la ville de Lille cette année 2024.

Un des slides de ma présentation était dédié à toutes les entreprises qui ont accueilli nos rencontres,
et qui, sans le savoir, m'ont permis d'ajuster le format et le contenu de nos Meetups. Un grand merci à elles
pour leur sympathie et leur accueil chaleureux. C'était également l'opportunité de mettre en avant les intervenants
et les intervenantes qui ont accepté de partager leur expérience et leur expertise lors des Meetup PostgreSQL Lille.
Un grand merci à elles et à eux d'avoir vécu l'aventure avec moi !

Enfin, j'ai été heureux que ce retour d'expérience puisse faire écho à quelques personnes dans la salle, qui
m'ont félicité pour le travail accompli et m'ont informé de leur intention de se lancer dans l'organisation
de Meetup dans leur propre ville. C'est une belle récompense pour moi, et cela me donne envie de poursuivre
mon engagement et de donner l'exemple pour la promotion de PostgreSQL en France.
