#!/usr/bin/env bash
# Verify the planted risk-judge patches (evals/risk-judge/README.md § Protocol).
#
# Usage: bash evals/risk-judge/planted/check.sh [--apply-only]
#
# Fetches BASE when it is absent, applies every P*.patch to BASE in a scratch
# index (the working tree and the real index are never touched), and writes
# facts.csv (pr,mechanical_hit) from BASE's own risk-facts.sh, with the same
# hit rule as scripts/ci/risk-verdict.sh. Without --apply-only it also checks
# that labels.csv holds exactly one low|needs-review row per patch and, once
# intent.csv is committed, that its sha256 matches intent.sha256.
#
# Exit codes: 0 every check passed; 1 a check failed; 2 usage or setup error.
set -euo pipefail

mode=full
case ${1:-} in
  --apply-only) mode=apply ;;
  "") ;;
  *) echo "usage: check.sh [--apply-only]" >&2; exit 2 ;;
esac

here=$(cd "$(dirname "$0")" && pwd)
cd "$(git -C "$here" rev-parse --show-toplevel)"
command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }
base=$(tr -d '[:space:]' <"$here/BASE")
if ! git cat-file -e "$base^{commit}" 2>/dev/null; then
  git fetch -q origin "$base" || { echo "cannot fetch base $base" >&2; exit 2; }
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git show "$base:skills/stages/check/scripts/risk-facts.sh" >"$tmp/risk-facts.sh"
export GIT_AUTHOR_NAME=planted GIT_AUTHOR_EMAIL=planted@invalid GIT_COMMITTER_NAME=planted \
  GIT_COMMITTER_EMAIL=planted@invalid GIT_AUTHOR_DATE=2000-01-01T00:00:00Z GIT_COMMITTER_DATE=2000-01-01T00:00:00Z

failed=0
ids=()
printf 'pr,mechanical_hit\n' >"$tmp/facts.csv"
for patch in "$here"/P*.patch; do
  [ -f "$patch" ] || { echo "no P*.patch in $here" >&2; exit 2; }
  id=$(basename "$patch" .patch)
  ids+=("$id")
  idx="$tmp/index.$id"
  GIT_INDEX_FILE=$idx git read-tree "$base"
  if ! GIT_INDEX_FILE=$idx git apply --cached --check "$patch" 2>"$tmp/err"; then
    echo "❌ $id does not apply to $base: $(head -1 "$tmp/err")" >&2
    failed=1
    continue
  fi
  GIT_INDEX_FILE=$idx git apply --cached "$patch"
  commit=$(git commit-tree "$(GIT_INDEX_FILE=$idx git write-tree)" -p "$base" -m "$id")
  facts=$(bash "$tmp/risk-facts.sh" "$base" "$commit")
  hits=$(jq -r '
    (if .counted_lines > 400 then ["size"] else [] end) + .always_review_hits +
    (if .ci_config_touched then ["ci"] else [] end) +
    (if .manifest_or_lockfile_touched then ["manifest"] else [] end) +
    (.test_changes.removed_files // []) + (.test_changes.skip_markers_added // []) +
    (.test_changes.assertions_removed // []) + (.test_changes.assertions_changed // [])
    | length' <<<"$facts")
  if [ "$hits" -gt 0 ]; then echo "$id,true"; else echo "$id,false"; fi >>"$tmp/facts.csv"
done
[ "$failed" -eq 0 ] || exit 1
mv "$tmp/facts.csv" "$here/facts.csv"
echo "✅ ${#ids[@]} patch(es) apply to ${base:0:7}; facts.csv written"
[ "$mode" = apply ] && exit 0

labels="$here/labels.csv"
if [ ! -f "$labels" ]; then
  echo "❌ $labels is missing: the owner labels every patch" >&2
  exit 1
fi
for id in "${ids[@]}"; do
  n=$(awk -F, -v id="$id" 'NR > 1 && $1 == id && ($2 == "low" || $2 == "needs-review")' "$labels" | wc -l | tr -d ' ')
  [ "$n" -eq 1 ] || { echo "❌ $id has $n valid label row(s) in labels.csv, expected 1" >&2; failed=1; }
done
rows=$(awk 'NR > 1 && NF' "$labels" | wc -l | tr -d ' ')
[ "$rows" -eq "${#ids[@]}" ] || { echo "❌ labels.csv has $rows row(s) for ${#ids[@]} patch(es)" >&2; failed=1; }

if [ -f "$here/intent.csv" ]; then
  want=$(awk '{print $1}' "$here/intent.sha256")
  got=$(python3 -I -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$here/intent.csv")
  [ "$got" = "$want" ] || { echo "❌ intent.csv sha256 $got does not match intent.sha256 $want" >&2; failed=1; }
fi
[ "$failed" -eq 0 ] || exit 1
echo "✅ every patch has one owner label${want:+; intent.csv matches its committed hash}"
