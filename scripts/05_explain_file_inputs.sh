#!/usr/bin/env bash
# `herdr agent explain --file` on odd inputs: empty, ANSI, 5 MB single line, invalid UTF-8, random bytes, missing file, unknown agent.
set -u; . "$(dirname "$0")/common.sh" "$1"; trap stop_server EXIT; start_server
cd "$SANDBOX"; : > empty.txt; printf '\033[31mred\033[0m\n' > ansi.txt; python3 -c "print('x'*5_000_000)" > huge.txt
printf '\xff\xfe\x00bad' > badutf.txt; head -c 3000 /dev/urandom > rand.bin
for f in empty.txt ansi.txt huge.txt badutf.txt rand.bin missing.txt; do for a in claude nosuch; do
  out=$(timeout 20 herdr agent explain --file $f --agent $a --json 2>&1); rc=$?
  echo "$f --agent $a: rc=$rc $(echo "$out" | head -c 110 | tr '\n' ' ')"; done; done
