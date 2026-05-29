# Contributing to plannen-post

plannen-post is a single-purpose Claude Code plugin: compose a personalised
newspaper and deliver it. Keep changes aligned with the design in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). The two load-bearing rules:

> **Intent is portable; bindings are local.** Anything in `config.md` must be safe
> to share — no secrets, identifiers, paths, or shell. Those live in `profile.yaml`.
>
> **Fill slots, don't invent layout.** The model plans; assembly fills a theme's
> component kit. No CSS is authored at runtime.

## Repo layout

```
.claude-plugin/         plugin.json + marketplace.json (install metadata)
commands/               thin slash-command entry points → delegate to skills
skills/<name>/SKILL.md  the actual behaviour; lean core + reference/ detail
skills/post-compose/reference/   on-demand detail (sources, components, delivery, failure-modes)
templates/<theme>.html  presentation; named by masthead.theme, newspaper.html is the fallback
examples/               config.example.md (generic) + config.pari.example.md (rich) + profile.example.yaml
scripts/                wrappers + the local PNG renderer + validate-config.sh
docs/ARCHITECTURE.md    the design of record
```

## How to add…

**A theme** → drop `templates/<name>.html` (copy `newspaper.html`), keep the spine
slots (`{{intro}}`/`{{weather}}`/`{{events}}`/`{{inbox}}`/`{{outro}}`) and the
`{{dynamic.left|center|right}}` markers and the masthead markers. Set
`masthead.theme: <name>` in a config. Don't remove component-kit CSS classes.

**A source type** → it must fit "anything that returns data". Add it to
`skills/post-compose/reference/sources.md` (how to fulfil + failure handling) and,
if it can run commands (`cli`-like), make it **profile-only** per the security rule.

**A section** → it's config, not code: add a `sources` entry, a `sections` entry
(spine or dynamic + a kit `component`), and a `## <id>` prose hint. No plugin change
needed. New visual treatments must reuse existing components — extend the theme CSS,
never author CSS at runtime.

**A sink / delivery format** → extend `reference/delivery.md`. Prefer MCP sinks
(they carry their own auth). Image/PDF formats require a render capability
(`profile.render`); always provide an `else:` fallback.

## Conventions

- **Skill files**: a lean `SKILL.md` (the flow) + `reference/*.md` loaded on demand. Keep the always-loaded surface small.
- **`description:` frontmatter** is the activation trigger — phrase it "Use when …".
- Don't reference a user's personal data in shipped examples; use the generic `config.example.md`.

## Before you push

```bash
scripts/validate-config.sh examples/config.example.md
scripts/validate-config.sh examples/config.pari.example.md
claude plugin validate .          # marketplace + plugin manifests
```
