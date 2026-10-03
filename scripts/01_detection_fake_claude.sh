#!/usr/bin/env bash
# A fake executable named `claude` prints screens that mimic the visible text the bundled claude manifest keys on
# (spinner line + "esc to interrupt", the "Do you want to proceed?" permission dialog, an idle prompt box).
# Checks that herdr's reported agent_status follows the screen. This tests the plumbing, NOT the real Claude Code UI.
set -u; . "$(dirname "$0")/common.sh" "$1"; trap stop_server EXIT; start_server
P=$(pane_of fake-claude); echo idle > "$FAKE_SCENARIO_FILE"; herdr pane run "$P" claude >/dev/null; sleep 3
for s in working blocked idle; do echo $s > "$FAKE_SCENARIO_FILE"; sleep 4; echo "scenario=$s  herdr says: $(agent_of $P)"; done
herdr agent explain "$P" | head -6
