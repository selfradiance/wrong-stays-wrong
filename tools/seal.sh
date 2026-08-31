#!/usr/bin/env bash
# Seal a chapter: sign it, timestamp it, commit and push.
# Usage (from the repo root):  ./tools/seal.sh chapters/01-slug.md
set -euo pipefail
cd "$(dirname "$0")/.."
usage="usage: ./tools/seal.sh chapters/NN-slug.md"
[ "$#" -eq 1 ] || { echo "$usage"; exit 1; }
f="$1"
[ -f "$f" ] || { echo "no such file: $f"; exit 1; }
[[ "$f" =~ ^chapters/[0-9]{2}-[a-z0-9][a-z0-9-]*\.md$ ]] || {
  echo "invalid chapter path: $f (expected chapters/NN-slug.md)"
  exit 1
}
key="../wrong-stays-wrong-keys/seal_key"
[ -f "$key" ] || { echo "seal key not found at $key"; exit 1; }
command -v ots >/dev/null || { echo "ots not installed: pip3 install opentimestamps-client"; exit 1; }
[ -z "$(git diff --cached --name-only)" ] || {
  echo "refusing to seal: Git already has staged changes"
  exit 1
}
base="$(basename "$f")"
[ -e "seals/$base.sig" ] && { echo "already sealed: seals/$base.sig exists. Sealed files are never re-sealed."; exit 1; }
[ -e "seals/$base.ots" ] && { echo "already sealed: seals/$base.ots exists. Sealed files are never re-sealed."; exit 1; }
trap 'rm -f "$f.sig" "$f.ots"' EXIT
ssh-keygen -Y sign -f "$key" -n wrong-stays-wrong "$f"
ssh-keygen -Y verify -f allowed_signers -I james -n wrong-stays-wrong -s "$f.sig" < "$f"
ots stamp "$f"
mv "$f.sig" "seals/$base.sig"
mv "$f.ots" "seals/$base.ots"
trap - EXIT
git add "$f" "seals/$base.sig" "seals/$base.ots"
git commit -m "Seal $base"
git push
echo "Sealed and pushed: $f"
