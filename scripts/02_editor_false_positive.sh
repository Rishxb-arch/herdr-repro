#!/usr/bin/env bash
# `git config core.editor "cursor --wait"` is the standard way to use the Cursor/VS Code editor for commit messages.
# `cursor` here is a stand-in script named `cursor` that blocks like `--wait` does. It is not an agent.
set -u; . "$(dirname "$0")/common.sh" "$1"; trap stop_server EXIT
mkdir "$SANDBOX/bin"; for n in kilo amp antigravity grok droid; do cp /bin/sleep "$SANDBOX/bin/$n"; done; export PATH="$SANDBOX/bin:$PATH"  # must be set before the server starts (panes inherit its env)
start_server
git init -q "$SANDBOX/repo" && cd "$SANDBOX/repo" && git config user.email t@example.invalid && git config user.name t \
  && git config core.editor "cursor --wait" && echo x > f && git add f
P=$(pane_of gitedit "$SANDBOX/repo")
echo "before:                      $(agent_of $P)"
herdr pane run "$P" "git commit" >/dev/null; sleep 4
echo "while editor is open:        $(agent_of $P)"
herdr agent list | python3 -c 'import json,sys; print("agent list:", [(a["pane_id"],a["agent"],a["agent_status"]) for a in json.load(sys.stdin)["result"]["agents"]])'
herdr agent explain "$P" | head -6
touch "$FAKE_RELEASE_FILE"; sleep 3
echo "after editor closed:         $(agent_of $P)"
echo "--- other names herdr maps to agents (each is a copy of /bin/sleep renamed) ---"
for n in kilo amp antigravity grok droid; do herdr pane run "$P" "$n 20" >/dev/null; sleep 2.5; echo "foreground '$n': $(agent_of $P)"; herdr pane send-keys "$P" C-c >/dev/null; sleep 1; done
