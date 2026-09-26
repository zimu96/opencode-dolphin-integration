#!/bin/sh
#
# disinstalla.sh  --  rimuove "Apri OpenCode qui" da Dolphin (KDE Plasma 6)
#
# Uso:
#   sh disinstalla.sh              rimuove tutto, comprese le impostazioni
#   sh disinstalla.sh --keep-config rimuove solo i file, lascia intatte
#                                   le impostazioni (kioslaverc, konsolerc,
#                                   dolphinui.rc)
#
# Non cancella niente di tuo: toglie solo quello che ha installato
# installa.sh, e la sua icona.
#
set -u

HOME_DIR=$HOME
BIN="$HOME_DIR/.local/bin"
MENU_DIR="$HOME_DIR/.local/share/kio/servicemenus"
ICON_DIR="$HOME_DIR/.local/share/icons/hicolor"
CONF="$HOME_DIR/.config"
KEEP=0
[ "${1:-}" = "--keep-config" ] && KEEP=1

say() { printf '%s\n' "$*"; }
step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok() { printf '    [ OK ] %s\n' "$*"; }
ko() { printf '    [-- ] %s\n' "$*"; }

step "1. Script in ~/.local/bin"
for f in opencode-here opencode-in opencode-here-check; do
	if [ -e "$BIN/$f" ]; then
		rm -f "$BIN/$f" && ok "rimosso $f"
	else
		ko "$f non c'era"
	fi
done

step "2. Voce di menu"
if [ -e "$MENU_DIR/opencode-here.desktop" ]; then
	rm -f "$MENU_DIR/opencode-here.desktop" && ok "rimossa opencode-here.desktop"
else
	ko "la voce di menu non c'era"
fi

step "3. Icona"
n=0
if [ -d "$ICON_DIR" ]; then
	find "$ICON_DIR" -name 'opencode-here.*' 2>/dev/null | while read -r f; do
		rm -f "$f"
		ok "rimossa $f"
	done
	# via le cartelle vuote
	for s in 16 22 32 48 64 128 scalable; do
		rmdir "$ICON_DIR/${s}x${s}/apps" 2>/dev/null
		rmdir "$ICON_DIR/${s}x${s}" 2>/dev/null
	done
	rmdir "$ICON_DIR" 2>/dev/null
	ok "pulite le cartelle vuote"
else
	ko "nessuna directory di icone"
fi

step "4. Cache"
rm -f "$HOME_DIR/.cache/opencode-here.log" \
	"$HOME_DIR/.cache/opencode-here-dirarg" 2>/dev/null
rm -f "$HOME_DIR"/.cache/opencode-here-ses.* 2>/dev/null
ok "pulita la cache"

if [ "$KEEP" -eq 1 ]; then
	step "5. Impostazioni: lasciate come sono (--keep-config)"
	ko "kioslaverc, konsolerc e dolphinui.rc non sono stati toccati"
else
	step "5. Impostazioni"

	# --- dolphinui.rc: togli solo la nostra riga --------------------------
	if [ -f "$CONF/dolphinui.rc" ] && grep -q 'servicemenu_opencode-here.desktop::opencodeHere' "$CONF/dolphinui.rc" 2>/dev/null; then
		sed -i '/servicemenu_opencode-here.desktop::opencodeHere/d' "$CONF/dolphinui.rc" 2>/dev/null
		ok "tolta la scorciatoia da dolphinui.rc"
	elif [ -f "$CONF/dolphinui.rc" ]; then
		ko "dolphinui.rc non conteneva la nostra scorciatoia"
	else
		ko "dolphinui.rc non esisteva"
	fi

	# --- kioslaverc: togli le due chiavi ----------------------------------
	if [ -f "$CONF/kioslaverc" ]; then
		kwriteconfig6 --file kioslaverc --group "KDE Action Restrictions" --key run_desktop_files --delete 2>/dev/null
		kwriteconfig6 --file kioslaverc --group "KDE Action Restrictions" --key "action/opencodeHere" --delete 2>/dev/null
		# queste le aggiunge installa.sh, non sono impostazioni preesistenti
		kwriteconfig6 --file kioslaverc --group "KDE Action Restrictions" --key openwith --delete 2>/dev/null
		kwriteconfig6 --file kioslaverc --group "KDE Action Restrictions" --key shell_access --delete 2>/dev/null
		ok "tolta l'autorizzazione da kioslaverc"
		# se non resta piu' niente, il file e' vuoto: non serve
		if [ ! -s "$CONF/kioslaverc" ]; then
			rm -f "$CONF/kioslaverc" && ok "kioslaverc vuoto, rimosso"
		fi
	else
		ko "kioslaverc non esisteva"
	fi

	# --- konsolerc: ripristina il backup se c'e', altrimenti togli la chiave
	if [ -f "$CONF/konsolerc.bak-opencodehere" ]; then
		cp -f "$CONF/konsolerc.bak-opencodehere" "$CONF/konsolerc" &&
			rm -f "$CONF/konsolerc.bak-opencodehere" &&
			ok "konsolerc ripristinato dal backup (impostazione di sicurezza tolta)"
	elif [ -f "$CONF/konsolerc" ]; then
		kwriteconfig6 --file konsolerc --group KonsoleWindow --key EnableSecuritySensitiveDBusAPI --delete 2>/dev/null
		ok "tolta EnableSecuritySensitiveDBusAPI da konsolerc"
	else
		ko "konsolerc non esisteva"
	fi

	# --- documentazione ----------------------------------------------------
	if [ -f "$CONF/OPENCODE-DOLPHIN.txt" ]; then
		rm -f "$CONF/OPENCODE-DOLPHIN.txt" && ok "rimossa la documentazione da ~/.config"
	fi
fi

step "6. Verifica: non deve restare nulla"
residui=0
for f in "$BIN/opencode-here" "$BIN/opencode-in" "$BIN/opencode-here-check" "$MENU_DIR/opencode-here.desktop"; do
	if [ -e "$f" ]; then
		ko "ANCORA PRESENTE: $f"
		residui=$((residui + 1))
	fi
done
if [ -d "$ICON_DIR" ] && find "$ICON_DIR" -name 'opencode-here.*' 2>/dev/null | grep -q .; then
	ko "ANCORA PRESENTI le icone in $ICON_DIR"
	residui=$((residui + 1))
fi
if [ "$residui" -eq 0 ]; then
	ok "niente residui: rimozione completa"
else
	ko "$residui residui: controlla i messaggi sopra"
fi

step "Fatto"
say "    Ora chiudi Dolphin (Ctrl+Q) e riaprilo: la voce sparira' dal menu."
say ""
say "    Per reinstallare in futuro:"
say "        sh ~/Scrivania/opencode-dolphin/installa.sh"
say ""
exit 0
