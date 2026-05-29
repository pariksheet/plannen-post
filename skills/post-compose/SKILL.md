---
name: post-compose
description: Compose and dispatch a personalised morning newspaper. Use when the user runs `/plannen-post:post`, asks for "the post", "today's post", "send my morning post", or otherwise asks plannen-post to compose and deliver today's edition.
allowed-tools: Read Write Bash
---

# post-compose

You are composing a one-page personalised newspaper from data gathered via the user's connected MCP tools, then dispatching it to Gmail (as a draft) and Telegram.

Channels are the archive. There is no database. Tomorrow's Post is the retry.

## Run flow

Execute these phases in order. Per-section errors do **not** abort the run — they are captured and reported at the end.

### 1. Load config

Config lives at `~/.post/config.yaml`.

- If the file does **not** exist:
  1. Copy `${CLAUDE_SKILL_DIR}/../../config.example.yaml` to `~/.post/config.yaml` (creating `~/.post/` first).
  2. Open it in `$EDITOR` (or `vi` if `$EDITOR` is unset): `${EDITOR:-vi} ~/.post/config.yaml`.
  3. Print: "First-run setup — edit the config, then run `/plannen-post:post` again." Exit cleanly.
- If the file exists but is malformed YAML, print the first parser error verbatim and exit. Do not attempt repair.

Read `sections` and `delivery` from the config. These are the only required top-level keys.

### 2. Fan out raw data

Walk `sections` in order. For each section, dispatch by `kind`:

| kind | how to fulfill |
|---|---|
| `ai-intro` | **Skip in this phase.** Composed in step 4 once everything else is gathered. |
| `ai-outro` | **Skip in this phase.** Composed in step 4. |
| `mcp-call` | Resolve `mcp: <server>, tool: <name>` to an available MCP tool (try both `mcp__<server>__<name>` and the plugin-prefixed `mcp__plugin_<server>_<server>__<name>` form — match whichever exists in your tool list). Invoke with the section's `args` (default `{}`). Store the result keyed by section `id`. |
| `http-fetch` | `curl -sS --max-time 15 <url>`. If `as: json`, parse to a structured object; otherwise keep as text. Store keyed by section `id`. |

**Per-section error handling.** If any of the following happens, do not raise — capture a `{section_id, error}` record and continue with the next section:
- MCP tool not connected (no matching tool name).
- MCP tool returns an error result.
- HTTP fetch returns non-2xx, or curl times out.
- JSON parse fails when `as: json`.

You will report all captured errors in step 6.

### 3. Compose prose for data sections

For each gathered section that has a `prose:` hint, write 1-3 paragraphs of prose using the hint as guidance. The hint is a free-form prompt — follow it.

If a section has **no** `prose:` hint, present the raw data as a tight bulleted or labelled summary, your call — keep it scannable.

Hard limits per section:
- Maximum 120 words.
- No marketing voice. Direct, factual, present tense.
- No emojis unless the source data itself contains one.

### 4. Compose `ai-intro` and `ai-outro`

Now that all data sections are written, compose the two AI sections from the full gathered set.

- **intro (`ai-intro`):** 2-3 lines. Set the tone of the day. Lead with whatever is most notable across all sections (a big event, a weather warning, an important email). Conversational but tight.
- **outro (`ai-outro`):** 2-3 lines. A closing thought. Could be a forward look ("rain tomorrow"), a reminder ("don't forget the dentist"), or simply a sign-off.

### 5. Render two views

Build a `{section_id → {kicker, tagline, body_html, body_text}}` dictionary. Per-section rules:

| id | kicker | tagline | notes |
|---|---|---|---|
| `intro` (ai-intro) | `LEAD STORY` | **required** — a short imperative-ish headline (~6-12 words) summarising the day | Body is 2-3 paragraphs. Optionally include a `<p class="byline">by your narrator · N min read</p>` after the tagline. |
| `outro` (ai-outro) | omit | omit | Body is 2-3 short lines. Renders as a yellow sticky note. |
| `weather` | `WEATHER` | optional — one-line tone-setter like "Sunny, with errands" | Body is the prose hint output. Renders inside a blue panel. |
| `events` | `EVENTS` | optional — e.g., "Two pickups, one practice" | Body should use `<ul><li>` for each event (CSS prepends an arrow). |
| `email` | `INBOX BRIEF` | optional | Body should use `<ul><li>` (arrows applied by CSS). If you summarised N of M threads, append `<p class="faint">M−N others tucked away.</p>` |
| _any other id_ | uppercased id | optional | Default rendering — kicker + optional tagline + dashed rule + body. |

**HTML per section** (omit blocks for null fields):
```html
<article class="post-section post-section--<id>">
  <div class="kicker">{KICKER}</div>           <!-- omit for outro -->
  <h2 class="hand">{tagline}</h2>              <!-- omit if no tagline -->
  <hr class="dashed">                          <!-- omit for outro and weather -->
  <div class="body">{body_html}</div>
</article>
```
Wrap each paragraph in `<p>`. For lists, use `<ul><li>`. Keep markup minimal — the template's CSS does the styling work.

**Plain text per section** (for Telegram digest): kicker-as-heading, blank line, tagline-then-body. Example:
```
WEATHER

Sunny, with errands

AM clear, PM hazy. High 22, low 14. No rain expected.
```
For outro, skip kicker and tagline; just emit the body text.

**HTML template substitution.** Read `${CLAUDE_SKILL_DIR}/../../templates/newspaper.html`. Then substitute, in this order:

1. **Section slots.** For each section, replace `<!-- {{<id>}} -->` with its `<article>…</article>` block. A slot with no matching section (or a failed section) becomes empty string — the column collapses cleanly.

2. **Masthead variables:**
   - `<!-- {{masthead.dateline}} -->` → composed dateline. Format: `"{day} · {DD} {Mon} · morning edition · for the {family} · {weather_emoji} {temp}°C"`. Examples:
     - Full: `"Friday · 22 May · morning edition · for the Cohen family · ☀ 24°C"`
     - Family name unknown: drop the `for the … family` clause.
     - No weather data: drop the `· ☀ 24°C` clause.
     - Use weather emoji from: ☀ (clear), ⛅ (partly cloudy), ☁ (overcast), 🌧 (rain), ❄ (snow), 🌫 (fog).
     - Family name source: look in the gathered `plannen` data (e.g., `get_briefing_context` may return a profile). If absent, omit.
   - `<!-- {{masthead.issue}} -->` → integer count of days since `2026-01-01`, zero-padded to 3 digits. E.g., on 2026-05-22 this is "142". Computed inline.
   - `<!-- {{masthead.printed}} -->` → current local time as `"HH:MM am"` lowercase, en-GB 24-clock styled (e.g., `"06:14 am"`, `"14:30 pm"`).

3. **Empty-comment cleanup.** After substitution, leave any remaining `<!-- {{…}} -->` markers as-is (they render invisibly). Do not error on unknown slots — they may be hand-added by the user.

Save the rendered HTML to `/tmp/plannen-post-${YYYY-MM-DD}.html` (overwrite ok). This is the Gmail body. **Do not write anywhere else.** No persistent log.

**Plain text digest.** Join all sections' plain-text blocks with `\n\n---\n\n` between them. Prepend a single header line: `THE PLANNEN POST — {Friday 22 May}`. This is what Telegram receives.

### 6. Dispatch

For each entry in `delivery`, dispatch independently. A failure in one channel does **not** block the other.

**`channel: gmail`** — call `mcp__claude_ai_Gmail__create_draft` with:
- `to`: from the config.
- `subject`: `config.subject` with `{{date}}` substituted as "Fri 22 May 2026" (locale: en-GB). Default `Post — {{date}}` if no subject set.
- `body`: the rendered HTML from step 5. Pass `mimeType: text/html` if the tool's schema supports it; otherwise pass the HTML as plain `body` and let Gmail render.

Capture the returned `draft_id` for the terminal report.

**`channel: telegram`** — POST to `https://api.telegram.org/bot${TOKEN}/sendMessage` via curl:
1. Read the token from the env var named in `bot_token_env` (default `TELEGRAM_BOT_TOKEN`).
2. **If the env var is unset or empty**, capture this as a delivery error ("Telegram skipped: $TELEGRAM_BOT_TOKEN not set") and continue. Do **not** prompt the user.
3. Split the plain-text digest into chunks ≤ 4000 chars on `---` boundaries (or on section boundaries if a single section is too long).
4. For each chunk:
   ```bash
   curl -sS -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
     --data-urlencode "chat_id=${CHAT_ID}" \
     --data-urlencode "text=${CHUNK}"
   ```
   No `parse_mode` — plain text, all-caps headings.
5. Capture the number of messages sent for the report.

### 7. Report to terminal

Print a tight summary. Example:

```
plannen-post composed and dispatched.

  ✓ gmail draft created (id: r-3f8a92...)
  ✓ telegram (3 messages to chat 12345678)

Sections rendered: intro, weather, events, email, outro
Sections skipped:
  ⚠ weather — http_fetch: curl exit 28 (timeout)

Edition saved at /tmp/plannen-post-2026-05-22.html
```

Adapt to actual results. If everything worked, drop the "skipped" block. If everything failed, lead with the error summary.

## Hard rules

- **Never auto-send Gmail.** Only `create_draft`. The user reviews and sends manually. This is a v1 limitation tied to the Gmail MCP's capability set.
- **Never call destructive MCP tools.** This skill is read + compose + draft. No `create_event`, no `delete_*`, no `update_*`.
- **No retries within a run.** If a section fails or a channel fails, log it and move on. Tomorrow's Post is the retry.
- **No persistent state.** The plugin writes only to `~/.post/config.yaml` (on first run) and `/tmp/plannen-post-*.html` (ephemeral). No logs, no cache, no archive.
- **Trust the user's MCP servers.** Do not introduce new tool calls beyond what the config asks for and what step 6 requires for dispatch.

## Failure modes worth knowing

- **`~/.post/config.yaml` missing** → first-run flow, exits cleanly (step 1).
- **All sections fail** → still dispatch what you have: intro + outro can compose from an empty dataset ("nothing to report this morning"). Report it as a Post-with-warnings.
- **Both channels fail** → exit non-zero. Print errors. The HTML at `/tmp/plannen-post-*.html` is recovery.
- **`TELEGRAM_BOT_TOKEN` env var missing in a `/schedule` routine** → almost always because it was set in `~/.zshrc` instead of `~/.zshenv`. Mention this in the warning text.
