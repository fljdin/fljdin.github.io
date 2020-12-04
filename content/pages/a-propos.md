---
title: À propos
---

> Carnet de découvertes d'un DBA libre et passionné par l'open-source.

![Florent Jardin](/assets/img/avatar.jpg){:class="profile-avatar" height="125px" width="125px" }

Je suis consultant en bases de données orientées relationnelles (Oracle Database, PostgreSQL) avec pour nouvelles ambitions de promouvoir l'open-source à travers une série d'articles et de découvertes sur ce monde alternatif sans limite. En parallèle, je tiens à jour la liste de [mes lectures personnelles](/lectures-personnelles/) que j'essaie de rendre la plus variée possible.

Vous pourriez me croiser au hasard d'un couloir dans la région lilloise où je co-organise les soirées [Meetup PostgreSQL Lille](https://www.meetup.com/fr-FR/Meetup-PostgreSQL-Lille) pour les passionné⋅es  et professionnel⋅les des Hauts-de-France.

Vous pouvez également me contacter et me suivre par l'un des médias suivants.

{% for link in site.data.navigation %}
<ul>
  {%- if link.url contains "http" -%}
  <li><a href="{{ link.url }}">{{ link.url }}</a></li>
  {%- endif -%}
</ul>  
{% endfor %}

---

Ce site est propulsé par [Jekyll](https://jekyllrb.com) et n'utilise aucun traceur ou service d'analyse de trafic.