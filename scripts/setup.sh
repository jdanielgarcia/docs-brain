#!/usr/bin/env bash
# One-time setup per machine per project. Safe to re-run.
# Non-interactive when BRAIN_HANDLE and BRAIN_INITIALS are set.
# BRAIN_SKIP_GRAPHIFY=1 skips installing graphify.
set -euo pipefail

BRAIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PROJECT="$(dirname "$BRAIN")"
say() { printf 'brain: %s\n' "$*"; }
die() { say "$*" >&2; exit 1; }

# 1. Location
[ "$(basename "$BRAIN")" = .brain ] || die "clone the brain into <project>/.brain, not $BRAIN"
top=$(git -C "$PROJECT" rev-parse --show-toplevel 2>/dev/null || true)
[ -n "$top" ] && [ "$(cd "$top" && pwd -P)" = "$PROJECT" ] || die "$PROJECT is not a git checkout"
cd "$PROJECT"

# 2. Hide the brain from the project's git
EXCLUDE=$(git rev-parse --git-path info/exclude)
mkdir -p "$(dirname "$EXCLUDE")"
exclude() { grep -qxF "$1" "$EXCLUDE" 2>/dev/null || echo "$1" >> "$EXCLUDE"; }
exclude .brain/
exclude .claude/settings.local.json
exclude /graphify-out

# 3. graphify-out lives in the brain
if [ -L graphify-out ]; then
  ln -sfn .brain/graphify-out graphify-out
else
  if [ -e graphify-out ]; then
    old="graphify-out.local-$(date +%Y-%m-%d)"
    [ -e "$old" ] && old="$old-$(date +%H%M%S)"
    mv graphify-out "$old"
    say "moved the existing graphify-out/ to $old"
  fi
  ln -s .brain/graphify-out graphify-out
fi

# 4. graphify CLI
if [ "${BRAIN_SKIP_GRAPHIFY:-}" != 1 ] && ! command -v graphify >/dev/null 2>&1; then
  say "installing graphify"
  { command -v uv >/dev/null 2>&1 && uv tool install graphifyy; } \
    || { command -v pipx >/dev/null 2>&1 && pipx install graphifyy; } \
    || python3 -m pip install --user graphifyy \
    || say "warning: couldn't install graphify; install the graphifyy package yourself"
  command -v graphify >/dev/null 2>&1 || say "warning: graphify isn't on PATH yet (try ~/.local/bin)"
fi

# 5. Claude Code hooks in .claude/settings.local.json
mkdir -p .claude
python3 - .claude/settings.local.json <<'PY'
import json, os, sys
path = sys.argv[1]
s = {}
if os.path.exists(path):
    with open(path) as f:
        s = json.load(f)  # invalid JSON: fail loudly rather than clobber it
ours = {"Bash|Grep|Glob": "graph_gate.py", "Edit|Write|MultiEdit": "adr_context.py"}
pre = s.setdefault("hooks", {}).setdefault("PreToolUse", [])
kept = []
for entry in pre:
    hooks = [h for h in entry.get("hooks", [])
             if not any(".brain/scripts/" + n in h.get("command", "") for n in ours.values())]
    if hooks:
        kept.append(dict(entry, hooks=hooks))
for matcher, script in ours.items():
    kept.append({"matcher": matcher, "hooks": [{"type": "command",
        "command": 'python3 "$CLAUDE_PROJECT_DIR/.brain/scripts/%s"' % script}]})
s["hooks"]["PreToolUse"] = kept
with open(path, "w") as f:
    json.dump(s, f, indent=2)
    f.write("\n")
PY

# 6. Git hooks
chmod +x "$BRAIN"/scripts/brain "$BRAIN"/scripts/*.sh "$BRAIN"/scripts/*.py \
  "$BRAIN"/scripts/project-* "$BRAIN"/scripts/hooks/*
git -C "$BRAIN" config core.hooksPath scripts/hooks
common=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
install_hook() {
  local name=$1 target=$2 f dir
  local line=".brain/scripts/$target \"\$@\" </dev/null || true"
  f=$(git rev-parse --git-path "hooks/$name")
  mkdir -p "$(dirname "$f")" 2>/dev/null || true
  dir=$(cd "$(dirname "$f")" && pwd -P)
  case "$dir/" in
    "$common"/*) ;;
    *) say "warning: hooks live in $dir (core.hooksPath); add this line to its $name hook yourself: $line"; return ;;
  esac
  if [ -f "$f" ]; then
    grep -q '\.brain/' "$f" && return
    printf '\n%s\n' "$line" >> "$f"
    say "appended the brain to your existing $name hook"
  else
    printf '#!/bin/sh\n%s\n' "$line" > "$f"
  fi
  chmod +x "$f"
}
install_hook pre-push project-pre-push
install_hook post-merge project-post-pull
install_hook post-rewrite project-post-pull

# 7. Identity
if [ -z "$(git -C "$BRAIN" config brain.handle || true)" ] || [ -z "$(git -C "$BRAIN" config brain.initials || true)" ]; then
  handle=${BRAIN_HANDLE:-}
  if [ -z "$handle" ] && command -v gh >/dev/null 2>&1; then handle=$(gh api user -q .login 2>/dev/null || true); fi
  [ -n "$handle" ] || read -rp "Your GitHub handle: " handle
  handle=${handle#@}
  [[ $handle =~ ^[A-Za-z0-9_-]+$ ]] || die "invalid handle '$handle'"
  "$BRAIN/scripts/brain" pull  # see everyone's initials before picking
  AUTHORS="$BRAIN/state/authors.json"
  known=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], ""))' "$AUTHORS" "$handle")
  initials=${BRAIN_INITIALS:-$known}
  if [ -z "$initials" ]; then
    guess=$(git config user.name 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) printf "%s", tolower(substr($i, 1, 1)) }')
    read -rp "Your initials [$guess]: " initials
    initials=${initials:-$guess}
  fi
  [[ $initials =~ ^[a-z]{1,4}$ ]] || die "initials must be 1-4 lowercase letters, got '$initials'"
  owner=$(python3 -c '
import json, sys
a = json.load(open(sys.argv[1]))
print(next((h for h, i in a.items() if i == sys.argv[3] and h != sys.argv[2]), ""))' "$AUTHORS" "$handle" "$initials")
  [ -z "$owner" ] || die "initials '$initials' already belong to @$owner; pick others with BRAIN_INITIALS=..."
  git -C "$BRAIN" config brain.handle "$handle"
  git -C "$BRAIN" config brain.initials "$initials"
  if [ "$known" != "$initials" ]; then
    python3 - "$AUTHORS" "$handle" "$initials" <<'PY'
import json, sys
p, h, i = sys.argv[1:]
a = json.load(open(p)); a[h] = i
with open(p, "w") as f:
    json.dump(a, f, indent=2, sort_keys=True); f.write("\n")
PY
    git -C "$BRAIN" add state/authors.json
    git -C "$BRAIN" commit -q -m "brain: add @$handle ($initials)" -- state/authors.json
    GIT_TERMINAL_PROMPT=0 git -C "$BRAIN" push -q origin HEAD 2>/dev/null \
      || say "couldn't push authors.json; it ships with the next sync"
  fi
  say "you are @$handle ($initials)"
fi

# 8. Skills, linked per project so several brains don't fight over global names
mkdir -p .claude/skills
for d in "$BRAIN"/skills/*/; do
  n=$(basename "$d"); dst=".claude/skills/$n"
  if [ -L "$dst" ]; then
    ln -sfn "../../.brain/skills/$n" "$dst"
  elif [ -e "$dst" ]; then
    say "skipping /$n: .claude/skills/$n already exists and isn't ours"; continue
  else
    ln -s "../../.brain/skills/$n" "$dst"
  fi
  exclude ".claude/skills/$n"
done

# 9. Empty brain?
compgen -G "$BRAIN/adr/*.md" >/dev/null \
  || say "Empty brain. In Claude Code, run /bootstrap to seed the glossary and first ADRs."

# 10. CLAUDE.md snippet
echo
say "paste this into $PROJECT/CLAUDE.md (once):"
echo "----------------------------------------------------------------"
cat "$BRAIN/CLAUDE.snippet.md"
echo "----------------------------------------------------------------"
