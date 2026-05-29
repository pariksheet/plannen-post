# plannen-post

A Claude Code plugin that composes a personalised morning newspaper from data you can already reach (MCP tools, web search, HTTP, CLI, files), renders it into a styled HTML edition, and delivers it to the channels you choose — Gmail draft, WhatsApp, Telegram, a printer, a file.

No database, no web service, no Vercel deploy. State is two small local files (`~/.post/config.md` + `~/.post/profile.yaml`) plus a rolling 7-day working memory of past editions. The full design lives in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## The two-layer config

| File | What it holds | Shareable? |
|---|---|---|
| `~/.post/config.md` | The **portable content brief** — frontmatter (sources, sections, delivery) + prose-hint body. Logical names only; **no secrets, no identifiers, no shell**. | ✅ yes |
| `~/.post/profile.yaml` | The **local profile** — non-MCP secrets, sink routing (chat ids, recipients), must-watch senders, the optional render capability, shell sinks. | ❌ never |

Connected MCPs need no binding (they own their auth), so on an all-MCP setup the profile is nearly empty. See [`examples/`](examples/) for both files.

## Prerequisites

- **Claude Code** (this is a Claude Code plugin).
- **The MCPs you want as sources/sinks**, connected in your session. None are mandatory — the Post composes from whatever you have and **skips sections whose source isn't connected**. Common ones:
  - **Gmail MCP** → inbox brief (source) + draft delivery (sink)
  - **Google Calendar MCP** → events
  - **A weather source** → not needed; the examples use [open-meteo](https://open-meteo.com) over HTTP, keyless
  - **Web search** → news/sport/any beat (built in)
  - **A notify MCP** (WhatsApp/Telegram) → delivery
  - **plannen** (optional, separate product) → family events + watched events
- **For PNG/PDF editions:** Google Chrome (or Chromium/Edge) **+ node/npm**. Without them, image formats fall back to text/HTML. (HTML and Gmail-draft need nothing extra.)

> **`plannen` vs `plannen-post`:** different products. `plannen-post` is this newspaper plugin; [`plannen`](https://github.com/pariksheet/plannen) is a separate family-planner whose MCP can *optionally* feed the events section. You do **not** need plannen to use the Post — the generic example doesn't reference it.

## Install

In any Claude Code session, add the marketplace and install the plugin:

```text
/plugin marketplace add pariksheet/plannen-post
/plugin install plannen-post@plannen-post
```

That's it — no clone, no flags. The plugin's commands are namespaced
`/plannen-post:…`, and you'll get updates when the marketplace refreshes.

**Developing the plugin?** Run it straight from a local checkout instead:

```bash
claude --plugin-dir /path/to/plannen-post
```

`/reload-plugins` picks up local edits without restarting.

## Quickstart (recommended)

```text
/plannen-post:setup
```

The interactive setup **detects your connected MCPs**, learns a little about you,
walks you through your sections conversationally, **previews today's edition**, then
configures delivery and (optionally) a schedule — writing `~/.post/config.md` +
`~/.post/profile.yaml` only after you sign off. This is the easiest path and builds
a config tailored to the tools you actually have.

## First run (manual)

Prefer to hand-write it? Just run:

```text
/plannen-post:post
```

With no config, it copies the bundled examples to `~/.post/config.md` +
`~/.post/profile.yaml`, opens the config in `$EDITOR`, and exits. Edit the sections
you want in `config.md`, put any bindings (sink routing, keys, must-watch senders)
in `profile.yaml`, then re-run.

Two starting points live in [`examples/`](examples/):
- **`config.example.md`** — a generic, plannen-free starter (Gmail + Calendar + open-meteo + web search) that degrades gracefully.
- **`config.pari.example.md`** — a rich, real-world config (plannen-integrated, pollen, four web-search beats, PNG-to-WhatsApp) as a reference.

## Scheduling

Two options:

- **Claude Code `/schedule`** — quickest: `/schedule "daily at 06:00 Europe/Brussels: /plannen-post:post"`. The routine inherits your MCP servers and shell environment as captured when `/schedule` ran.
- **macOS launchd** (in `scripts/`) — for "run at 06:00, and if the Mac was off, attempt after bootup." `scripts/post-wrapper.sh` + a `LaunchAgent` with `StartCalendarInterval` (06:00) and `RunAtLoad` give you native wake/boot catch-up; a per-day guard prevents double-posting.

Prefer MCP sinks over raw curl — an MCP carries its own auth, so the non-interactive-shell token problem below doesn't arise.

## Telegram setup (only if using the curl fallback, not a Telegram MCP)

1. Create a bot via `@BotFather` on Telegram. Save the token.
2. Send any message to your new bot, then grab your chat_id from `https://api.telegram.org/bot<TOKEN>/getUpdates`.
3. Put the chat_id in your `~/.post/profile.yaml` (under the telegram sink).
4. Put the token in your shell environment — **in `~/.zshenv`, not `~/.zshrc`**:
   ```sh
   export TELEGRAM_BOT_TOKEN="123456789:ABC-..."
   ```
   `~/.zshrc` only loads for interactive shells; `/schedule`'s background routine is non-interactive. If the token isn't visible to the routine, the Telegram channel is skipped with a warning and Gmail still goes out.

To send Telegram-only without Gmail, comment out the gmail entry in `delivery:`.

## Sources & sections

A **source** is anything that returns data; declare each under `sources:` with a logical `name` and a `type`:

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

The **prose hint** for each section lives in the markdown body, under a `## <section-id>` heading — a free-form prompt telling the model how to turn raw data into prose (what to lead with, what to skip, tone). The frontmatter is the deterministic skeleton; the prose is the editorial taste.

`{{since_last_edition}}` in a source's `args` is expanded at runtime from working memory (so Monday's inbox reaches back to Friday).

### Per-section failure isolation

If a source isn't connected, a tool errors, or a URL times out, that section is skipped with a warning. The run continues. The terminal report lists what was dropped.

## Customising the look

The edition is rendered from a **theme** — `templates/<theme>.html`, chosen by `masthead.theme` in your config (e.g. `theme: classic` → `templates/classic.html`). If the named theme is missing, it falls back to `templates/newspaper.html`. Ships with `classic` (the hand-drawn three-column look) and the `newspaper` default; copy one to start your own. Slots are HTML comments:

```html
<!-- {{intro}} -->      <!-- spine slots -->
<!-- {{weather}} -->
<!-- {{events}} -->
<!-- {{inbox}} -->
<!-- {{outro}} -->
<!-- {{dynamic.left}} -->    <!-- dynamic zone: improvised sections -->
<!-- {{dynamic.center}} -->  <!-- flow here, balanced across columns -->
<!-- {{dynamic.right}} -->
```

Spine sections fill their named slot; dynamic sections flow into the dynamic-zone markers, balanced across columns. You can rearrange them, add columns, or change the CSS — the skill just substitutes content into matching markers, and a slot with no matching section collapses gracefully. The component-kit classes (`card`/`list`/`stat`/`quote`/`two-col`/`photo`/sticky-note) are all styled in the template, so improvised sections never need new CSS.

`design-ref/A1.html` is the original visual reference (a hand-drawn three-column newspaper aesthetic). It is not used at runtime — it is kept as a design spec for anyone reworking the template.

## Out of scope

- **No Gmail send** — the Gmail MCP exposes `create_draft` only. You review and send manually.
- **No long-term archive** — channels are the permanent record. Local state is a rolling **7-day** working memory (`~/.post/memory/`, HTML + JSON sidecar) used only for continuity (look-back windows, inbox dedup/escalation, callbacks). Older editions are pruned.
- **No bundled renderer** — PNG/PDF need a connected `html→{png,pdf}` render capability; without one, those formats fall back per the delivery's `else:` chain.
- **No multi-user** — one config, one user.
- **No retries** — tomorrow's Post is the retry.
- **No web UI** — `/plannen-post:post-config` is the only knob.

## Troubleshooting

| symptom | likely cause |
|---|---|
| "Telegram skipped: $TELEGRAM_BOT_TOKEN not set" inside a `/schedule` routine | Token is in `~/.zshrc`; move it to `~/.zshenv`. |
| Gmail draft body looks like raw HTML | The Gmail MCP may not be honouring `mimeType: text/html`. Check the MCP version. |
| `weather` section keeps failing | The example uses open-meteo. If your network blocks it, swap to your local weather site or a different MCP. |
| A section's content is empty | The MCP tool returned an empty result. Run the tool manually in a Claude session to see why. |
