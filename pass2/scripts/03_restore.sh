#!/usr/bin/env bash
# Session persistence: build layout (2 workspaces, tabs, split panes, renamed panes/tabs, cwd, env, scrollback),
# then (a) `server stop` + restart, (b) kill -9 + restart; compare layout/labels/cwd/scrollback/process.
set -u
T=$(mktemp -d /tmp/herdr-p2-03.XXXXXX)
export HOME=$T XDG_CONFIG_HOME=$T/.config XDG_STATE_HOME=$T/.state XDG_RUNTIME_DIR=$T/run SHELL=/bin/bash
mkdir -p "$XDG_RUNTIME_DIR" $T/dirA $T/dirB $T/"dir with space"; chmod 700 "$XDG_RUNTIME_DIR"
J() { python3 -c "import sys,json;d=json.load(sys.stdin);print($1)"; }
start() { herdr server >/dev/null 2>&1 & SRV=$!; for i in $(seq 60); do herdr workspace list >/dev/null 2>&1 && break; sleep 0.2; done; sleep 1; }
snap() { echo "## $1"; herdr workspace list | J '[(w["workspace_id"],w["label"],w["pane_count"],w["tab_count"]) for w in d["result"]["workspaces"]]'
  herdr tab list | J '[(t["tab_id"],t["label"],t["pane_count"]) for t in d["result"]["tabs"]]'
  herdr pane list | J '[(p["pane_id"],p["cwd"].replace("'$T'","$T"),p.get("label")) for p in d["result"]["panes"]]'; }
start; herdr --version
W1=$(herdr workspace create --cwd $T/dirA --label alpha --no-focus | J 'd["result"]["workspace"]["workspace_id"]')
W2=$(herdr workspace create --cwd "$T/dir with space" --label "beta ünï 日本" --no-focus | J 'd["result"]["workspace"]["workspace_id"]')
P1=$(herdr pane list --workspace $W1 | J 'd["result"]["panes"][0]["pane_id"]')
P2=$(herdr pane split $P1 --direction right --cwd $T/dirB --no-focus | J 'd["result"]["pane"]["pane_id"]')
herdr pane rename $P2 "my pane 🚀" >/dev/null
herdr tab create --workspace $W1 --label "tab two" --no-focus >/dev/null
herdr pane run $P1 'export FOO=bar; seq 1 3000 | tail -n 3; echo SCROLLBACK_MARK; sleep 1000 & echo started' >/dev/null
sleep 2
snap before
herdr pane read $P1 --source recent --lines 5 | python3 -c 'import sys;print(repr(sys.stdin.read()))'
herdr server stop >/dev/null 2>&1; sleep 2; echo "server pid $SRV alive after stop: $(kill -0 $SRV 2>/dev/null && echo yes || echo no)"
start; snap "after graceful stop+restart"
herdr pane read $P1 --source recent --lines 8 | python3 -c 'import sys;print(repr(sys.stdin.read()))'
herdr pane run $P1 'echo FOO=$FOO; jobs; pwd' >/dev/null; sleep 1
herdr pane read $P1 --source recent --lines 4 | python3 -c 'import sys;print(repr(sys.stdin.read()))'
kill -9 $SRV; sleep 1
start; snap "after kill -9 + restart"
herdr pane read $P1 --source recent --lines 8 | python3 -c 'import sys;print(repr(sys.stdin.read()))'
herdr server stop >/dev/null 2>&1; sleep 1; rm -rf $T
