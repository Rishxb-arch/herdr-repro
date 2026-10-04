#!/usr/bin/env bash
# agent prompt delivery + wait semantics with an interactive fake `claude` (no real agent, no network).
# Checks: exact text received for tricky prompts, return state of `--wait`, concurrent prompts.
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d /tmp/herdr-p2-06.XXXXXX)
export HOME=$T XDG_CONFIG_HOME=$T/.config XDG_STATE_HOME=$T/.state XDG_RUNTIME_DIR=$T/run SHELL=/bin/bash
export PATH=$HERE/fakeagents:$PATH FAKE_LOG=$T/fake.log FAKE_WORK=${FAKE_WORK:-2}
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
herdr --version
herdr server >/dev/null 2>&1 & 
for i in $(seq 50); do herdr workspace list >/dev/null 2>&1 && break; sleep 0.2; done
J() { python3 -c "import sys,json;d=json.load(sys.stdin);print($1)"; }
P=$(herdr workspace create --cwd "$T" --no-focus | J 'd["result"]["root_pane"]["pane_id"]')
sleep 1
herdr pane run $P claude >/dev/null
for i in $(seq 40); do st=$(herdr pane get $P | J 'd["result"]["pane"]["agent_status"]'); [ "$st" = idle ] || [ "$st" = done ] && break; sleep 0.25; done
echo "agent status after start: $st"; herdr agent list | head -c 400; echo
send() { # label text
  local s=$(date +%s.%N)
  out=$(herdr agent prompt $P "$2" --wait --timeout 20000 2>&1); rc=$?
  local e=$(date +%s.%N)
  printf '[%s] rc=%s %.1fs result=%s\n' "$1" $rc $(python3 -c "print($e-$s)") "$(echo "$out" | head -c 160 | tr '\n' ' ')"
}
send plain "hello world"
send unicode "日本語 é 🚀 👨‍👩‍👧‍👦 ok"
send multiline $'line1\nline2\n\nline4'
send dashes "--help -x -- /model"
send quotes "it's \"quoted\" \$HOME \`id\` \\n"
send trailing_ws $'trailing spaces   \t'
send big "$(python3 -c "print('x'*30000)")"
send escseq $'esc\x1b[31mred\x1b[0m'
echo "--- received by fake agent (repr), lengths for big:"
python3 - "$T/fake.log" <<'PY'
import sys,ast
for l in open(sys.argv[1]):
    v=ast.literal_eval(l.strip()); print(len(v), repr(v[:70]))
PY
herdr server stop >/dev/null 2>&1; rm -rf "$T"
