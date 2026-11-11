---
name: things
description: >-
  Read and change to-dos, projects, areas and tags in the Things 3 app through the
  `things` script (reads the local Things database, writes through the Things URL
  scheme). Use for ANY question or action about Things or the user's tasks — e.g.
  "what's on my Today", "what's due this week", "what's left in project X", "find the
  task about Y", "add a to-do to call Z tomorrow", "mark these as done", "move that to
  someday".
---

# Things 3 (`things`)

Things has no official CLI or API. This skill ships one, `scripts/things` next to this
file: a stdlib-only Python script that **reads** Things' SQLite database directly
(opened read-only) and **writes** only through Things' official URL scheme.

Every `things` below means this script, invoked by path (it isn't on `PATH`):

```bash
~/.claude/skills/things/scripts/things today
```

Do not memorize the options: `things --help` and `things <command> --help` are complete.
This file covers what `--help` does not.

## Reading

```bash
things today                    # the Today list, This Evening included
things inbox | anytime | someday
things upcoming --days 14       # scheduled items + next repeat of repeating to-dos
things deadlines --days 7       # every open deadline up to N days out, overdue included
things logbook --days 7         # completed/canceled
things areas | tags
things projects [--area Work]
things project "atualização rds"   # one project, by heading; --all adds finished items
things area Finance | things tag SIAN
things search "stopwords" [--notes] [--all]
things show <uuid> [<uuid>...]  # notes, checklist items, every date
```

- **Add `--json` whenever you will process the result** (counting, regrouping, filtering).
  The text output is for scanning; it prints `‹uuid›` on every line so you can act on items
  afterwards.
- Text output groups by **area › project › heading**, which is how the user usually wants
  lists. `upcoming`, `deadlines` and `logbook` group by date instead.
- Names (projects, areas, tags, `--list`) match case- and accent-insensitively, exactly or
  by unique substring. On an ambiguous name the script lists the candidates with uuids —
  show them to the user or pick by uuid, never guess.
- Raw SQL is fine for one-off questions the commands don't cover. Open it read-only:
  `sqlite3 -readonly "$(ls ~/Library/Group\ Containers/JLMPQHK86H.com.culturedcode.ThingsMac/ThingsData-*/Things\ Database.thingsdatabase/main.sqlite)"`.
  Read "Data model" below first.

## Things semantics worth knowing

- **Today** = open items whose start date has arrived (Things sets `start=1` once a
  scheduled date passes; items it hasn't processed yet still say `start=2`, and the script
  counts both), plus items with no start date whose deadline has passed. It includes
  **projects**, not just to-dos. Items marked `evening` are the This Evening section.
- **Repeating to-dos pile up.** Each repetition is a separate instance; an instance that
  is never checked off stays in Today forever, next to the newer ones. Ten copies of
  "Pagar fatura" with old deadlines usually means they were paid and never ticked. Point
  this out and offer to complete the old ones; don't assume.
- **Repeating templates** are hidden rules that create the instances. The list commands
  leave them out; `upcoming` shows each template's next date. Writes go to instances,
  never to templates.
- `OVERDUE` in the output means the deadline is before today; Things shows those in red.
- **An item being edited in the app isn't in the database yet.** Things saves the title
  and notes when the user leaves the item (click outside or Esc). When a search misses
  something the user says they just typed, look at the most recently modified items
  (`ORDER BY userModificationDate DESC`). If the likely item is there with the old
  content, ask the user to close the editor and retry. Don't act on a guess.

## Writing — confirm first

Writes go through `things:///json`, launched in the background with `open -g` (Things
starts if it isn't running). The script then **polls the database until the change
appears** and fails loudly if it doesn't within 15s, so a successful exit means Things
really recorded it. Never write to the SQLite file itself: Things would not see it,
it can corrupt the database, and the change would never sync.

Things syncs to the user's other devices through Things Cloud, so every write is real and
shows up everywhere. **Before any write, state exactly what will change (which items, by
title, and how) and get the user's go-ahead.** For a batch (e.g. completing 20 old
repetitions), list them first.

```bash
# New to-do (goes to the Inbox unless --list or --when say otherwise)
things add "Ligar para a Cemig" --when today --list Personal
things add "Revisar contrato" --when 2026-11-20 --deadline 2026-11-25 --tags Next \
  --notes "..." --checklist "Ler cláusulas" --checklist "Enviar dúvidas"
things add "Deploy" --list "Atualização RDS na AWS" --heading SOLAR
things add "Nova unidade" --project --list Work      # a project goes in an area

# Change, complete, cancel, reopen — several uuids at once is one call
things complete <uuid> <uuid> ...
things update <uuid> --when someday
things update <uuid> --when evening
things update <uuid> --deadline 2026-12-01      # or --deadline none to clear it
things update <uuid> --list Finance              # move to another project/area
things update <uuid> --add-tags Next             # --tags replaces the whole set
things update <uuid> --append-notes "..." --append-checklist "..."
things update <uuid> --cancel | --reopen
```

- `--when`: `today`, `evening`, `tomorrow`, `anytime`, `someday`, or `YYYY-MM-DD`;
  `YYYY-MM-DD@HH:MM` also sets a reminder.
- **Tags must already exist.** The URL scheme silently drops unknown tags, so the script
  refuses instead. Creating tags is done in the app.
- `add` prints the new item via `show`, uuid included. Use it for follow-up changes.
- The URL scheme cannot delete or move items to the Trash. Cancelling is the closest
  equivalent; for a real delete, ask the user to do it in the app.
- Updates need the URL-scheme auth token. The script reads it from the database
  (`TMSettings.uriSchemeAuthenticationToken`), so no setup is needed. If it says there is
  no token, the user must turn on Things → Settings → General → Enable Things URLs.

## Data model (for raw SQL)

- `TMTask` holds to-dos (`type` 0), projects (1) and headings (2). `status`: 0 open,
  2 canceled, 3 completed. Always filter `trashed = 0`; filter
  `rt1_recurrenceRule IS NULL` to drop repeating templates.
- `start`: 0 Inbox, 1 Anytime, 2 Someday. With a `startDate` set, `start=2` means
  scheduled (Upcoming). `startBucket = 1` is This Evening.
- **Calendar dates** (`startDate`, `deadline`, `rt1_nextInstanceStartDate`) are packed
  integers: `year << 16 | month << 12 | day << 7`. Decode in SQL with
  `printf('%04d-%02d-%02d', d >> 16, (d >> 12) & 15, (d >> 7) & 31)`. Templates carry a
  placeholder deadline of 4001-01-01; ignore it.
- `reminderTime` is `hour << 26 | minute << 20`. `creationDate`, `userModificationDate`
  and `stopDate` are Unix timestamps (REAL).
- A to-do's project is `project`, or `heading → TMTask.project` when it sits under a
  heading. Its area is `area`, or the project's `area`. Tags: `TMTaskTag(tasks, tags)` →
  `TMTag`. Checklists: `TMChecklistItem.task`. Areas: `TMArea`.
- The schema is undocumented and has changed between versions (dates moved to the packed
  format in 3.15; this was written against 3.24). If queries start failing or returning
  nonsense after a Things update, check `PRAGMA table_info(TMTask)` before trusting them.

## Privacy

This is the user's personal and work task list, notes included. Read what the question
needs, and don't paste task content into commits, artifacts or anything outward-facing
unless asked for exactly that.
