#!/usr/bin/env bash
# Lint a plannen-post config.md: frontmatter structure + the portability rule
# (no secrets/identifiers/paths in the shareable config). Best-effort; exits
# non-zero on errors (warnings don't fail).
#
# Usage: scripts/validate-config.sh [path/to/config.md]   (default: ~/.post/config.md)

CONFIG="${1:-$HOME/.post/config.md}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$CONFIG" ]]; then
  echo "✘ not found: $CONFIG" >&2; exit 2
fi

python3 - "$CONFIG" "$REPO_ROOT" <<'PY'
import sys, re, os
path, repo = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()

m = re.search(r'(?ms)^---\s*\n(.*?)\n---\s*\n', text)
if not m:
    print("✘ no YAML frontmatter (--- … ---) found"); sys.exit(2)
fm = m.group(1)

errors, warns = [], []

# Required top-level keys.
for key in ("sources:", "sections:", "deliver:"):
    if not re.search(r'(?m)^%s' % re.escape(key), fm):
        errors.append(f"missing top-level `{key}`")

# Collect declared source names and section source refs.
src_names = set(re.findall(r'(?m)^\s*-\s*name:\s*([A-Za-z0-9_\-]+)', fm))
sec_sources = re.findall(r'(?m)^\s*source:\s*(.+)$', fm)
refs = set()
for s in sec_sources:
    s = s.strip()
    if s.startswith('['):
        refs |= {x.strip() for x in s.strip('[]').split(',') if x.strip()}
    else:
        refs.add(s)
for r in sorted(refs):
    if r and r not in src_names:
        errors.append(f"section source `{r}` is not declared under sources:")

# Theme file exists (if named).
tm = re.search(r'(?m)^\s*theme:\s*([A-Za-z0-9_\-]+)', fm)
theme = tm.group(1) if tm else "newspaper"
if not os.path.isfile(os.path.join(repo, "templates", theme + ".html")):
    warns.append(f"theme `{theme}` has no templates/{theme}.html (will fall back to newspaper.html)")

# Portability: the shared config must carry no secrets/identifiers/paths/shell.
leak_patterns = [
    (r'(?i)\b(api[_-]?key|secret|token|password|bearer)\b\s*[:=]', "looks like an inline secret"),
    (r'\bchat_id\b\s*[:=]', "chat_id belongs in profile.yaml, not config.md"),
    (r'/Users/|/home/', "absolute machine path — bindings belong in profile.yaml"),
    (r'(?m)^\s*command:\s*', "shell `command:` — only the profile may define shell"),
    (r'sk-[A-Za-z0-9]{8,}', "looks like an API key literal"),
]
for pat, why in leak_patterns:
    if re.search(pat, fm):
        errors.append(f"portability: {why}")

# A `secret:` field naming a key is fine (resolved in profile) — don't flag it.

print(f"config: {path}")
print(f"sources: {len(src_names)}  section-source-refs: {len(refs)}  theme: {theme}")
for w in warns: print(f"  ⚠ {w}")
for e in errors: print(f"  ✘ {e}")
if errors:
    print("✘ validation failed"); sys.exit(1)
print("✔ validation passed")
PY
