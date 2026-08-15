#!/usr/bin/env bash
# Falsifiability harness for gate.sh. Every case states the expected exit code;
# a case that cannot fail is not a test, so the red cases come first.
GATE="$(cd "$(dirname "$0")" && pwd)/gate.sh"
pass=0; bad=0

t() { # t <want_exit> <name> <NEEDS> <EXPECTED>
  local want="$1" name="$2"
  NEEDS="$3" EXPECTED="$4" bash "$GATE" >/tmp/gate.out 2>&1
  local got=$?
  if [ "$got" = "$want" ]; then
    printf '  PASS  exit=%s  %s\n' "$got" "$name"; pass=$((pass+1))
  else
    printf '  FAIL  exit=%s want=%s  %s\n' "$got" "$want" "$name"
    sed 's/^/          /' /tmp/gate.out; bad=$((bad+1))
  fi
}

D='"detect":{"result":"success"}'

echo "--- cases that MUST be red (exit 1) ---"
t 1 "(c) job removed from needs entirely — the plan's script passed this" \
  "{$D}" '["typecheck"]'
t 1 "expected job skipped" \
  "{$D,\"typecheck\":{\"result\":\"skipped\"}}" '["typecheck"]'
t 1 "expected job failed" \
  "{$D,\"typecheck\":{\"result\":\"failure\"}}" '["typecheck"]'
t 1 "(d) expected job cancelled by concurrency" \
  "{$D,\"typecheck\":{\"result\":\"cancelled\"}}" '["typecheck"]'
t 1 "empty expectation — vacuous truth floor" \
  "{$D}" '[]'
t 1 "detect itself failed" \
  '{"detect":{"result":"failure"}}' '["lint"]'
t 1 "detect skipped" \
  '{"detect":{"result":"skipped"}}' '["lint"]'
t 1 "unexpected job failed while every expected job passed" \
  "{$D,\"lint\":{\"result\":\"success\"},\"secrets\":{\"result\":\"failure\"}}" '["lint"]'
t 1 "one of three expected jobs absent" \
  "{$D,\"lint\":{\"result\":\"success\"},\"test\":{\"result\":\"success\"}}" '["lint","test","build"]'

echo "--- cases that MUST be green (exit 0) ---"
t 0 "single expected job succeeded" \
  "{$D,\"secrets\":{\"result\":\"success\"}}" '["secrets"]'
t 0 "all four expected jobs succeeded" \
  "{$D,\"lint\":{\"result\":\"success\"},\"test\":{\"result\":\"success\"},\"build\":{\"result\":\"success\"},\"secrets\":{\"result\":\"success\"}}" \
  '["lint","test","build","secrets"]'
t 0 "legitimately skipped job that was NOT expected (Python repo, no node lint)" \
  "{$D,\"lint\":{\"result\":\"skipped\"},\"secrets\":{\"result\":\"success\"}}" '["secrets"]'

echo
echo "passed=$pass failed=$bad"
[ "$bad" -eq 0 ]
