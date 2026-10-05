---
name: zendesk
description: >-
  Read and manage Zendesk support tickets through the Zendesk REST API v2 using the
  `zdapi` curl wrapper. Use for ANY question or action about Zendesk tickets, ticket
  comments, requesters, views or search — e.g. "what tickets are open", "show ticket
  4521", "reply to this ticket", "search tickets tagged X", "who reported this",
  "solve that ticket".
---

# Zendesk REST API (`zdapi`)

There is no official CLI for tickets — `zcli` only handles apps and themes. This skill
talks to the REST API directly through `scripts/zdapi`, a thin authenticated curl
wrapper living next to this file. API docs:
https://developer.zendesk.com/api-reference/ticketing/introduction/

## Auth — OAuth client credentials

Zendesk is retiring API tokens, so this skill authenticates with the OAuth 2.0
**client credentials** flow — no browser, no refresh token, made for server-side scripts.

Set up once:

1. Admin Center → Apps and integrations → APIs → **OAuth clients** → add a client of
   type **Confidential** (the flow is refused for public clients). Note the Identifier
   and the Secret — the secret is shown only once.
2. Store these in the login keychain, as generic passwords under the account
   `avantsistemas` — `ZENDESK_SUBDOMAIN` (the `<sub>` of `<sub>.zendesk.com`, not the
   full host), `ZENDESK_CLIENT_ID`, `ZENDESK_CLIENT_SECRET`:

   ```bash
   security add-generic-password -a avantsistemas -s ZENDESK_CLIENT_ID -w '<identifier>' -U
   ```

   `zdapi` reads each one with `security find-generic-password -a <account> -s <name> -w`,
   so nothing has to be in the shell environment. Set `ZENDESK_KEYCHAIN_ACCOUNT` to use a
   different account.

`zdapi` exchanges those for an access token on demand and caches it (mode 600) under
`$XDG_CACHE_HOME/zendesk/token-<subdomain>.json` until just before it expires, so a
burst of calls costs one token request. A cached token that turns out to be revoked is
dropped and refetched once, automatically. Delete the cache file to force a new token.

**Attribution:** everything done through a client credentials token is recorded as the
Zendesk user who *created the OAuth client*. Ticket comments will carry that name — so
create the client under the account whose name should appear, not a colleague's.

An exported `ZENDESK_*` variable overrides the keychain, which is how you point a single
call at a sandbox subdomain or a second OAuth client. If `zdapi` says a var is neither
set nor in the keychain, check the item name and account with
`security find-generic-password -a avantsistemas -s ZENDESK_SUBDOMAIN -w`.

Scopes default to **`read tickets:write`**: broad read plus write on tickets only.
Resource-qualified read scopes (`tickets:read` and friends) look tighter but break
`/search.json`, which insists on the broad `read` — hence the default. Override with
`ZENDESK_SCOPE` (space-separated) if an endpoint needs more; changing it invalidates the
cached token automatically. A `403` almost always means a missing scope rather than a
missing permission, and Zendesk names the scope it wanted in the error body — `zdapi`
prints both that and the current scope list. A failed *token request* instead means bad
client id/secret, or a client that isn't Confidential.

## The wrapper

```bash
zdapi METHOD PATH [JSON|@file]      # PATH starts after /api/v2
```

It adds the base URL, the `Bearer` header and the JSON headers; encodes the spaces and quotes that
Zendesk search queries need; prints the body on stdout; and on HTTP >= 400 prints the
status and error body on **stderr** and exits 1 (reporting `Retry-After` on a 429).
Pipe into `jq` freely — a failed call produces no stdout, so it won't feed jq garbage.

Every `zdapi` in the examples below means this wrapper, invoked by path (it isn't on `PATH`):
`~/.claude/skills/zendesk/scripts/zdapi GET /tickets.json`

## Reading

```bash
# Newest tickets first. NOTE: `sort_by`/`sort_order` are silently IGNORED here —
# with cursor pagination this endpoint only understands `sort`, and defaults to
# oldest-first. To sort by anything but id, use search (below) instead.
zdapi GET "/tickets.json?page[size]=25&sort=-id"

# One ticket, and its conversation
zdapi GET /tickets/4521.json
zdapi GET "/tickets/4521/comments.json?page[size]=100"

# Several at once (up to 100 ids)
zdapi GET "/tickets/show_many.json?ids=4521,4522,4523"

# Who is involved — ticket JSON carries ids, not names
zdapi GET /users/12345.json
# ...or sideload them in one request instead of N follow-ups:
zdapi GET "/tickets/4521.json?include=users,organizations"
```

Useful `include` values: `users`, `organizations`, `groups`, `comment_count`,
`custom_statuses`.

## Search — the main way in

```bash
zdapi GET "/search.json?query=type:ticket status:open"
zdapi GET "/search.json?query=type:ticket status<solved assignee:me"
zdapi GET "/search.json?query=type:ticket tags:integracao created>2026-01-01"
zdapi GET "/search.json?query=type:ticket \"pedido de venda\""
# Search DOES honour sort_by/sort_order — the reliable way to get "the latest ticket"
zdapi GET "/search.json?query=type:ticket&sort_by=created_at&sort_order=desc"
```

Syntax: `:` is equality, `<` / `>` compare (dates as `YYYY-MM-DD`), `-` negates
(`-status:closed`), `*` is a wildcard, double quotes match an exact phrase, and
space-separated terms are ANDed. Always lead with `type:ticket` — otherwise users and
organizations come back mixed in.

Limits worth knowing:

- `/search.json` caps at **1000 results total**, 100 per page, offset pagination.
- For more than that use `/search/export.json?filter[type]=ticket&query=...`, which is
  cursor-paginated (1000/page) but limited to **100 requests/min** and one object type.
- Indexing lags: a ticket created seconds ago may not be searchable yet. Fetch it by id.

## Writing — confirm first

Tickets are customer-facing. **A public comment emails the requester and cannot be
unsent.** Before any POST/PUT: state the ticket, the exact change and the comment text,
and get the user's go-ahead. Default new comments to `"public": false` (an internal
note) unless the user explicitly asked to reply to the customer.

```bash
# Internal note + status change
zdapi PUT /tickets/4521.json '{"ticket":{"status":"pending","comment":{"body":"Aguardando retorno do cliente.","public":false}}}'

# Public reply to the requester
zdapi PUT /tickets/4521.json '{"ticket":{"comment":{"body":"...","public":true}}}'

# Other common updates
zdapi PUT /tickets/4521.json '{"ticket":{"priority":"high","assignee_id":12345}}'
zdapi PUT /tickets/4521.json '{"ticket":{"tags":["integracao","sian"]}}'

# New ticket
zdapi POST /tickets.json '{"ticket":{"subject":"...","comment":{"body":"..."},"priority":"normal","requester_id":12345}}'
```

For bodies with quotes, accents or newlines, write the JSON to a file in the scratchpad
and pass `@file` — it avoids a whole class of shell-quoting bugs.

`status` is one of `new`, `open`, `pending`, `hold`, `solved`, `closed`;
`priority` one of `low`, `normal`, `high`, `urgent`;
`type` one of `problem`, `incident`, `question`, `task`.

## Gotchas

- **`tags` replaces the whole list.** To add one, read the current tags first and PUT
  the union, or use `PUT /tickets/4521/tags.json` which appends.
- **`closed` is terminal** — a closed ticket cannot be updated at all, only followed up
  with a new linked ticket. `solved` is the reversible one.
- Ticket JSON gives `requester_id`/`assignee_id`, never names. Sideload with `include`
  rather than firing one `/users/{id}.json` per row.
- Cursor pagination is the modern one: `page[size]=100` plus `links.next` in the
  response. The old `?page=2` still works on some endpoints but is being retired.
- **`/tickets.json` ignores `sort_by`/`sort_order` under cursor pagination** — no error,
  it just returns oldest-first and you quietly answer with a ticket from years ago. It
  accepts only `sort=id` / `sort=-id`. For any other ordering, go through
  `/search.json`, which does honour `sort_by` + `sort_order`.
- 429 means rate limited — honor `Retry-After` (the wrapper prints it); don't hammer.
- Endpoints answer with `.json` appended by convention; the API also accepts the path
  without it.

## Reading a ticket

Ticket JSON gives `subject`, `description` (the first comment), `status`, `priority`,
`type`, `tags`, `requester_id`, `assignee_id`, `group_id`, `organization_id`,
`created_at` / `updated_at`, `via.channel` (email, web, api…) and `custom_fields`. The
conversation is **not** in there — pull `/tickets/{id}/comments.json`, where each
comment has `body` (plain) / `html_body`, `author_id`, `public` and `created_at`. When
summarizing, separate public replies from internal notes: the customer never saw the
notes.
