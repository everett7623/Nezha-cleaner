# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A single-file Bash script (`nezha-agent-cleaner.sh`) that safely removes Nezha monitoring components from Linux systems. v2.1 provides an interactive menu to choose between uninstalling the Agent (被控端), Dashboard (主控端), or both — each with its own dedicated 12-step safety pipeline.

- **Target platform:** Linux with systemd (Ubuntu, Debian, CentOS, Fedora, Arch)
- **Runtime requirement:** Must run as root (`id -u` check near the top)
- **Distribution:** curl-pipe or wget-download from GitHub raw
- **Dependencies:** GNU coreutils (`realpath`/`readlink -f`, `mktemp`, `xargs`), `systemctl`, `crontab`, `pgrep`/`pkill` (procps), `docker` (optional, container steps). No package installation is performed — missing tools cause individual steps to skip gracefully.
- **Error handling:** Does NOT use `set -euo pipefail`. Errors are handled per-step with `2>/dev/null` and explicit exit-on-failure for critical failures (`mktemp`). This is intentional — a failed `grep` or `find` should not abort the whole cleanup.
- **License:** MIT — see `LICENSE` file.

> **Note on line numbers:** Line number references throughout this document are approximate and will drift as the script evolves. Use them as navigation hints, not absolute truth. Grep for the relevant pattern if the line has moved.

## Script architecture (v2.1)

### Top-level flow

```
Welcome banner → Root check → Interactive menu (1-4) → Mode dispatcher
                                                          │
                                     ┌────────────────────┼────────────────────┐
                                     ▼                    ▼                    ▼
                              cleanup_agent()     cleanup_dashboard()    Both (agent → dashboard)
```

The menu, safety infrastructure (`PROTECTED_DIRS`, `is_protected_dir()`, `safe_remove()`), and mode dispatcher live at the top level. The two cleanup functions each contain their own local `TRACKED_PATHS`/`unique_paths` arrays and follow the same 12-step pattern with target-specific patterns.

### Mode 1: Agent cleanup — `cleanup_agent()`

The original v1.4 10-step pipeline, wrapped in a function. Unchanged except Docker filtering narrowed to `--filter "name=*nezha-agent*"`.

| Step | Purpose | Key safety mechanism |
|------|---------|---------------------|
| 1 | Check running processes (`ps aux`) | Reads only, no mutation |
| 1.5 | **Smart path tracking** — traces binary paths from `/proc/{pid}/exe` and `ExecStart`/`WorkingDirectory` from systemd unit files | Critical for non-standard installs |
| 2 | Remove crontab entries | greps `nezha-agent\|/nezha/` |
| 3 | `systemctl stop` + `disable` all matching services | Only matches `nezha-agent` or `nezha.service` |
| 4 | `pkill -9 -f nezha-agent` | Force kill remaining processes |
| 5 | Remove service unit files under `/etc/systemd/system/` | Only `*nezha-agent*` and `*nezha.service*` |
| 6 | Remove known binary/directory locations | Hardcoded list of standard paths |
| 6.5 | Remove paths discovered by step 1.5 | Checks `is_protected_dir()` before deleting |
| 7 | Global `find` scan + interactive delete | Triple guard: path contains `nezha`, file exists, not a protected dir; user must confirm `[y/N]` |
| 8 | `systemctl daemon-reload` | Reload after unit changes |
| 9 | Docker container check (Agent-filtered) | `--filter "name=*nezha-agent*"` + grep fallback + per-container `docker inspect` verification |
| 10 | Final verification | Reports remaining processes, services, and files |

### Mode 2: Dashboard cleanup — `cleanup_dashboard()`

New 12-step pipeline mirroring the Agent flow but targeting Dashboard-specific patterns:

| Step | Purpose | Key safety mechanism |
|------|---------|---------------------|
| D1 | Check Dashboard processes (bare-metal + Docker `docker ps --filter "name=*nezha*"`) | Reads only; explicitly excludes `nezha-agent` containers from display |
| D2 | **Smart path tracking** — traces from `/proc/{pid}/exe` and systemd units (`*nezha-dashboard*`, `*nezha.service*` excluding agent) | `is_protected_dir()` guard |
| D3 | Remove crontab entries | greps `nezha-dashboard\|/nezha/dashboard` |
| D4 | `systemctl stop` + `disable` Dashboard services | Matches `nezha-dashboard` and `nezha.service`, excludes `nezha-agent` |
| D5 | `pkill -9 -f "[n]ezha-dashboard"` | Bracket trick prevents self-matching |
| D6 | Remove Dashboard service unit files | `*nezha-dashboard*` and `*nezha.service*`, excludes `*nezha-agent*` |
| D7 | Remove known Dashboard directories + binaries | `/opt/nezha/dashboard/`, `/opt/nezha-dashboard/`, plus `docker-compose.yaml`/`.yml` |
| D8 | Remove paths discovered by D2 | `safe_remove()` each tracked path |
| D9 | Global `find` scan + interactive delete | Same triple-guard as Agent step 7 |
| D10 | Docker container + image cleanup (4-layer defense) | See Docker defense-in-depth below |
| D11 | `systemctl daemon-reload` | Reload after unit changes |
| D12 | Final verification | Reports remaining Dashboard processes, services, Docker containers, files |

### Docker container归属 (v2.1)

Each mode only touches its own containers:

| 容器名模式 | Agent mode | Dashboard mode | Both mode |
|-----------|-----------|---------------|----------|
| `*nezha-agent*` | ✅ 删除 | ❌ 跳过 | ✅ 删除 |
| `*nezha-dashboard*` | ❌ 跳过 | ✅ 删除 | ✅ 删除 |
| `*nezha*` (generic) | ❌ 跳过 | ✅ 删除 | ✅ 删除 |

Classification uses lowercased container name matching before `docker inspect` verification. Dashboard mode explicitly skips containers whose lowercased name contains `nezha-agent`.

## Output conventions

- **Bilingual messages:** Every user-facing message is a pair — Chinese line first, then English, using the same echo prefix color. Example:
  ```bash
  echo -e "${YELLOW}[信息] 开始清理哪吒探针Agent...${NC}"
  echo -e "${YELLOW}[INFO] Starting Nezha Agent cleanup...${NC}"
  ```
- **Color variables** defined at the top of the script: `RED`, `GREEN`, `YELLOW`, `BLUE`, `CYAN`, `NC` (no-color reset). Use these — never hardcode ANSI escapes.
  - `RED` — errors, warnings about skipped protected paths
  - `GREEN` — success confirmations, "not found" messages
  - `YELLOW` — informational, prompts, "found" messages
  - `BLUE` — section headers (step banners, menu box)
  - `CYAN` — smart tracking output, version info lines

## Safety patterns (do not weaken)

- **Protected directories** (`PROTECTED_DIRS` array): Uses targeted leaf-directory protection (`/usr/bin`, `/usr/sbin`, `/usr/lib`, etc.) rather than broad prefix matching like `/usr`. This allows deletion of `/usr/local/nezha-agent` while protecting `/usr/bin`. Note: `/etc` and `/var` are intentionally NOT in the protected list since they are common install locations.
- **`is_protected_dir()`**: Resolves symlinks via `realpath` (falling back to `readlink -f`, then raw path) before comparing against PROTECTED_DIRS. Uses prefix matching (`$protected/*`) so subdirectories of protected dirs are also guarded.
- **Exact name matching:** All grep/find patterns use `nezha` rather than generic `agent` to avoid false positives on ssh-agent, 1panel-agent, tailscale-agent, etc. Dashboard mode additionally distinguishes `nezha-dashboard` from `nezha-agent` in service/container matching.
- **Interactive confirmation:** Steps D9 (find scan) and D10 (containers + images) require user `[y/N]` confirmation before destructive actions. All interactive reads use `</dev/tty` redirection so they work when piped via `curl | bash`.
- **Docker defense-in-depth (v2.1):** Dashboard step D10 uses four layers:
  1. Docker native `--filter "name=*nezha*"` for broad container-name matching
  2. Classification: lowercased container name checked — `*nezha-agent*` containers are skipped, all others proceed
  3. `docker inspect` per-container verification — containers failing verification are skipped with a warning
  4. **Image removal with separate confirmation** — after containers are cleaned, lists `docker images | grep -iE "nezha"` and requires a **second** `[y/N]` confirmation before `docker rmi`
- **Docker storage exclusion:** Global `find` scans (step 7 and D9) prune `/var/lib/docker` and `/var/lib/containerd` to prevent accidental traversal of container runtime internals.
- **Media/document file protection (v2.1):** `safe_remove()` skips individual files with common media/document extensions (`.png`, `.jpg`, `.gif`, `.svg`, `.webp`, `.bmp`, `.ico`, `.heic`, `.heif`, `.pdf`, `.doc`, `.docx`, `.md`, `.txt`, `.rst`, `.html`, `.htm`, `.rtf`, `.mp4`, `.mp3`, `.avi`, `.mov`, `.mkv`, `.wav`, `.flac`, `.pptx`, `.ppt`, `.xlsx`, `.xls`, `.csv`). These file types are never part of Nezha monitoring software (which consists of binaries without extensions, `.service`, `.json`, `.yaml`, `.sh`, `.conf`). This prevents the catastrophic deletion of user content like blog post illustrations (`nezha-architecture.png`) or articles (`nezha-guide.md`) that happen to have "nezha" in the filename. **Do not weaken this guard** — if a new extension needs to be added to the allow-list (i.e., a file type that COULD be a Nezha component), add it explicitly to the case statement rather than removing the guard.

## Version management

The version string appears in four places that must stay in sync:
1. Header comment: `# Version: 2.1 (Safety Enhanced)`
2. Welcome banner echoes: `v2.1 (安全增强)` / `v2.1 (Safety Enhanced)`
3. Closing banner echoes: `v2.1: 安全增强` / `v2.1: Safety Enhanced`
4. README.md version badges and changelog

## Implementation patterns

- **`safe_remove()` function**: All file/directory deletion must go through this wrapper. Checks existence → `is_protected_dir()` → case-insensitive "nezha" substring → **file-type guard (new in v2.1)** → `rm -rf`. Never bypass with raw `rm -rf`.
  - **File-type guard:** Individual files with known media/document extensions (`.png`, `.jpg`, `.gif`, `.svg`, `.pdf`, `.md`, `.txt`, `.mp4`, etc.) are skipped — even if their name contains "nezha". This prevents deleting user content like article illustrations (`nezha.png`) that have nothing to do with Nezha monitoring software. Nezha components are binaries, configs (`.json`/`.yaml`/`.service`), and shell scripts — never images or documents.
- **`[n]ezha-agent` / `[n]ezha-dashboard` bracket trick**: All `pgrep`, `pkill`, `grep -E` targeting nezha processes must use `[n]ezha-...` not `nezha-...`, so the pattern matches the real process but NOT the script's own filename (`nezha-agent-cleaner.sh`). `SCRIPT_PID=$$` is **unused** — the bracket trick is what actually prevents self-matching.
- **`</dev/tty` on interactive reads**: All `read -r` for user confirmation must redirect from `/dev/tty` so confirmation works when the script is piped via `curl | bash`. This includes the main menu and all step-level confirmations.
- **ExecStart prefix stripping**: `sed 's/^ExecStart=[-@!+]*//'` strips systemd prefix modifiers (`-`, `@`, `+`, `!`) before extracting the binary path.
- **`trap 'rm -f "$temp_file"' EXIT`**: Registered after `mktemp` in global find steps. Ensures temp file cleanup on SIGINT/SIGTERM/normal exit.
- **Local arrays in functions**: Both `cleanup_agent()` and `cleanup_dashboard()` declare `local -a TRACKED_PATHS` and `local -A unique_paths` so the two modes are fully isolated — Both mode runs them sequentially without variable collision.
- **Container classification (Dashboard mode)**: Before displaying found containers, D10 iterates the collected map and removes entries whose lowercased name contains `nezha-agent`. This is done with `unset 'dashboard_container_map[$cid]'` on the associative array.

## Data flow: smart path tracking

Both cleanup functions implement the same two-array pattern independently:

- **`TRACKED_PATHS`** (local indexed array): Collects raw paths from `/proc/{pid}/exe` and systemd unit parsing. May contain duplicates.
- **`unique_paths`** (local associative array): Used solely for deduplication before display and deletion.

Sources differ by target:
- **Agent**: traces `pgrep -f "[n]ezha-agent"` + systemd units matching `*nezha-agent*` or `*nezha.service*`
- **Dashboard**: traces `pgrep -f "[n]ezha-dashboard"` + systemd units matching `*nezha-dashboard*` or `*nezha.service*` (excluding `*nezha-agent*`)

The parent directory of each discovered binary is also tracked (unless protected), catching non-standard install directories.

## Making changes

### Validation

- **No build, lint, or test infrastructure exists.** Validation requires running the script on a Linux machine with systemd (VM or container).
- Bash syntax check: `bash -n nezha-agent-cleaner.sh`
- ShellCheck (if installed): `shellcheck nezha-agent-cleaner.sh`
  - Expect ShellCheck warnings — the script intentionally uses patterns ShellCheck flags (e.g., `pgrep -f` without `-x`, `2>/dev/null` without checking `$?`). These are not bugs; they reflect deliberate trade-offs for readability and compatibility across distros.
- Test scenarios:
  - Agent: standard `/opt/nezha`, non-standard custom paths, Docker-based Agent, crontab-only, systemd service but no running process
  - Dashboard: Docker Compose deployment (`/opt/nezha/dashboard/`), standalone Docker container, bare-metal systemd service, crontab-based restart

### Code conventions

- When adding new cleanup logic, always route deletion through `safe_remove()` — never introduce raw `rm -rf`.
- Ensure grep/find patterns reference `nezha` specifically, and for Dashboard mode, distinguish `nezha-dashboard` from `nezha-agent`.
- New user-facing output must follow the bilingual convention: Chinese line first, English line second, same color prefix.
- Use the existing color variables (`$RED`, `$GREEN`, `$YELLOW`, `$BLUE`, `$CYAN`, `$NC`) — do not hardcode ANSI escape sequences.
- Use the bracket trick (`[n]ezha-agent`, `[n]ezha-dashboard`) in all `pgrep`/`pkill`/`grep -E` patterns to avoid self-matching.
- New interactive `read` prompts must use `</dev/tty` redirection.
- When adding a new cleanup mode, use `local` arrays inside the function to avoid cross-mode variable pollution.

### Git workflow

Standard fork-PR workflow (from README):
1. Create a feature branch: `git checkout -b feature/YourFeature`
2. Commit changes with a descriptive message
3. Push and open a Pull Request

The repository has a `.claude/settings.local.json` with permissive Bash allow rules for git operations — if you need to add new permissions, update that file.

## Known quirks

- **`SCRIPT_PID=$`** is dead code. The `[n]ezha-agent` / `[n]ezha-dashboard` bracket trick handles self-avoidance. Could be removed in a future cleanup.
- **Dashboard D10 image removal** uses a `while IFS=$'\t' read` pipeline for `docker rmi`. This runs in a subshell due to the pipe — image removal failures within the loop don't affect the outer script's exit code (which is acceptable since D12 final verification will report any remaining images).
- **Docker `grep -vi "nezha-agent"` in Dashboard mode** (D1, D10, D12) is case-insensitive on the `v` flag but the agent name pattern is lowercase. This works because `-i` applies to all patterns in the grep invocation.

## Upstream context

- [Nezha monitoring](https://github.com/naiba/nezha) — the server monitoring tool this script cleans up after. Now maintained under [nezhahq](https://github.com/nezhahq/nezha).
- The Agent (被控端) is the "controlled" endpoint installed on monitored servers; the Dashboard (主控端) is the management UI.
- **Security note (2026):** Multiple critical CVEs affect Nezha Dashboard — CVE-2026-53519 (path traversal, CVSS 9.1), CVE-2026-46716 (cross-tenant RCE, CVSS 9.9), CVE-2026-48119 (cross-tenant data forgery), and CVE-2026-47124 (WebSocket info leak). This script provides a safe way to completely remove vulnerable Dashboard instances, including Docker images.
