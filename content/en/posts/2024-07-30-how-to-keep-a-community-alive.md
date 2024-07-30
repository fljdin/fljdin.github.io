---
title: "How to keep a community alive"
categories: [postgresql]
tags: [opensource, conferences]
date: "2024-07-30 09:30:00"
translationKey: "how-to-keep-a-community-alive"
---

The [PG Day France](https://pgday.fr/) took place on June 11th and 12th in Lille, my hometown.
It is the event of the French PostgreSQL community that settles in a different city each year.
The opportunity was too good for me and I met many people from all over France and its surroundings,
to discuss PostgreSQL during two days of workshops and conferences.

For this edition, I had the pleasure of speaking and sharing my experience on the animation of
the local Meetup group that I took over four years ago. In this article, I want to write down the
main points discussed during this presentation, while waiting for the video of the conference to be
posted online.

<!--more-->

{{< message >}}
The slides of my presentation are [available at this address](/documents/pgdayfr-faire-vivre-une-communaute.pdf) (french).
{{< /message >}}

---

## What is a PUG?

A « PUG » is a PostgreSQL User Group, a community of PostgreSQL users who meet regularly to exchange
about PostgreSQL. These local communities are common, especially for free software, and allow users
to share their experiences and knowledge about the software.

Lille is a city with a rich economic ecosystem, and many communities are active in the region, such as
the [Ch'ti JUG][1] (_Java User Group_), the [GDG Lille][2] (_Google Developer Group_), [Nord Agile][3]
or [Software Craft Lille][4]. What could be more natural than wanting to offer a handful of this audience
more meetings with PostgreSQL?

[1]: https://www.meetup.com/fr-FR/chtijug/
[2]: https://www.meetup.com/GDG-Lille/
[3]: https://www.meetup.com/fr-FR/nord-agile/
[4]: https://www.meetup.com/Software-Craftsmanship-Lille/

A [dedicated page][5] of the PostgreSQL project lists the different PUGs around the world, and it is possible
to find groups in many countries, including France. At the time of writing my presentation, I counted 62 global
groups, including 5 in France: Paris, Lyon, Nantes (not referenced), Toulouse and Lille.

Meetup's platform is often used to organize meetings, and as proof, 46 PUGs are affiliated with it. This has
been a convenience for more than 10 years, and most French groups are registered there.

[5]: https://www.postgresql.org/community/user-groups/

![Map of PUGs in France](/img/en/2024-07-30-map-of-pugs-in-france.png)

La création d'un PUG reconnu par la communauté internationale est un processus simple, qui nécessite
de constituer un groupe d'organisation et de postuler à l'adresse e-mail `usergroups@postgresql.org`.
Le groupe doit respecter un certain nombre de règles, prévues par la [charte des PUGs][6], et doit
s'engager à respecter les valeurs de la communauté PostgreSQL. En substance, voici les points qu'il
faut retenir :

The creation of a PUG recognized by the international community is a simple process, which requires
to form an organizing committee and to apply to the email address `usergroups@postgresql.org`.
The group must respect a number of rules, provided by the [PUG policy][6], and must commit to
respecting the values of the PostgreSQL community. In essence, here are the points to remember:

[6]: https://www.postgresql.org/about/policies/user-groups/

* The group must be open to all, without discrimination.
* Meetings must be proposed at least once every two years.
* Meetings must not be subject to a non-disclosure agreement (NDA).
* Meetings are attached to the geographical area of the group.
* A company cannot be represented at 50% or more in the organizing committee.
* The selection of conferences is at the discretion of the organizing committee.
* Companies can promote their products and services, if their activities facilitate
  the adoption of PostgreSQL and if the content presented is technical in nature.
* The group must disclose the names of sponsors, and may mention them in the
  introduction of meetings.
* The PUG must adopt a code of conduct and can use [the one from the PostgreSQL community][7].

[7]: https://www.postgresql.org/about/policies/coc/fr/

---

## Genesis of the group

The Meetup PostgreSQL Lille group was founded on February 25, 2016 on the eponymous platform. At the time,
the idea of reproducing the Paris's Meetup format was shared between Guillaume Lelarge and Pierre Hilbert,
two Lille residents who regularly crossed paths at events. One of the main motivations was to promote free
software with a sharing of feedback to inspire other local actors.

At that time, I myself attended events organized by the Meetup Oracle Paris and Province group, and I followed
with interest the conferences about PostgreSQL in my region. The first meeting of the PG Lille group took place
on [June 24, 2016][8], in the premises of Decathlon Campus (Villeneuve D'Ascq, 59). I was seduced by the format
and the relaxed atmosphere, and I have kept an excellent memory of it.

[8]: https://www.meetup.com/meetup-postgresql-lille/events/231446425/

![First Meetup PG Lille](/img/en/2024-07-30-first-meetup-pg-lille.png)

However, the regularity of the meetings did not meet the expectations of the project. The next event was scheduled
more than a year later, on October 17, 2017, and it was the only one I could not attend. Guillaume and Pierre's
professional commitments did not allow them to keep up the pace, and the group remained dormant for more than three
years.

I took the decision to take over the group in 2019, by offering Pierre to transfer me the administration rights
of the group. My arrival at Dalibo as a PostgreSQL consultant gave me the opportunity to meet passionate experts,
including Guillaume Lelarge and Stefan Fercot, who encouraged me to take over the project.

With a quality professional network on Twitter at the time, I was able to quickly mobilize a team of volunteers
to organize the Meetup of [January 28, 2020][9]. I have been supported by Stefan Fercot (Dalibo), Stéphane Definin
(Think) and Sébastien Freiss (SFEIR) to make this renewal a small success.

[9]: https://www.meetup.com/meetup-postgresql-lille/events/267319389/

... Unfortunately, in March of the same year, the COVID-19 pandemic forced the group to suspend its projects
and I did not have the courage to propose online content, much to the chagrin of the group's members.
For the record, no other Meetup group in France was spared by the health crisis and the restrictions in force.

![Timeline of Meetups](/img/en/2024-07-30-timeline-meetups.png)

Two additional years of pause were imposed on the group, before the health situation stabilized. In 2022, I
contacted Lætitia Avrot, a very active member of the French community, to revive activities and find a dynamic
and a rhythm for its members. The event of [April 14, 2022][10] was a relief for me, seeing that I could still
count on the participation of the community.

[10]: https://www.meetup.com/meetup-postgresql-lille/events/284819405/

To this day, no more shadows have come to darken the picture, and the group has been able to resume
the regular organization of meetings, from two to three per year. The community has expanded, and the
organizing committee has been strengthened with the arrival of Yoann La Cancellera in 2023, who has
allowed in particular to submit a request for recognition within the international community, on
February 24, 2023.

---

## How-to Meetup

To conclude this feedback, I wanted to share all the necessary steps to organize a Meetup, focusing on
the crucial points of success and pitfalls to avoid.

**Welcome** : find the venue for the event

As the PG Day France changes location every year, the Meetup PG Lille group has chosen to vary the
venues for each meeting. This allows you to discover new spaces and stimulate inter-community curiosity.
Local companies are often delighted to be able to host technical events, and this helps to strengthen
ties between local actors.

Searching for a venue is often the first step in organizing a Meetup. It is important to find a space
that can accommodate between ten and forty people, with access to public transport or parking nearby.
To do this, I have had the opportunity to use several strategies:

* Chinest whispers: ask your professional contacts if they know of potential hosting locations
* Social networks: post an announcement on Twitter or LinkedIn to solicit spontaneous proposals or leads
  to explore
* Privatization of a space: contact coworking spaces or meeting rooms to get a rental quote
* Partnering with other groups: propose a partnership with another Meetup group to share rental costs
  or to benefit from an already identified hosting location

**Speakers**: find {{< u >}}two{{< /u >}} varied presentations

From the beginning, Pierre and Guillaume have chosen to offer two technical presentations to vary the
topics and formats. This allows to reach a wider audience and to meet the expectations of the group's
members. This formula has been used for subsequent meetings, and has been a success every time.

Finding speakers is a time-consuming and patience-testing task. Often, a chance meeting or an informal
discussion can lead to a presentation proposal. It is best to build a pool of resource persons who can
be called upon when needed. It is not always easy, it is a long-term job, but it is worth it.

Spread the word, ask your colleagues, friends, and professional contacts if they are interested in
sharing their experience or expertise, or if they know someone who might be interested.

**Networking**: extend the evening with a community highlight

From my point of view, this is the **most important** step in organizing a Meetup. (laughs!)

It's the moment when group members can exchange, discuss, share, and meet. It's a highlight of the evening
that I particularly cherish, and that is intimately linked to the success of the event. Networking is what
best promotes serendipity, chance encounters, sharing experiences, and creating lasting bonds. I discuss
the group's upcoming projects with members and the organizing committee, and I take notes on everyone's
expectations and listen to their suggestions.

Of course, it is important to provide drinks and snacks to extend the evening. It is necessary to provide
a space to facilitate circulation and the natural creation of small discussion groups. The choice of a
sponsor is mainly motivated by the coverage of these costs, with an invoice or an expense report as proof.

Until now, no incidents have been reported, and participants respect the few safety and conduct rules that
are announced at the beginning of the evening.

**Communication**: reach the registration limit

This step is to be taken seriously a month before the event. It is about maximizing the visibility of the
event to reach the maximum capacity set by the venue hosting the event. To do this, I have had the opportunity
to use several methods:

* Beeing as exhaustive as possible in the event description (date, location, schedule, program, sponsors,
  visuals, etc.)
* Creating regular content on social networks to remind the date of the event and the registration modalities
  (LinkedIn majority, Twitter in the past)
* Asking event participants to share the event on their social networks or their company networks
* Informing the French community with the `pgsql-fr-generale` mailing list to reach a wider audience, or even
  to inspire other groups to organize Meetups (who knows?)

**Visual identity** (optional)

We worked with Yoann on the redesign of the Meetup group's visual identity with a new logo and a new graphic
charter in the last few months. It's cosmetic, but it allows us to give a more professional image and a strong
identity within the existing Lille communities. We hope to make a small place and a small notoriety in the local
landscape.

We have delegated the creation of the event thumbnail twice, and I recommend working with a graphic designer
or a designer to get a professional and neat result. Until one of the members around me is qualified enough,
we do with the means at hand.

Last but not least, and it was our little pride of the year, we have given ourselves a Slonik logo, the PostgreSQL
mascot. The creation process relied heavily on the new AI generation tools, and we were blown away by the quality
of the result. A big thank you to [Isaac](https://www.instagram.com/_ekpyrosis/) for his invaluable help in the
retouching and adjustments of the logo.

![Meetup PG Lille Logo](/img/en/2024-07-30-meetup-pg-lille-logo.png)

---

## Acknowledgements

During this conference, I thanked a lot of people. In particular, the members of the PostgreSQL France
association, for their trust they have given us, Matthieu Cornillon and myself, for accepting our application
file for the choice of the city of Lille this year 2024.

One of the slides of my presentation was dedicated to all the companies that hosted our meetings, and who, without
knowing it, allowed me to adjust the format and content of our Meetups. A thank you to them for their sympathy
and warm welcome. It was also an opportunity to highlight the speakers who agreed to share their experience and
expertise during the PostgreSQL Lille Meetups. A big thank you to them for living the adventure with me!

After the conference, I felt that feedback had a positive impact on the audience, with a few people coming to
me to congratulate me on the work done and inform me of their intention to organize a Meetup in their own city.
It was a nice reward for me, and it made me want to continue my commitment and set an example for the promotion
of PostgreSQL in France.
