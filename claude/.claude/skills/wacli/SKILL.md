---
name: wacli
description: >-
  Read, search and send WhatsApp messages from the local `wacli` store (a WhatsApp CLI
  backed by a synced SQLite DB). Use for ANY question or action about WhatsApp — e.g.
  "what did <person> say about X", "did anyone message me today", "find that WhatsApp
  message with the link", "send a WhatsApp to <person>", "what's in the <group> group",
  "download that photo someone sent me".
---

# WhatsApp CLI (`wacli`)

`wacli` keeps a **local SQLite mirror** of the linked WhatsApp account and sends through
it. Binary from Homebrew; docs: https://wacli.sh — store is `$WACLI_STORE_DIR`
(`~/.local/state/wacli`, set in `fish/.config/fish/conf.d/exports.fish`).

Do **not** memorize the command surface — it is large and versioned. Every level is
self-documenting (`wacli <group> --help`, `wacli <group> <cmd> --help`) and every
command takes `--json`. This file covers only what `--help` does *not* tell you.

## The local DB is a snapshot — check freshness first

No sync daemon runs on this machine (no LaunchAgent, no background `wacli sync`). The DB
only holds what the last sync pulled, so **answering "did anything new arrive?" from a
stale DB produces a confident wrong answer.**

```bash
wacli doctor            # STORE, AUTHENTICATED, CONNECTED, LAST_SYNC, MESSAGES, CHATS
```

Compare `LAST_SYNC` to now. If the question is about *recent* activity and the DB is
stale, sync before answering — and say that you did:

```bash
wacli sync --once --presence-mode quiet     # sync until idle, then exit
```

- `--once` is essential: the default `--follow` runs until Ctrl+C and will hang the call.
- `--presence-mode quiet` avoids broadcasting "online" to contacts while syncing.
- Historical questions ("what did we agree in March?") need no sync — but old messages
  may simply never have been pulled. `wacli history coverage` shows the real range per
  chat; `wacli history backfill --chat <JID>` requests more from the primary device.

## Default to read-only

Exploration must not be able to send anything. Prefix read sessions:

```bash
WACLI_READONLY=1 wacli messages search "deploy" --limit 20
```

Anything that would touch WhatsApp or the store then fails with *"read-only mode: command
would intentionally modify..."* — including `sync`. Drop the var only for the one command
that is meant to write.

## Sending — outward-facing and effectively irreversible

A sent message reaches a real person instantly. `wacli messages revoke` exists but only
works on your own recent messages, and recipients still saw the notification.

- **Confirm recipient and exact text with the user before every `send`.** Show what will
  go out, verbatim, and who receives it. Never send on inferred intent.
- Resolve the recipient *first* rather than trusting a name to match. `--to` accepts a
  JID, a phone number, or a contact/group/chat name; when a name is ambiguous `wacli`
  reports the matches and `--pick N` chooses one. Show the matches to the user and let
  them pick — do not guess with `--pick`.
- **Never bulk-send.** One recipient per confirmed request; a loop over contacts is spam
  and risks the account.
- `--message-escapes` is required for `\n` to become a real line break.
- Other writes are equally real: `chats mark-read`, `send react`, `presence`, `groups`.
  Same confirmation rule.

## Recipes

```bash
# Who has unread / recent traffic
wacli chats list --unread --limit 20
wacli chats list --query "family" --json

# Name → JID (needed by every --chat flag)
wacli contacts search "maria" --json

# Find a message, then read around it
wacli messages search "invoice" --after 2026-08-01 --limit 20 --json
wacli messages context --chat <CHAT_JID> --id <MSG_ID> --before 10 --after 10

# One chat's recent history
wacli messages list --chat <CHAT_JID> --limit 50 --asc --json

# Media
wacli messages search "" --chat <CHAT_JID> --has-media --type image --json
wacli media download --chat <CHAT_JID> --id <MSG_ID> --output <path>
```

`--full` disables table truncation; prefer `--json` whenever the text body matters, since
tables cut it.

## JSON gotchas

All output is the envelope `{success, data, error}` — check `.success`, read `.data`.
The shape under `.data` is **not** uniform:

- `chats list`, `contacts search` → `.data` is an **array**, keys `snake_case`
  (`jid`, `name`, `last_message_ts`, `unread_count`).
- `messages list`, `messages search` → `.data.messages` is the array, keys **PascalCase**
  (`ChatJID`, `MsgID`, `SenderName`, `Timestamp`, `Text`, `MediaType`, `LocalPath`).
  `.data.fts` reports whether real full-text search was used or it fell back to `LIKE`.

Use `DisplayText` for rendering (it resolves media captions and system events); `Text` is
the raw body. `Revoked` / `DeletedForMe` rows still exist — filter them out when
summarizing a conversation.

## Privacy

This is the user's personal message history. Read what the current question needs, quote
sparingly in summaries, and never paste chat content into an artifact, a commit, a
webhook, or any other outward destination without the user asking for exactly that.
