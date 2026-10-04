#!/usr/bin/env bash
# Concurrency probe: fire many CLI mutations in parallel against one server; check for errors,
# duplicate IDs, inconsistent counts, server panics.
set -u
T=$(mktemp -d /tmp/herdr-p2-02.XXXXXX)
export HOME=$T XDG_CONFIG_HOME=$T/.config XDG_STATE_HOME=$T/.state XDG_RUNTIME_DIR=$T/run SHELL=/bin/bash
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
herdr --version
herdr server >/dev/null 2>&1 &
for i in $(seq 50); do herdr workspace list >/dev/null 2>&1 && break; sleep 0.2; done
J() { python3 -c "import sys,json;d=json.load(sys.stdin);print($1)"; }
WS=$(herdr workspace create --cwd "$T" --no-focus | J 'd["result"]["workspace"]["workspace_id"]')
P0=$(herdr pane list --workspace "$WS" | J 'd["result"]["panes"][0]["pane_id"]')
echo "ws=$WS root=$P0"
mkdir -p $T/o
# 1) 30 parallel splits of the same pane
pids=""; for i in $(seq 30); do ( herdr pane split "$P0" --direction right --no-focus >$T/o/s$i 2>&1; echo "rc=$?" >>$T/o/s$i ) & pids="$pids $!"; done; wait $pids
ok=$(grep -l '"pane_id"' $T/o/s* | wc -l); echo "splits ok=$ok / 30"
grep -h -o '"code":"[a-z_]*"' $T/o/s* | sort | uniq -c
ids=$(cat $T/o/s* | grep -o '"pane":{[^}]*"pane_id":"[^"]*"' | grep -o '"pane_id":"[^"]*"' | sort)
echo "unique ids returned: $(echo "$ids" | sort -u | wc -l) of $(echo "$ids" | wc -l)"
echo "pane list count: $(herdr pane list --workspace $WS | J 'len(d["result"]["panes"])') (expected $((ok+1)))"
# 2) parallel close of all but root + parallel splits again
LIST=$(herdr pane list --workspace "$WS" | J '" ".join(p["pane_id"] for p in d["result"]["panes"])')
rm -f $T/o/*
pids=""; n=0; for p in $LIST; do [ "$p" = "$P0" ] && continue; n=$((n+1)); ( herdr pane close "$p" >$T/o/c$n 2>&1; echo "rc=$?" >>$T/o/c$n ) & pids="$pids $!"; done
for i in $(seq 10); do ( herdr pane split "$P0" --direction down --no-focus >$T/o/t$i 2>&1; echo "rc=$?" >>$T/o/t$i ) & pids="$pids $!"; done; wait $pids
echo "close results:"; cat $T/o/c* | grep -o '"code":"[a-z_]*"\|"type":"[a-z_]*"' | sort | uniq -c
echo "split-during-close results:"; cat $T/o/t* | grep -o '"code":"[a-z_]*"\|"type":"[a-z_]*"' | sort | uniq -c
echo "final panes: $(herdr pane list --workspace $WS | J 'len(d["result"]["panes"])')"
# 3) parallel workspace/tab creation
rm -f $T/o/*
pids=""; for i in $(seq 15); do ( herdr workspace create --cwd "$T" --no-focus >$T/o/w$i 2>&1 ) & pids="$pids $!"; ( herdr tab create --workspace "$WS" --no-focus >$T/o/x$i 2>&1 ) & pids="$pids $!"; done; wait $pids
echo "workspaces: $(herdr workspace list | J 'len(d["result"]["workspaces"])') (expected 16)"
echo "tabs in $WS: $(herdr tab list --workspace $WS | J 'len(d["result"]["tabs"])')"
echo "workspace ids unique: $(herdr workspace list | J 'len(set(w["workspace_id"] for w in d["result"]["workspaces"]))')"
echo "--- server log panics/errors:"; grep -i -E "panic|error|warn" $XDG_CONFIG_HOME/herdr/herdr-server.log | tail -10
herdr status server | head -3
herdr server stop >/dev/null 2>&1; rm -rf "$T"
