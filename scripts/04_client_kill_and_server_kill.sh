#!/usr/bin/env bash
# Needs tmux. Attach the TUI client in tmux, kill the client, check the agent process survives; then SIGKILL the server.
set -u; . "$(dirname "$0")/common.sh" "$1"; trap 'stop_server; tmux kill-server 2>/dev/null' EXIT; start_server
P=$(pane_of survive); echo idle > "$FAKE_SCENARIO_FILE"; herdr pane run "$P" claude >/dev/null; sleep 3
tmux kill-server 2>/dev/null; tmux new-session -d -x 150 -y 45 -s hc "$HERDR_BIN"; sleep 3
echo "agent pid before: $(pgrep -f '^[^ ]*python3 [^ ]*/fakeagents/claude$')"; tmux kill-session -t hc; sleep 1
echo "after killing the client: agent pid=$(pgrep -f '^[^ ]*python3 [^ ]*/fakeagents/claude$')  herdr says: $(agent_of $P)"
SP=$(pgrep -f "^[^ ]*herdr server$" | head -1); kill -9 "$SP"; sleep 1
echo "after SIGKILL of server: agent pid='$(pgrep -f '^[^ ]*python3 [^ ]*/fakeagents/claude$')' (empty = agent died with the server)"
start_server; Q=$(herdr pane list | python3 -c 'import json,sys; ps=json.load(sys.stdin)["result"]["panes"]; print(len(ps), ps[0]["pane_id"])')
echo "after restart: panes=${Q% *}, first pane agent: $(agent_of ${Q#* })"
