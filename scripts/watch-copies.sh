#!/usr/bin/env bash
# Background watcher — polls every $INTERVAL seconds using check-copies.sh.
# Pure shell: burns ZERO model tokens while waiting. As soon as at least one copy is
# ready, it prints the issue numbers and exits 0 — which re-invokes Claude to correct.
#
# Env: INTERVAL (seconds, default 300), LOG (heartbeat file), REPO, OWNER.
HERE="$(cd "$(dirname "$0")" && pwd)"
INTERVAL="${INTERVAL:-300}"
LOG="${LOG:-/tmp/devoirs-watch.log}"

echo "[$(date '+%F %T')] watcher armé (intervalle ${INTERVAL}s, repo ${REPO:-xag/devoirs-vacances-2026})" >>"$LOG" 2>/dev/null
while true; do
  pending="$(bash "$HERE/check-copies.sh")"
  if [ -n "$pending" ]; then
    echo "[$(date '+%F %T')] COPIES A CORRIGER: $(echo "$pending" | tr '\n' ' ')" >>"$LOG" 2>/dev/null
    echo "$pending"
    exit 0
  fi
  echo "[$(date '+%F %T')] rien a corriger" >>"$LOG" 2>/dev/null
  sleep "$INTERVAL"
done
