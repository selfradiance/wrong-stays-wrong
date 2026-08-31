#!/usr/bin/env bash
# Seal a chapter: sign it, timestamp it, commit and push.
# Usage (from the repo root):  ./tools/seal.sh chapters/01-slug.md
set -euo pipefail
cd "$(dirname "$0")/.."
f="${1:?usage: ./tools/seal.sh chapters/NN-slug.md}"
[ -f "$f" ] || { echo "no such file: $f"; exit 1; }
key="../wrong-stays-wrong-keys/seal_key"
[ -f "$key" ] || { echo "seal key not found at $key"; exit 1; }
command -v ots >/dev/null || { echo "ots not installed: pip3 install opentimestamps-client"; exit 1; }
base="$(basename "$f")"
[ -e "seals/$base.sig" ] && { echo "already sealed: seals/$base.sig exists. Sealed files are never re-sealed."; exit 1; }
ssh-keygen -Y sign -f "$key" -n wrong-stays-wrong "$f"
mv "$f.sig" "seals/$base.sig"
ots stamp "$f"
mv "$f.ots" "seals/$base.ots"
ssh-keygen -Y verify -f allowed_signers -I james -n wrong-stays-wrong -s "seals/$base.sig" < "$f"
git add "$f" "seals/$base.sig" "seals/$base.ots"
git commit -m "Seal $base"
git push
echo "Sealed and pushed: $f"
