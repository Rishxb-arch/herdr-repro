# Source me. Runs herdr in a throwaway HOME so nothing touches your real config.
# usage: . scripts/common.sh <path-to-herdr-binary>
export HERDR_BIN="$(readlink -f "${1:?path to herdr binary}")"
export ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SANDBOX="$(mktemp -d /tmp/herdr-repro.XXXXXX)"
export HOME="$SANDBOX" XDG_CONFIG_HOME="$SANDBOX/.config" XDG_STATE_HOME="$SANDBOX/.state" XDG_RUNTIME_DIR="$SANDBOX/run"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
export FAKE_SCENARIO_FILE="$SANDBOX/scenario" FAKE_RELEASE_FILE="$SANDBOX/release"
export PATH="$ROOT/fakeagents:$PATH"
herdr() { "$HERDR_BIN" "$@"; }
start_server() { ( "$HERDR_BIN" server >"$SANDBOX/server.out" 2>&1 & ); for _ in $(seq 20); do [ -S "$XDG_CONFIG_HOME/herdr/herdr.sock" ] && break; sleep 0.5; done; sleep 1; }
stop_server() { "$HERDR_BIN" server stop >/dev/null 2>&1; pkill -f '^[^ ]*python3 [^ ]*/fakeagents/(claude|cursor)( |$)' 2>/dev/null; true; }
pane_of() { "$HERDR_BIN" workspace create --cwd "${2:-$SANDBOX}" --label "$1" --no-focus | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["root_pane"]["pane_id"])'; }
agent_of() { "$HERDR_BIN" pane get "$1" | python3 -c 'import json,sys; r=json.load(sys.stdin)["result"]["pane"]; print(r.get("agent"), r["agent_status"])'; }
