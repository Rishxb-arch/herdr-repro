#!/usr/bin/env bash
# `herdr config check` against malformed / odd config.toml files (no server needed). Prints diagnostics + exit code.
T=$(mktemp -d /tmp/herdr-p2-08.XXXXXX); export HOME=$T XDG_CONFIG_HOME=$T/.config; mkdir -p $XDG_CONFIG_HOME/herdr
herdr --version
c() { printf '%b' "$2" > $XDG_CONFIG_HOME/herdr/config.toml; out=$(timeout 10 herdr config check 2>&1); rc=$?; echo "--- $1 (exit=$rc): $(echo "$out" | tr '\n' ' ' | cut -c1-200)"; }
c empty ''
c truncated 'ui = [\n'
c unknown_key '[ui]\nnonexistent = 1\n'
c wrong_type '[ui]\nconfirm_close = "yes"\n'
c negative '[advanced]\nscrollback_limit_bytes = -5\n'
c overflow '[advanced]\nscrollback_limit_bytes = 99999999999999999999\n'
c dup_key '[ui]\nconfirm_close = true\nconfirm_close = false\n'
c bad_keybind '[keys]\nsplit_right = "prefix+nonsense+++"\n'
c key_conflict '[keys]\nprefix = "ctrl+b"\nsplit_vertical = "ctrl+b"\n'
c bom '\xef\xbb\xbf[ui]\nconfirm_close = false\n'
c crlf '[ui]\r\nconfirm_close = false\r\n'
c bad_sound '[ui.sound]\nenabled = true\npath = "/nonexistent"\n'
c nul_byte '[ui]\nconfirm_close = false\n\x00\n'
c invalid_utf8 '[ui]\nconfirm_close = false\n# \xff\xfe\n'
c huge_value "[ui]\nname = \"$(python3 -c 'print("x"*1000000)')\"\n"
rm -rf $T
