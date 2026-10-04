#!/usr/bin/env bash
# Does herdr sanitize control bytes in user/program-supplied display strings before drawing them to the OUTER terminal?
# Needs tmux (as a host terminal with raw pipe-pane capture). Throwaway HOME.
set -u
T=$(mktemp -d /tmp/herdr-p2-04.XXXXXX)
export HOME=$T XDG_CONFIG_HOME=$T/.config XDG_STATE_HOME=$T/.state XDG_RUNTIME_DIR=$T/run SHELL=/bin/bash TERM=xterm-256color LANG=C.UTF-8
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
S=h04$$
tmux -f /dev/null new-session -d -s $S -x 120 -y 40 "env HOME=$HOME XDG_CONFIG_HOME=$XDG_CONFIG_HOME XDG_STATE_HOME=$XDG_STATE_HOME XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR SHELL=/bin/bash TERM=xterm-256color LANG=C.UTF-8 $(command -v herdr); sleep 60"
for i in $(seq 40); do herdr workspace list >/dev/null 2>&1 && break; sleep 0.25; done; sleep 1
tmux send-keys -t $S Enter; sleep 1; tmux send-keys -t $S Escape; sleep 0.5; tmux send-keys -t $S Escape; sleep 0.5
herdr --version
P=w1:p1
rm -f $T/raw.bin; tmux pipe-pane -t $S -o "cat >> $T/raw.bin"
ESC=$'\x1b'; BEL=$'\x07'
herdr pane rename $P "PANE${ESC}]52;c;SU5KRUNUX1BBTkU=${BEL}END" >/dev/null
herdr workspace rename w1 "WS${ESC}]52;c;SU5KRUNUX1dT${BEL}END" >/dev/null
herdr tab rename w1:t1 "TAB${ESC}]52;c;SU5KRUNUX1RBQg==${BEL}END" >/dev/null
herdr notification show "TTL${ESC}]52;c;SU5KRUNUX1RUTA==${BEL}x" --body "BODY${ESC}]52;c;SU5KRUNUX0JPRFk=${BEL}y" >/dev/null
herdr pane report-metadata $P --source t --title "META${ESC}]52;c;SU5KRUNUX01FVEE=${BEL}z" >/dev/null 2>&1
# program-set window title (OSC 2) from inside the pane
herdr pane run $P "printf 'x\\033]2;OSCTITLE\\033]52;c;SU5KRUNUX09TQ1RJVExF\\007\\033\\\\y\\n'" >/dev/null
sleep 2
tmux resize-window -t $S -x 110 -y 36; sleep 1.5   # force a full repaint
tmux pipe-pane -t $S
python3 - "$T/raw.bin" <<'PY'
import sys,re,base64
d=open(sys.argv[1],'rb').read()
print("raw bytes captured:",len(d))
tags={"INJECT_PANE":"pane label","INJECT_WS":"workspace label","INJECT_TAB":"tab label","INJECT_TTL":"notification title","INJECT_BODY":"notification body","INJECT_META":"report-metadata title","INJECT_OSCTITLE":"program OSC title"}
for m in re.finditer(rb'\x1b\]52;c;([A-Za-z0-9+/=]+)(?:\x07|\x1b\\)',d):
    try: dec=base64.b64decode(m.group(1)).decode()
    except Exception: dec='?'
    print("  OSC52 SEQUENCE REACHED OUTER TERMINAL (raw ESC ] 52) with payload:",dec, "->", tags.get(dec,'?'))
print("done; any 'PANE'/'WS'/'TAB' text drawn:", [w for w in (b'PANE',b'WS',b'TAB',b'TTL',b'BODY',b'META',b'OSCTITLE') if w in d])
PY
tmux kill-session -t $S; herdr server stop >/dev/null 2>&1; sleep 1; rm -rf "$T"
