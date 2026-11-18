#!/usr/bin/env python3
"""PreToolUse hook (Bash|Grep|Glob): no code search until the session has asked
the graph once. No graph on disk means no gate. Never fails the tool call on error."""
import json
import os
import re
import sys
import tempfile

PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GRAPH_CMD = re.compile(r"\bgraphify\s+(query|explain|path)\b")
SEARCH_CMD = re.compile(r"(^|[\s|;&(`])(grep|egrep|rg|ag|ack|find|fd)(\s|$)")
REASON = (
    "This project has a code graph. Ask it before searching: run "
    '`graphify query "<your question>"` (or `graphify explain "<concept>"`, '
    '`graphify path "<A>" "<B>"`). Grep, Glob and shell search unlock for the rest '
    "of this session after one graph query."
)


def main():
    if not os.path.isfile(os.path.join(PROJECT, "graphify-out", "graph.json")):
        return
    d = json.load(sys.stdin)
    session = re.sub(r"[^\w-]", "_", str(d.get("session_id") or "none"))
    marker = os.path.join(tempfile.gettempdir(), "brain-graph-gate-" + session)
    cmd = str((d.get("tool_input") or {}).get("command") or "")
    if GRAPH_CMD.search(cmd):
        open(marker, "w").close()
        return
    if os.path.exists(marker):
        return
    if d.get("tool_name") in ("Grep", "Glob") or SEARCH_CMD.search(cmd):
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": REASON,
        }}))


try:
    main()
except Exception:
    pass
sys.exit(0)
