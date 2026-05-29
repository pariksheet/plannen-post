<!--
  plannen-post config — the PORTABLE content brief.

  This file says WHAT the paper contains and WHERE it goes, by logical name.
  It carries NO secrets, NO personal identifiers, NO machine paths, NO shell
  commands — so you can hand it to someone else and they can run it against
  their own bindings.

  The machine-specific resolution (chat_id, API keys, printer name, which
  render capability) lives in your LOCAL PROFILE, never here. See
  examples/profile.example.yaml.

  Two layers, on purpose:
    • frontmatter (below)  = the deterministic skeleton — sections, sources,
                             slots, delivery. Debuggable: "why did sport
                             vanish?" has an answer.
    • markdown body        = the prose hints — editorial taste, what to
                             emphasise, what to skip. Fuzzy on purpose.
-->
---
# ── masthead ────────────────────────────────────────────────────────────────
masthead:
  title: "THE PLANNEN POST"
  family: "the Cohen family"     # optional; drops from the dateline if absent
  theme: classic                 # a theme we ship; presentation only

# ── sources (data in) ────────────────────────────────────────────────────────
# Each source has a logical `name` other parts of the config refer to.
# `type` is one of: mcp | http | web-search | cli | file.
# Connected MCPs need no secret here — the MCP server owns its auth.
sources:
  - name: weather
    type: http
    url: "https://api.open-meteo.com/v1/forecast?latitude=50.85&longitude=4.35&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code&timezone=Europe%2FBrussels&forecast_days=1"
    as: json

  - name: plannen
    type: mcp
    tool: get_briefing_context          # resolved against the connected plannen MCP

  - name: inbox
    type: mcp
    tool: gmail.search_threads
    args:
      query: "is:unread newer_than:1d -category:promotions -category:social"
      max_results: 15

  - name: markets
    type: http
    url: "https://api.example-finance.com/v1/quote?symbols=^GSPC,^STOXX50E,BTC-EUR"
    as: json
    secret: FINANCE_API_KEY             # NAME of a key resolved in the local profile — not the key itself

  - name: tennis
    type: web-search
    query: "ATP WTA tennis results and news today"

# ── sections ─────────────────────────────────────────────────────────────────
# The SPINE is always present (intro/weather/events/inbox/outro).
# DYNAMIC-zone sections appear only when their source has something worth saying;
# the renderer may also improvise *new* dynamic sections from the component kit.
# `component` must be one the theme provides: card | list | sticky-note | stat
#   | quote | two-col | photo.
sections:
  - id: intro    
    slot: spine        
    kind: ai-intro                       # composed last, from the full gathered set

  - id: weather  
    slot: spine        
    source: weather    
    component: card

  - id: events   
    slot: spine        
    source: plannen    
    component: list

  - id: inbox    
    slot: spine        
    source: inbox      
    component: list

  - id: markets  
    slot: dynamic      
    source: markets    
    component: stat
    when: present                        # render only if the source returned data

  - id: sport    
    slot: dynamic      
    source: tennis     
    component: card
    when: present

  - id: outro    
    slot: spine        
    kind: ai-outro

# ── delivery (sinks) ─────────────────────────────────────────────────────────
# Each entry is (to, format, else?). `to` is a LOGICAL sink name resolved in the
# local profile. `format` is opt-in by capability: html is always available;
# png/pdf need a connected render capability. `else` is the fallback if the
# requested format/sink is unavailable — we attempt, then degrade, then warn.
deliver:
  - to: gmail        
    format: html                         # email renders HTML natively; the default

  - to: telegram     
    format: text                         # plain-text digest

  - to: whatsapp     
    format: png
    else: html-link                      # no render capability? send a link instead

  - to: printer      
    format: pdf
    else: skip                           # no printer / no renderer? just skip it
---

<!--
  ── PROSE HINTS ──────────────────────────────────────────────────────────────
  One `## <section-id>` block per section that wants steering. The text under
  each heading is a free-form prompt telling the renderer how to turn raw source
  data into prose: what to lead with, what to skip, how long, what tone.
  A section with no block here gets a tight default summary.

  Hard limits still apply (set by the skill): ≤ ~120 words/section, factual,
  present tense, no marketing voice, no emoji unless the data carries one.
-->

## intro

Set the tone of the day in 2–3 lines. Lead with whatever is most notable across
everything gathered — a big event, a weather warning, a market move, an email
that needs a reply. Conversational but tight. This is the front-page lead.

## weather

One sentence. Lead with the headline (sunny / rain expected / cold snap), then
high/low, then chance of precipitation only if it's non-trivial. Two sentences max.

## events

The day's events as a tight list — time, title, who, where; one short line each.
Lead with anything time-critical or newly added. Skip all-day noise.

## inbox

Pick the 3–5 threads worth knowing about — real people, replies expected,
deadlines, money. For each: sender, one-line summary, why it matters. Skip
newsletters and bulk mail. If you summarised N of M, note the rest are tucked away.

## markets

One line. The two or three moves that matter, with direction and rough size.
No tickers-as-noise; say it like a human would over coffee.

## sport

Only if there's real tennis news today. One short card: the result or story that
matters, a sentence of why. If nothing notable, omit the section entirely.

## outro

A closing thought in 2–3 short lines. A forward look ("rain tomorrow"), a nudge
("don't forget the dentist at 4"), or a plain sign-off. Renders as a sticky note.
