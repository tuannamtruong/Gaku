Summarize what was done in the last coding session between the user and Claude.

## Step 1 — Find the previous session transcript

Derive the Claude project slug from the current working directory and list session files by recency:

```
PROJ=$(pwd | sed 's|/|-|g') && ls -lt ~/.claude/projects/$PROJ/*.jsonl
```

The top entries are the current session. Find the most recent file that belongs to a **previous** session: it will be the first file with a timestamp older than the current session's start time (or noticeably larger, as it's fully written). Take that file path.

## Step 2 — Extract the conversation

Run this on the file path from Step 1 (replace `<FILE>`):

```
python3 << 'EOF'
import json, sys
for line in open("<FILE>"):
    try:
        obj = json.loads(line)
        t = obj.get("type")
        content = obj.get("message", {}).get("content", "")
        if t == "user" and isinstance(content, list):
            for b in content:
                if isinstance(b, dict) and b.get("type") == "text":
                    text = b["text"].strip()
                    if text and not text.startswith("<"):
                        print(f"[USER]: {text[:400]}")
        elif t == "assistant" and isinstance(content, list):
            for b in content:
                if isinstance(b, dict) and b.get("type") == "text":
                    print(f"[CLAUDE]: {b['text'][:400]}")
    except:
        pass
EOF
```

Pipe through `| head -120` to limit output.

## Step 3 — Git context

Run in parallel:

- `git log --oneline -10`
- `git diff HEAD --stat`

## Step 4 — Produce the summary

Using all three sources, write a concise recap with these sections:

**Conversation** — What the user and Claude discussed and decided (from the transcript). Focus on questions asked, problems encountered, and decisions made.

**Changes** — What was built or fixed (from git log), grouped by theme.

**Open** — Any uncommitted changes still in the working tree and what they represent.
