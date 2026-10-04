#!/usr/bin/env bash
# Large-output / memory probe: push N MB through panes (many short lines, one giant line, binary garbage),
# watch server RSS and API responsiveness.
set -u
MB=${MB:-300}
T=$(mktemp -d /tmp/herdr-p2-05.XXXXXX)
export HOME=$T XDG_CONFIG_HOME=$T/.config XDG_STATE_HOME=$T/.state XDG_RUNTIME_DIR=$T/run SHELL=/bin/bash
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
herdr --version
herdr server >/dev/null 2>&1 & SRV=$!
for i in $(seq 50); do herdr workspace list >/dev/null 2>&1 && break; sleep 0.2; done
J() { python3 -c "import sys,json;d=json.load(sys.stdin);print($1)"; }
P=$(herdr workspace create --cwd "$T" --no-focus | J 'd["result"]["root_pane"]["pane_id"]')
rss() { awk '/VmRSS/{print $2/1024 " MB"}' /proc/$SRV/status; }
lat() { local s=$(date +%s.%N); herdr pane list >/dev/null; python3 -c "print('api latency %.0f ms'%((${EPOCHREALTIME}-$s)*1000))" 2>/dev/null || true; }
echo "start RSS: $(rss)"
run() { # label cmd
  local s=$(date +%s.%N)
  herdr pane run $P "$2; echo; echo DONE_$1" >/dev/null
  herdr pane wait-output $P --regex "^DONE_$1\$" --lines 1000 --timeout 180000 >/dev/null 2>&1; local rc=$?
  local e=$(date +%s.%N)
  printf '%-12s rc=%s  %.1fs  RSS=%s\n' "$1" $rc $(python3 -c "print($e-$s)") "$(rss)"
}
run lines   "yes 'the quick brown fox jumps over the lazy dog 0123456789' | head -c ${MB}000000"
run giantline "head -c $((MB/3))000000 /dev/zero | tr '\\0' 'x'; echo"
run binary  "head -c $((MB/3))000000 /dev/urandom"
run lines2  "yes 'again' | head -c 50000000"
herdr pane run $P 'reset' >/dev/null; sleep 1
s=$(date +%s%N); herdr pane list >/dev/null; e=$(date +%s%N); echo "api latency after: $(( (e-s)/1000000 )) ms; RSS=$(rss)"
herdr pane read $P --source visible | tail -3
echo "scrollback_limit_bytes default = 10000000 (10 MB) per pane"
herdr server stop >/dev/null 2>&1; rm -rf "$T"
