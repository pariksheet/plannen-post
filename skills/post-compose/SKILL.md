---
name: post-compose
description: Compose and dispatch a personalised morning newspaper. Use when the user runs `/plannen-post:post`, asks for "the post", "today's post", "send my morning post", or otherwise asks plannen-post to compose and deliver today's edition.
allowed-tools: Read Write Bash WebSearch WebFetch
---

# post-compose (v2)

Compose a one-page personalised newspaper from data the user can reach (MCP tools,
web search, HTTP, CLI, files), render it into a styled edition, and deliver it to
the channels their config asks for.

**Detail lives in `reference/` — read each file when you reach its step, not before:**
- `reference/sources.md` — source types + gather rules (step 3)
- `reference/components.md` — assembly, component kit, placement, masthead, digest (step 5)
- `reference/delivery.md` — sinks, formats, fallback, security (step 7)
- `reference/failure-modes.md` — what to do when things break
- `${CLAUDE_PLUGIN_ROOT}/docs/ARCHITECTURE.md` — the full design, if anything is ambiguous

## Two files drive everything (strictly separated)

- **`~/.post/config.md`** — the *portable content brief*: frontmatter (`masthead`,
  `sources`, `sections`, `deliver`) + per-section prose hints (markdown body, one
  `## <section-id>` block each). Logical names only. **No secrets, identifiers,
  paths, or shell.**
- **`~/.post/profile.yaml`** — the *local profile*: resolves logical names to real
  accounts, keys, devices; holds non-MCP secrets, sink routing, must-watch senders,
  the optional render capability, shell sinks. **Never shared.**

## Principles (non-negotiable)

1. A source is anything that returns data; a sink is anything that accepts content.
2. **Declare structure, prompt for judgment** — frontmatter is deterministic; prose hints steer tone/selection.
3. **Fill slots, don't invent layout** — Pass 1 emits a plan; Pass 2 assembles from the theme's component kit. Never hand-write CSS.
4. **Intent is portable; bindings are local** — resolve logical names through the profile.
5. **Connected MCP = no binding needed** — the MCP server owns its auth.
6. **Capability-gated with graceful degradation** — probe; use if present; else fall back per declared order and warn.
7. **Short, bounded memory** — each edition persists as HTML + a JSON sidecar; keep the last 7; use it for continuity only.

Per-section and per-channel failures **never abort the run** (see `reference/failure-modes.md`).

---

## Run flow

**0. Load config + profile.**
- `~/.post/config.md` missing → first-run setup: `mkdir -p ~/.post`; copy
  `${CLAUDE_PLUGIN_ROOT}/examples/config.example.md` → `~/.post/config.md` and
  `examples/profile.example.yaml` → `~/.post/profile.yaml`; open the config
  (`${EDITOR:-vi} ~/.post/config.md`); print "First-run setup — edit
  `~/.post/config.md` (and `profile.yaml`), then run `/plannen-post:post` again."
  and exit. (Suggest `/plannen-post:setup` for a guided alternative.)
- Malformed frontmatter → print the first parse error verbatim, exit. Don't repair.
- `profile.yaml` may be absent → treat as empty (all-MCP setups need almost nothing); unresolved sinks/secrets are handled by capability-gating in step 7.

**1. Resolve runtime tokens.** Today = local date in `profile.defaults.timezone`
(fallback `Europe/Brussels`). Expand `{{since_last_edition}}` (see
`reference/sources.md`). Compute masthead vars: dateline, issue number (days since
`2026-01-01`, 3-digit), printed time (`"HH:MM am"` lowercase).

**2. Read prior memory (continuity).** Read the most recent 1–3
`~/.post/memory/*.json` sidecars; keep their `carryover`, `inbox_surfaced`,
`open_items` for Pass 1. **First run (no sidecars): no continuity — invent none.**

**3. Gather sources** — fan out, failure-isolated. See **`reference/sources.md`**.

**4. Pass 1 — editorial judgment.** Produce a structured section-plan:
- Spine sections always appear; dynamic sections appear only when their source
  returned usable data (`when: present`). You may improvise a new dynamic section
  for something notable, using only kit components.
- Write prose under each section's hint. **Limits:** ≤120 words/section, factual,
  present tense, no marketing, no emoji unless the data carries one.
- Pick the most notable thing across everything for `ai-intro` (the lead).
- **Continuity (gated):** weave in change-since-last-edition *only when it adds
  signal* — persistence, storyline carry, escalation, recurrence ("second
  reminder", "follow-up on last week's thread"). If the past adds nothing, stay
  silent. Never narrate "yesterday we said…".
- **Inbox** (if `inbox_new` / `inbox_open` exist): *main brief* from `inbox_new`
  (the 3–5 that matter; note how many others are tucked away); *still-open rail*
  from `inbox_open` (keep only threads whose **latest message is not the user's**
  AND from `profile.inbox.must_watch` or clearly awaiting reply; cap ~3; use prior
  `open_items` to escalate by `shown_count` and **drop** once the user has replied).
- Each planned section: `{ id, kind|component, slot, kicker, tagline, body, byline? }`.
  Also emit per-section `carryover`, `inbox_surfaced`, and updated `open_items`.

**5. Pass 2 — deterministic assembly.** Build the HTML from the theme + component
kit; flow dynamic sections to balance columns; substitute masthead; write the
plain-text digest. Full rules in **`reference/components.md`**.

**6. Write working memory.** Write the edition to `~/.post/memory/${TODAY}.html`
and the sidecar to `~/.post/memory/${TODAY}.json` (`{ date, carryover{per-section},
inbox_surfaced[], open_items[], events_today[], sections_rendered[],
sections_skipped[] }`). **Prune** to the 7 newest `YYYY-MM-DD.{html,json}` pairs.

**7. Deliver.** Resolve each `deliver` entry through the profile; capability-gate
format; dispatch per sink; walk `else:` on failure. Full rules in
**`reference/delivery.md`**.

**8. Report.** Tight terminal summary — sections rendered, sections skipped (with
reason), per-channel result, edition path, memory written. Example:

```
The Plannen Post composed.
  ✓ whatsapp png (msg 3EB0…)
  ⚠ gmail draft → skipped (sink unresolved)
Sections: intro · weather · events · inbox · sport · tech · startup · news · outro
Skipped:  watches — source empty
Edition:  /tmp/plannen-post-2026-05-29.html
Memory:   ~/.post/memory/2026-05-29.{html,json}
```
Drop the skipped block if all clean.

---

## Hard rules

- **Never auto-send Gmail** — `create_draft` only.
- **Never call destructive MCP tools** — read + compose + draft/notify only. No `create_*` / `update_*` / `delete_*`.
- **No CSS authoring** — Pass 1 plans, Pass 2 fills the kit. New info → new section from existing components.
- **No retries within a run** — log failures and move on; tomorrow's Post is the retry.
- **Only the profile may define `cli` sources or shell sinks** — a config references them by name, never introduces them.
- **Persistence is bounded** — write only `~/.post/config.md` (first run), `~/.post/memory/*` (rolling 7), `/tmp/plannen-post-*.html`. Nothing else.
- **Continuity is gated** — surface change-since-yesterday only when it adds signal.
