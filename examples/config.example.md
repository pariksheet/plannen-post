<!--
  config.example.md — a GENERIC starter. No plannen, no exotic MCPs.

  It uses only widely-available sources, so it works for most people:
    • weather  → open-meteo over HTTP (keyless — just change the lat/long)
    • events   → Google Calendar MCP   (optional; skipped if not connected)
    • inbox    → Gmail MCP             (optional; skipped if not connected)
    • news     → web search            (built-in)
    • intro/outro → the model, from everything gathered

  Graceful degradation: a section whose source isn't connected is simply skipped
  with a warning — the rest of the paper still composes. So you can run this with
  *nothing but* the weather source and still get a paper, then light up more
  sections as you connect MCPs.

  Easiest way to build YOUR version: run `/plannen-post:setup` — it detects your
  connected MCPs and scaffolds a config tailored to what you actually have.

  This file is the PORTABLE content brief: logical names only, NO secrets, NO
  personal identifiers, NO shell. Machine bindings live in profile.yaml.
  For a rich real-world config, see config.pari.example.md.
-->
---
masthead:
  title: "THE PLANNEN POST"
  # family: "the Smith family"     # optional — appears in the dateline
  theme: classic

# ── sources (data in) ─────────────────────────────────────────────────────────
# type: mcp | http | web-search | cli | file. Logical `name` is referenced below.
sources:
  - name: weather                  # open-meteo forecast — KEYLESS. Change lat/long.
    type: http
    url: "https://api.open-meteo.com/v1/forecast?latitude=51.51&longitude=-0.13&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code,uv_index_max&timezone=auto&forecast_days=1"
    as: json

  - name: calendar                 # today's events via the Google Calendar MCP
    type: mcp
    tool: google-calendar.list_events
    args: { maxResults: 10 }       # tune to your calendar MCP's parameters

  - name: inbox_new                # main inbox brief
    type: mcp
    tool: gmail.search_threads
    # {{since_last_edition}} expands at runtime to after:YYYY/MM/DD from memory
    # (so Monday reaches back to Friday); falls back to newer_than:1d if no memory.
    args: { query: "(is:unread OR is:starred) {{since_last_edition}} -category:promotions -category:social", max_results: 25 }

  - name: inbox_open               # "still open" rail — read but awaiting your reply
    type: mcp
    tool: gmail.search_threads
    args: { query: "in:inbox -in:sent newer_than:7d -category:promotions -category:social -from:notifications@github.com -from:no-reply -from:noreply", max_results: 30 }

  - name: news                     # headlines via web search — tailor the query
    type: web-search
    query: "top world news headlines today"

# ── sections ──────────────────────────────────────────────────────────────────
# slot: spine = always present; dynamic = appears only when its source has data.
# component: card | list | stat | quote | two-col | photo
sections:
  - id: intro    
    slot: spine    
    kind: ai-intro
  - id: weather  
    slot: spine    
    source: weather                
    component: card
  - id: events   
    slot: spine    
    source: calendar               
    component: list
  - id: inbox    
    slot: spine    
    source: [inbox_new, inbox_open]  
    component: list
  - id: news     
    slot: dynamic  
    source: news                   
    component: list  
    when: present
  - id: outro    
    slot: spine    
    kind: ai-outro

# ── delivery ──────────────────────────────────────────────────────────────────
# Universal default: a Gmail draft you review and send. `format: html`.
# To send the rendered newspaper as a PNG image to WhatsApp/Telegram instead,
# add a render capability in profile.yaml and use `format: png` (see below).
deliver:
  - to: gmail
    format: html
  # - to: whatsapp
  #   format: png
  #   else: text          # falls back to text if no render capability is present
---

## intro
2-3 lines, front-page lead. Open with whatever is most notable across everything
gathered — a big event, a weather warning, an important email. Conversational but tight.

## weather
One sentence. Lead with the headline (sunny / rain / cold), then high/low, then
chance of rain only if it's non-trivial. Mention the UV index if it's high.

## events
The day's events as a tight list — time, title, where; one short line each. Lead
with anything time-critical. Skip all-day noise.

## inbox
Two buckets.

**Main brief** (from inbox_new): the 3-5 threads worth knowing — real people,
deadlines, money. Sender, one-line summary, why it matters. Skip newsletters/bulk.
Note how many others are tucked away.

**Still-open rail** (from inbox_open): read-but-unanswered threads where the ball
is in your court — keep only those whose *latest message isn't from you* AND that
are from your must-watch senders (resolved from the local profile) or clearly
await a reply. Cap at ~3. Memory escalates by shown_count and drops once replied.

## news
Up to 3 headlines worth knowing, one line each, neutral. Skip a quiet day.

## outro
A short sign-off, 2-3 lines, as a sticky note. A forward look (tomorrow's weather,
what's coming up) and/or a gentle nudge on anything pending. Warm, brief.
