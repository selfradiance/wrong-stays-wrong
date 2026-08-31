# Wrong Stays Wrong

A book written in public time. Each chapter is one question about how AI is unfolding, worked out through James's spontaneous speech-to-text exploration—"jambling"—with an AI collaborator, distilled into short prose, and cryptographically sealed the day it is finished. Falsifiable claims are marked where they occur, each with a horizon date. Once a year a scoring chapter grades every claim that has come due: right, wrong, or unresolvable, in public, no excuses. Nothing is edited after sealing; corrections happen in later chapters that cite the sealed original. Each chapter names the AI model that actually co-wrote it. Wrong stays wrong.

## Layout

Chapters live in `chapters/`, their seals (an Ed25519 signature and an OpenTimestamps proof) in `seals/`, and annual scoring chapters in `scoring/`.

Every chapter begins with five fields: `Date`, `Chapter`, `Question`, `AI model`, and `Reasoning level`.

## Verifying a seal

Every sealed chapter has two proofs. The signature proves the file is unaltered since it was signed with this project's key. A new `.ots` proof records a pending timestamp with public calendar servers; after it is upgraded and verified, it anchors the chapter's hash in the Bitcoin blockchain. To check both, from the repo root:

    ssh-keygen -Y verify -f allowed_signers -I james -n wrong-stays-wrong \
      -s seals/NN-slug.md.sig < chapters/NN-slug.md

    ots verify -f chapters/NN-slug.md seals/NN-slug.md.ots

`ssh-keygen` ships with macOS, Linux, and Windows. `ots` is the open-source OpenTimestamps client (`brew install opentimestamps-client` on macOS or `pip install opentimestamps-client`). A newly submitted proof will normally report that Bitcoin confirmation is pending. `tools/upgrade-seals.sh` upgrades pending proofs when their Bitcoin attestations become available. The project's public verification key is `seal_key.pub`; the private signing key is never stored in this repository.
