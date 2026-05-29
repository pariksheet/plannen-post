---
name: post-setup
description: Interactive first-time setup — detect your connected MCPs, build your config conversationally, preview, configure delivery, and optionally schedule.
argument-hint: ""
---

Run the interactive plannen-post setup.

Do not re-implement the flow here — the skill is the source of truth. Locate
`skills/post-setup/SKILL.md` inside this plugin and follow it exactly: detect
connected MCPs, learn about the user, walk the sections conversationally, preview
today's edition, configure delivery (bindings into the profile, intent into the
config), and offer to schedule. Write `~/.post/config.md` + `~/.post/profile.yaml`
only after the user signs off on a preview.
