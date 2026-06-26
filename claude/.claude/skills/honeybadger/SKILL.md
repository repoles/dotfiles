---
name: honeybadger
description: >-
  Inspect Honeybadger projects, faults (errors), notices, deployments, uptime and
  Insights via the `hb` command-line utility. Use for ANY question about Honeybadger
  errors/exceptions, error details/backtraces, affected users, project health, fault
  counts, or deployments — e.g. "what's failing in <project>", "details on fault <id>",
  "list unresolved errors", "who is affected by this error".
---

# Honeybadger CLI (`hb`)

Read and inspect Honeybadger data from the command line. The binary is `hb`
(installed via Homebrew: `honeybadger-io/tap/honeybadger`). Docs:
https://docs.honeybadger.io/resources/cli/

## Auth (already configured)

The **personal auth token** (Data API) is provided as the `HONEYBADGER_AUTH_TOKEN`
env var via mise — defined in `~/.config/mise/config.local.toml` (a stow symlink into
this dotfiles repo, git-ignored). Because it's the mise **global** config, the token is
available in any directory once mise is active.

- If a command fails with *"auth token is required"*, the env var isn't loaded. Force it
  by prefixing commands with the mise env, e.g.:
  `eval "$(mise env -s bash)"; hb projects list`
- Two credential types exist: `--auth-token` / `HONEYBADGER_AUTH_TOKEN` for the **Data
  API** (reading projects/faults — what you almost always want) and `--api-key` /
  `HONEYBADGER_API_KEY` for the **Reporting API** (sending deploys/metrics).
- To rotate the token: User settings → Authentication in the Honeybadger web app, then
  update `~/.config/mise/config.local.toml`.

## Standard workflow

1. **Resolve project name → ID.** Project IDs are required by most fault commands but
   change per account, so never hardcode them — look them up:
   ```bash
   hb projects list                      # ID, NAME, ACTIVE, FAULTS, UNRESOLVED
   ```
2. **List / drill into faults** using the project ID.
3. Prefer `-o json` when you need full detail (message, backtrace, request context); the
   default table is best for quick scans.

## Command reference

Top-level Data API commands (use the auth token):
`accounts`, `check-ins`, `comments`, `deployments`, `environments`, `faults`,
`insights`, `projects`, `statuspages`, `teams`, `uptime`.

### Projects
```bash
hb projects list                         # all projects + fault/unresolved counts
hb projects get --id <PROJECT_ID>
hb projects list --account-id <ACCOUNT_ID>
```

### Faults (errors)  — the main use case
```bash
# List faults for a project
hb faults list --project-id <PID>                     # 25 most recent (default)
hb faults list --project-id <PID> --order frequent    # by frequency instead of recency
hb faults list --project-id <PID> -q "RequestError"   # search/filter query
hb faults list --project-id <PID> --limit 25 -o json

# Get one fault (NOTE: ID is a FLAG --id, not positional)
hb faults get --project-id <PID> --id <FAULT_ID> -o json

# Notices = individual occurrences of a fault (backtrace, request, env, params)
hb faults notices --project-id <PID> --id <FAULT_ID> -o json --limit 25

# Who is affected
hb faults affected-users --project-id <PID> --id <FAULT_ID>

# Fault counts for a project
hb faults counts --project-id <PID>
```

### Other
```bash
hb deployments --help
hb uptime --help
hb insights --help          # query Insights data
hb comments --help          # fault comments
```

## Gotchas (learned the hard way)

- `hb faults get` and `hb faults notices` take the fault id as **`--id` (a flag)**, NOT a
  positional argument. `hb faults get <id>` fails with *required flag(s) "id" not set*.
- `--project-id` is a **global flag** on the `faults` group; pass it on the subcommand.
- `--limit` maxes out at 25 for `faults list` and `faults notices`.
- Use `-o json` (output is `text`/`json` for `get`/`counts`, `table`/`json` elsewhere).

## Reading a fault

A fault's JSON gives: `klass` (error class), `component` (controller/job + action),
`message`, `environment`, `notices_count` (total occurrences), `created_at` /
`last_notice_at` (first/last seen), `resolved`, `ignored`, `assignee`, and a web `url`.
Pull `faults notices ... -o json` for the **backtrace** (with source context), the
**request** block (params, context, job handler), and the deploy **revision**/host. When
summarizing an error, trace the backtrace frames marked `"context": "app"` first — those
are the user's code, not gem internals.
