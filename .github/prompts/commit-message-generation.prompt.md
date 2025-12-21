---
model: GPT-5 mini (copilot)
description: This prompt generates a structured commit message (header + detailed sections) in one pass from pasted edit diffs and history. It strictly reproduces the format, tone, headings, and conventions based on the Style Reference below.
---

# Full Commit Message Generator (ready to run)

This prompt generates a structured commit message (header + detailed sections) in one pass from pasted edit diffs and history. It strictly reproduces the format, tone, headings, and conventions based on the Style Reference below.

## Inputs

- Staged change statistics (`--stat`)

```
{{diff_stat}}
```

- High-level change summary (bulleted; purpose/impact per file)

```
{{change_summary}}
```

- Key diff hunks (excerpts of important additions/deletions/renames)

```
{{diff_hunks}}
```

Helper commands (optional):

```sh
git --no-pager diff --cached --stat
git --no-pager diff --cached --minimal
```

## Goal (instructions to the AI)

1. Infer the house style from the log or the Style Reference below (language, imperative voice, Conventional Commits prefix/scope/capitalization, section layout, emoji usage, reference patterns).
2. Classify the diff into add/change/remove/move and extract feature additions, refactors, config changes, migrations, and test impacts.
3. Detect potential breaking changes; when present, append `!` to the header and describe details under “Breaking Changes”.
4. Output must fully comply with the Style Reference. Keep the header ≤72 chars. Use Markdown sections in this order with headings + bullets: “Motivation”, “Overview”, “Main Changes”, “Breaking Changes”.
5. If inputs are missing, do not guess. Briefly list what’s missing (1–3 lines) and request them.

## Style Reference (reproduce exactly)

```md
feat: summary of diff changes

**Motivation**

why this change is needed.

**Overview**

- key point 1 of the change
- key point 2 of the change

**Main Changes**

- file/path/one.rb (add/change/remove/move): brief explanation of change

**Breaking Changes (Important)**

- description of breaking change 1
- description of breaking change 2
```

## Output Requirements

- One commit message (Markdown) using the same section layout, tone, and conventions as the Style Reference.
- Header uses Conventional Commits prefix and `!` when needed. Examples: `feat!:`, `refactor!:`, `fix!:`. Include a scope only if consistently present in history.
- ≤72 chars and succinct. Emoji only if the history uses them.
- “Main Changes” lists key files and short explanations as bullets, marking add/change/remove/move explicitly.
- “Breaking Changes” specifies config key changes, interface breaks, required migrations, operational requirements (HTTPS), and test impacts.

## Breaking-change detection hints (generalized rules)

- Session foundation switches to Cookie/DB (e.g., `set_*cookie*`, `resume_*session*`, token-based introduction)
- Default key names or config options are added/changed (e.g., `session_key`, `session_expiry`, `keep_legacy_login_session`)
- Migrations adding new tables/columns (e.g., session-related tables in `db/migrate/*`)
- Public API/test expectation changes (Rails `session` → `cookies.signed`)
- Operational requirements inferred from diffs (HTTPS required, per-scope sign-out)

---

After pasting, output immediately. Only request missing inputs when necessary.
