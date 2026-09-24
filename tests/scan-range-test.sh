#!/usr/bin/env bash
# Falsifiability harness for scan-range.sh. Every case states the expected
# output; a case that cannot fail is not a test.
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")" && pwd)/scan-range.sh"
pass=0; bad=0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git -C "$tmp" init -q
git -C "$tmp" -c user.email=t@t -c user.name=t commit --allow-empty -q -m one
c1=$(git -C "$tmp" rev-parse HEAD)
git -C "$tmp" -c user.email=t@t -c user.name=t commit --allow-empty -q -m two
c2=$(git -C "$tmp" rev-parse HEAD)
zero="0000000000000000000000000000000000000000"
unknown="deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"

t() { # t <name> <want> <before> <sha>
  local name="$1" want="$2" before="$3" sha="$4"
  local got
  got=$(cd "$tmp" && bash "$SCRIPT" "$before" "$sha")
  if [ "$got" = "$want" ]; then
    printf '  PASS  %-40s -> %s\n' "$name" "$got"; pass=$((pass+1))
  else
    printf '  FAIL  %-40s got=%s want=%s\n' "$name" "$got" "$want"; bad=$((bad+1))
  fi
}

echo "--- must produce a real range ---"
t "normal push, known BEFORE" "$c1..$c2" "$c1" "$c2"

echo "--- must fall back to -1 SHA ---"
t "empty BEFORE (no push event / first push)" "-1 $c2" "" "$c2"
t "all-zeros BEFORE (new branch)" "-1 $c2" "$zero" "$c2"
t "unknown sha BEFORE (force-push / shallow checkout)" "-1 $c2" "$unknown" "$c2"

echo
echo "passed=$pass failed=$bad"
[ "$bad" -eq 0 ]
