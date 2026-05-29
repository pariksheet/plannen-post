# plannen-post

A Claude Code plugin that composes a personalised morning newspaper from data gathered via your connected MCP tools, then delivers it to Gmail (as a draft) and Telegram.

Channels are the archive. No database, no web service, no Vercel deploy. One YAML file is the only mutable state.

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

1. Create `~/.post/config.yaml` from the bundled example.
2. Open it in `$EDITOR` (falls back to `vi`).
3. Exit with: "First-run setup — edit the config, then run `/plannen-post:post` again."

Edit the `to:` address for Gmail and the `chat_id:` for Telegram, then re-run.

## Scheduling

There is no scheduler in this plugin. Use Claude Code's `/schedule`:

```text
/schedule "weekdays at 07:00 Europe/Brussels: /plannen-post:post"
```

The routine inherits your MCP servers and your shell environment **as captured at the moment `/schedule` was run**. That matters for the Telegram bot token — see below.

## Telegram setup

1. Create a bot via `@BotFather` on Telegram. Save the token.
2. Send any message to your new bot, then grab your chat_id from `https://api.telegram.org/bot<TOKEN>/getUpdates`.
3. Put the chat_id in `~/.post/config.yaml`.
4. Put the token in your shell environment — **in `~/.zshenv`, not `~/.zshrc`**:
   ```sh
   export TELEGRAM_BOT_TOKEN="123456789:ABC-..."
   ```
   `~/.zshrc` only loads for interactive shells; `/schedule`'s background routine is non-interactive. If the token isn't visible to the routine, the Telegram channel is skipped with a warning and Gmail still goes out.

To send Telegram-only without Gmail, comment out the gmail entry in `delivery:`.

## Sections

Each entry in `sections:` becomes a block in the newspaper. The block's `id` matches a slot in `templates/newspaper.html`.

### Kinds

| kind | what it does | required fields |
|---|---|---|
| `ai-intro` | Model writes 2-3 lines from all gathered data. Placed early. | — |
| `ai-outro` | Same, placed at the close. | — |
| `mcp-call` | Invokes an MCP tool. | `mcp`, `tool`. Optional `args`, `prose`. |
| `http-fetch` | Curls a URL. | `url`, `as: text\|json`. Optional `prose`. |

The optional `prose:` hint on data sections is a free-form prompt that tells the model how to summarise the raw data. Examples:

```yaml
prose: |
  One sentence on today's weather. Lead with the headline, then high/low.
```

```yaml
prose: |
  Pick the 3-5 threads that look most worth knowing about. Skip newsletters.
  For each: sender, one-line summary, why it matters.
```

If you omit `prose:`, the section renders a scannable bulleted/labelled summary of the raw data — usually fine for things like a calendar feed.

### Per-section failure isolation

If an MCP server is not connected, a tool errors, or a URL times out, that section is skipped with a warning. The run continues. The terminal report at the end lists which sections were dropped.

## Customising the look

The Gmail draft body is rendered from `templates/newspaper.html`. Slots are HTML comments:

```html
<!-- {{intro}} -->
<!-- {{weather}} -->
<!-- {{events}} -->
<!-- {{email}} -->
<!-- {{outro}} -->
```

You can rearrange them across columns, add columns, or change the CSS — the skill just substitutes section content into matching markers. A slot with no matching section becomes an empty string and collapses gracefully.

`design-ref/A1.html` is the original visual reference (a hand-drawn three-column newspaper aesthetic). It is not used at runtime — it is kept as a design spec for anyone reworking the template.

## Out of scope in v1

- **No Gmail send** — the Gmail MCP exposes `create_draft` only. You review and send manually.
- **No persistence** — channels are the archive. The skill writes a transient HTML file to `/tmp/` and nothing else.
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
