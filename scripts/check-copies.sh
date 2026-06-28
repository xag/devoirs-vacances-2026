#!/usr/bin/env bash
# Programmatic check — NO model tokens involved.
# Prints, one per line, the numbers of open issues whose copy is ready to correct.
#
# A copy is "ready" when it has been handed in AND we haven't answered that hand-in yet.
#
# Each hand-in is a ticked "rendre la copie" checkbox ("- [x] ... rend ... copie"), which
# can live in the issue body (first hand-in) OR inside one of my hint/correction comments
# (re-hand-in after a two-pass hint: I end a hint with a fresh checkbox, the girls tick it).
# Ticking a checkbox inside my comment doesn't change the comment author, so we can't rely
# on "who spoke last" alone — we COUNT instead:
#
#   ticks = ticked "rendre la copie" boxes across body + all comments
#   mine  = comments authored by the owner (xag) — one per hint/correction I post
#   ready = handed-in AND ( ticks > mine  OR  the last comment is from a girl )
#
# ticks > mine  -> a hand-in checkbox is ticked that I haven't matched with a reply yet
#                  (catches a re-hand-in done by ticking the box inside my hint comment).
# last comment from a girl -> they re-asked by comment without ticking (belt and braces).
# No state file: the GitHub thread itself is the state.
#
# Env: REPO (default xag/devoirs-vacances-2026), OWNER (default xag).
REPO="${REPO:-xag/devoirs-vacances-2026}"
export OWNER="${OWNER:-xag}"

read -r -d '' JQ <<'EOF'
.[]
| ( [ (.body // ""), (.comments[].body // "") ]
    | map( [ scan("(?im)^- \\[x\\] .*copie") ] | length ) | add ) as $ticks
| ( [ .comments[] | select(.author.login == $ENV.OWNER) ] | length ) as $mine
| ( (.comments | length) == 0 or (.comments[-1].author.login != $ENV.OWNER) ) as $lastFromGirl
| ( $ticks >= 1 or any(.comments[].body; test("(?i)rend.*copie")) ) as $handedIn
| select( $handedIn and ( $ticks > $mine or $lastFromGirl ) )
| .number
EOF

gh issue list --repo "$REPO" --state open --limit 100 \
  --json number,body,comments --jq "$JQ" 2>/dev/null
