---
name: post-compose
description: Compose and dispatch a personalised morning newspaper. Use when the user runs `/post`, asks for "the post", "today's post", "send my morning post", or otherwise asks plannen-post to compose and deliver today's edition.
allowed-tools: Read Write Bash WebSearch WebFetch
---

# post-compose (v2)

Compose a one-page personalised newspaper from data the user can reach (MCP tools,
web search, HTTP, CLI, files), render it into a styled edition, and deliver it to
the channels their config asks for.

**Detail lives in `reference/` — read each file when you reach its step, not before:**
- `reference/sources.md` — source types + gather rules, join keys (step 3)
- `reference/components.md` — assembly, component kit, cross-ref note, placement, masthead, digest (step 5)
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
  `~/.post/config.md` (and `profile.yaml`), then run `/post` again."
  and exit. (Suggest `/post-setup` for a guided alternative.)
- Malformed frontmatter → print the first parse error verbatim, exit. Don't repair.
- `profile.yaml` may be absent → treat as empty (all-MCP setups need almost nothing); unresolved sinks/secrets are handled by capability-gating in step 7.

**1. Resolve runtime tokens.** Today = local date in `profile.defaults.timezone`
(fallback `Europe/Brussels`). Expand `{{since_last_edition}}` (see
`reference/sources.md`). Compute masthead vars: dateline, issue number (days since
`2026-01-01`, 3-digit), printed time (`"HH:MM am"` lowercase).
- **Timezone applies to *times*, not just the date.** Source timestamps are
  usually **UTC** (ISO with a `Z` suffix — e.g. MCP event `start_date`/`end_date`
  like `2026-06-05T16:15:00.000Z`). Convert every displayed time to
  `profile.defaults.timezone` before writing it, and never print a raw `Z`
  wall-clock — it lands hours early.
  - **Convert deterministically — don't eyeball the offset.** DST and offset vary
    by zone *and* date, so mental math is unsafe for arbitrary zones. Shell out,
    e.g.:
    `python3 -c "import sys;from datetime import datetime;from zoneinfo import ZoneInfo;print(datetime.fromisoformat(sys.argv[1].replace('Z','+00:00')).astimezone(ZoneInfo(sys.argv[2])).strftime('%H:%M'))" 2026-06-05T16:15:00Z "$TZ"`
    → `18:15` for `Europe/Brussels`, `02:15` (next day) for `Australia/Sydney`,
    `21:45` for `Asia/Kolkata`. Works for any IANA zone. Sanity-check against
    recurring cadence / calendar notices, which already state local time.

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
  (the 3–5 that matter; note how many others are tucked away). *Still-open rail*
  from `inbox_open`: read each candidate thread **end-to-end, the user's own sent
  replies included**, and classify it by the **last message's author *and*
  content** — never by position alone (a courteous "Perfect!" from the other side
  is a close, not an open ask). Three outcomes:
  - **awaiting the user** — the counterparty's latest message asks for or expects
    something the user hasn't answered → surface as an action in the user's court.
  - **awaiting the counterparty** — the user's latest message asked or delivered
    something and there's been no reply → surface as *"No response yet from
    <sender> (Nth day)"*. Gate these to `profile.inbox.must_watch` senders or
    threads where a reply is clearly expected — don't nag every sent mail.
    **Not an open loop:** a submission *against a standing facility* — a
    budget/allowance the user draws down, an expense or claims portal, a
    reimbursement envelope, a recurring filing — where no reply is the normal flow.
    Silence there is the process working, not a stall; never flag it as waiting.
    (E.g. submitting invoices against a fixed education-reimbursement *budget* is
    consumption, not a pending question.)
  - **resolved** — the last message merely acknowledges or closes the loop
    ("thanks / received / perfect / all set"), from **either** side, or the
    counterparty has acknowledged something the user already sent → **drop**; never
    flag a done thread.
  When the snippet doesn't settle the state, fetch the thread (`get_thread`) for
  rail candidates only. Cap ~3 total; use prior `open_items` to escalate by
  `shown_count` and drop once a thread reaches *resolved*.
  - **Reconcile loops by entity, not by thread.** A reply often arrives in a
    *different* thread — a fresh subject, or a ticketing/no-reply address — so the
    original thread still ends on the user's message and falsely reads *awaiting the
    counterparty* forever. Before re-surfacing any carried `open_item` as "no
    response yet," scan **all** recent mail (not just its thread) for a newer inbound
    that matches the loop's **signature**, then reclassify on that match. Persist the
    signature on each `open_item` as `match: { sender, ref, topic }`:
    - **`ref` is the strong key** — a case/ticket/invoice number (e.g.
      `CASE-10293`). Run one targeted search for the ref token; a newer inbound hit
      *anywhere* closes or advances the loop. Highest precision — prefer it.
    - **`sender` + `topic` is the fallback** when there's no ref.
    - **`sender` alone is never sufficient.** One counterparty often runs several
      parallel cases (same HR/finance address, different refs); matching on sender
      would wrongly resolve loop A the moment an unrelated reply B from the same
      sender lands. Disambiguate by ref/topic, always.
- Each planned section: `{ id, kind|component, slot, kicker, tagline, body, byline? }`.
  Also emit per-section `carryover`, `inbox_surfaced`, and updated `open_items`.

**4.5 Pass 1.5 — reconcile across sections.** Pass 1 writes each section blind to
the others. This step is the *only* place the plan is read as a whole — it removes
duplication and draws connections, working on the **structured section objects**, not
rendered HTML. No new sources. Two parts:

- **De-dup by ownership.** Every fact has exactly one canonical home:
  - a scheduled item → **events** · an email thread → **inbox** · the forecast →
    **weather** · a news/feed item → its dynamic section.
  - If a fact also surfaces in a non-owner section, the non-owner **drops it** or
    demotes it to a one-line pointer ("more in today's events") — never restates it.
  - The **lead (`ai-intro`)** is the one exception: it may reference any fact, but
    only if it adds an *angle* (why it's the day's headline), never a verbatim echo
    of the owning section.

- **Correlate — inline on the owning event.** Join sections on a **concrete shared
  key — time window, location, or person** — never on theme or vibe. For each event,
  scan the other sections' data for an intersection and attach a `cross_refs[]` entry
  to that event **only when the connection is *actionable*** — i.e. it changes what
  the user would do:
  - weather hazard during an event whose `outdoor`/category says it's exposed → attach
    (e.g. *hail 18:00 ⨯ outdoor skating*); the **same hazard during an indoor event →
    stay silent**. Over-correlation trains the reader to ignore the post — silence is
    the safer default.
  - two events whose windows collide, or whose back-to-back travel time doesn't fit →
    attach to the earlier one.
  - an inbox thread *about* an event happening today → attach to the event.
  - Each `cross_refs` entry: `{ note, severity? }` — one terse clause, present tense.
    Cap **one per event**, the most actionable; if none clears the actionability bar,
    attach nothing. Correlations live on the event, never as their own section (a
    "connections" box would just re-introduce the duplication de-dup just removed).

Emit the reconciled plan (sections with `cross_refs` populated, duplicates pruned)
to Pass 2. The join only works if the gathered data carries keys — see
`reference/sources.md` for the event/weather fields it needs.

**5. Pass 2 — deterministic assembly.** Build the HTML from the theme + component
kit; place sections into their page-column (left = day, center = feeds, right =
personal — each column renders as one page); substitute masthead; write the
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
