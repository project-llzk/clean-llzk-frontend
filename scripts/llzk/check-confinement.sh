#!/usr/bin/env bash
# Keep the entry points that skip a gate out of ordinary code.
#
# Two families, and the reason is the same for both: this backend's guarantees
# are stated over `compile`/`emit`, and every other public way in weakens one of
# them. They cannot be deleted -- the corpus and the negative fixtures need them
# -- so what they can be is named honestly and confined to the modules that have
# a reason.
#
# 1. `Config.unsafeWithTables` supplies lookup tables with no certificate.
#    R5's X1: `{ field := .babybear, tables := #[fatBytes] }` compiled
#    Addition8FullCarry into a module admitting `w0 = 300`, which Clean's
#    `ByteTable` rejects, with every gate green. The rows cannot be checked by
#    the compiler -- that is D012 -- so the path stays, behind a name that says
#    so, while the supported entry points take a `CertifiedConfig`, which cannot
#    be built without the certificates (S24).
#
# 2. `compileSource`, `compileSource'` and `lowerRecognized` return a module
#    without running both halves of G9. R5b, R5a, R5c and R5d each found one of
#    them independently; R5d rebuilt R2's Control 4 -- `Multiply` with its
#    multiplication constraint deleted -- through `lowerRecognized` and passed
#    G3, G4, G5, G6, G10a and G10b with it.
#
#    `lowerRecognized` is not "unchecked": it validates the field registry, both
#    the configured and hand-built retained table registries, their exact
#    relationship, and (since R5) D011's side conditions. What it cannot do is
#    compare against a Clean circuit, because a hand-built `Recognized` has none.
#    That is why the six `Square_*` corpus entries report `constraintsAgree =
#    none` rather than `some true` -- G9 does not apply to them, and `EmitMain`
#    says so in as many words.
#
# What this does NOT establish: that the confined call sites are correct. It
# establishes that the set of places that can be wrong is small enough to read,
# and that adding one is a reviewed diff rather than an import away.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"

# shellcheck source=scripts/llzk/lib.sh
source "${script_dir}/lib.sh"

cd "${repo_root}"

status=0

# confine NAME PATTERN ALLOWED_REGEX WHY
#
# Matches against the file with its **comments blanked** (A2). Greping the raw
# source made a docstring that says "use `compile`, not `compileSource'`" into a
# call site, and the fix each time was to add the file to the allowlist -- three
# times in one session, at which point the list no longer meant what its name
# says. Reading code instead makes the gate stricter, not looser: the three
# entries that were there for prose are gone.
confine() {
  local name="$1" pattern="$2" allowed="$3" why="$4"
  local offenders=()
  local file
  while IFS= read -r file; do
    [[ "${file}" =~ ${allowed} ]] && continue
    python3 "${script_dir}/strip-lean-comments.py" "${file}" \
      | grep -qE -- "${pattern}" && offenders+=("${file}")
  done < <(grep -rlE --include='*.lean' -- "${pattern}" Clean/ || true)

  if (( ${#offenders[@]} > 0 )); then
    printf 'error: %s outside the modules allowed to name it:\n' "${name}" >&2
    printf '  %s\n' "${offenders[@]}" >&2
    printf '  %s\n' "${why}" >&2
    status=1
  else
    echo "  ok  ${name}"
  fi
}

echo "confinement:"

confine 'Config.unsafeWithTables' 'unsafeWithTables' \
  '^(Clean/Backend/LLZK/Basic\.lean|Clean/Backend/LLZK/Certificate\.lean|Clean/Backend/LLZK/Test/.*\.lean)$' \
  'supply tables through a CertifiedConfig, which requires an ExportTable.Certifies proof per table (Certificate.lean) and is what the supported checked WitnessCheck entry points take. If a table genuinely cannot be certified, that is a decision to record, not a call site to add.'

# `Witness.lean`, `Lookups.lean` and `Soundness.lean` used to be on this list for
# prose alone. They are not any more: the check reads code (A2), so a docstring
# naming an entry point is not a call site and the allowlist is back to the
# modules that genuinely call one.
confine 'the G9-skipping entry points' "compileSource'?\\b|lowerRecognized" \
  '^Clean/Backend/LLZK/(Circuit|Constraints|WitnessCheck|Corpus)\.lean$|^Clean/Backend/LLZK/Test/.*\.lean$' \
  'use LLZK.compile or LLZK.emit, which run both halves of G9 (Constraints.lean, WitnessCheck.lean). These three return a module without that comparison; Corpus.lean is allowed because the registry-conformance entries have no Clean circuit to compare against.'

if (( status != 0 )); then
  llzk_fail "a gate-skipping entry point escaped its confinement; see the errors above"
fi

echo "confinement check: every gate-skipping entry point is confined"
