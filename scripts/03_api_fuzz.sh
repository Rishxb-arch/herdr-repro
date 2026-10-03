#!/usr/bin/env bash
set -u; . "$(dirname "$0")/common.sh" "$1"; trap stop_server EXIT; start_server
P=$(pane_of fuzz)
python3 "$ROOT/scripts/api_fuzz.py" "$P"; echo "server still up: $(herdr status server | head -2 | tr '\n' ' ')"
