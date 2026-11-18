#!/usr/bin/env bash
# End-to-end test of the brain in a temp dir: bash scripts/test.sh
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(cd "$(mktemp -d)" && pwd -P)"
trap '[ -n "${KEEP:-}" ] || rm -rf "$T"' EXIT; echo "tmp: $T"

# Isolate from the machine's git config and identity.
export GIT_CONFIG_GLOBAL="$T/gitconfig" GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
git config --global init.defaultBranch main
git config --global user.name "Test User"
git config --global user.email test@example.invalid
git config --global advice.detachedHead false
export BRAIN_SKIP_GRAPHIFY=1 TMPDIR="$T/tmp"
mkdir -p "$TMPDIR"

n=0
ok() { n=$((n + 1)); echo "ok $n - $1"; }
fail() { echo "FAIL - $1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; exit 1; }
check() { local d=$1; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else fail "$d"; fi; }
same() { [ "$2" = "$3" ] && ok "$1" || fail "$1" "expected: $3
got:      $2"; }
has() { case $2 in *"$3"*) ok "$1" ;; *) fail "$1" "missing '$3' in:
$2" ;; esac; }
hasnt() { case $2 in *"$3"*) fail "$1" "unexpected '$3' in:
$2" ;; *) ok "$1" ;; esac; }

# Remotes: the brain (from this template's files) and a project.
mkdir -p "$T/seed"
(cd "$SRC" && git ls-files -co --exclude-standard -z | xargs -0 tar cf -) | tar xf - -C "$T/seed"
git -C "$T/seed" init -q && git -C "$T/seed" add -A && git -C "$T/seed" commit -qm "template" --no-verify
git clone -q --bare "$T/seed" "$T/brain.git"
git init -q "$T/pseed" && echo hi > "$T/pseed/README.md"
git -C "$T/pseed" add -A && git -C "$T/pseed" commit -qm init
git clone -q --bare "$T/pseed" "$T/proj.git"

# Two users, each with a project clone and a brain inside it.
user() {
  git clone -q "$T/proj.git" "$T/$1/proj"
  git clone -q "$T/brain.git" "$T/$1/proj/.brain"
}
user alice
user bob
A="$T/alice/proj" B="$T/bob/proj"
ab() { "$A/.brain/scripts/brain" "$@"; }
bb() { "$B/.brain/scripts/brain" "$@"; }

echo "# setup"
mkdir -p "$A/.claude" "$A/.git/hooks"
echo '{"permissions": {"allow": ["Bash(ls)"]}}' > "$A/.claude/settings.local.json"
printf '#!/bin/sh\necho existing-hook\n' > "$A/.git/hooks/post-merge" && chmod +x "$A/.git/hooks/post-merge"
mkdir -p "$A/graphify-out" && touch "$A/graphify-out/old.json"
out=$(BRAIN_HANDLE=alice BRAIN_INITIALS=al bash "$A/.brain/scripts/setup.sh" 2>&1) || fail "setup alice" "$out"
has "setup prints the empty-brain hint" "$out" "Empty brain"
has "setup prints the CLAUDE.md snippet" "$out" "brain lookup"
BRAIN_HANDLE=alice BRAIN_INITIALS=al bash "$A/.brain/scripts/setup.sh" >/dev/null 2>&1 || fail "setup re-run"
ok "setup re-runs cleanly"
for l in .brain/ .claude/settings.local.json .claude/skills/adr .claude/skills/absorb; do
  check "exclude has $l" grep -qxF "$l" "$A/.git/info/exclude"
done
same "exclude lines are not duplicated" "$(grep -cxF .brain/ "$A/.git/info/exclude")" 1
same "graphify-out is a symlink into the brain" "$(readlink "$A/graphify-out")" .brain/graphify-out
check "old graphify-out kept as graphify-out.local-*" test -f "$A"/graphify-out.local-*/old.json
s=$(cat "$A/.claude/settings.local.json")
has "settings keep existing keys" "$s" "Bash(ls)"
has "settings have the graph gate" "$s" '.brain/scripts/graph_gate.py'
has "settings have the ADR context hook" "$s" '.brain/scripts/adr_context.py'
same "hooks not duplicated on re-run" "$(grep -c graph_gate "$A/.claude/settings.local.json")" 1
same "brain hooksPath" "$(git -C "$A/.brain" config core.hooksPath)" scripts/hooks
check "project pre-push calls the brain" grep -q project-pre-push "$A/.git/hooks/pre-push"
check "project post-rewrite calls the brain" grep -q project-post-pull "$A/.git/hooks/post-rewrite"
check "existing post-merge kept" grep -q existing-hook "$A/.git/hooks/post-merge"
same "brain appended to existing post-merge once" "$(grep -c project-post-pull "$A/.git/hooks/post-merge")" 1
check "skill symlink resolves" test -f "$A/.claude/skills/adr/SKILL.md"
check "skill is a symlink" test -L "$A/.claude/skills/grill-with-docs"
same "identity" "$(ab me)" "@alice (al)"
check "authors.json pushed" sh -c "git --git-dir='$T/brain.git' show main:state/authors.json | grep -q '\"alice\": \"al\"'"
same "project git status shows only the moved graphify-out" "$(git -C "$A" status --porcelain)" "?? graphify-out.local-$(date +%Y-%m-%d)/"
if BRAIN_HANDLE=bob BRAIN_INITIALS=al bash "$B/.brain/scripts/setup.sh" >/dev/null 2>&1; then
  fail "setup refuses initials taken by another handle"
fi
ok "setup refuses initials taken by another handle"
BRAIN_HANDLE=bob BRAIN_INITIALS=bo bash "$B/.brain/scripts/setup.sh" >/dev/null 2>&1 || fail "setup bob"
same "bob identity" "$(bb me)" "@bob (bo)"
git -C "$B/.brain" config --unset brain.handle
has "brain without identity says to run setup" "$(bb me 2>&1 || true)" "run .brain/scripts/setup.sh"
git -C "$B/.brain" config brain.handle bob

echo "# numbering, claims, lookup"
same "next on empty brain" "$(ab next)" 0001
check "next-sub needs the parent" sh -c "! '$A/.brain/scripts/brain' next-sub 0001"
out=$(ab claim billing "billing and refunds") || fail "alice claims billing" "$out"
check "claim pushed" git --git-dir="$T/brain.git" cat-file -e main:claims/billing.md
has "lookup shows the live claim" "$(ab lookup billing)" "billing  @alice"
if out=$(bb claim billing "billing too" 2>&1); then fail "bob's claim refused" "$out"; fi
has "refusal names the holder" "$out" "@alice"
ab release billing >/dev/null
check "release removes the claim file" test ! -e "$A/.brain/claims/billing.md"

adr() { # dir file title initiator body-lines...
  local f="$1/.brain/adr/$2" t=$3 who=$4; shift 4
  { echo "# $t"; echo; echo "**Initiated by:** @$who"; printf '%s\n' "$@"; } > "$f"
}
adr "$A" 0001-billing.md "0001 Billing" alice "**Status:** Accepted" "" "Invoices are immutable." "" "## Revisions" \
  "- 0001.1 (2026-11-18, @alice): refunds create credit notes"
adr "$A" 0001.1-al-refunds.md "0001.1 Refunds as credit notes" alice "**Revises:** 0001" "" "## What changed"
printf '\n**Invoice**:\nA bill sent to a customer.\n_Avoid_: bill\n' >> "$A/.brain/CONTEXT.md"
same "next after 0001" "$(ab next)" 0002
same "next-sub after 0001.1" "$(ab next-sub 0001)" 0001.2
l=$(ab lookup invoices)
has "lookup ranks the ADR with title and initiator" "$l" "0001-billing  @alice  0001 Billing"
has "lookup shows glossary terms with line numbers" "$(ab lookup invoice)" ": **Invoice**:"
hasnt "lookup skips released claims" "$(ab lookup billing)" "since"
ab sync feature-x
msg=$(git --git-dir="$T/brain.git" log -1 --format=%s main)
has "sync commit message" "$msg" "docs(adr): "
has "sync commit names the branch and handle" "$msg" "from feature-x by @alice"
check "sync pushed alice's ADR" git --git-dir="$T/brain.git" cat-file -e main:adr/0001-billing.md
check "sync shipped the release" sh -c "! git --git-dir='$T/brain.git' cat-file -e main:claims/billing.md"

echo "# collisions"
adr "$B" 0001-auth.md "0001 Auth" bob "**Status:** Accepted" "" "Sessions live in cookies." "" "## Revisions" \
  "- 0001.1 (2026-11-18, @bob): sessions expire after 30 days"
adr "$B" 0001.1-bo-sessions.md "0001.1 Session expiry" bob "**Revises:** 0001" "" "## What changed"
out=$(bb sync main)
has "sync reports the renumbering" "$out" "renumbered"
check "bob's top-level moved to 0002" test -f "$B/.brain/adr/0002-auth.md"
check "bob's sub-ADR moved to 0002.1" test -f "$B/.brain/adr/0002.1-bo-sessions.md"
check "old names gone" test ! -e "$B/.brain/adr/0001-auth.md" -a ! -e "$B/.brain/adr/0001.1-bo-sessions.md"
same "renumbered H1" "$(head -1 "$B/.brain/adr/0002-auth.md")" "# 0002 Auth"
same "renumbered sub H1" "$(head -1 "$B/.brain/adr/0002.1-bo-sessions.md")" "# 0002.1 Session expiry"
check "sub-ADR revises 0002" grep -qxF "**Revises:** 0002" "$B/.brain/adr/0002.1-bo-sessions.md"
check "parent's Revisions line fixed" grep -qxF -- "- 0002.1 (2026-11-18, @bob): sessions expire after 30 days" "$B/.brain/adr/0002-auth.md"
check "alice's ADRs untouched" grep -qxF -- "- 0001.1 (2026-11-18, @alice): refunds create credit notes" "$B/.brain/adr/0001-billing.md"
check "renumbering pushed" git --git-dir="$T/brain.git" cat-file -e main:adr/0002.1-bo-sessions.md
same "brain clean after sync" "$(git -C "$B/.brain" status --porcelain)" ""

echo "# offline sync"
echo "draft" > "$B/.brain/adr/0003-draft.md"
git -C "$B/.brain" remote set-url origin "$T/nowhere.git"
out=$(bb sync main 2>&1); rc=$?
same "offline sync exits 0" "$rc" 0
has "offline sync says it committed locally" "$out" "committed locally"
git -C "$B/.brain" remote set-url origin "$T/brain.git"
bb sync main >/dev/null
check "next sync pushes it" git --git-dir="$T/brain.git" cat-file -e main:adr/0003-draft.md

echo "# graph files"
mkdir -p "$A/.brain/graphify-out"
echo '{"v": 1}' > "$A/.brain/graphify-out/graph.json"
git -C "$A/.brain" add graphify-out/graph.json
if out=$(git -C "$A/.brain" commit -qm graph 2>&1); then fail "pre-commit refuses graph.json"; fi
has "pre-commit refuses graph.json and shows the undo" "$out" "git restore --staged graphify-out/graph.json"
ABSORB=1 git -C "$A/.brain" commit -qm "graph" || fail "ABSORB=1 commits the graph"
ok "pre-commit allows graph.json with ABSORB=1"
ab sync main >/dev/null
echo "my sketch" > "$A/.brain/graphify-out/auth-flow.md"
ab sync main >/dev/null
check "sync ships hand-written write-ups" git --git-dir="$T/brain.git" cat-file -e main:graphify-out/auth-flow.md
echo '{"v": "bob local build"}' > "$B/.brain/graphify-out/graph.json"
bb sync main >/dev/null
same "sync takes upstream's built graph over a local build" "$(cat "$B/.brain/graphify-out/graph.json")" '{"v": 1}'
echo '{"v": "local"}' > "$A/.brain/graphify-out/graph.json"
echo "x" > "$A/.brain/adr/0004-x.md"
ab sync main >/dev/null
check "sync never stages the built graph" sh -c "git --git-dir='$T/brain.git' show main:graphify-out/graph.json | grep -q '\"v\": 1'"

echo "# project hooks"
adr "$A" 0005-deploy.md "0005 Deploy" alice "**Status:** Proposed"
echo change >> "$A/README.md"
git -C "$A" commit -qam change
git -C "$A" push -q origin HEAD 2>/dev/null || fail "project push"
check "project push shipped the brain" git --git-dir="$T/brain.git" cat-file -e main:adr/0005-deploy.md
out=$(git -C "$B" pull -q 2>&1) || fail "project pull" "$out"
check "project pull fast-forwarded bob's brain" test -f "$B/.brain/adr/0005-deploy.md"

echo "# Claude Code hooks"
gate() { printf '%s' "$1" | CLAUDE_PROJECT_DIR="$A" python3 "$A/.brain/scripts/graph_gate.py"; }
has "gate denies Grep before a graph query" "$(gate '{"session_id":"s1","tool_name":"Grep","tool_input":{}}')" '"deny"'
has "gate denies rg in Bash" "$(gate '{"session_id":"s1","tool_name":"Bash","tool_input":{"command":"cd x && rg foo"}}')" "graphify query"
same "gate allows other Bash" "$(gate '{"session_id":"s1","tool_name":"Bash","tool_input":{"command":"ls -la"}}')" ""
same "gate allows graphify query" "$(gate '{"session_id":"s1","tool_name":"Bash","tool_input":{"command":"graphify query \"x\""}}')" ""
same "gate allows Grep after a graph query" "$(gate '{"session_id":"s1","tool_name":"Grep","tool_input":{}}')" ""
has "gate is per session" "$(gate '{"session_id":"s2","tool_name":"Glob","tool_input":{}}')" '"deny"'
same "gate never fails on bad input" "$(gate 'not json'; echo "rc=$?")" "rc=0"
ctx() { printf '%s' "$1" | python3 "$A/.brain/scripts/adr_context.py"; }
out=$(ctx '{"session_id":"s1","tool_name":"Edit","tool_input":{"file_path":"/src/billing.py"}}')
has "adr_context returns context for a matching file" "$out" "additionalContext"
has "adr_context names the ADR" "$out" "0001-billing"
same "adr_context only fires on the first edit" "$(ctx '{"session_id":"s1","tool_name":"Edit","tool_input":{"file_path":"/src/billing.py"}}')" ""
same "adr_context silent for a non-matching file" "$(ctx '{"session_id":"s1","tool_name":"Write","tool_input":{"file_path":"/src/zebra.py"}}')" ""
same "adr_context never fails on bad input" "$(ctx 'nope'; echo "rc=$?")" "rc=0"

echo "all $n checks passed"
