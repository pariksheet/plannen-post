# plannen-post

A Claude Code plugin that composes a personalised morning newspaper from data you can already reach (MCP tools, web search, HTTP, CLI, files), renders it into a styled HTML edition, and delivers it to the channels you choose — Gmail draft, WhatsApp, Telegram, a printer, a file.

No database, no web service, no Vercel deploy. State is two small local files (`~/.post/config.md` + `~/.post/profile.yaml`) plus a rolling 7-day working memory of past editions. The full design lives in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## The two-layer config

| File | What it holds | Shareable? |
|---|---|---|
| `~/.post/config.md` | The **portable content brief** — frontmatter (sources, sections, delivery) + prose-hint body. Logical names only; **no secrets, no identifiers, no shell**. | ✅ yes |
| `~/.post/profile.yaml` | The **local profile** — non-MCP secrets, sink routing (chat ids, recipients), must-watch senders, the optional render capability, shell sinks. | ❌ never |

Connected MCPs need no binding (they own their auth), so on an all-MCP setup the profile is nearly empty. See [`examples/`](examples/) for both files.

## Install

Clone or place this directory anywhere on disk. Then in any Claude Code session:

```bash
claude --plugin-dir /path/to/plannen-post
```

For development edits, `/reload-plugins` picks up changes without restarting.

## First run

```text
/plannen-post:post
```

On first run there is no config. The plugin will:

1. Create `~/.post/config.md` and `~/.post/profile.yaml` from the bundled examples.
2. Open `config.md` in `$EDITOR` (falls back to `vi`).
3. Exit with: "First-run setup — edit `~/.post/config.md` (and `~/.post/profile.yaml`), then run `/plannen-post:post` again."

Edit the sections you want in `config.md`, and put any bindings (sink routing, keys, must-watch senders) in `profile.yaml`, then re-run.

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

The Gmail draft body is rendered from `templates/newspaper.html`. Slots are HTML comments:

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
