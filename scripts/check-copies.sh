#!/usr/bin/env bash
# Programmatic check — NO model tokens involved.
# Prints, one per line, the numbers of open issues whose copy is ready to correct.
#
# A copy is "ready" when:
#   - the submit box "- [x] ... rend ... copie" is ticked in the body, OR a comment
#     says "je rends ma copie" / "on rend notre copie", AND
#   - the LAST comment is NOT from the owner (xag) — i.e. we haven't handled it yet.
# This last-comment rule naturally re-triggers the two-pass hint flow (girl asks for a
# hint -> we answer -> girl replies again -> ready again) without any state file.
#
# Env: REPO (default xag/devoirs-vacances-2026), OWNER (default xag).
REPO="${REPO:-xag/devoirs-vacances-2026}"
export OWNER="${OWNER:-xag}"

read -r -d '' JQ <<'EOF'
.[]
| select(
    ( (.body | test("(?im)^- \\[x\\] .*copie"))
      or any(.comments[].body; test("(?i)rend.*copie")) )
    and ( (.comments | length) == 0 or (.comments[-1].author.login != $ENV.OWNER) )
  )
| .number
EOF

gh issue list --repo "$REPO" --state open --limit 100 \
  --json number,body,comments --jq "$JQ" 2>/dev/null
