#!/usr/bin/env bash
# OpenTimestamps proofs start incomplete and can be upgraded once the
# Bitcoin attestation lands (usually within a day). Run occasionally.
# Usage (from the repo root):  ./tools/upgrade-seals.sh
set -euo pipefail
cd "$(dirname "$0")/.."
changed=0
for o in seals/*.ots; do
  [ -e "$o" ] || continue
  if ots upgrade "$o" 2>&1 | grep -q Upgraded; then changed=1; fi
  rm -f "$o.bak"
done
if [ "$changed" = 1 ]; then
  git add seals/*.ots
  git commit -m "Upgrade OTS proofs"
  git push
  echo "Upgraded proofs pushed."
else
  echo "Nothing to upgrade yet."
fi
