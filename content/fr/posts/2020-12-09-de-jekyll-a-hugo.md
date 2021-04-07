---
title: "De Jekyll à Hugo"
date: 2020-12-09
categories: [blog]
tags: [administration]
---

Dans l'univers des générateurs de sites statiques, la bataille fait rage entre
plusieurs _frameworks_ depuis quelques années. Vous avez peut-être entendu parler
de [Jekyll][1], [Next.js][2], [Gastby][3] ou [Hugo][4] ? Je ne cite que les plus
sollicités par la communauté sur GitHub, mais il en existe des centaines.

[1]: https://github.com/jekyll/jekyll
[2]: https://github.com/vercel/next.js
[3]: https://github.com/gatsbyjs/gatsby
[4]: https://github.com/gohugoio/hugo

Pourquoi cet engouement ? Cet article n'en parlera pas.

<!--more-->

---

Pour de louables raisons, je m'étais engagé [l'année dernière][5] à auto-héberger
mon nouvel espace d'expression personnel. J'y ai découvert avec intérêt et amusement
de nombreuses technologies que j'ai pliées, réinstallées, transformées pour les
adapter à mon besoin. Sans trop rentrer dans les détails, j'ai fini par avoir :

* un serveur VPS chez OVH pour un coût de 3,99€ par mois
* une routine mensuelle de renouvellement de certificat avec [certbot]
* une instance [Theia][6] dans un conteneur Docker
* une image Jekyll 4.1.0 que j'invoquais dans Docker
* deux dépôts GitHub privés pour les articles (_posts_) et les brouillons (_drafts_)
* le thème [Poole][7], léger et modulable… que j'ai modulé

[5]: /2019/06/12/reprenons-serieusement
[6]: https://github.com/eclipse-theia/theia
[7]: https://github.com/poole/poole
[certbot]: https://pypi.org/project/certbot/

Alors que la question de conserver ou non le serveur VPS se pose pour la nouvelle
année qui démarre bientôt (il devient agé, limité, pour ne pas dire sénil), j'ai
remis récemment en cause mon attachement pour le _framework_ **Jekyll**, si élégant
à l'époque.

Le machin repose sur des dépendances Ruby. Aussi nombreuses (ou presque) qu'un
nouveau projet en Node.js. J'ai mangé du `Gemfile` par le passé, aussi je n'ai eu
aucune réelle difficulté à installer les quelques modules nécessaires à la
concrétisation de mon projet. En voici le contenu :

```ruby
source "https://rubygems.org"

gem "jekyll", "~> 4.1.0"
gem "classifier-reborn"

# If you have any plugins, put them here!
group :jekyll_plugins do
  gem "jekyll-paginate-v2"
  gem 'jekyll-target-blank', "~> 2.0"
  gem 'jekyll-time-to-read'
end
```

Et c'est tout.

Je n'avais besoin que de la pagination et de l'estimation du temps de lecture par
article. Mine de rien, ça me semblait un peu grossier d'exiger que ces simples
modules ne soient pas intégrés nativement. J'ai donc engagé mes recherches et le
portage du présent site sur l'une des autres solutions, à savoir **Hugo**.

---

## Migre moi ça, p'ti con

Et les développeurs de Hugo n'y sont pas allé de main morte pour asseoir leur
logiciel dans ce paysage turbulent : ils intègrent un assistant de migration
spécialement pour un projet Jekyll en récupérant ses fichiers `.md` et ses
ressources statiques. En soit, la chose n'est pas complexe et le résultat est
au rendez-vous. Mais…

```text
$ hugo import jekyll blog blog_hugo
Importing...
Congratulations! 128 post(s) imported!
Now, start Hugo by yourself:
$ cd blog_hugo
$ git clone https://github.com/spf13/herring-cove.git themes/herring-cove
$ hugo server --theme=herring-cove
```

Bien sûr, l'assistant propose un thème pour embellir le projet en lieu et place
d'une transposition du language [Liquid][8] sur lequel repose les fichiers
modèles de Jekyll. C'est plus simple mais… ce n'est pas réellement ce que je
souhaitais.

[8]: https://jekyllrb.com/docs/liquid/

![Un thème par défaut pas sans défaut](/img/posts/2020-12-09-hugo-import-from-jekyll.png)

Autant le rendu des articles est impeccable avec ce thème, autant la navigation
est assez pauvre à mon goût. Bien évidemment, c'est bien suffisant pour n'importe
qui. Mais voilà. Mon thème principal me manquait et malheureusement pour moi,
il n'existait pas pour Hugo.

---

## De longues soirées d'hiver

J'aime les choses simples. Et j'aime encore plus les comprendre en profondeur.
C'est pour cette raison que je me suis lancé plusieurs heures dans la lecture
assidue de la documentation très riche sur [gohugo.io][9]. Les concepts sont
assez différents et le passage n'a pas été si évident que cela. Je vous propose
un florilège des astuces qu'il m'a fallu découvrir pour proposer le portage
intégral de mon site.

[9]: https://gohugo.io/documentation/

### Les permaliens

Jekyll et Hugo proposent une gestion fine des URL à l'aide du paramètre
`permalinks` pour reconstruire l'adresse d'une page ou d'un article et favoriser
son référencement. Cependant, leur paramètrage par défaut diffère et il est
nécessaire de retrouver le comportement de [l'un][11] avec [l'autre][12].

[11]: https://jekyllrb.com/docs/permalinks/
[12]: https://gohugo.io/content-management/urls/#permalinks

```yaml
permalinks:
  posts: /:year/:month/:day/:slug
```

Pour ma part, j'ai privilégié le dérivé `:slug` pour être en mesure de surcharger
la dernière portion de l'URL dans les rares cas où le titre était malformé entre
Jekyll et Hugo. Par exemple pour mon article « [Tour d'horizon de PgBouncer][13] »
où l'apostrophe n'était pas remplacée par le tiret et où je ne voulais pas
perdre le référencement, j'ai pu contourner le problème avec l'ajout d'une simple
ligne en en-tête du fichier Markdown.

[13]: /2020/08/21/tour-d-horizon-de-pgbouncer/

```yaml
---
title: "Tour d'horizon de PgBouncer"
slug: tour-d-horizon-de-pgbouncer
---
```

Il m'a également fallu découvrir un paramètre particulier pour ne pas prendre en
compte les accents présents dans les titres lors de la génération du _slug_.

```yaml
removePathAccents: true
```

### Syndication automatique du contenu

Pour le coup, j'ai bénéficié d'une simplification dans mon projet grâce au support
natif et avancé des flux RSS. Alors qu'avec Jekyll, je devais maintenir mes
fichiers `feed.xml` et `atom.xml` à la racine du projet, j'ai découvert avec Hugo
la notion de _[taxonomie][14]_ qui permet la classification des articles. La
taxonomie regroupe autant les sections, les catégories et les _tags_, et je trouve
ça astucieux.

[14]: https://gohugo.io/content-management/taxonomies/

Imaginons une arborescence très simple avec une page et un article :

```text
content/
├── pages
│   └── a-propos.md
└── posts
    └── 2020-11-18-quelques-outils-meconnus.md
```

Sans configuration supplémentaire, Hugo générera le contenu statique pour chacun
des éléments du projet, en consultant notamment les en-têtes pour extraire les
informations `categories` et `tags` des articles. 

La magie opère avec un ensemble de fichiers `index.xml` regroupant les éléments
d'une même taxonomie.

```text
public/
├── 2020
│   └── 11
│       └── 18
│           └── quelques-outils-meconnus
│               └── index.html
├── categories
│   ├── index.html
│   ├── index.xml
│   └── postgresql
│       ├── index.html
│       └── index.xml
├── index.html
├── index.xml
├── pages
│   ├── a-propos
│   │   └── index.html
│   ├── index.html
│   └── index.xml
└── tags
    └── administration
        ├── index.html
        └── index.xml
```

### La colorisation syntaxique

À ce sujet, j'ai eu une petite surprise avec les balises HTML jusqu'à ce que je
me penche sur la [documentation][15]. En effet, par défaut, Hugo transforme un
bloc de code Markdown en série de balises stylisées.

[15]: https://gohugo.io/content-management/syntax-highlighting/#generate-syntax-highlighter-css

```html
<div class="highlight">
<pre style="color:#f8f8f2;background-color:#272822;
            -moz-tab-size:4;-o-tab-size:4;tab-size:4">
<code class="language-sql" data-lang="sql">
  <span style="color:#66d9ef">CREATE</span> 
  <span style="color:#66d9ef">TABLE</span> people (
    id BIGINT 
    <span style="color:#66d9ef">GENERATED</span> 
    ALWAYS <span style="color:#66d9ef">AS</span> 
    <span style="color:#66d9ef">IDENTITY</span>,
    details jsonb,
    <span style="color:#66d9ef">PRIMARY</span> 
    <span style="color:#66d9ef">KEY</span> (id)
  );
</code>
</pre>
</div>
```

Puisque mon thème original proposait une feuille de style au format [SASS][16]
spécfiquement pour la colorisation syntaxique, j'ai tenté d'activer l'un des
paramètres de Hugo pour utiliser les classes de style plutôt que le comportement
ci-dessus.

[16]: https://sass-lang.com/

```yaml
pygmentsUseClasses: true
```

Le résultat était inespéré avec les classes reconnus par mes règles CSS.

```html
<div class="highlight">
<pre class="chroma">
<code class="language-sql" data-lang="sql">
  <span class="k">CREATE</span> 
  <span class="k">TABLE</span> <span class="n">people</span> 
  <span class="p">(</span>
  <span class="n">id</span> <span class="nb">BIGINT</span> 
  <span class="k">GENERATED</span> 
  <span class="n">ALWAYS</span> <span class="k">AS</span> 
  <span class="k">IDENTITY</span><span class="p">,</span>
  <span class="n">details</span> <span class="n">jsonb</span>
  <span class="p">,</span>
  <span class="k">PRIMARY</span> <span class="k">KEY</span> 
  <span class="p">(</span><span class="n">id</span><span class="p">)</span>
  <span class="p">);</span>
</code>
</pre>
</div>
```

### Les balises HTML dans le Markdown

Mes fichiers Markdown contenaient des balises HTML pour quelques effets visuels,
à savoir des encarts d'avertissement `<div>`, du surlignage `<u>` et de très 
(trop) nombreux exposants `<sup>` pour mes sources d'articles. Pour cet aspect,
Hugo est plus restrictif que Jekyll et ignore tout bonnement les balises dans le
rendu de ses pages.

```html
<!-- raw HTML omitted -->
```

Pour le coup, je n'ai pas chercher s'il existait un paramètre de configuration
qui me permettrait de lever la restriction. Ma solution de contournement fut
d'utiliser les composants _shortcodes_ pour mes quelques exceptions et la
[documentation][17] était bien suffisante pour y parvenir sereinement.

[17]: https://gohugo.io/templates/shortcode-templates/

Par exemple pour mes encarts, j'ai gagné en facilité de rédaction avec la méthode
`markdownify` fourni par le système de rendu, et je n'écris plus que du Markdown
dans mes fichiers !

```html
<!-- layout/shortcodes/message.html -->
<div class="message">{{ .Inner | markdownify }}</div>

<!-- content/posts/exemple.md -->
{\{< message >}\}
Exemple de rendu avec un lien de [documentation][17].
{\{< /message >}\}
```

_Ne pas s'attarder sur les `\` qui ne servent qu'à échapper les accolades._

---

## En bref

Au-delà des quelques paramètrages ou réécriture Markdown qui m'ont fait perdre
du temps, Hugo présente bien plus de fonctionnalités natives que ne le fait
Jekyll. Je dresse une liste non exhausitive des apports qui m'ont convaincu à
passer le cap.

* [Pagination][18] simple et intégrée
* [Temps estimé de lecture][19] avec la variable `.ReadingTime`
* Génération des pages [nettement plus rapide][20]
* Portabilité du logiciel avec **zéro** dépendance système

[18]: https://gohugo.io/templates/pagination/
[19]: https://gohugo.io/variables/page/#page-variables
[20]: https://forestry.io/blog/hugo-vs-jekyll-benchmark/

Pour conclure, je me suis résolu à héberger le projet et le rendu des pages sur
GitHub, en suivant les [instructions][21] détaillées. La [bascule][22] du nom de
domaine a ainsi été opérée ce midi et je n'ai plus à me préoccuper de mon ancienne
instance VPS ni du certificat à renouveller auprès de Let's Encrypt.

[21]: https://gohugo.io/hosting-and-deployment/hosting-on-github/
[22]: https://docs.github.com/en/free-pro-team@latest/github/working-with-github-pages/managing-a-custom-domain-for-your-github-pages-site