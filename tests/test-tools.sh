#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
failures=0
test_root="$(mktemp -d)"
staged_fixture="tests/.staged-fixture-$$"
chapter_fixture="chapters/99-contract-test.md"

cleanup() {
  git restore --staged -- "$staged_fixture" 2>/dev/null || true
  rm -f "$staged_fixture" "$chapter_fixture" \
    "seals/99-contract-test.md.sig" "seals/99-contract-test.md.ots"
  rm -rf "$test_root"
}
trap cleanup EXIT

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; failures=$((failures + 1)); }
check() {
  local description="$1"
  shift
  if "$@"; then pass "$description"; else fail "$description"; fi
}
contains() {
  local needle="$1" file="$2"
  grep -Fq "$needle" "$file"
}
not_contains() {
  local needle="$1" file="$2"
  ! grep -Fq "$needle" "$file"
}
run_failure() {
  local output_file="$1"
  shift
  if "$@" >"$output_file" 2>&1; then return 1; fi
}

check "README title" test "$(sed -n '1p' README.md)" = "# Wrong Stays Wrong"
check "project context title" test "$(sed -n '1p' wrong-stays-wrong-project-context.md)" = "# Wrong Stays Wrong"
check "settled title documented" contains 'The settled title is **Wrong Stays Wrong**' wrong-stays-wrong-project-context.md
check "model collaboration rule" contains 'Each chapter names the AI model that actually co-wrote it' README.md
check "README does not assign every chapter to Claude" not_contains 'between James and Claude' README.md
check "Claude seed provenance retained" contains 'Claude vintage at seeding:' wrong-stays-wrong-project-context.md
check "Codex handoff dated" contains 'Continuing work moved to Codex on 2026-08-31' wrong-stays-wrong-project-context.md
check "jambling defined" contains '“Jambling” is James' wrong-stays-wrong-project-context.md
check "workflow documented" contains 'jambling → distill → mark → seal' wrong-stays-wrong-project-context.md
check "header fields documented" contains '`Date`, `Chapter`, `Question`, `AI model`, and `Reasoning level`' wrong-stays-wrong-project-context.md
check "Sol default documented" contains 'Sol at the highest available reasoning level unless James explicitly chooses otherwise' wrong-stays-wrong-project-context.md
check "old project context filename is gone" test ! -e contemporaneous-record-project-brief.md

tracked_files="$(git ls-files)"
for placeholder in chapters/.gitkeep seals/.gitkeep scoring/.gitkeep; do
  if grep -Fxq "$placeholder" <<<"$tracked_files"; then pass "$placeholder is tracked"; else fail "$placeholder is tracked"; fi
done
for local_file in log.md contract.md wrong-stays-wrong-project-context.md; do
  check "$local_file is ignored" git check-ignore -q "$local_file"
  if grep -Fxq "$local_file" <<<"$tracked_files"; then fail "$local_file is not tracked"; else pass "$local_file is not tracked"; fi
done

if grep -Eq '(^|/)(\.env($|\.)|[^/]*\.pem$|[^/]*-identity[^/]*\.json$|privvy[^/]*$|seal_key$)' <<<"$tracked_files"; then
  fail "prohibited private filenames are not tracked"
else
  pass "prohibited private filenames are not tracked"
fi
private_key_header='BEGIN OPENSSH'" PRIVATE KEY"
if git grep -q "$private_key_header" -- .; then
  fail "no private-key header is tracked"
else
  pass "no private-key header is tracked"
fi

private_key="../wrong-stays-wrong-keys/seal_key"
check "private key is a regular file" test -f "$private_key"
check "private key mode is 600" test "$(stat -f '%Lp' "$private_key")" = 600
derived_key="$(ssh-keygen -y -f "$private_key" | awk '{print $1 " " $2}')"
published_key="$(awk '{print $1 " " $2}' seal_key.pub)"
check "published key derives from private key" test "$derived_key" = "$published_key"
nonblank_signers="$(grep -cve '^[[:space:]]*$' allowed_signers)"
signer_identity="$(awk 'NF {print $1}' allowed_signers)"
signer_key="$(awk 'NF {print $2 " " $3}' allowed_signers)"
check "allowed_signers has one entry" test "$nonblank_signers" = 1
check "allowed_signers identity is james" test "$signer_identity" = james
check "allowed_signers key matches" test "$signer_key" = "$published_key"

check "OpenTimestamps is installed" ots --version
check "shell syntax" bash -n tools/seal.sh tools/upgrade-seals.sh tests/test-tools.sh
for executable in tools/seal.sh tools/upgrade-seals.sh tests/test-tools.sh; do
  check "$executable is executable" test -x "$executable"
done
check "pending proof wording" contains 'A new `.ots` proof records a pending timestamp' README.md
check "README omits false immediate-anchor claim" not_contains 'The `.ots` proof anchors' README.md
check "README omits false key timestamp claim" not_contains 'itself timestamped by every seal' README.md

output="$test_root/output"
if run_failure "$output" ./tools/seal.sh && grep -Fq 'usage:' "$output"; then pass "seal requires one argument"; else fail "seal requires one argument"; fi
if run_failure "$output" ./tools/seal.sh chapters/does-not-exist.md && grep -Fq 'no such file' "$output"; then pass "seal identifies a missing chapter"; else fail "seal identifies a missing chapter"; fi
if run_failure "$output" ./tools/seal.sh README.md && grep -Fq 'invalid chapter path' "$output"; then pass "seal rejects a repository file outside chapters"; else fail "seal rejects a repository file outside chapters"; fi
if run_failure "$output" ./tools/seal.sh chapters/../README.md && grep -Fq 'invalid chapter path' "$output"; then pass "seal rejects traversal paths"; else fail "seal rejects traversal paths"; fi

printf 'contract fixture\n' > "$chapter_fixture"
printf 'original signature\n' > seals/99-contract-test.md.sig
sig_before="$(shasum -a 256 seals/99-contract-test.md.sig)"
if run_failure "$output" ./tools/seal.sh "$chapter_fixture" && grep -Fq 'already sealed' "$output" && test "$sig_before" = "$(shasum -a 256 seals/99-contract-test.md.sig)"; then
  pass "seal preserves an existing signature"
else
  fail "seal preserves an existing signature"
fi
rm -f seals/99-contract-test.md.sig
printf 'original timestamp\n' > seals/99-contract-test.md.ots
ots_before="$(shasum -a 256 seals/99-contract-test.md.ots)"
if run_failure "$output" ./tools/seal.sh "$chapter_fixture" && grep -Fq 'already sealed' "$output" && test "$ots_before" = "$(shasum -a 256 seals/99-contract-test.md.ots)"; then
  pass "seal preserves an existing timestamp"
else
  fail "seal preserves an existing timestamp"
fi
rm -f seals/99-contract-test.md.ots

printf 'staged fixture\n' > "$staged_fixture"
git add "$staged_fixture"
head_before="$(git rev-parse HEAD)"
if run_failure "$output" ./tools/seal.sh "$chapter_fixture" && grep -Fq 'staged changes' "$output" && git diff --cached --quiet --exit-code -- . ':!tests/.staged-fixture-*' && test "$head_before" = "$(git rev-parse HEAD)"; then
  pass "seal refuses a non-clean Git index"
else
  fail "seal refuses a non-clean Git index"
fi
if run_failure "$output" ./tools/upgrade-seals.sh && grep -Fq 'staged changes' "$output" && test "$head_before" = "$(git rev-parse HEAD)"; then
  pass "upgrade refuses a non-clean Git index"
else
  fail "upgrade refuses a non-clean Git index"
fi
git restore --staged -- "$staged_fixture"
rm -f "$staged_fixture"

head_before="$(git rev-parse HEAD)"
upgrade_output="$(./tools/upgrade-seals.sh)"
if test "$upgrade_output" = 'Nothing to upgrade yet.' && test "$head_before" = "$(git rev-parse HEAD)"; then
  pass "upgrade handles an empty seals directory"
else
  fail "upgrade handles an empty seals directory"
fi

upgrade_test_root="$test_root/upgrade-detection"
mkdir -p "$upgrade_test_root/repo/tools" "$upgrade_test_root/repo/seals" "$upgrade_test_root/fake-bin"
cp tools/upgrade-seals.sh "$upgrade_test_root/repo/tools/upgrade-seals.sh"
printf 'pending proof\n' > "$upgrade_test_root/repo/seals/01-test.md.ots"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "bitcoin attestation\n" >> "$2"' \
  'printf "calendar response changed\n"' \
  > "$upgrade_test_root/fake-bin/ots"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [ "$1" = diff ]; then exit 0; fi' \
  'printf "%s\n" "$1" >> "$TEST_GIT_LOG"' \
  > "$upgrade_test_root/fake-bin/git"
chmod +x "$upgrade_test_root/fake-bin/ots" "$upgrade_test_root/fake-bin/git"
upgrade_git_log="$upgrade_test_root/git.log"
if PATH="$upgrade_test_root/fake-bin:$PATH" TEST_GIT_LOG="$upgrade_git_log" "$upgrade_test_root/repo/tools/upgrade-seals.sh" > "$output" 2>&1 \
  && grep -Fq 'Upgraded proofs pushed.' "$output" \
  && grep -Fxq add "$upgrade_git_log" \
  && grep -Fxq commit "$upgrade_git_log" \
  && grep -Fxq push "$upgrade_git_log"; then
  pass "upgrade detects proof changes without parsing calendar wording"
else
  fail "upgrade detects proof changes without parsing calendar wording"
fi

repo_artifacts_before="$(find chapters seals scoring tests -maxdepth 1 -type f -print | sort)"
ssh-keygen -q -t ed25519 -N '' -C 'temporary contract test' -f "$test_root/test_key"
printf 'signature fixture\n' > "$test_root/signed.txt"
ssh-keygen -Y sign -q -f "$test_root/test_key" -n wrong-stays-wrong "$test_root/signed.txt"
printf 'tester %s\n' "$(cat "$test_root/test_key.pub")" > "$test_root/allowed_signers"
check "temporary signature verifies" sh -c "ssh-keygen -Y verify -f '$test_root/allowed_signers' -I tester -n wrong-stays-wrong -s '$test_root/signed.txt.sig' < '$test_root/signed.txt'"
printf 'timestamp fixture\n' > "$test_root/timestamped.txt"
if ots stamp "$test_root/timestamped.txt" >/dev/null 2>&1 && test -s "$test_root/timestamped.txt.ots" && ots info "$test_root/timestamped.txt.ots" >/dev/null 2>&1; then
  pass "temporary OpenTimestamps proof parses"
else
  fail "temporary OpenTimestamps proof parses"
fi
if test "$repo_artifacts_before" != "$(find chapters seals scoring tests -maxdepth 1 -type f -print | sort)"; then
  fail "temporary test artifacts stay outside the repository"
else
  pass "temporary test artifacts stay outside the repository"
fi

if [ "$failures" -ne 0 ]; then
  printf '\n%d test(s) failed.\n' "$failures" >&2
  exit 1
fi
printf '\nAll contract tests passed.\n'
