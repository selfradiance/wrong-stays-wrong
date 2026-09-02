#!/usr/bin/env bash
# OpenTimestamps proofs start incomplete and can be upgraded once the
# Bitcoin attestation lands (usually within a day). Run occasionally.
# Usage (from the repo root):  ./tools/upgrade-seals.sh
set -euo pipefail
cd "$(dirname "$0")/.."
command -v ots >/dev/null || { echo "ots not installed: brew install opentimestamps-client"; exit 1; }
[ -z "$(git diff --cached --name-only)" ] || {
  echo "refusing to upgrade: Git already has staged changes"
  exit 1
}
changed=0
for o in seals/*.ots; do
  [ -e "$o" ] || continue
  proof_before="$(shasum -a 256 "$o" | awk '{print $1}')"
  if ! ots_output="$(ots upgrade "$o" 2>&1)"; then
    printf '%s\n' "$ots_output" >&2
    exit 1
  fi
  rm -f "$o.bak"
  proof_after="$(shasum -a 256 "$o" | awk '{print $1}')"
  if [ "$proof_before" != "$proof_after" ]; then changed=1; fi
done
if [ "$changed" = 1 ]; then
  git add seals/*.ots
  git commit -m "Upgrade OTS proofs"
  git push
  echo "Upgraded proofs pushed."
else
  echo "Nothing to upgrade yet."
fi
