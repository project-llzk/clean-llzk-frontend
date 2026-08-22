# Shared helpers for the Clean → LLZK scripts. Source, do not execute.

llzk_fail() { echo "error: $*" >&2; exit 1; }

# Expected LLZK version. Overridable so a pin update is one variable, not a grep
# through the scripts.
LLZK_EXPECTED_VERSION="${LLZK_EXPECTED_VERSION:-3.0.0}"

# require_llzk_executable VAR PATH
require_llzk_executable() {
  local var="$1" path="${2:-}"
  [[ -n "${path}" ]] || llzk_fail "${var} is not set; see doc/llzk/CURRENT.md for provisioning"
  [[ -x "${path}" ]] || llzk_fail "${var}=${path} is not an executable"
}

# require_llzk_version VAR PATH
#
# Fails unless PATH's --version mentions the pinned LLZK version. This is the
# substantive check: an LLZK 2.0 llzk-opt is installed on this machine and
# accepts different syntax, so an existence check alone would validate the
# emitter against the wrong language.
require_llzk_version() {
  local var="$1" path="$2" version
  version="$("${path}" --version 2>&1 || true)"
  grep -q -- "LLZK version ${LLZK_EXPECTED_VERSION}" <<<"${version}" \
    || llzk_fail "${var}=${path} does not report LLZK version ${LLZK_EXPECTED_VERSION}:
$(sed 's/^/    /' <<<"${version}")"
  echo "${var}: ${path}"
  echo "  $(grep -m1 'LLZK version' <<<"${version}" | sed 's/^ *//')"
}

# require_llzk_sibling VAR PATH REFERENCE_VAR REFERENCE_PATH
#
# Establishes PATH's provenance by co-location rather than by --version.
#
# Not laziness: at LLZK 3.0.0, `llzk-witgen --version` prints only LLVM's version
# banner and never mentions LLZK, so there is nothing to match on. Requiring it
# to sit in the same directory as a version-checked llzk-opt ties it to the same
# installation.
#
# Provenance is necessary and not sufficient: a two-line `exit 0` script named
# llzk-witgen next to a symlink to the real llzk-opt used to satisfy this and
# make the whole harness report PASS while checking nothing (R2-06). What the
# gates need is that the binary *discriminates*, which is
# require_llzk_witgen_discriminates below.
require_llzk_sibling() {
  local var="$1" path="$2" ref_var="$3" ref_path="$4"
  [[ "$(dirname -- "${path}")" == "$(dirname -- "${ref_path}")" ]] \
    || llzk_fail "${var}=${path} is not in the same directory as ${ref_var}=${ref_path}; \
both must come from the same LLZK installation"
  echo "${var}: ${path}"
  echo "  version: not self-reported; provenance from ${ref_var} (same installation)"
}

# require_llzk_witgen_discriminates ARTIFACT INPUTS EXPECTED PUBLIC_EXPECTED WORKDIR
#
# Proves, on a real emitted artifact, that llzk-witgen --check-output can go both
# green and red. For both output scopes, the expected document must succeed and
# three independently corrupted documents -- first, middle, and last field --
# must fail. The three positions matter for wide headline outputs: a checker
# that validates only `out0` must not make the rest of the matrix look green.
#
# Without this, every green below is unfalsifiable: the harness cannot tell a
# passing check from a binary that exits 0 unconditionally. The expanded probes
# cost multiple invocations per backend/scope/group; they are R2's Control 1,
# promoted from something a reviewer did by hand to something the harness does
# every run and strengthened for S29's wide outputs.
require_llzk_witgen_discriminates() {
  local artifact="$1" inputs="$2" expected="$3" public_expected="$4" workdir="$5"
  local require_distinct="${6:-false}"
  case "${require_distinct}" in
    true|false) ;;
    *) llzk_fail "llzk-witgen self-test: strict-distinct flag must be true or false, got \
${require_distinct}" ;;
  esac
  # Not a fixed name. R5d's D-5: two six-line shims that special-cased the
  # scratch paths defeated both self-tests, because those paths were literals a
  # shim could recognise. The basename and PID make them unguessable from
  # inside the tool.
  local tag; tag="$(basename -- "${artifact}" .llzk).$$"
  local corrupted_prefix="${workdir}/witgen-selftest-${tag}"
  local public_corrupted_prefix="${workdir}/witgen-public-selftest-${tag}"
  local positions=(first middle last)

  python3 - "${expected}" "${corrupted_prefix}" \
      "${public_expected}" "${public_corrupted_prefix}" "${require_distinct}" <<'PYEOF' \
    || llzk_fail "llzk-witgen self-test: \
could not build the corrupted witness"
import copy, json, sys

def corrupt_positions(document, keys, prefix, what, group):
    if not keys:
        return
    positions = (("first", 0), ("middle", len(keys) // 2), ("last", len(keys) - 1))
    for label, index in positions:
        changed = copy.deepcopy(document)
        target = changed["signals"] if what != "public output" else changed
        key = keys[index]
        value = int(target[key])
        target[key] = "1" if value == 0 else "0"
        with open(f"{prefix}-{group}-{label}.json", "w") as output:
            json.dump(changed, output)

with open(sys.argv[1]) as source:
    witness = json.load(source)
signals = witness.get("signals", {})
if not isinstance(signals, dict):
    raise SystemExit("expected full witness signals are not an object")
def numbered_keys(values, prefix):
    keys = [key for key in values if key.startswith(prefix)
            and key[len(prefix):].isdigit()
            and key == prefix + str(int(key[len(prefix):]))]
    return sorted(keys, key=lambda key: int(key[len(prefix):]))

witness_keys = numbered_keys(signals, "w")
output_keys = numbered_keys(signals, "out")
if not witness_keys and not output_keys:
    raise SystemExit("expected full witness has no signal or output to perturb")
if sys.argv[5] == "true":
    for label, values in (("witness cells", witness_keys),
                          ("full-witness outputs", output_keys)):
        if len(values) < 3:
            raise SystemExit(f"widest artifact has only {len(values)} distinct {label}; need 3")
corrupt_positions(witness, witness_keys, sys.argv[2], "witness signals", "witness")
corrupt_positions(witness, output_keys, sys.argv[2], "full-witness outputs", "output")

with open(sys.argv[3]) as source:
    public = json.load(source)
if not public:
    raise SystemExit("expected public output has no value to perturb")
public_keys = numbered_keys(public, "out")
if len(public_keys) != len(public):
    raise SystemExit("public expectation contains a key other than out{j}")
if sys.argv[5] == "true" and len(public_keys) < 3:
    raise SystemExit(f"widest artifact has only {len(public_keys)} distinct public outputs; need 3")
corrupt_positions(public, public_keys, sys.argv[4], "public output", "output")
PYEOF

  # Both backends, because both are gates. R5d's D-1: the self-test ran only the
  # default interpreter, so `--backend=execution-engine` -- the whole of G6, and
  # half of what makes G7 a *differential* -- was never shown to discriminate. A
  # stub execution engine that exited 0 would have made G6 vacuous while the log
  # differed from a real run only in tool paths.
  local backend
  for backend in interpreter execution-engine; do
    "${LLZK_WITGEN}" "${artifact}" --inputs "${inputs}" --backend="${backend}" \
      --output-scope=full-witness --check-output "${expected}" >/dev/null \
      || llzk_fail "llzk-witgen self-test (${backend}): ${artifact} does not match its own \
expected witness; every later green would be meaningless"

    local group position corrupted
    for group in witness output; do
      for position in "${positions[@]}"; do
        corrupted="${corrupted_prefix}-${group}-${position}.json"
        [[ -f "${corrupted}" ]] || continue
        if "${LLZK_WITGEN}" "${artifact}" --inputs "${inputs}" --backend="${backend}" \
             --output-scope=full-witness --check-output "${corrupted}" >/dev/null 2>&1; then
          llzk_fail "llzk-witgen self-test (${backend}): ${LLZK_WITGEN} accepted a full witness \
with its ${group} group's ${position} field perturbed, so --check-output is incomplete. Every \
G5/G6/G7 green below would be vacuous."
        fi
      done
    done

    "${LLZK_WITGEN}" "${artifact}" --inputs "${inputs}" --backend="${backend}" \
      --output-scope=public --check-output "${public_expected}" >/dev/null \
      || llzk_fail "llzk-witgen public-output self-test (${backend}): ${artifact} does not match \
its own expected output; every later public-scope green would be meaningless"

    local public_corrupted
    for position in "${positions[@]}"; do
      public_corrupted="${public_corrupted_prefix}-output-${position}.json"
      if "${LLZK_WITGEN}" "${artifact}" --inputs "${inputs}" --backend="${backend}" \
           --output-scope=public --check-output "${public_corrupted}" >/dev/null 2>&1; then
        llzk_fail "llzk-witgen public-output self-test (${backend}): ${LLZK_WITGEN} accepted an \
expectation with its ${position} public output perturbed, so the visibility/value gate is \
incomplete."
      fi
    done
  done
  local position
  for group in witness output; do
    for position in "${positions[@]}"; do
      rm -f -- "${corrupted_prefix}-${group}-${position}.json"
    done
  done
  for position in "${positions[@]}"; do
    rm -f -- "${public_corrupted_prefix}-output-${position}.json"
  done
  if [[ "${require_distinct}" == "true" ]]; then
    echo "llzk-witgen self-test: both backends and both scopes green on expected JSON, \
red on distinct first/middle/last witness-cell, full-output, and public-output perturbations"
  else
    echo "llzk-witgen self-test: both backends and both scopes green on expected JSON, \
red on every available first/middle/last probe (positions can coincide; empty groups are skipped)"
  fi
}

# llzk_widest_public_input OUTPUT_DIRECTORY
#
# Returns the vector-zero input path belonging to the artifact with the widest
# public expectation. Deriving the probe from emitted JSON means BLAKE3.G's
# eventual 64-field interface automatically becomes the discriminator target.
llzk_widest_public_input() {
  local directory="$1" selected
  selected="$(python3 - "${directory}" <<'PYEOF'
import glob, json, os, sys

candidates = []
for path in glob.glob(os.path.join(sys.argv[1], "*.0.public.json")):
    with open(path) as source:
        public = json.load(source)
    if not isinstance(public, dict) or not public:
        raise SystemExit(f"{path}: public expectation is not a nonempty object")
    candidates.append((len(public), path))
if not candidates:
    raise SystemExit("no vector-zero public expectation found")
_, widest = max(candidates, key=lambda item: (item[0], item[1]))
print(widest.removesuffix(".public.json") + ".inputs.json")
PYEOF
)" || llzk_fail "could not select the widest public-output self-test artifact"
  [[ -f "${selected}" ]] \
    || llzk_fail "widest public-output self-test has no input file: ${selected}"
  echo "${selected}"
}

# llzk_require_exact_count LABEL ACTUAL EXPECTED
#
# Count floors let a new refusal hide behind an unrelated new success, or let a
# permissive lowering turn every declared skip green. Exact counts reject both
# smaller and larger totals; callers must state separately whether an aggregate
# permits compensating per-item changes.
llzk_require_exact_count() {
  local label="$1" actual="$2" expected="$3"
  [[ "${actual}" =~ ^[0-9]+$ && "${expected}" =~ ^[0-9]+$ ]] \
    || llzk_fail "${label}: counts must be natural numbers (got ${actual}, expected ${expected})"
  (( actual == expected )) \
    || llzk_fail "${label}: got ${actual}, expected exactly ${expected}"
}

# require_llzk_opt_discriminates WORKDIR ARTIFACT
#
# The symmetric control to require_llzk_witgen_discriminates, and it was missing:
# llzk-opt's only validation was `--version`, which is exactly the "existence
# check" this file rejects as insufficient for llzk-witgen. Reversing R2-06's
# attack -- a four-line shim that answers `--version` and exits 0 otherwise --
# satisfied require_llzk_tools and made G3, G4 and G10 all vacuous while e2e.sh
# printed PASS (R4b-2).
#
# Runs llzk-opt three times: once on a real emitted artifact, which must verify;
# once on a file that is not MLIR at all, which must not; and once on a module
# that is well-formed MLIR and invalid *LLZK*, which must not either.
#
# The third probe is R5d's D-2, and it matters more than it sounds. With only the
# first two, any generic MLIR parser passes this self-test -- and that is not
# hypothetical: LLZK 3.0.0 itself accepts, exit 0, a module whose entire body is
#
#     func.func @f(%a: i32) -> i32 { return %a : i32 }
#
# with no LLZK construct in it at all. So "rejects a file that is not MLIR"
# establishes nothing about whether the LLZK verifier ran, and G3's "verifies"
# could be false while green. The probe used instead is a `struct.def` carrying a
# `@compute` and no `@constrain`, which parses fine and which only LLZK's own
# verifier rejects.
require_llzk_opt_discriminates() {
  local workdir="$1" artifact="$2"
  # Derived, not fixed: see the note in require_llzk_witgen_discriminates.
  local tag; tag="$(basename -- "${artifact}" .llzk).$$"
  local garbage="${workdir}/llzk-opt-selftest-${tag}.notmlir"
  local nonllzk="${workdir}/llzk-opt-selftest-${tag}.llzk"

  "${LLZK_OPT}" "${artifact}" -o /dev/null >/dev/null 2>&1 \
    || llzk_fail "llzk-opt self-test: ${artifact} does not verify; every later green would be \
meaningless"

  printf 'this is not MLIR, let alone LLZK\n' > "${garbage}"
  if "${LLZK_OPT}" "${garbage}" -o /dev/null >/dev/null 2>&1; then
    llzk_fail "llzk-opt self-test: ${LLZK_OPT} accepted a file that is not MLIR, so G3, G4 and \
G10 are not checking anything."
  fi

  cat > "${nonllzk}" <<'LLZKEOF'
module attributes {llzk.lang = "clean", llzk.main = !struct.type<@Main>} {
  struct.def @Main {
    function.def @compute() -> !struct.type<@Main> {
      %v0 = struct.new : !struct.type<@Main>
      function.return %v0 : !struct.type<@Main>
    }
  }
}
LLZKEOF
  if "${LLZK_OPT}" "${nonllzk}" -o /dev/null >/dev/null 2>&1; then
    llzk_fail "llzk-opt self-test: ${LLZK_OPT} accepted a struct.def with a @compute and no \
@constrain, which is well-formed MLIR and invalid LLZK. Something is parsing the text without \
running LLZK's verifier, so G3, G4 and G10 are green without checking anything."
  fi

  rm -f "${garbage}" "${nonllzk}"
  echo "llzk-opt self-test: green on an emitted artifact, red on a non-MLIR file \
and on well-formed MLIR that is not valid LLZK"
}

# llzk_smt_declared_reason LOGFILE
#
# Echoes the declared reason --llzk-to-smt-no-cf could not lower a module, or
# nothing if the diagnostic is not one of the known limits of LLZK 3.0.0's
# SMT lowering.
#
# Keyed on the tool's own diagnostic rather than on what the artifact contains.
# A proxy — "the module has a global.read, so any failure is excusable" — would
# have excused an unrelated failure in the same module, which is how the first
# version of this gate would have missed a root component not named @Main in
# Addition8FullCarry.
# The list holds only reasons an artifact in the corpus actually produces as an
# *error*. A tolerance nothing exercises is a hole: it can only ever excuse
# something. LLZK 3.0.0 also leaves `global.read`/`constrain.in` unhandled, but
# it reports those as *warnings* — Addition8FullCarry's log carries both, and
# then fails with the felt.uintdiv error — so there is no tolerated reason for
# them and a lookup-only circuit would turn G10b red until someone adds one with
# evidence.
llzk_smt_declared_reason() {
  local log="$1" line reason=""
  # Every *error* line must be tolerated. Grepping the whole log for one
  # tolerated pattern excused any other error that happened to appear beside it,
  # and warnings are not errors: the real Addition8FullCarry log carries
  # "unhandled operation" warnings for global.read and constrain.in *and* the
  # felt.uintdiv error, which the previous whole-log grep conflated (R4b-5).
  while IFS= read -r line; do
    case "${line}" in
      *"failed to legalize operation 'felt.uintdiv'"*|*"failed to legalize operation 'felt.umod'"*)
        reason="felt.uintdiv/felt.umod are marked illegal by --llzk-to-smt-no-cf" ;;
      *"failed to legalize operation 'felt.bit_and'"*|*"failed to legalize operation 'felt.bit_or'"*|\
      *"failed to legalize operation 'felt.bit_xor'"*|*"failed to legalize operation 'felt.shl'"*|\
      *"failed to legalize operation 'felt.shr'"*)
        reason="felt bitwise/shift operations are marked illegal by --llzk-to-smt-no-cf" ;;
      *'no prime field specified'*)
        reason="the module declares no felt type, so the pass cannot deduce a prime field" ;;
      *) return 1 ;;
    esac
  done < <(grep 'error:' "${log}")
  [[ -n "${reason}" ]] || return 1
  echo "${reason}"
}

# require_llzk_tools
#
# Validates LLZK_OPT and LLZK_WITGEN together, which is the only way to validate
# llzk-witgen at all.
require_llzk_tools() {
  require_llzk_executable LLZK_OPT "${LLZK_OPT:-}"
  require_llzk_executable LLZK_WITGEN "${LLZK_WITGEN:-}"
  require_llzk_version LLZK_OPT "${LLZK_OPT}"
  require_llzk_sibling LLZK_WITGEN "${LLZK_WITGEN}" LLZK_OPT "${LLZK_OPT}"
}
