#!/usr/bin/env bash
# The gate. Reads two env vars, both JSON:
#   NEEDS    — toJSON(needs): {"job":{"result":"success"},...}
#   EXPECTED — JSON array of job ids that were REQUIRED to run, computed by `detect`.
#
# Invariant: a check that did not run must never look like a check that passed.
# Two independent ways that can happen, so two independent loops:
#   1. a job in EXPECTED is absent from NEEDS (removed from `needs:`) or skipped
#   2. a job present in NEEDS failed/cancelled/timed out
# Plus a floor: EXPECTED can never be empty, or an empty set passes vacuously.
set -uo pipefail

fail=0

# --- 0. detect itself must have succeeded, or EXPECTED is not trustworthy ----
detect_result=$(jq -r '.detect.result // "ABSENT"' <<<"$NEEDS")
if [ "$detect_result" != "success" ]; then
  echo "::error::detect = $detect_result — la liste des contrôles attendus n'est pas fiable"
  exit 1
fi

# --- 1. the floor: an empty expectation is never a pass ----------------------
count=$(jq -r 'length' <<<"$EXPECTED")
if [ "$count" -eq 0 ]; then
  echo "::error::aucun contrôle attendu — une porte sans attente est verte par omission"
  exit 1
fi

# --- 2. every expected job must be present AND successful --------------------
while IFS= read -r job; do
  res=$(jq -r --arg j "$job" '.[$j].result // "ABSENT"' <<<"$NEEDS")
  if [ "$res" = "success" ]; then
    printf '  ok       %-12s %s\n' "$job" "$res"
  else
    printf '  MANQUANT %-12s %s\n' "$job" "$res"
    echo "::error::$job était attendu et vaut '$res' (attendu: success)"
    fail=1
  fi
done < <(jq -r '.[]' <<<"$EXPECTED")

# --- 3. nothing present may have failed, even if it was not expected ---------
while IFS= read -r job; do
  res=$(jq -r --arg j "$job" '.[$j].result' <<<"$NEEDS")
  case "$res" in
    success|skipped) ;;
    *) echo "::error::$job = $res"; fail=1 ;;
  esac
done < <(jq -r 'keys[]' <<<"$NEEDS")

exit "$fail"
