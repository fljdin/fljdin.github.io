---
title: "Poissons et coquillages"
categories: [linux]
tags: [developpement, administration, interface]
date: "2024-10-14 10:30:00 +0200"
---

En tant que pur produit académique des années 2010, mon langage de script de prédilection a
toujours été le Bash (_Bourne Again Shell_). Non sans ignorer qu'il ait pu en exister d'autres, je
ne me suis jamais vraiment tourné vers d'autres shells pour automatiser les tâches du quotidien
dans mon métier de DBA.

Et pour cause, j'ai administré des centaines de serveurs de distributions très variées et il
n'était pas bien vu d'installer des dépendances systèmes lourdes pour enrichir des scripts Python
ou Perl. Nous apprenions donc à écrire des scripts portables et universels, compatibles partout
où nous déposions nos valises.

Me suis-je enfermé dans un dogme conservateur, en m'interdisant _de facto_ à me tourner vers des
shells modernes et bien plus aisés à appréhender ?

<!--more-->

---

## Beurk, le Bash

Ne faisons pas de détour, le Bash c'est moche. Puissant, pratique, universel, mais moche.

Vous pourriez penser que c'est un avis parfaitement subjectif, et qu'il ne faut pas juger un livre
à sa couverture... mais avouez-le, une partie de vous pense sensiblement la même chose que moi.
Combien d'heures ai-je pu perdre durant ma courbe d'apprentissage du langage, à cause d'un grand
nombre de subtilités et de pièges de syntaxes ?

Entre les assignations sans espace autour du signe `=`, les accolades `{}` pour les variables
contenant un signe `_`, les backticks `` ` ` `` pour les commandes subshells, ou encore les doubles
crochets `[[ ... ]]` pour les comparaisons non-POSIX, il y a de quoi s'arracher les cheveux.

Certain·e·s y verront une forme d'esthétisme ou de tradition d'une culture informatique, mais
personnellement je trouve que c'est un langage qui vieillit mal, très mal. Vous ne vous offusqueriez
pas non plus si je devais vous témoigner mon désamour le Perl, n'est-ce pas ?

```bash
# une comparaison de deux variables
[[ "$a" == "$b" ]]

# une addition et une affectation
z=$(( $x + $y ))

# une boucle for
for i in $(seq 1 10); do
    echo $i
done

# un switch case
case $1 in
    1) echo "un";;
    2) echo "deux";;
    *) echo "autre";;
esac

# une chaîne en minuscule
a=${a,,}

# une gestion des erreurs de commandes chaînées
some_command | another_command
if [[ ${PIPESTATUS[0]} -ne 0 || ${PIPESTATUS[1]} -ne 0 ]]; then
    echo "Une des commandes a échoué"
fi
```

Le [Bash][1] est apparu l'année de ma naissance, en 1989. Il a été conçu en opposition au [Bourne Shell][2]
(`sh`) pour apporter des fonctionnalités de programmation plus avancées. Il est devenu le shell par
défaut de la plupart des distributions Linux, et est devenu un standard pour tous les scripts à travers
le monde entier.

[1]: https://en.wikipedia.org/wiki/Bash_(Unix_shell)
[2]: https://en.wikipedia.org/wiki/Bourne_shell

Fort de ses années de succès, et de son emprise sur le monde Unix, le Bash s'impose parfois comme la première
porte vers la programmation pour des administrateurices système ou les étudiant·e·s en informatique. Et il
faut accepter que la qualité de ses premiers scripts n'est pas toujours au rendez-vous. Souvenez-vous des
longues heures passées sur StackOverflow à trouver la syntaxe la plus lisible ou la plus efficace, car les
réponses se révélaient aussi variées que touffues !

Et c'est l'un des plus gros problèmes que je trouve au Bash : ce langage de programmation est exigeant,
excentrique, voire [idiosyncratique][3], et qui ne pardonne pas les erreurs. Un des [paradoxes][4] que j'associe
au Bash est qu'il peut ne pas être considéré comme un véritable langage de programmation, réduisant ainsi
la volonté et l'effort de l'apprendre en profondeur par une large communauté de professionnel·le·s.

[3]: https://fr.wikipedia.org/wiki/Idiosyncrasie
[4]: https://dev.to/taikedz/your-bash-scripts-are-rubbish-use-another-language-5dh7

[Et si vos scripts Bash sont nuls, utilisez un autre langage.][5]

[5]: https://dev.to/taikedz/your-bash-scripts-are-rubbish-use-another-language-5dh7

---

## L'ami Fish, Friendly Interactive Shell

Je suis tombé sur [Fish][6] par hasard, alors que je questionnais mon usage quotidien sur [ZSH][7]. Sur
mon poste personnel, j'ai étendu mon expérience passée sur le Bash avec une configuration ZSH enrichie de
[Oh My Zsh][8]. C'était un peu le jour et la nuit dans l'interaction avec mes terminaux : la navigation,
les suggestions, les thèmes, les plugins, tout est plus fluide et plus agréable. Sa compatibilité avec
Bash m'avait alors évité de tout réapprendre.

[6]: https://fishshell.com/
[7]: https://fr.wikipedia.org/wiki/Z_Shell
[8]: https://ohmyz.sh/

Fish répond au besoin de modernité et de simplicité que je cherche sans vraiment le savoir. Contrairement
à ZSH, un grand nombre de fonctionnalités sont disponibles sans aucune configuration préalable ou plugin
à activer.

**Assistance à la commande**

- Recopie la commande incomplète et en erreur sans besoin de naviguer dans l'historique
- Accès à l'historique partiel avec les touches directionnelles dès la première frappe au clavier
- Proposition de chemins avec la complétion de la touche Tab, suivie des touches directionnelles

![](/img/fr/2024-20-14-fish-01.png)

**Auto-suggestions des chemins et des options d'une grande majorité des outils**

- Mémoire des précédents répertoires parcourus
- Support très complet des commandes Git, notamment le `git rebase -i` ❤️

![](/img/fr/2024-20-14-fish-02.png)

**Coloration plus poussée des commandes**

- une couleur différente par mot selon la syntaxe employée (variables, chemin, options)
- un rouge prononcé pour les commandes inconnues

---

## Un langage qui vous veut du bien

Pour revenir au sujet principal de cet article, Fish révolutionne notre rapport avec la rédaction
de scripts. Fini les pièges et la syntaxe qui nous ont tenu en otage durant des années. Les choses
deviennent bien plus simples et lisibles.

```fish
# une comparaison de deux variables
test "$a" = "$b"

# une addition et une affectation
set z (math $x + $y)

# une boucle for
for i in (seq 1 10)
    echo $i
end

# un switch case
case $argv[1]
    1; echo "un"
    2; echo "deux"
    *; echo "autre"
end

# une chaîne en minuscule
set a (string lower $a)

# une gestion des erreurs de commandes chaînées
some_command | another_command
if contains 1 $pipestatus
    echo "Une des commandes a échoué"
end
```

L'investissement initial pour perdre ses habitudes acquises avec Bash est modéré, notamment
le [remplacement][9] de `export` ou de l'assignation `=` par la méthode `set -x` ou `set -u`
respectivement. Mais l'enrichissement du langage par quelques nouveaux mots-clés permet
d'alléger le script avec des syntaxes claires et lisibles (`contains`, `math` ou `string`
présents dans l'exemple ci-dessus).

[9]: https://fishshell.com/docs/current/language.html#variables-export

L'ajout de plugins communautaire n'est pas en reste, si comme moi, vous en consommiez avec
Oh-My-ZSH. L'outil [Fisher][10] s'installe dans votre `~/.config/fish` et donne accès à un
gestionnaire complet et sobre. Pour ma part, j'ai pu rapidement combler mon besoin de charger
les variables d'environnement fournies par l'agent SSH (`ssh-agent`) lors du démarrage de ma
session.

[10]: https://github.com/jorgebucaran/fisher

```console
$ fisher install danhper/fish-ssh-agent
fisher install version 4.4.5
Fetching https://api.github.com/repos/danhper/fish-ssh-agent/tarball/HEAD
Installing danhper/fish-ssh-agent
           /home/florent/.config/fish/functions/__ssh_agent_is_started.fish
           /home/florent/.config/fish/functions/__ssh_agent_start.fish
           /home/florent/.config/fish/conf.d/fish-ssh-agent.fish
Updated 1 plugin/s
```

Pas de mystère, ni d'arcanes magiques, votre environnement est enrichi de nouvelles fonctions
et de scripts de démarrage, développés en Fish.

---

## Osons la modernité

La documentation du projet est très bien fournie. En plus de la page [Tutorial][1], vous trouverez
une page dédiée aux [utilisateurs de Bash][12] pour vous aider à réussir votre transition. Pour ma
part, j'y retrouve des syntaxes bien plus proches du Python, et c'est un vrai plaisir.

[11]: https://fishshell.com/docs/current/tutorial.html
[12]: https://fishshell.com/docs/current/fish_for_bash_users.html

Le projet est vivant, avec un rythme de versions régulier. Je me suis surpris moi-même à ne pas en
avoir entendu parler par d'autres collègues ou auprès des auteurices de blogs que je suis. Au cours des
dernières années, la communauté francophone a essaimé quelques bons articles qui complètent le
mien.

- [Changer de shell, de Bash à Fish][13] (2016)
- [Fish, une ligne de commande intelligente et simple d'utilisation][14] (2017)
- [Comment passer de Bash à Fish Shell sous Linux][15] (2021)
- [Migration de shell de zsh à fish][16] (2024)

[13]: https://lkdjiin.github.io/blog/2016/12/13/changer-de-shell-de-bash-a-fish/
[14]: https://ubunlog.com/fr/ligne-de-commande-fish-smart/
[15]: https://toptips.fr/comment-passer-de-bash-a-fish-shell-sous-linux/
[16]: https://blog.otso.fr/2024-01-17-passer-zsh-fish-shell

Ces temps-ci, je fais évoluer mon expérience d'utilisateur de Linux avec une transition vers Wayland
et SwayWM (j'y reviendrais dans un autre article). Je ne le cache pas, la tentation de remplacer mes
scripts Bash qui gèrent mes thèmes ou les composants _swaybar_, est forte, très forte.

De quoi occuper mes prochaines longues soirées d'hiver.
