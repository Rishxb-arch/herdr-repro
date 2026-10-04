#!/usr/bin/env bash
# herdr 0.9.3: `pane wait-output` polls a snapshot of only the LAST 80 rows (default window, 100 ms poll).
# If a marker scrolls out of that window between two polls it is never matched (the call then hangs
# forever without --timeout) even though the marker is still in the pane's scrollback.
# `--lines 1000` (undocumented maximum; server clamps to 1000) avoids it.
# Self-contained: throwaway server under a temp HOME. Needs herdr + python3 in PATH.
# Usage: K=20 N=200 ./01_wait_output_window.sh     (K trials per variant; N rows printed after the marker)
set -u
K=${K:-20}; N=${N:-200}
T=$(mktemp -d /tmp/herdr-p2-01.XXXXXX)
export HOME=$T XDG_CONFIG_HOME=$T/.config XDG_STATE_HOME=$T/.state XDG_RUNTIME_DIR=$T/run SHELL=/bin/bash
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
herdr --version
herdr server >/dev/null 2>&1 &
for i in $(seq 50); do herdr workspace list >/dev/null 2>&1 && break; sleep 0.2; done
P=$(herdr workspace create --cwd "$T" --no-focus | python3 -c 'import sys,json;print(json.load(sys.stdin)["result"]["root_pane"]["pane_id"])')
sleep 1
declare -A hit miss
trial() { # $1=variant $2=id  rest=extra args
  local v=$1 id=$2; shift 2
  herdr pane run "$P" 'clear' >/dev/null; sleep 0.3
  # Marker is computed at runtime so the echoed command line cannot match (that is the separate issue #4161).
  ( timeout 6 herdr pane wait-output "$P" --match "NEEDLE-$id" --timeout 2500 "$@" >"$T/o" 2>&1; echo "x=$?" >>"$T/o" ) &
  local w=$!; sleep 0.4
  herdr pane run "$P" "echo NEEDLE-\$((1+1+0))x | sed 's/2x/$id/'; seq 1 $N" >/dev/null
  wait $w
  local sb; sb=$(herdr pane read "$P" --source recent --lines 1000 | grep -c "^NEEDLE-$id$")
  if tail -1 "$T/o" | grep -q 'x=0'; then hit[$v]=$(( ${hit[$v]:-0}+1 )); r=matched; else miss[$v]=$(( ${miss[$v]:-0}+1 )); r=MISSED; fi
  echo "trial $v #$id: $r (marker still in scrollback: $sb)"
}
for i in $(seq $K); do
  trial default "d$i"
  trial lines1000 "w$i" --lines 1000
done
echo "SUMMARY N=$N K=$K  default: matched=${hit[default]:-0} missed=${miss[default]:-0} | --lines 1000: matched=${hit[lines1000]:-0} missed=${miss[lines1000]:-0}"
herdr server stop >/dev/null 2>&1; rm -rf "$T"
