---
name: last-session
description: >
  Summarizes the previous coding session between the user and Claude. Reads the most recent
  completed JSONL transcript, recent git commits, unpushed commits, and open working-tree
  changes to produce a concise recap of what was discussed, what changed, and what's still
  open. Invoke when the user types /last-session, asks "what did we do last time?",
  "summarize last session", "what happened last session", "catch me up", or any similar
  request to recap a prior conversation or recent work.
---

# last-session

Produce a concise recap of the previous coding session. Three sources: the previous
session transcript, git log, and the current working tree.

## Step 1 — Find the previous session transcript

Derive the Claude project slug from the current working directory:

```bash
PROJ=$(pwd | sed 's|/|-|g') && ls -lt ~/.claude/projects/$PROJ/*.jsonl 2>/dev/null | head -20
```

The topmost file is the **current** session (still being written). The next older file is
the previous session — take that path as `<PREV_FILE>`.

If no previous file exists, skip Steps 2–3 and note "no previous session transcript found."

## Step 2 — Extract conversation highlights

Run this on `<PREV_FILE>`:

```bash
python3 << 'EOF'
import json, sys

FILE = "<PREV_FILE>"  # replace before running
lines_out = []

for line in open(FILE):
    try:
        obj = json.loads(line)
        t = obj.get("type")
        content = obj.get("message", {}).get("content", "")
        if t == "user" and isinstance(content, list):
            for b in content:
                if isinstance(b, dict) and b.get("type") == "text":
                    text = b["text"].strip()
                    # skip injected system context blocks
                    if text and not text.startswith("<") and len(text) > 10:
                        lines_out.append(f"[USER]: {text[:500]}")
        elif t == "assistant" and isinstance(content, list):
            for b in content:
                if isinstance(b, dict) and b.get("type") == "text":
                    text = b["text"].strip()
                    if text:
                        lines_out.append(f"[CLAUDE]: {text[:500]}")
    except Exception:
        pass

# Print first ~100 lines to avoid overwhelming context
for l in lines_out[:100]:
    print(l)
EOF
```

## Step 3 — Git context (run all three in parallel)

```bash
git log --oneline -15
```

```bash
git log --oneline origin/$(git rev-parse --abbrev-ref HEAD)..HEAD 2>/dev/null || echo "(no unpushed commits or no remote)"
```

```bash
git status --short
```

## Step 4 — Write the summary

Using all three sources, produce a summary with exactly these sections:

---

### Last Session Summary

**Conversation** — What the user and Claude discussed, in plain language. Focus on:
goals the user brought in, problems encountered, decisions made, and anything agreed for
next time. 2–4 bullet points.

**Changes** — What was built or fixed, derived from git log and transcript. Group by theme
(e.g. "CI/CD", "Kubernetes", "Architecture"). 2–5 bullet points.

**Unpushed** — Any commits that exist locally but haven't been pushed to the remote yet,
and what they represent. If none, say so.

**Open** — Uncommitted changes still in the working tree (from `git status`) and what they
likely represent. If the tree is clean, say so.

---

Keep each bullet short — one sentence. The goal is a 30-second catch-up, not a full
retelling.
