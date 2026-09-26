#!/bin/sh
#
# installa.sh  --  installa "Apri OpenCode qui" per Dolphin (KDE Plasma 6)
#
# Cosa fa, in ordine:
#   1. copia gli script in ~/.local/bin e li rende eseguibili
#   2. installa la voce di menu in ~/.local/share/kio/servicemenus/
#   3. installa l'icona nel tema hicolor (SVG + PNG di fallback)
#   4. abilita le autorizzazioni necessarie (kioslaverc, konsolerc, dolphinui.rc)
#   5. lancia opencode-here-check per verificare
#
# Tutto sta in ~/.local e ~/.config: nessun aggiornamento di pacman lo tocca.
# Lo script e' idempotente: puoi rilanciarlo quante volte vuoi.
#
#Uso:   sh installa.sh          (oppure:  ./installa.sh)
#       sh installa.sh --remove rimuove tutto
#
set -u

HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
HOME_DIR=$HOME
BIN="$HOME_DIR/.local/bin"
MENU_DIR="$HOME_DIR/.local/share/kio/servicemenus"
ICON_DIR="$HOME_DIR/.local/share/icons/hicolor"
CONF="$HOME_DIR/.config"

say() { printf '%s\n' "$*"; }
step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok() { printf '    [ OK ] %s\n' "$*"; }
warn() { printf '    [!! ] %s\n' "$*"; }
ko() { printf '    [KO ] %s\n' "$*"; }

# ---------------------------------------------------------------------------
# rimuovi
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--remove" ]; then
	step "Rimozione"
	for f in "$BIN/opencode-here" "$BIN/opencode-in" "$BIN/opencode-here-check"; do
		if [ -e "$f" ]; then
			rm -f "$f" && ok "rimosso $f"
		fi
	done
	if [ -e "$MENU_DIR/opencode-here.desktop" ]; then
		rm -f "$MENU_DIR/opencode-here.desktop" && ok "rimossa la voce di menu"
	fi
	find "$ICON_DIR" -name 'opencode-here.*' 2>/dev/null | while read -r f; do
		rm -f "$f" && ok "rimossa icona $f"
	done
	# la scorciatoia: solo se Punta a questa installazione
	if [ -f "$CONF/dolphinui.rc" ] && grep -q 'servicemenu_opencode-here.desktop::opencodeHere' "$CONF/dolphinui.rc" 2>/dev/null; then
		sed -i '/servicemenu_opencode-here.desktop::opencodeHere/d' "$CONF/dolphinui.rc" 2>/dev/null
		ok "rimossa la scorciatoia da dolphinui.rc"
	fi
	rm -f "$HOME_DIR/.cache/opencode-here.log" "$HOME_DIR/.cache/opencode-here-dirarg" 2>/dev/null
	rm -f "$HOME_DIR"/.cache/opencode-here-ses.* 2>/dev/null
	say ""
	say "Fatto. Ora chiudi Dolphin (Ctrl+Q) e riaprilo."
	ok "per annullare anche le impostazioni: kwriteconfig6 --file kioslaverc --group 'KDE Action Restrictions' --key run_desktop_files --type bool false"
	exit 0
fi

# ---------------------------------------------------------------------------
# controlli preliminari
# ---------------------------------------------------------------------------
step "Controlli preliminari"
[ -f "$HERE/opencode-here" ] && [ -f "$HERE/opencode-in" ] && [ -f "$HERE/opencode-here-check" ] || {
	ko "lo script deve stare nella stessa cartella di opencode-here, opencode-in, opencode-here-check"
	exit 1
}
ok "i file sorgente sono presenti"

if [ "$(id -u)" -eq 0 ]; then
	warn "lo stai eseguendo come root: NON farlo, altrimenti i file finiscono nel tuo /root"
	exit 1
fi

command -v opencode >/dev/null 2>&1 || [ -x /usr/bin/opencode ] || {
	warn "opencode non trovato. Installalo e rilancia lo script."
}
ok "opencode presente"

terminale=""
for t in kde-terminal-exec xdg-terminal-exec konsole kgx alacritty xterm; do
	command -v "$t" >/dev/null 2>&1 && { terminale=$t; break; }
done
if [ -n "$terminale" ]; then
	ok "terminale: $terminale"
else
	ko "nessun terminale trovato (konsole, kgx, alacritty, xterm...)"
fi

# ---------------------------------------------------------------------------
# 1. script
# ---------------------------------------------------------------------------
step "1. Script in ~/.local/bin"
mkdir -p "$BIN" || exit 1
for s in opencode-here opencode-in opencode-here-check; do
	cp -f "$HERE/$s" "$BIN/$s" && chmod +x "$BIN/$s" && ok "$s"
done

# ---------------------------------------------------------------------------
# 2. voce di menu
# ---------------------------------------------------------------------------
step "2. Voce di menu in ~/.local/share/kio/servicemenus"
mkdir -p "$MENU_DIR" || exit 1
cp -f "$HERE/opencode-here.desktop" "$MENU_DIR/opencode-here.desktop" || exit 1
# ATTENZIONE: KIO pretende che il .desktop sia eseguibile, altrimenti lo
# rifiuta con "Non sei autorizzato ad eseguire questo file".
chmod +x "$MENU_DIR/opencode-here.desktop"
ok "opencode-here.desktop installato ed eseguibile"

# ---------------------------------------------------------------------------
# 3. icona
# ---------------------------------------------------------------------------
step "3. Icona nel tema hicolor"
if [ -f "$HERE/opencode-here.svg" ]; then
	mkdir -p "$ICON_DIR/scalable/apps" || exit 1
	cp -f "$HERE/opencode-here.svg" "$ICON_DIR/scalable/apps/opencode-here.svg"
	ok "SVG installato"
	if command -v rsvg-convert >/dev/null 2>&1; then
		for s in 16 22 32 48 64 128; do
			mkdir -p "$ICON_DIR/${s}x${s}/apps"
			rsvg-convert -w "$s" -h "$s" "$ICON_DIR/scalable/apps/opencode-here.svg" \
				-o "$ICON_DIR/${s}x${s}/apps/opencode-here.png" 2>/dev/null
		done
		ok "PNG di fallback generati (6 risoluzioni)"
	else
		warn "rsvg-concast non trovato: mancano i PNG, si vedra' solo l'SVG"
	fi
else
	warn "opencode-here.svg non trovato: la voce sara' senza icona"
fi

# ---------------------------------------------------------------------------
# 4. permessi e scorciatoia
# ---------------------------------------------------------------------------
step "4. Autorizzazioni e scorciatoia"

# kio/servicemenus e' la directory che KIO legge
if [ -d "$MENU_DIR" ]; then ok "KIO trovera' la voce in kio/servicemenus"; else ko "directory kio/servicemenus mancante"; fi

# autorizzazione KIO: senza questa KIO puo' bloccare i file .desktop utente
kwriteconfig6 --file kioslaverc --group "KDE Action Restrictions" --key run_desktop_files --type bool true 2>/dev/null
kwriteconfig6 --file kioslaverc --group "KDE Action Restrictions" --key "action/opencodeHere" --type bool true 2>/dev/null
ok "kioslaverc: run_desktop_files e action/opencodeHere autorizzati"

# konsole: serve per iniettare il percorso nella casella di opencode
# (e' l'API di incolla di konsole, quella di Ctrl+Shift+V)
if kreadconfig6 --file konsolerc --group KonsoleWindow --key EnableSecuritySensitiveDBusAPI 2>/dev/null | grep -q true; then
	ok "konsolerc: API D-Bus gia' abilitata"
else
	if [ ! -f "$CONF/konsolerc.bak-opencodehere" ]; then
		cp -f "$CONF/konsolerc" "$CONF/konsolerc.bak-opencodehere" 2>/dev/null || true
		ok "backup di konsolerc salvato in ~/.config/konsolerc.bak-opencodehere"
	fi
	kwriteconfig6 --file konsolerc --group KonsoleWindow --key EnableSecuritySensitiveDBusAPI --type bool true 2>/dev/null
	ok "konsolerc: EnableSecuritySensitiveDBusAPI=true"
fi

# scorciatoia Ctrl+Shift+O (Dolphin la registra da sola come azione dei
# service menu: noi scriviamo solo la scorciatoia nel suo file XML)
if [ ! -f "$CONF/dolphinui.rc" ]; then
	printf '<?xml version="1.0" encoding="UTF-8"?>\n<kxmlgui version="1">\n<ActionProperties>\n' >"$CONF/dolphinui.rc"
	printf '<action name="servicemenu_opencode-here.desktop::opencodeHere" shortcut="Ctrl+Shift+O"/>\n' >>"$CONF/dolphinui.rc"
	printf '</ActionProperties>\n</kxmlgui>\n' >>"$CONF/dolphinui.rc"
	ok "dolphinui.rc creato con Ctrl+Shift+O"
elif grep -q 'servicemenu_opencode-here.desktop::opencodeHere' "$CONF/dolphinui.rc" 2>/dev/null; then
	ok "scorciatoia gia' presente in dolphinui.rc"
else
	# il file c'e' ma senza la nostra riga: la inseriamo prima della chiusura
	if grep -q '</ActionProperties>' "$CONF/dolphinui.rc" 2>/dev/null; then
		sed -i 's|</ActionProperties>|<action name="servicemenu_opencode-here.desktop::opencodeHere" shortcut="Ctrl+Shift+O"/>\n</ActionProperties>|' \
			"$CONF/dolphinui.rc" 2>/dev/null
		ok "scorciatoia Ctrl+Shift+O aggiunta a dolphinui.rc"
	else
		warn "dolphinui.rc non e' un XML valido: la scorciatoia va messa a mano"
		say "        Dolphin -> Configura -> Scorciatoie -> categoria"
		say "        'Azioni del menu contestuali' -> 'Apri OpenCode qui'"
	fi
fi

# ---------------------------------------------------------------------------
# 5. verifica
# ---------------------------------------------------------------------------
step "5. Verifica"
if [ -x "$BIN/opencode-here-check" ]; then
	"$BIN/opencode-here-check"
	rc=$?
else
	ko "opencode-here-check non eseguibile"
	rc=1
fi

step "Fatto"
say "    Ora chiudi Dolphin (Ctrl+Q) e riaprilo: cosi' ricarica menu e icone."
say "    Poi: tasto destro in una cartella -> 'Apri OpenCode qui'."
say ""
say "    Se un giorno qualcosa smette di funzionare dopo un aggiornamento:"
say "        opencode-here-check          # verifica"
say "        opencode-here-check --fix    # verifica e ripara"
say ""
say "    Per disattivare l'incolla automatica, apri Konsole e togli"
say "    'Abilita le parti sensibili dell'API DBus' (Impostazioni -> Generale)."
say "    Per togliere tutto:  sh ~/Scrivania/opencode-dolphin/disinstalla.sh"
say ""
exit $rc
