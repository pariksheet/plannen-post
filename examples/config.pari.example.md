---
# =============================================================================
# config.pari.example.md — a real-world, fully-loaded config (the maintainer's
# actual setup), shown as a "what a rich config looks like" reference.
#
# It integrates the separate plannen product (github.com/pariksheet/plannen) for
# family events + watched events, adds an air-quality (pollen) source alongside
# weather, four web-search beats (sport/news/tech/startup), the two-bucket inbox,
# and PNG-to-WhatsApp delivery.
#
# For a from-scratch generic starter that needs NO plannen, see config.example.md.
# Carries logical names only — no secrets. Bindings live in profile.yaml.
# =============================================================================

masthead:
  title: "THE PLANNEN POST"
  theme: classic

# ── sources (data in) ────────────────────────────────────────────────────────
sources:
  - name: weather                       # open-meteo forecast — Mechelen
    type: http
    url: "https://api.open-meteo.com/v1/forecast?latitude=51.03&longitude=4.48&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code,uv_index_max&hourly=temperature_2m,precipitation_probability,precipitation,weather_code,wind_gusts_10m&models=best_match,knmi_harmonie_arome_netherlands,dwd_icon_d2,meteofrance_arome_france_hd,ecmwf_ifs025&timezone=Europe%2FBrussels&forecast_days=2"
    as: json
  - name: pollen                        # open-meteo air-quality — pollen per type
    type: http
    url: "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=51.03&longitude=4.48&hourly=alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,ragweed_pollen&timezone=Europe%2FBrussels&forecast_days=1"
    as: json
  - name: plannen                       # day context / events — needs the plannen MCP
    type: mcp
    tool: plannen.get_briefing_context
  - name: inbox_new                     # main brief: new & notable
    type: mcp
    tool: gmail.search_threads
    args: { query: "(is:unread OR is:starred) {{since_last_edition}} -category:promotions -category:social", max_results: 25 }
  - name: inbox_open                    # 'still open' rail: read but unanswered
    type: mcp
    tool: gmail.search_threads
    args: { query: "in:inbox -in:sent newer_than:7d -category:promotions -category:social -from:notifications@github.com -from:no-reply -from:noreply -from:support@mailgun.net -from:calendar-notification@google.com", max_results: 30 }
  - name: inbox_sent                    # threads where I wrote last — to detect 'no reply yet'
    type: mcp
    tool: gmail.search_threads
    # Recent threads I've sent into. The editorial pass checks each: if my message
    # is the LATEST and the other side hasn't answered, it's a 'waiting on them'
    # item → "No response yet from <sender>". Catches cold outreach with no inbound
    # (e.g. a fresh quote request) that in:inbox would miss entirely.
    args: { query: "in:sent newer_than:7d", max_results: 25 }
  - name: sport
    type: web-search
    query: "IPL T20 latest results and news; football hockey cricket matches near Mechelen Belgium this week"
  - name: news
    type: web-search
    query: "top news vrt.be today; Mechelen local news today"
  - name: tech
    type: web-search
    query: "Databricks latest announcements product releases"
  - name: startup
    type: web-search
    query: "EU AI startup funding rounds and VC investments this week"
  - name: watches                       # needs the plannen MCP
    type: mcp
    tool: plannen.get_watch_queue

# ── sections ─────────────────────────────────────────────────────────────────
sections:
  - id: intro
    slot: spine
    kind: ai-intro
  - id: weather
    slot: spine
    source: [weather, pollen]
    component: card
  - id: events
    slot: spine
    source: plannen
    component: list
  - id: inbox
    slot: spine
    source: [inbox_new, inbox_open, inbox_sent]
    component: list
  - id: sport
    slot: dynamic
    source: sport
    component: card
    when: present
  - id: news
    slot: dynamic
    source: news
    component: list
    when: present
  - id: tech
    slot: dynamic
    source: tech
    component: card
    when: present
  - id: startup
    slot: dynamic
    source: startup
    component: list
    when: present
  - id: watches
    slot: dynamic
    source: watches
    component: list
    when: present
  - id: outro
    slot: spine
    kind: ai-outro

# ── delivery ─────────────────────────────────────────────────────────────────
deliver:
  - to: whatsapp
    format: png
    else: text
---

## intro
2-3 lines, front-page lead. Open with whatever is most notable across everything
gathered today — a big event, a weather/pollen warning, an important email, a
score. Conversational but tight.

## weather
Lead with the headline (sunny/rain/cold) for Mechelen, then high/low and rain
chance if non-trivial. **From April through September only**, add a pollen line
(name each type and level — alder, birch, grass, mugwort, ragweed — flag anything
moderate+ since I'm allergic) and the UV index. Outside those months, just the
forecast. Note persistence vs the last edition ("grass pollen high — 3rd day").

**Multi-model consensus.** The weather source returns several models, so fields are
suffixed per model (e.g. `wind_gusts_10m_dwd_icon_d2`, `temperature_2m_max_ecmwf_ifs025`).
For every headline number — and **especially wind gusts** — take the **median across
models per hour**, never a single model. Report the peak gust as a consensus value
*with its hour*, and when models disagree widely (range > ~25 km/h) give the spread,
e.g. "peak gusts ~58 km/h around 21:00 (models split 18–106)". Never headline a lone
outlier (AROME-HD in particular often runs the gustiest). Pin a gust/weather warning
to the **event's actual hour**, not the day's peak — the 16:00–18:00 window can be
calm while a 21:00 storm front spikes.

## events
The day's events as a tight list — time, title, who, where; one line each. Lead
with time-critical or newly added (kids' school/activities, my office days,
practices). Skip all-day noise.

## inbox
Two buckets.

**Main brief** (from inbox_new): up to 5 that matter — real people, deadlines,
money. Includes unread plus anything important/starred since the last edition.
Skip newsletters/bulk. Note how many others are tucked away.

**Still-open rail** (from inbox_open + inbox_sent): read each thread *in full —
including my own sent replies* — and judge the whole exchange, not just who spoke
last. Three outcomes:
- **Ball in my court** (mostly inbox_open) — their latest message asks/expects
  something I haven't answered → surface it as mine to handle.
- **Waiting on them** (mostly inbox_sent) — my message is the *latest* in the
  thread and they haven't replied → surface as *"No response yet from <sender>"*
  with how long ("3rd day"). Limit these to my **must-watch senders** (from the
  profile) or where a reply is clearly expected (a question I asked, a quote I
  requested, a follow-up I chased) — don't nag about every sent mail.
- **Resolved** — the last message just acknowledges or closes the loop ("perfect",
  "received", "thanks, all set"), even when it's from them, or they've confirmed
  something I already sent → drop it; never flag a done thread.
Cap at ~5 total. Use memory to escalate by shown_count and frame recurrences
("second reminder", "follow-up on last week's thread"); drop once resolved. If a
snippet doesn't make the state clear, read the thread before deciding.

## sport
Two things. (1) IPL T20 — latest results/standings, **only while the IPL season is
running**; once it's over, drop IPL entirely. (2) Football, hockey, and cricket
matches happening near Mechelen this week — fixtures, who's playing, when. Carry
storylines across days ("after yesterday's win, …").

## news
Top 3 from vrt.be today, plus anything specifically about Mechelen. One line each,
neutral. Skip if there's nothing of substance.

## tech
Databricks announcements and notable new releases. One short card — what shipped,
why it matters. Only if there's something real and recent.

## startup
New VC funding rounds for EU AI companies this week — company, amount, investor.
Up to 3 lines. Skip a quiet week.

## watches
My watched events (plannen) — surface any changes or news since the last edition:
new dates, registration opening/closing, anything moved. Quiet if nothing changed.

## outro
A short sign-off, 2-3 lines, as a sticky note. Forward-look first (tomorrow's
weather, what's coming up — an office day, a kid activity), then a nudge on open
loops (unanswered must-watch mail, anything pending). Warm, brief.
