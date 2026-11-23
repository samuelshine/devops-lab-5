#!/usr/bin/env bash
# Send a request to the Service every 0.2 s for N seconds and log what came back.
# Used during rolling updates to prove there is no downtime.
# Usage: scripts/traffic.sh <seconds> [logfile]
SECS=${1:-60}
LOG=${2:-traffic.log}
URL=${URL:-http://localhost:8085/api/info}
: > "$LOG"
end=$(( $(date +%s) + SECS ))
while [ "$(date +%s)" -lt "$end" ]; do
  body=$(curl -s -m 2 -w ' %{http_code}' "$URL")
  code=${body##* }
  ver=$(echo "$body" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')
  pod=$(echo "$body" | sed -n 's/.*"pod":"\([^"]*\)".*/\1/p')
  echo "$(date +%T) $code ${ver:--} ${pod:--}" >> "$LOG"
  sleep 0.2
done
total=$(wc -l < "$LOG" | tr -d ' ')
fail=$(awk '$2 != 200' "$LOG" | wc -l | tr -d ' ')
echo "requests: $total   failed: $fail"
echo "responses per version:"
awk '$2 == 200 {print "  " $3}' "$LOG" | sort | uniq -c
