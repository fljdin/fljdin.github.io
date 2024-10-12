---
title: "Gestion des signaux internes"
date: 2020-01-17 20:00:00 +0200
categories: [postgresql, linux]
tags: [developpement]
---

Je voulais m'attarder sur une notion que je n'avais pas exploré à l'époque où 
j'apprenais à naviguer dans un terminal GNU/Linux sur les sièges de l'école et 
où l'on usait de commandes apprises par cœur : les signaux !

Les signaux les plus connus et les plus utilisés sont les numéros 6 `SIGABRT` et 
9 `SIGKILL`, ça vous revient ? Pourquoi en existe-t-il autant, dans quels 
contextes sont-ils nécessaires et de quelles façons les configure-t-on ? Prenons 
le temps de (re)découvrir les signaux UNIX et leurs utilisations dans PostgreSQL !

<!--more-->

---

Commençons sobrement par une description issue de [Wikipédia][1] :

[1]: https://fr.wikipedia.org/wiki/Signal_(informatique)

> Un signal est une forme limitée de communication entre processus utilisée par 
> les systèmes de type Unix et ceux respectant les standards POSIX. Il s'agit 
> d'une notification asynchrone envoyée à un processus pour lui signaler 
> l'apparition d'un événement. Quand un signal est envoyé à un processus, le 
> système d'exploitation interrompt l'exécution normale de celui-ci. Si le 
> processus possède une routine de traitement pour le signal reçu, il lance son 
> exécution. Dans le cas contraire, il exécute la routine de traitement des
> signaux par défaut.

En somme, les signaux sont de simples événements à destination d'un processus 
pour ordonner une action, comme l'éveil, l'arrêt, la lecture d'un fichier de 
configuration ou le repli sur un champ de bataille (non, pas ce signal-là).

![Gestion des signaux en temps de guerre arthurienne](/img/fr/2020-01-17-drapeaux-kaamelott.jpg)

Tout administrateur qui se respecte (ou non) connaît la commande `kill` fournie 
par son système pour résoudre le problème épineux des programmes qui font n'importe
quoi -- d'après leurs dires -- en leur envoyant un message d'arrêt. Ces messages 
sont nombreux et permettent différentes réactions en s'inspirant de cette fameuse 
norme POSIX.1-1990 dont je vous renvoie au tableau du [manuel][2] `signal(7)` ou 
la commande `kill -l` pour les lister.

[2]: http://man7.org/linux/man-pages/man7/signal.7.html

```sh
kill -l

#  1) SIGHUP       2) SIGINT       3) SIGQUIT      4) SIGILL       5) SIGTRAP
#  6) SIGABRT      7) SIGBUS       8) SIGFPE       9) SIGKILL     10) SIGUSR1
# 11) SIGSEGV     12) SIGUSR2     13) SIGPIPE     14) SIGALRM     15) SIGTERM
# 16) SIGSTKFLT   17) SIGCHLD     18) SIGCONT     19) SIGSTOP     20) SIGTSTP
# 21) SIGTTIN     22) SIGTTOU     23) SIGURG      24) SIGXCPU     25) SIGXFSZ
# 26) SIGVTALRM   27) SIGPROF     28) SIGWINCH    29) SIGIO       30) SIGPWR
# 31) SIGSYS      34) SIGRTMIN    35) SIGRTMIN+1  36) SIGRTMIN+2  37) SIGRTMIN+3
# 38) SIGRTMIN+4  39) SIGRTMIN+5  40) SIGRTMIN+6  41) SIGRTMIN+7  42) SIGRTMIN+8
# 43) SIGRTMIN+9  44) SIGRTMIN+10 45) SIGRTMIN+11 46) SIGRTMIN+12 47) SIGRTMIN+13
# 48) SIGRTMIN+14 49) SIGRTMIN+15 50) SIGRTMAX-14 51) SIGRTMAX-13 52) SIGRTMAX-12
# 53) SIGRTMAX-11 54) SIGRTMAX-10 55) SIGRTMAX-9  56) SIGRTMAX-8  57) SIGRTMAX-7
# 58) SIGRTMAX-6  59) SIGRTMAX-5  60) SIGRTMAX-4  61) SIGRTMAX-3  62) SIGRTMAX-2
# 63) SIGRTMAX-1  64) SIGRTMAX 
```

À l'aide de cette commande, il est possible d'interragir avec un processus actif 
dès lors que l'on a connaissance de son `pid`, le _process identifier_. La plupart 
du temps, nous ignorons tout bonnement l'état dans lequel il se trouve. Est-il
en attente ? Fait-il un calcul important ? 

Trop souvent, en l'absence de journaux d'activité ou de verbosité du processus, 
d'impatience ou d'urgence, on lui envoie un message d'auto-suicide `kill -9 pid`. 
Et prends ça dans tes circuits logiques.

---

À son démarrage, un programme met en place une série d'instructions à l'aide de 
méthodes comme `trap` ([documentation][3]) pour un script _bash_ ou de la librairie 
`signal.h` pour un programme en C. Ces outils permettent de surcharger les 
comportements du programme à la réception d'un signal en leur associant une 
instruction ou une fonction plus complexe. Prenons l'exemple d'un bête terminal, 
qui en soit, est un programme en attente de saisie utilisateur,  dispose d'un
`pid` et d'un interpréteur _bash_.

[3]: http://man7.org/linux/man-pages/man1/trap.1p.html

```sh
# Obtenir le pid du terminal tty courant
echo $$
# 5032

# Définir les comportements attendus
trap 'echo SIGUSR1 received' 10
trap 'date' 12

kill -SIGUSR1 5032
# SIGUSR1 received
kill -SIGUSR2 5032
# ven. janv. 17 16:29:10 CET 2020
```

Cela devient particulièrement intéressant dans un contexte de programme 
multi-processeurs, de pouvoir se reposer sur un système de signaux pour déclencher 
les événements entre un processus père et ses enfants, plutôt que de complexifier
les échanges avec une _queue_ en mémoire ou sur fichier.

Si l'on prend l'exemple du processus `archiver` de PostgreSQL, la définition des 
signaux est la première étape au moment de sa création par le processus `postmaster`, 
juste avant l'entrée dans sa boucle principale.

```c
// src/backend/postmaster/pgarch.c
/*
 * PgArchiverMain
 *
 *  The argc/argv parameters are valid only in EXEC_BACKEND case.  However,
 *  since we don't use 'em, it hardly matters...
 */
NON_EXEC_STATIC void
PgArchiverMain(int argc, char *argv[])
{
  /*
   * Ignore all signals usually bound to some action in the postmaster,
   * except for SIGHUP, SIGTERM, SIGUSR1, SIGUSR2, and SIGQUIT.
   */
  pqsignal(SIGHUP, SignalHandlerForConfigReload);
  pqsignal(SIGINT, SIG_IGN);
  pqsignal(SIGTERM, SignalHandlerForShutdownRequest);
  pqsignal(SIGQUIT, pgarch_exit);
  pqsignal(SIGALRM, SIG_IGN);
  pqsignal(SIGPIPE, SIG_IGN);
  pqsignal(SIGUSR1, pgarch_waken);
  pqsignal(SIGUSR2, pgarch_waken_stop);
  /* Reset some signals that are accepted by postmaster but not here */
  pqsignal(SIGCHLD, SIG_DFL);
  PG_SETMASK(&UnBlockSig);

  /*
   * Identify myself via ps
   */
  init_ps_display("archiver", "", "", "");

  pgarch_MainLoop();

  exit(0);
}
```

La méthode `pqsignal` prend en paramètre la valeur `enum` du signal ainsi qu'un 
pointeur de fonction selon l'événement que l'on veut provoquer. Dans PostgreSQL,
certains paramètres d'instance sont dynamiques et doivent être réactualisés sans 
interrompre le processus, c'est notamment le cas pour le processus `archiver` 
et son paramètre `archive_command` qui définit la méthode d'archivage lorsqu'un 
journal de transaction doit être archivé.

```c
// src/backend/postmaster/interrupt.c
/*
 * Simple signal handler for triggering a configuration reload.
 *
 * Normally, this handler would be used for SIGHUP. The idea is that code
 * which uses it would arrange to check the ConfigReloadPending flag at
 * convenient places inside main loops, or else call HandleMainLoopInterrupts.
 */
void
SignalHandlerForConfigReload(SIGNAL_ARGS)
{
  int      save_errno = errno;

  ConfigReloadPending = true;
  SetLatch(MyLatch);

  errno = save_errno;
}
```

Ainsi, lorsque le processus `archiver` reçoit un signal `SIGHUP`, il active le 
_flag_ `ConfigReloadPending` qui sera traité au sein de la boucle principale 
`pgarch_MainLoop()` et déclenchera la relecture du fichier de configuration avec
la function `ProcessConfigFile()`.

```c
// src/backend/postmaster/pgarch.c
/*
 * pgarch_MainLoop
 *
 * Main loop for archiver
 */
static void
pgarch_MainLoop(void)
{
  ...
  do
  {
    ...
    /* Check for config update */
    if (ConfigReloadPending)
    {
      ConfigReloadPending = false;
      ProcessConfigFile(PGC_SIGHUP);
    }
    ...
  } while (!time_to_stop);
}
```

---

Les déclencheurs de signaux sont multiples et peuvent venir des propres enfants 
du `postmater` pour annoncer un événement ou un changement d'état en usant 
principalement du signal `SIGUSR1`. Ces événements internes sont nécessaires pour 
coordonner les processus comme par exemple, demander au `walwriter` de changer 
de journal de transactions ou à l'`autovacuum launcher` de créer un nouveau 
processus `autovacuum worker`. 
Les différents événements sont référencés par l'énumération `PMSignalReason` 
décrite dans le fichier `src/include/storage/pmsignal.h`.

L'administrateur peut également provoquer ces signaux et ses effets mais inutile
de préciser qu'il est formellement déconseillé de passer par la commande `kill` !
Préférez les outils `systemctl` ou `pg_ctl` pour recharger (`reload`) la 
configuration ou les [fonctions SQL][4] prévues pour envoyer des signaux internes.

[4]: https://www.postgresql.org/docs/current/functions-admin.html#FUNCTIONS-ADMIN-SIGNAL

{{< message >}}
Je remercie par avance tou·te·s les relecteur·rice·s qui me feront des remarques 
toujours enrichissantes ! J'espère que cet article vous a plu et que vous avez 
pris plaisir comme moi à parcourir quelques fichiers du code source du projet 
libre PostgreSQL !
{{< /message >}}