"Apri OpenCode qui" per Dolphin (KDE Plasma 6)

Verificato su: CachyOS, KDE Plasma 6.7.5, Dolphin 26.08.1, KIO 6.30,
konsole 25.x, opencode 2.0.18, Wayland.

COME SI USA
-----------
Tasto destro in Dolphin, su una cartella, su uno spazio vuoto o su un file:

    -> "Apri OpenCode qui"

opencode si apre subito nella cartella giusta e, dopo un paio di secondi, il
percorso gli compare nella casella di scrittura. Non viene inviato niente
all'AI: leggi quello che c'e' scritto, modificalo se vuoi, e premini Invio
quando decidi tu.

    cartella o spazio vuoto   ->  /percorso/della/cartella
    file                      ->  @/percorso/del/file
                                 (la @ fa si' che opencode alleghi il file)

Quando esci da opencode la finestra di konsole si chiude, come un terminale
normale.

La voce appare nel menu contestuale subito sotto "Apri terminale qui".
Esiste anche la scorciatoia Ctrl+Shift+O, che funziona solo con qualcosa
selezionato (vedi "Limiti noti").

Se per un motivo l'incolla non riesce, il percorso va negli appunti e dentro
opencode basta Ctrl+Shift+V. Solo in quel caso viene toccata la cronologia
del clipboard: se l'incolla funziona, gli appunti restano intatti.


INSTALLAZIONE
-------------
    sh ~/Scrivania/opencode-dolphin/installa.sh

Fa tutto lui: copia gli script, installa la voce di menu e l'icona, abilita
le autorizzazioni necessarie, imposta la scorciatoia, poi lancia la verifica.

Lo script e' idempotente: puoi rilanciarlo quante volte vuoi, alla seconda
esecuzione non cambia nulla. Se lo esegui come root si rifiuta, per non
scrivere i file nel /root sbagliato.

DISINSTALLAZIONE
----------------
    sh ~/Scrivania/opencode-dolphin/disinstalla.sh

Togliere tutto, comprese le impostazioni. Per lasciare intatte le
impostazioni e togliere solo i file:

    sh ~/Scrivania/opencode-dolphin/disinstalla.sh --keep-config

Il disinstallatore ripristina konsole dal backup (quindi l'opzione di
sicurezza sparisce) e NON tocca ~/.local/share/icons/hicolor, dentro la
quale ci sono anche le icone di altre applicazioni.

Dopo installazione o disinstallazione: chiudi Dolphin (Ctrl+Q) e riaprilo,
perche' tiene in memoria menu e icone.


VERIFICARE CHE FUNZIONI ANCORA
-------------------------------
    opencode-here-check          verifica (18 controlli)
    opencode-here-check --fix    verifica e ripara

Utile dopo un aggiornamento di sistema. Se la voce sparisce dal menu, il
primo tentativo e' riavviare Dolphin.


COSA VIENE INSTALLATO
---------------------
Tutto in ~/.local e ~/.config: nessun pacman -Syu lo sovrascrive o lo
rimuove.

    ~/.local/share/kio/servicemenus/opencode-here.desktop  voce di menu
    ~/.local/bin/opencode-here                            script del menu
    ~/.local/bin/opencode-in                              launcher interno
    ~/.local/bin/opencode-here-check                      verifica / ripara
    ~/.local/share/icons/hicolor/*/apps/opencode-here.*    icona (SVG + PNG)
    ~/.config/kioslaverc                                 autorizzazione KIO
    ~/.config/konsolerc                                  opzione di konsole
    ~/.config/dolphinui.rc                               scorciatoia
    ~/.config/konsolerc.bak-opencodehere                 backup di konsolerc


IMPOSTAZIONI
------------
In cima a ~/.local/bin/opencode-here, una riga per volta:

    AUTO_PASTE_IN_OPENCODE=1   incolla automatica del percorso
                                0 = solo appunti, poi Ctrl+Shift+V a mano
    PASTE_DELAY=2.5            secondi di attesa prima di incollare.
                                Sotto ~2 il testo arriva prima che opencode
                                sia pronto e si perde: meglio non toccarlo.
    CLIPBOARD_FALLBACK=1       copia negli appunti solo se l'incolla fallisce
    OPEN_FILE_IN_OPENCODE=0    1 = manda il file all'AI subito con --prompt
                                (consuma token a ogni click)
    COPY_PATH_TO_CLIPBOARD=1   copia negli appunti (usata solo come ripiego)

Non serve riavviare Dolphin per cambiarli: vengono letti a ogni click.
Per PASTE_DELAY in modo permanente, mettila in ~/.config/environment.d/ e
rifai il login.


PERCHE' RESISTE AGLI AGGIORNAMENTI
---------------------------------
1. Niente file di sistema. Tutto in ~/.local e ~/.config.

2. Il .desktop DEVE essere eseguibile, e non e' un capriccio. KIO, prima di
   eseguire una voce di un service menu, chiama
   KDesktopFile::isAuthorizedDesktopFile(), che accetta il file solo se sta
   in applications/, in autostart/, oppure se e' eseguibile o di root.
   Senza il bit +x Dolphin risponde "Non sei autorizzato ad eseguire questo
   file". E' il motivo per cui i service menu di KDE in /usr/share sono di
   root. Il --fix rimette il chmod se qualcuno lo perde.

3. Il percorso non passa dalla shell. konsole -e passa alla shell tutto cio'
   che segue, quindi un percorso con spazi verrebbe corrotto. Per questo a
   konsole diamo SOLO il percorso di opencode-in (senza spazi) e la cartella
   viaggia con variabili d'ambiente.

4. opencode viene cercato in piu' posti: OPENCODE_HERE_BIN, il PATH,
   /usr/bin, /usr/local/bin, ~/.opencode/bin, ~/.local/bin.

5. L'argomento <directory> viene verificato con opencode --help e il
   risultato viene ricordato insieme alla versione. Se una versione futura
   lo toglie, lo script ricade sul cwd e funziona uguale.

6. Il terminale non e' fissato: si prova kde-terminal-exec,
   xdg-terminal-exec, konsole, kgx, alacritty, xterm.

7. opencode-here-check controlla anche che KIO cerchi ancora le voci in
   kio/servicemenus, leggendo direttamente la libreria: se un aggiornamento
   cambiasse quel percorso, te lo segnala.


L'OPZIONE DI SICUREZZA DI KONSOLE
---------------------------------
L'incolla automatica passa dalla API D-Bus di konsole, che di default e'
SPENTA apposta. Per questo in ~/.config/konsolerc c'e':

    [KonsoleWindow]
    EnableSecuritySensitiveDBusAPI=true

In questa modalita' le applicazioni locali possono inviare testo e comandi
alle sessioni di konsole. E' il prezzo dell'incolla automatica.

Se preferisci non tenerla attiva: metti false, oppure toglie la sezione, e
imposta AUTO_PASTE_IN_OPENCODE=0. L'incolla automatica sparisce, ma restano
appunti e Ctrl+Shift+V.

Konsole legge questa impostazione all'avvio: dopo aver cambiato konsolerc
devi chiudere konsole e riaprirlo. opencode-here-check ti avvisa se non
l'hai fatto.


LIMITI NOTI
-----------
- opencode non accetta un file come argomento: risponde
  "Error: ENOTDIR: not a directory". E non esiste un'opzione per
  pre-compilare la casella di scrittura senza inviare (l'unica, --prompt,
  manda la richiesta al modello: verificato nel sorgente del TUI). Per questo
  il file finisce negli appunti con la @ davanti e lo incolli tu.

- La voce non puo' comparire nel menu hamburger (quello con l'icona a tre
  righe). Quel menu e' una lista di azioni scritta a mano nel codice di
  Dolphin (dolphinmainwindow.cpp, updateHamburgerMenu): non esiste un hook
  per azioni esterne. Mettercelo richiederebbe di patchare Dolphin, che si
  rompe a ogni aggiornamento.

- Ctrl+Shift+O funziona solo con qualcosa selezionato: se la selezione e'
  vuota KIO non esegue l'azione. Su spazio vuoto usa il tasto destro. Dolphin
  puo' anche togliere la scorciatoia da solo; non e' essenziale.

- Con piu' file selezionati la voce sparisce (X-KDE-MaxNumberOfUrls=1):
  KIO passa un solo percorso, e con piu' non saprebbe quale usare.


SE QUALCOSA NON FUNZIONA
------------------------
1. La voce non compare nel menu
   -> chiudi Dolphin (Ctrl+Q) e riaprilo
   -> poi: opencode-here-check

2. "Non sei autorizzato ad eseguire questo file"
   -> il .desktop ha perso il bit +x: opencode-here-check --fix

3. Si apre opencode ma il percorso non arriva nella casella
   -> konsole e' partito prima che tu cambiassi konsolerc: riavvialo
   -> opencode-here-check ti dice se e' questo il caso

4. opencode non parte
   -> opencode-here-check controlla anche che sia installato e che il
      terminale esista

5. Vuoi togliere il 24 e il 256 px dall'icona
   -> rm ~/.local/share/icons/hicolor/{24x24,256x256}/apps/opencode-here.png
   -> non servono, ma io li avevo generati per completezza
