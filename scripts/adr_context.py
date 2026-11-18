#!/usr/bin/env python3
"""PreToolUse hook (Edit|Write|MultiEdit): before the first edit to a file in a
session, show the ADRs and glossary terms that match the file's name.
Never blocks, never fails the tool call."""
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile

BRAIN = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    d = json.load(sys.stdin)
    path = str((d.get("tool_input") or {}).get("file_path") or "")
    if not path or os.path.abspath(path).startswith(BRAIN + os.sep):
        return
    stem = os.path.splitext(os.path.basename(path))[0]
    if len(stem) < 3:
        return
    session = re.sub(r"[^\w-]", "_", str(d.get("session_id") or "none"))
    key = hashlib.sha1(os.path.abspath(path).encode()).hexdigest()[:16]
    marker = os.path.join(tempfile.gettempdir(), "brain-adr-context-%s-%s" % (session, key))
    if os.path.exists(marker):
        return
    open(marker, "w").close()
    out = subprocess.run([os.path.join(BRAIN, "scripts", "brain"), "lookup", stem],
                         capture_output=True, text=True, timeout=10).stdout
    if not any(l.strip() and not l.startswith("## ") for l in out.splitlines()):
        return
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "additionalContext": "Brain entries matching '%s':\n%s\nRead the ADRs that apply "
                             "before editing. If the change contradicts one, tell the user which."
                             % (stem, out.strip()),
    }}))


try:
    main()
except Exception:
    pass
sys.exit(0)
