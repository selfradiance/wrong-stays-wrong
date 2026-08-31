# Wrong Stays Wrong

A book written in public time. Each chapter is one question about how AI is unfolding, worked out in conversation between James and Claude, distilled into short prose, and cryptographically sealed the day it is finished. Falsifiable claims are marked in the text where they occur, each with a horizon date. Once a year a scoring chapter grades every claim that has come due: right, wrong, or unresolvable, in public, no excuses. Nothing is edited after sealing; corrections happen in later chapters that cite the sealed original. Each chapter's header records the date and the Claude model vintage that co-wrote it. Wrong stays wrong.

## Layout

Chapters live in `chapters/`, their seals (an Ed25519 signature and an OpenTimestamps proof) in `seals/`, and annual scoring chapters in `scoring/`.

## Verifying a seal

Every sealed chapter has two proofs. The signature proves the file is unaltered since it was signed with this project's key. The `.ots` proof anchors the file's hash in the Bitcoin blockchain, proving it existed at that time. To check both, from the repo root:

    ssh-keygen -Y verify -f allowed_signers -I james -n wrong-stays-wrong \
      -s seals/NN-slug.md.sig < chapters/NN-slug.md

    ots verify -f chapters/NN-slug.md seals/NN-slug.md.ots

`ssh-keygen` ships with macOS, Linux, and Windows. `ots` is the open-source OpenTimestamps client (`pip install opentimestamps-client`). The public key is `seal_key.pub`, committed in this repo since the first commit and itself timestamped by every seal that follows.
