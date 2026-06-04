---
name: post-help
description: Explains plannen-post to the user — what it is, prerequisites, setup, the config/profile split, sources & sections, scheduling, themes, what's out of scope, and troubleshooting. Loads when the user runs /plannen-post:help or asks how plannen-post works, how to set it up, schedule it, add a source, change the look, or why something failed.
allowed-tools: Read
---

# post-help

The full guide to **plannen-post**. Present the parts relevant to what the user
asked; don't recite the whole thing unless they want everything. The README is the
short landing page — this is the depth behind it.

## What it is

A Claude Code plugin that composes a personalised morning newspaper from data the
user can already reach (MCP tools, web search, HTTP, CLI, files), renders it into a
styled HTML edition, and delivers it to the channels they choose — Gmail draft,
WhatsApp, Telegram, a printer, a file. No database, no web service, no deploy.
State is two small local files plus a rolling 7-day working memory of past
editions. Full design: `docs/ARCHITECTURE.md`.

## The two-layer config

| File | What it holds | Shareable? |
|---|---|---|
| `~/.post/config.md` | The **portable content brief** — frontmatter (sources, sections, delivery) + prose-hint body. Logical names only; **no secrets, no identifiers, no shell**. | ✅ yes |
| `~/.post/profile.yaml` | The **local profile** — non-MCP secrets, sink routing (chat ids, recipients), must-watch senders, the optional render capability, shell sinks. | ❌ never |

Connected MCPs need no binding (they own their auth), so on an all-MCP setup the
profile is nearly empty. See `examples/` for both files.

## Prerequisites

- **Claude Code** (this is a Claude Code plugin).
- **The MCPs you want as sources/sinks**, connected in your session. None are
  mandatory — the Post composes from whatever you have and **skips sections whose
  source isn't connected**. Common ones:
  - **Gmail MCP** → inbox brief (source) + draft delivery (sink)
  - **Google Calendar MCP** → events
  - **Weather** → no MCP needed; the examples use [open-meteo](https://open-meteo.com) over HTTP, keyless
  - **Web search** → news/sport/any beat (built in)
  - **A notify MCP** (WhatsApp/Telegram) → delivery
  - **plannen** (optional, separate product) → family events + watched events
- **For PNG/PDF editions:** Google Chrome (or Chromium/Edge) **+ node/npm**. Without
  them, image formats fall back to text/HTML. HTML and Gmail-draft need nothing extra.

> **`plannen` vs `plannen-post`:** different products. `plannen-post` is this
> newspaper plugin; [`plannen`](https://github.com/pariksheet/plannen) is a separate
> family-planner whose MCP can *optionally* feed the events section. You do **not**
> need plannen to use the Post — the generic example doesn't reference it.

## Setup

**Recommended — interactive:**

```text
/plannen-post:post-setup
```

Detects your connected MCPs, learns a little about you, walks your sections
conversationally, **previews today's edition**, then configures delivery and
(optionally) a schedule — writing `~/.post/config.md` + `~/.post/profile.yaml` only
after you sign off.

**Manual first run:**

```text
/plannen-post:post
```

With no config it copies the bundled examples to `~/.post/`, opens the config in
`$EDITOR`, and exits. Edit the sections you want in `config.md`, put any bindings in
`profile.yaml`, then re-run. Two starting points in `examples/`:
- **`config.example.md`** — generic, plannen-free (Gmail + Calendar + open-meteo + web search), degrades gracefully.
- **`config.pari.example.md`** — a rich real-world reference (plannen, pollen, four web-search beats, PNG-to-WhatsApp).

`/plannen-post:post-config` reopens the config in `$EDITOR` later.

## Sources & sections

A **source** is anything that returns data; declare each under `sources:` with a
logical `name` and a `type`:

| type | fields |
|---|---|
| `mcp` | `tool: server.name`, optional `args` |
| `http` | `url`, `as: text\|json`, optional `secret: NAME` (resolved in the profile) |
| `web-search` | `query` |
| `cli` | defined **only** in the profile (security) |
| `file` | a path |

A **section** binds a source to a slot and a component:

```yaml
sections:
  - id: weather
    slot: spine                 # always present
    source: [weather, pollen]   # one or more sources
    component: card             # card | list | stat | quote | two-col | photo
  - id: sport
    slot: dynamic               # appears only when its source has something
    source: sport
    component: card
    when: present
  - id: intro
    slot: spine
    kind: ai-intro              # ai-intro / ai-outro have no source
```

The **prose hint** for each section lives in the markdown body under a
`## <section-id>` heading — a free-form prompt telling the model how to turn raw
data into prose (what to lead with, what to skip, tone). Frontmatter is the
deterministic skeleton; the prose is the editorial taste.

`{{since_last_edition}}` in a source's `args` expands at runtime from working memory
(so Monday's inbox reaches back to Friday).

**Failure isolation:** if a source isn't connected, a tool errors, or a URL times
out, that section is skipped with a warning and the run continues. The terminal
report lists what was dropped.

## Scheduling

- **Claude Code `/schedule`** — quickest:
  `/schedule "daily at 06:00 Europe/Brussels: /plannen-post:post"`. The routine
  inherits the MCP servers + shell environment captured when `/schedule` ran.
- **macOS launchd** (in `scripts/`) — for "run at 06:00, and if the Mac was off,
  attempt after bootup." `scripts/post-wrapper.sh` + a `LaunchAgent` with
  `StartCalendarInterval` (06:00) and `RunAtLoad`; a per-day guard prevents
  double-posting.

Prefer MCP sinks over raw curl — an MCP carries its own auth, so the
non-interactive-shell token problem (below) doesn't arise.

### Telegram via the curl fallback (only if not using a Telegram MCP)

1. Create a bot via `@BotFather`; save the token.
2. Message your bot, then grab your chat_id from
   `https://api.telegram.org/bot<TOKEN>/getUpdates`.
3. Put the chat_id in `~/.post/profile.yaml` (under the telegram sink).
4. Put the token in **`~/.zshenv`, not `~/.zshrc`**:
   `export TELEGRAM_BOT_TOKEN="123456789:ABC-..."` — `~/.zshrc` only loads for
   interactive shells; a scheduled routine is non-interactive, so a token there is
   invisible and the channel is skipped with a warning.

## Customising the look

The edition renders from a **theme** — `templates/<theme>.html`, chosen by
`masthead.theme` (e.g. `theme: classic` → `templates/classic.html`); falls back to
`templates/newspaper.html` if missing. Ships with `classic` (the hand-drawn
three-column look) and the `newspaper` default.

**Each column renders as one phone page**, so the slots are grouped by page:

```html
<div class="col col-left">    <!-- page 1 — the day -->
  <!-- {{events}} --> <!-- {{intro}} --> <!-- {{weather}} -->
</div>
<div class="col col-center">  <!-- page 2 — the feeds -->
  <!-- {{dynamic.center}} -->   <!-- all dynamic sections flow here -->
</div>
<div class="col col-right">   <!-- page 3 — personal -->
  <!-- {{inbox}} --> <!-- {{outro}} -->
</div>
```

Spine sections fill their named slot; dynamic sections flow into
`{{dynamic.center}}`. A slot with no matching section collapses; an empty column
emits no page. The component-kit classes
(`card`/`list`/`stat`/`quote`/`two-col`/`photo`/sticky-note) are all styled in the
template, so improvised sections never need new CSS. `design-ref/A1.html` is the
original visual reference (not used at runtime).

## Out of scope

- **No Gmail send** — the Gmail MCP exposes `create_draft` only; you review and send.
- **No long-term archive** — channels are the record. Local state is a rolling
  **7-day** working memory (`~/.post/memory/`, HTML + JSON sidecar) used only for
  continuity (look-back windows, inbox dedup/escalation, callbacks).
- **No bundled renderer** — PNG/PDF need a render capability (local Chrome via
  `scripts/render-png.sh`, or a render MCP); without one, image formats fall back
  per the delivery `else:` chain.
- **No multi-user** — one config, one user.
- **No retries** — tomorrow's Post is the retry.

## Troubleshooting

| symptom | likely cause |
|---|---|
| "Telegram skipped: $TELEGRAM_BOT_TOKEN not set" inside a `/schedule` routine | Token is in `~/.zshrc`; move it to `~/.zshenv`. |
| Gmail draft body looks like raw HTML | The Gmail MCP may not be honouring `mimeType: text/html`. Check the MCP version. |
| `weather` section keeps failing | The example uses open-meteo. If your network blocks it, swap to your local weather site or a different MCP. |
| A section's content is empty | The MCP tool returned an empty result. Run the tool manually in a Claude session to see why. |
| Event times look 1–2 h off | Source timestamps are UTC; the time must be converted to `profile.defaults.timezone`. Check that it's set correctly. |
| PNG delivery falls back to text | No render capability — install Chrome + node/npm, or point `profile.render` at a render MCP. |
