# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A single-file Bash script (`nezha-agent-cleaner.sh`) that completely removes Nezha monitoring Agent from Linux systems. Used when the Agent persists after deletion from the Nezha management dashboard.

- **Target platform:** Linux with systemd (Ubuntu, Debian, CentOS, Fedora, Arch)
- **Runtime requirement:** Must run as root (`id -u` check at line 44)
- **Distribution:** curl-pipe or wget-download from GitHub raw
- **Dependencies:** GNU coreutils (`realpath`/`readlink -f`, `mktemp`, `xargs`), `systemctl`, `crontab`, `pgrep`/`pkill` (procps), `docker` (optional, step 9). No package installation is performed — missing tools cause individual steps to skip gracefully.
- **Error handling:** Does NOT use `set -euo pipefail`. Errors are handled per-step with `2>/dev/null` and explicit exit-on-failure for critical failures (`mktemp`). This is intentional — a failed `grep` or `find` should not abort the whole cleanup.

## Script architecture

The script is a linear 10-step interactive process with embedded safety guards:

| Step | Purpose | Key safety mechanism |
|------|---------|---------------------|
| 1 | Check running processes (`ps aux`) | Reads only, no mutation |
| 1.5 | **Smart path tracking** — traces binary paths from `/proc/{pid}/exe` and `ExecStart`/`WorkingDirectory` from systemd unit files | Critical for non-standard installs |
| 2 | Remove crontab entries | greps `nezha-agent\|/nezha/` |
| 3 | `systemctl stop` + `disable` all matching services | Only matches `nezha-agent` or `nezha.service` |
| 4 | `pkill -9 -f nezha-agent` | Force kill remaining processes |
| 5 | `rm -f` service unit files under `/etc/systemd/system/` | Only `*nezha-agent*` and `*nezha.service*` |
| 6 | Remove known binary/directory locations | Hardcoded list of standard paths |
| 6.5 | Remove paths discovered by step 1.5 | Checks `is_protected_dir()` before deleting |
| 7 | Global `find` scan + interactive delete | Triple guard: path contains `nezha`, file exists, not a protected dir; user must confirm `[y/N]` |
| 8 | `systemctl daemon-reload` | Reload after unit changes |
| 9 | Docker container check | Interactive, only containers matching `nezha-agent\|nezha:` |
| 10 | Final verification | Reports remaining processes, services, and files |

## Safety patterns (do not weaken)

- **Protected directories** (`PROTECTED_DIRS` array, lines 58-76): Uses targeted leaf-directory protection (`/usr/bin`, `/usr/sbin`, `/usr/lib`, etc.) rather than broad prefix matching like `/usr`. This allows deletion of `/usr/local/nezha-agent` while protecting `/usr/bin`. Note: `/etc` and `/var` are intentionally NOT in the protected list since they are common install locations.
- **`is_protected_dir()`** (line 79): Resolves symlinks via `realpath` (falling back to `readlink -f`, then raw path) before comparing against PROTECTED_DIRS. Uses prefix matching (`$protected/*`) so subdirectories of protected dirs are also guarded.
- **Exact name matching:** All grep/find patterns use `nezha` rather than generic `agent` to avoid false positives on ssh-agent, 1panel-agent, tailscale-agent, etc.
- **Interactive confirmation:** Steps 7 and 9 require user `[y/N]` confirmation before destructive actions. Both use `</dev/tty` redirection so they work when piped via `curl | bash`.

## Version management

The version string appears in three places that must stay in sync:
1. Header comment on line 8: `# Version: 1.3 (Bugfix Release)`
2. Welcome banner echo on lines 35-38: `v1.3 (Bugfix版)` / `v1.3 (Bugfix Release)`
3. Closing banner echo on line 477: `v1.3 修复` / `v1.3 fixes`

**Note:** The README.md version badges still say `v1.1` — these are stale and should be updated when the script version changes.

## Implementation patterns (v1.3)

- **`safe_remove()` function** (line 93): All file/directory deletion must go through this wrapper. Checks existence → `is_protected_dir()` → case-insensitive "nezha" substring → `rm -rf`. Never bypass with raw `rm -rf`.
- **`[n]ezha-agent` bracket trick**: All `pgrep`, `pkill`, `grep -E` targeting nezha-agent processes must use `[n]ezha-agent` not `nezha-agent`, so the pattern matches the real agent but NOT the script's own filename (`nezha-agent-cleaner.sh`). Note: `SCRIPT_PID=$$` is defined at line 54 but is **unused** — the bracket trick is what actually prevents self-matching; SCRIPT_PID is dead code.
- **`</dev/tty` on interactive reads**: Both step 7 and step 9 `read -r response` must redirect from `/dev/tty` so confirmation works when the script is piped via `curl | bash`.
- **ExecStart prefix stripping**: `sed 's/^ExecStart=[-@!+]*//'` strips systemd prefix modifiers (`-`, `@`, `+`, `!`) before extracting the binary path.
- **`trap 'rm -f "$temp_file"' EXIT`** (line 360): Registered after `mktemp` in step 7. Ensures temp file cleanup on SIGINT/SIGTERM/normal exit.
- **`unique_paths` declared at top scope** (line 147): Not inside an `if` block. Safe under `set -u`.

## Making changes

- **No build, lint, or test infrastructure exists.** Validation requires running the script on a Linux machine with systemd (VM or container).
- Bash syntax check: `bash -n nezha-agent-cleaner.sh`
- ShellCheck (if installed): `shellcheck nezha-agent-cleaner.sh`
- Test scenarios: standard install under `/opt/nezha`, non-standard custom paths, Docker-based Agent, crontab-only setup, systemd service but no running process.
- When adding new cleanup logic, always add a `is_protected_dir()` guard before any `rm -rf`, and ensure grep patterns reference `nezha` specifically.
- Bilingual output convention: every user-facing message has a Chinese line followed by an English line using the same echo prefix color.

## Data flow: smart path tracking (steps 1.5 → 6.5)

Two arrays work together:
- **`TRACKED_PATHS`** (indexed array, line 145): Collects raw paths from `/proc/{pid}/exe` and systemd unit parsing. May contain duplicates.
- **`unique_paths`** (associative array, line 147): Used solely for deduplication before display and deletion. Populated by iterating `TRACKED_PATHS` and using paths as keys.

Step 1.5 populates `TRACKED_PATHS` from two sources:
1. `/proc/{pid}/exe` for each `pgrep -f "[n]ezha-agent"` match — resolves the actual binary via `readlink -f`
2. Systemd unit files matching `*nezha-agent*` or `*nezha.service*` — parses `ExecStart` (with prefix stripping) and `WorkingDirectory`

The parent directory of each discovered binary is also tracked (unless protected), catching non-standard install directories.

Step 6.5 iterates `unique_paths` and calls `safe_remove()` on each existing path.

## Known quirks

- **Step 5 uses raw `rm -f`** instead of `safe_remove()`. Service files live under `/etc/systemd/system/` which is not a protected directory, so the risk is low, but this is an inconsistency with the rest of the script's safety discipline.
- **`SCRIPT_PID=$$`** (line 54) is dead code. The `[n]ezha-agent` bracket trick handles self-avoidance. Could be removed in a future cleanup.

## Upstream context

- [Nezha monitoring](https://github.com/naiba/nezha) — the server monitoring tool this script cleans up after
- The Agent (被控端) is the "controlled" endpoint installed on monitored servers; the Dashboard (主控端) is the management UI
