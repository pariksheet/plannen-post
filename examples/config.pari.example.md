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
    url: "https://api.open-meteo.com/v1/forecast?latitude=51.03&longitude=4.48&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code,uv_index_max&timezone=Europe%2FBrussels&forecast_days=1"
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
    source: [inbox_new, inbox_open]
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

## events
The day's events as a tight list — time, title, who, where; one line each. Lead
with time-critical or newly added (kids' school/activities, my office days,
practices). Skip all-day noise.

## inbox
Two buckets.

**Main brief** (from inbox_new): the 3-5 that matter — real people, deadlines,
money. Includes unread plus anything important/starred since the last edition.
Skip newsletters/bulk. Note how many others are tucked away.

**Still-open rail** (from inbox_open): read-but-unanswered threads where the ball
is in my court — keep only those whose *latest message is not from me* AND that
are from my **must-watch senders** (resolved from the local profile) or where a
reply is clearly expected. Cap at ~3. Use memory to escalate by shown_count ("3rd day
waiting"), frame recurrences ("second reminder", "follow-up on last week's
thread"), and drop an item once I've replied (latest message becomes mine).

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
