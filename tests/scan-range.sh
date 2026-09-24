#!/usr/bin/env bash
# Prints the gitleaks --log-opts value for a push range. Same logic as the
# "Scan the PR diff" step in .github/workflows/pr-gate.yml, deliberately
# duplicated there for the same reason gate.sh is duplicated into the `gate`
# job's run: block — CI cannot source a file from the repo it is gating.
#
# Usage: scan-range.sh BEFORE SHA
#
# Falls back to a single-commit scan (`-1 SHA`) when BEFORE cannot anchor a
# real range: empty (no push event / first push), all-zeros (new branch, per
# GitHub's push-event convention), or a sha this checkout has never seen
# (force-push rewriting history, or a shallow checkout).
set -uo pipefail

before="${1:-}"
sha="${2:?scan-range.sh: SHA is required}"
zero="0000000000000000000000000000000000000000"

if [ -n "$before" ] && [ "$before" != "$zero" ] && git cat-file -e "${before}^{commit}" 2>/dev/null; then
  echo "${before}..${sha}"
else
  echo "-1 $sha"
fi
