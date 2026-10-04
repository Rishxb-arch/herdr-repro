# herdr-repro: hands-on notes on herdr 0.9.3 (Linux, CPU-only)

Small, honest test pass on [herdr](https://github.com/herdrdev/herdr) v0.9.3 (released 2026-09-29; source read at `5da0a01e`, the head of the default branch `master` on 2026-10-03), run on 2026-10-03 on a headless Linux x86_64 box with no GPU, no Docker and no real coding-agent CLIs installed. Everything here uses the official release binary (`herdr-linux-x86_64`, sha256 `18a8dc65f1c2fa485884344356dea1cfd911c6f06cf46fa78e193f4087f4dba7`) in a throwaway `$HOME`.

## Second pass (4 Oct 2026)

agent prompt does not neutralise an embedded bracketed-paste terminator (ESC[201~); see [pass2/FINDINGS.md](pass2/FINDINGS.md) and [pass2/scripts/07_paste_breakout.sh](pass2/scripts/07_paste_breakout.sh). Tested only with a fake agent; impact is inference.

## The one real finding (minor): agents are recognised by process name alone, with no opt-out

herdr decides "this pane is running an agent" from the foreground process name (`src/detect/mod.rs`, `lookup_agent`). Several of those names are also ordinary programs. The most realistic case is the Cursor editor: the standard way to use it for commit messages is `git config core.editor "cursor --wait"`, and `cursor` maps to the Cursor agent. While `git commit` waits for the editor, the pane is reported as a `cursor` agent in state `idle`:

```
while editor is open:        cursor idle
agent list: [('w1:p1', 'cursor', 'idle')]
fallback_reason: default_known_agent_idle_fallback
after editor closed:         None unknown
```

(`logs/02_editor_false_positive.log`; in a manual run the TUI sidebar also listed a `cursor` row under "agents".) The same identification happens for any foreground binary named `kilo` (also the name of a small terminal text editor), `amp`, `antigravity` (the launcher of the Antigravity editor), `grok`, `droid`, and so on; these were reported with state `unknown` rather than `idle` (`foreground 'kilo': kilo unknown`, `foreground 'amp': amp unknown`, `foreground 'antigravity': agy unknown`, ...).

What I did **not** verify: I used a stand-in script named `cursor` that blocks like `--wait`, not the real Cursor binary, because I do not have it on this box. The effect is cosmetic (a spurious agent row and `agent list` entry that disappears when the process exits) and `agent list` showed no `completion_seq` for it (I did not test notification sounds/toasts). `HERDR_AGENT` can only force a label, there is no value that says "this is not an agent", and I did not find a documented way to exclude a process name. I did not write a patch: a clean fix (for example an `HERDR_AGENT=none` hint, or a config list of ignored process names) is a design choice for the maintainers.

I searched the open and closed issues for this before writing it up (queries on process-name/false-positive wording). Related but different: [herdrdev/herdr#4564](https://github.com/herdrdev/herdr/issues/4564) (generic screen patterns from non-agent commands keep a pane `working`). I did not find an issue about name-based identification itself.

## What held up (checked, nothing wrong found)

| Check | Result | Log |
|---|---|---|
| Detection plumbing with a fake executable named `claude` printing screens that mimic the visible text the bundled manifest keys on (spinner + "esc to interrupt", "Do you want to proceed?" dialog, idle prompt box) | `working` -> `blocked` -> `idle` followed the screen; `agent explain` named the matching rule | `logs/01_detection_fake_claude.log` |
| Kill the attached TUI client | server and agent process keep running, status still reported | `logs/04_client_kill_and_server_kill.log` |
| `kill -9` the server, restart | agent processes die with the server (expected: it owns the PTYs); workspace/pane layout restores, the agent is not relaunched | same |
| Socket API with malformed input: bad JSON, missing fields, wrong types, 100 000-deep nesting, huge numbers, NUL in ids, negative/huge ids, invalid UTF-8 | structured errors every time (except invalid UTF-8, see below), no panic or hang, server stayed up | `logs/03_api_fuzz.log` |
| `agent explain --file` on empty, ANSI, 5 MB single-line, invalid UTF-8 and random-byte files | sensible results or a clean error, exit code 1 on errors | `logs/05_explain_file_inputs.log` |
| 40 consecutive `pane split` calls | no failure; server RSS ~21 MB -> ~31 MB (manual check, not scripted) | |

Tiny observations, not bugs worth an issue on their own: invalid UTF-8 on the API socket closes the connection with no error reply; `agent explain --file x --agent nosuch` exits 0 with `fallback_reason: unknown_agent`.

## Honest limitations

- No real Claude Code / Codex / OpenCode were run, so nothing here says anything about how well the manifests match the *real* agent UIs. The fake `claude` only proves the plumbing.
- Not tested: SSH / `--remote` / saved machines (no sshd on the box), Windows, macOS, live handoff, `herdr update`, worktrees, sounds, integrations.
- The first start of `herdr server` fetches agent-detection manifests from the network and caches them (visible in `status.toml`); results above used manifest versions fetched on 2026-10-03 (claude 2026.09.11.1, cursor 2026.08.03.1).
- `herdr` source was read at `5da0a01e` but not built (the build needs the Zig toolchain; I used the release binary).

## Reproduce

```bash
curl -L -o herdr https://github.com/herdrdev/herdr/releases/download/v0.9.3/herdr-linux-x86_64 && chmod +x herdr
bash scripts/02_editor_false_positive.sh ./herdr     # the finding
bash scripts/01_detection_fake_claude.sh ./herdr     # detection plumbing
bash scripts/03_api_fuzz.sh ./herdr                  # socket API robustness
bash scripts/04_client_kill_and_server_kill.sh ./herdr   # needs tmux
bash scripts/05_explain_file_inputs.sh ./herdr
```

Each script uses a temporary `$HOME`/`XDG_*` directory, starts its own `herdr server`, and stops it on exit.
