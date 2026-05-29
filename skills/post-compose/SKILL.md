---
name: post-compose
description: Compose and dispatch a personalised morning newspaper. Use when the user runs `/plannen-post:post`, asks for "the post", "today's post", "send my morning post", or otherwise asks plannen-post to compose and deliver today's edition.
allowed-tools: Read Write Bash WebSearch WebFetch
---

# post-compose (v2)

You compose a one-page personalised newspaper from data the user can reach
(MCP tools, web search, HTTP, CLI, files), render it into a styled HTML edition,
and deliver it to the channels their config asks for.

Two files drive everything, and they are **strictly separated**:

- **`~/.post/config.md`** — the *portable content brief*. Frontmatter (sources,
  sections, delivery) + prose-hint body. Logical names only. **No secrets, no
  personal identifiers, no machine paths, no shell commands.**
- **`~/.post/profile.yaml`** — the *local profile*. Resolves logical names to real
  accounts, keys, devices. Holds non-MCP secrets, sink routing, must-watch
  senders, and the optional render capability. **Never shared.**

The architecture this implements lives in `${CLAUDE_PLUGIN_ROOT}/docs/ARCHITECTURE.md`
— read it if anything here is ambiguous. Core principles you must honour:

1. **A source is anything that returns data; a sink is anything that accepts content.**
2. **Declare structure, prompt for judgment.** Frontmatter is deterministic; prose hints steer tone/selection.
3. **Fill slots, don't invent layout.** Pass 1 emits a *plan*; Pass 2 assembles HTML from the theme's component kit. Never hand-write CSS.
4. **Intent is portable; bindings are local.** Resolve logical names through the profile.
5. **Connected MCP = no binding needed.** The MCP server owns its auth.
6. **Capability-gated with graceful degradation.** Probe; use if present; else fall back per declared order and warn.
7. **Short, bounded memory.** Each edition persists as HTML + a JSON sidecar; keep the last 7; use it for continuity only.

Per-section and per-channel failures **never abort the run** — capture and report them.

---

## Run flow

### 0. Load config + profile

- **`~/.post/config.md`** missing → first-run setup:
  1. `mkdir -p ~/.post`
  2. Copy `${CLAUDE_PLUGIN_ROOT}/examples/config.example.md` → `~/.post/config.md`
     and `${CLAUDE_PLUGIN_ROOT}/examples/profile.example.yaml` → `~/.post/profile.yaml`.
  3. Open the config in the editor: `${EDITOR:-vi} ~/.post/config.md`.
  4. Print: "First-run setup — edit `~/.post/config.md` (and `~/.post/profile.yaml`), then run `/plannen-post:post` again." Exit cleanly.
- Malformed frontmatter → print the first parse error verbatim and exit. Do not repair.
- `~/.post/profile.yaml` may be absent — treat as an empty profile (all-MCP setups need almost nothing). Sinks/secrets/must_watch that the config references but the profile doesn't resolve are handled by capability-gating in step 7.

Parse from the config: `masthead`, `sources`, `sections`, `deliver` (frontmatter)
and the per-section prose hints (markdown body, one `## <section-id>` block each).

### 1. Resolve runtime tokens

- **Today** = local date in `profile.defaults.timezone` (fallback `Europe/Brussels`).
- **`{{since_last_edition}}`** → look at `~/.post/memory/` for the newest `YYYY-MM-DD.html`. If found, expand to `after:YYYY/MM/DD` (its date). If memory is empty, expand to `newer_than:1d`. This is what makes Monday reach back to Friday and a skipped day get covered. Substitute the token anywhere it appears in a source's `args`.
- Compute masthead vars: dateline, issue number (days since `2026-01-01`, zero-padded to 3), printed time (`"HH:MM am"` lowercase).

### 2. Read prior memory (continuity)

Read the most recent 1–3 sidecars from `~/.post/memory/*.json`. Keep their
`carryover`, `inbox_surfaced`, and `open_items` in mind for Pass 1. This is how
continuity works — you join today's fresh data with yesterday's facts. **First
run (no sidecars): there is no continuity; do not invent any.**

### 3. Gather sources (fan-out, failure-isolated)

Walk `sources`. For each, dispatch by `type`. Resolve any `secret: NAME` to
`profile.secrets.NAME` (or the env var it names). Store the result keyed by source
`name`. On **any** failure (MCP not connected, tool error, non-2xx, timeout, parse
error, missing secret), capture `{source, error}` and continue.

| type | how to fulfill |
|---|---|
| `mcp` | Resolve `tool: server.name` to an available MCP tool — try `mcp__<server>__<name>` and the plugin form `mcp__plugin_<server>_<server>__<name>`; match whichever exists. Invoke with `args` (default `{}`). |
| `http` | `curl -sS --max-time 15 <url>` (inject secret header/param if `secret:` set). `as: json` → parse; else text. |
| `web-search` | Run `WebSearch` with `query`. Keep titles + URLs for provenance. |
| `cli` | **Only if defined in the profile** (security). Run the profile's command, capture stdout. A config naming a `cli` source the profile doesn't define is skipped with a warning. |
| `file` | Read the path (from profile if machine-specific). |

`ai-intro` / `ai-outro` sections have no source — skip here, compose in Pass 1.

### 4. Pass 1 — editorial judgment

Produce a **structured section-plan** (you'll assemble it in Pass 2). For each
section in `sections`:

- **Spine** sections always appear. **Dynamic** sections (`slot: dynamic`) appear
  only when their source returned usable data — honour `when: present`. You may
  also **improvise a new dynamic section** when a source surfaced something
  notable that no configured section covers, using only components from the kit.
- Write prose under the section's hint. **Limits:** ≤120 words/section, factual,
  present tense, no marketing voice, no emoji unless the source data carries one.
- **Lead/order:** pick what's most notable across everything for the `ai-intro`.
- **Continuity (gated):** weave in change-since-last-edition *only when it adds
  signal* — persistence ("3rd day of high pollen"), storyline carry, escalation
  ("Silvia — 3rd day waiting"), recurrence ("second reminder", "follow-up on last
  week's thread"). If the past adds nothing, stay silent. Never narrate "yesterday
  we said…".

**Inbox specifics** (if the config has `inbox_new`/`inbox_open` sources):
- *Main brief* from `inbox_new`: the 3–5 that matter; note how many others are tucked away.
- *Still-open rail* from `inbox_open`: keep only threads whose **latest message is not from the user** AND that are from `profile.inbox.must_watch` senders or clearly await a reply. Cap ~3. Use prior `open_items` to escalate by `shown_count` and to **drop** an item once the user has replied (latest message is now theirs).

Each planned section is: `{ id, kind|component, slot, kicker, tagline, body, byline? }`.
Also emit the **carryover** facts each section wants to leave for tomorrow, plus
`inbox_surfaced` (thread ids) and updated `open_items` (with `shown_count`).

### 5. Pass 2 — deterministic assembly

Read `${CLAUDE_PLUGIN_ROOT}/templates/<masthead.theme or "newspaper">.html`.

**Render each planned section** as an `<article>` using the component kit
(omit blocks for absent fields):

```html
<article class="post-section post-section--<id>">
  <div class="kicker">{KICKER}</div>      <!-- omit for outro -->
  <h2 class="hand">{tagline}</h2>          <!-- omit if none -->
  <p class="byline">{byline}</p>           <!-- intro only, optional -->
  <hr class="dashed">                      <!-- omit for outro & weather -->
  <div class="body">{body_html}</div>
</article>
```

Component → markup (the theme's CSS does the styling; never write CSS):

| component | render the body as |
|---|---|
| `card` | paragraphs in `<p>` |
| `list` | `<ul><li>` (CSS adds the arrow) |
| `stat` | `<div class="stat"><span class="num">N</span><span class="lbl">…</span></div>` |
| `quote` | `<blockquote class="pull">…</blockquote>` |
| `two-col` | `<div class="twocol"><div>…</div><div>…</div></div>` |
| `photo` | `<figure><img src="…"><figcaption>…</figcaption></figure>` |
| `sticky-note` | outro styling (set by `post-section--outro`) |

**Place sections:**
- **Spine** → its named slot: replace `<!-- {{<id>}} -->` (intro, weather, events, inbox, outro).
- **Dynamic** → flow into the **dynamic zone** to balance columns: fill
  `<!-- {{dynamic.left}} -->` and `<!-- {{dynamic.center}} -->` first (and
  `<!-- {{dynamic.right}} -->` only if needed), appending each section to whichever
  marker's column is currently **shortest** by rough rendered height. Never leave
  one column long and another empty.
- A slot with no matching/failed section → empty string; the column collapses cleanly.

**Masthead substitution:**
- `<!-- {{masthead.dateline}} -->` → `"{Day} · {DD} {Mon} · morning edition[ · for the {family}][ · {emoji} {temp}°C]"`. Drop the family clause if `masthead.family` is unset; drop the weather clause if no weather data. Emoji: ☀ clear, ⛅ partly cloudy, ☁ overcast, 🌧 rain, ❄ snow, 🌫 fog.
- `<!-- {{masthead.printed}} -->` → the printed time from step 1.

Write the rendered HTML to `/tmp/plannen-post-${TODAY}.html`.

**Plain-text digest** (for text sinks): per section emit `KICKER` heading, blank
line, tagline-then-body; join sections with `\n\n---\n\n`; prepend
`THE PLANNEN POST — {Day DD Mon}`. Outro: body only.

### 6. Write working memory

- Write the rendered HTML to `~/.post/memory/${TODAY}.html`.
- Write the sidecar to `~/.post/memory/${TODAY}.json`: `{ date, carryover{per-section}, inbox_surfaced[], open_items[], events_today[], sections_rendered[], sections_skipped[] }` — i.e. the Pass-1 plan's continuity facts.
- **Prune**: keep only the 7 newest `YYYY-MM-DD.{html,json}` pairs; delete older.

### 7. Deliver (sinks, capability-gated)

For each entry in `deliver` (a `{to, format, else?}` triple), resolve `to` to
`profile.sinks.<to>` and dispatch independently. One channel failing never blocks
another. Walk the `else:` chain on missing capability; warn.

- **Format gating.** `html` is always available. `png`/`pdf` require
  `profile.render` (an `html→{png,pdf}` capability — a render MCP, or a local shell
  renderer such as `scripts/render-png.sh`). To produce the asset: run the render
  capability with `{in}` = the `/tmp` HTML edition and `{out}` = a `/tmp` image
  path (for `via: shell`, substitute `{in}`/`{out}`/`{format}` into the command and
  run it). If no render capability exists → take `else:` (e.g. `text`, `html-link`,
  `skip`) and record a warning.
- **Sink dispatch by `via`:**
  - `via: mcp` → call the named MCP tool. **Gmail (`gmail.create_draft`) is
    draft-only — never send.** For an **image/pdf** format on an image-capable sink
    (e.g. `whatsapp-notify.send_notification`), pass the rendered file as the tool's
    image/file parameter (`imagePath`) with the masthead line as the `message`
    caption. For **text** format, send the plain-text digest (chunk to ≤4000 chars
    on `---` boundaries for chat sinks).
  - `via: http` → curl (e.g. legacy Telegram `sendMessage` with `${env:TOKEN}`). If
    a required env var/token is unset, capture "skipped: <VAR> not set" and continue.
  - `via: shell` → run the profile's command with `{file}`/`{format}` substituted.
    **Shell sinks are valid only when defined in the profile** — never run a shell
    command a config introduced.
- A `to:` the profile doesn't resolve → skip with a warning.

Capture each channel's result (draft id, messages sent, file path, or the skip reason).

### 8. Report

Tight terminal summary: sections rendered, sections skipped (with reason),
per-channel result, the edition path, and that memory was written. Example:

```
The Plannen Post composed.

  ✓ gmail draft (id: r-3f8a…)
  ⚠ whatsapp png → fell back to text (no render capability)

Sections: intro · weather · events · inbox · sport · tech · startup · news · outro
Skipped:  watches — source empty
Edition:  /tmp/plannen-post-2026-05-29.html
Memory:   ~/.post/memory/2026-05-29.{html,json}
```

If everything worked, drop the skipped block. If all sources failed, still compose
intro+outro from an empty set ("quiet morning") and deliver that.

---

## Hard rules

- **Never auto-send Gmail.** `create_draft` only — the user reviews and sends.
- **Never call destructive MCP tools.** Read + compose + draft/notify only. No `create_*`, `update_*`, `delete_*`.
- **No CSS authoring.** Pass 1 plans; Pass 2 fills the kit. New info → new section *from existing components*, never new styles.
- **No retries within a run.** Log failures and move on. Tomorrow's Post is the retry.
- **Only the profile may define `cli` sources or shell sinks.** A config can reference them by name but never introduce them.
- **Persistence is bounded.** Write only `~/.post/config.md` (first run), `~/.post/memory/*` (rolling 7), and `/tmp/plannen-post-*.html`. No other state.
- **Continuity is gated.** Surface change-since-yesterday only when it adds signal.

## Failure modes

- **`~/.post/config.md` missing** → first-run flow, exit cleanly.
- **A source fails** → skip its section(s), report it; the run continues.
- **All sources fail** → compose a minimal intro+outro and deliver with warnings.
- **A format isn't renderable** (no `profile.render`) → take the delivery's `else:` and warn.
- **A sink is unreachable / unresolved** → skip that channel, keep the others.
- **No delivery channel works** → the HTML at `/tmp` and `~/.post/memory/` is the recovery; exit non-zero with the errors printed.
