#!/usr/bin/env bash
# Waits for the GitHub Actions run of the pushed HEAD and requires success.
source "$(dirname "$0")/lib.sh"
sha="$(git rev-parse HEAD)"
[ "$sha" = "$(git rev-parse "origin/$POC_BRANCH")" ] || fail "HEAD is not pushed"

run_id=""
for _ in $(seq 1 30); do
  run_id="$(gh run list --branch "$POC_BRANCH" --commit "$sha" --json databaseId -q '.[0].databaseId' 2>/dev/null || true)"
  [ -n "$run_id" ] && break
  sleep 10
done
[ -n "$run_id" ] || fail "no GitHub Actions run found for $sha"

gh run watch "$run_id" --exit-status --interval 15 || { gh run view "$run_id" --log-failed | tail -60; fail "CI failed (run $run_id)"; }
gh run view "$run_id" --json conclusion,url -q '"conclusion=\(.conclusion) \(.url)"'
pass "CI green for $sha"
