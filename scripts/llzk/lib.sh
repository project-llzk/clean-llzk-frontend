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
#   [sampled|strict-sampled|exhaustive-outputs] [EXPECTED_OUTPUTS]
#   [ALTERNATE_FULL ALTERNATE_PUBLIC]
# or
#   exhaustive-interface EXPECTED_INPUTS EXPECTED_WITNESSES EXPECTED_OUTPUTS
#
# Proves, on a real emitted artifact, that llzk-witgen --check-output can go both
# green and red. For both output scopes, the expected document must succeed and
# independently corrupted documents must fail. Sampled mode checks numeric
# first, middle, and last positions. Exhaustive-output mode checks every
# `out{j}` in both scopes and can additionally require a semantically distinct
# alternate full/public witness pair to go red. Exhaustive-interface mode also
# checks the exact input/signal layouts and mutates every `w{k}` one at a time.
#
# Without this, every green below is unfalsifiable: the harness cannot tell a
# passing check from a binary that exits 0 unconditionally. The expanded probes
# cost multiple invocations per backend/scope/group; they are R2's Control 1,
# promoted from something a reviewer did by hand to something the harness does
# every run and strengthened for S29's wide outputs.
require_llzk_witgen_discriminates() {
  local artifact="$1" inputs="$2" expected="$3" public_expected="$4" workdir="$5"
  local mode="${6:-sampled}" arg7="${7:-}" arg8="${8:-}" arg9="${9:-}" arg10="${10:-}"
  local expected_inputs="" expected_witnesses="" expected_outputs=""
  local alternate_full="" alternate_public=""
  case "${mode}" in
    sampled|strict-sampled)
      [[ -z "${arg7}${arg8}${arg9}${arg10}" ]] \
        || llzk_fail "llzk-witgen self-test: ${mode} mode takes no output count or alternate"
      ;;
    exhaustive-outputs)
      expected_outputs="${arg7}"
      alternate_full="${arg8}"
      alternate_public="${arg9}"
      [[ "${expected_outputs}" =~ ^[1-9][0-9]*$ ]] \
        || llzk_fail "llzk-witgen self-test: exhaustive-output count must be a positive integer"
      if [[ -n "${alternate_full}" || -n "${alternate_public}" ]]; then
        [[ -n "${alternate_full}" && -n "${alternate_public}" ]] \
          || llzk_fail "llzk-witgen self-test: alternate full and public expectations must be supplied together"
      fi
      [[ -z "${arg10}" ]] \
        || llzk_fail "llzk-witgen self-test: exhaustive-output mode takes at most an output count and two alternates"
      ;;
    exhaustive-interface)
      expected_inputs="${arg7}"
      expected_witnesses="${arg8}"
      expected_outputs="${arg9}"
      [[ "${expected_inputs}" =~ ^[1-9][0-9]*$ ]] \
        || llzk_fail "llzk-witgen self-test: exhaustive-interface input count must be a positive integer"
      [[ "${expected_witnesses}" =~ ^[1-9][0-9]*$ ]] \
        || llzk_fail "llzk-witgen self-test: exhaustive-interface witness count must be a positive integer"
      [[ "${expected_outputs}" =~ ^[1-9][0-9]*$ ]] \
        || llzk_fail "llzk-witgen self-test: exhaustive-interface output count must be a positive integer"
      [[ $# -eq 9 ]] \
        || llzk_fail "llzk-witgen self-test: exhaustive-interface mode takes exactly three counts"
      ;;
    *) llzk_fail "llzk-witgen self-test: unknown discriminator mode ${mode}" ;;
  esac
  # Not a fixed name. R5d's D-5: two six-line shims that special-cased the
  # scratch paths defeated both self-tests, because those paths were literals a
  # shim could recognise. PID-derived scratch names keep the source filenames,
  # especially their semantic `raw` marker, out of the tool invocation. This is
  # a regression discriminator, not a secrecy claim.
  local tag; tag="$(basename -- "${artifact}" .llzk).$$"
  local corrupted_prefix="${workdir}/witgen-selftest-${tag}"
  local public_corrupted_prefix="${workdir}/witgen-public-selftest-${tag}"
  local alternate_full_probe="${corrupted_prefix}-alternate.json"
  local alternate_public_probe="${public_corrupted_prefix}-alternate.json"
  local witness_positions=(first middle last)
  local output_positions=(first middle last)
  if [[ "${mode}" == "exhaustive-interface" ]]; then
    witness_positions=()
    local witness_index
    for ((witness_index = 0; witness_index < expected_witnesses; witness_index++)); do
      witness_positions+=("index-${witness_index}")
    done
  fi
  if [[ "${mode}" == "exhaustive-outputs" || "${mode}" == "exhaustive-interface" ]]; then
    output_positions=()
    local output_index
    for ((output_index = 0; output_index < expected_outputs; output_index++)); do
      output_positions+=("index-${output_index}")
    done
  fi

  python3 - "${expected}" "${corrupted_prefix}" \
      "${public_expected}" "${public_corrupted_prefix}" "${mode}" \
      "${expected_inputs}" "${expected_witnesses}" "${expected_outputs}" "${inputs}" \
      "${alternate_full}" "${alternate_public}" \
      "${alternate_full_probe}" "${alternate_public_probe}" <<'PYEOF' \
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

def corrupt_all(document, keys, prefix, what, group):
    for index, key in enumerate(keys):
        changed = copy.deepcopy(document)
        target = changed["signals"] if what != "public output" else changed
        value = int(target[key])
        target[key] = "1" if value == 0 else "0"
        with open(f"{prefix}-{group}-index-{index}.json", "w") as output:
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
mode, expected_input_count, expected_witness_count, expected_output_count, inputs_path = \
    sys.argv[5:10]
if mode == "strict-sampled":
    for label, values in (("witness cells", witness_keys),
                          ("full-witness outputs", output_keys)):
        if len(values) < 3:
            raise SystemExit(f"widest artifact has only {len(values)} distinct {label}; need 3")

if mode == "exhaustive-interface":
    input_count = int(expected_input_count)
    witness_count = int(expected_witness_count)
    output_count = int(expected_output_count)
    exact_input_keys = [f"arg{i}" for i in range(input_count)]
    exact_witness_keys = [f"w{i}" for i in range(witness_count)]
    exact_output_keys = [f"out{i}" for i in range(output_count)]
    with open(inputs_path) as source:
        inputs = json.load(source)
    if not isinstance(inputs, dict) or list(sorted(inputs, key=lambda key:
            int(key[3:]) if key.startswith("arg") and key[3:].isdigit() else -1)) != exact_input_keys \
            or set(inputs) != set(exact_input_keys):
        raise SystemExit(f"inputs are not exactly arg0 through arg{input_count - 1}")
    if witness.get("inputs") != inputs:
        raise SystemExit("full-witness inputs disagree with the supplied input document")
    if witness_keys != exact_witness_keys or output_keys != exact_output_keys \
            or set(signals) != set(exact_witness_keys + exact_output_keys):
        raise SystemExit("full witness has the wrong exact w{k}/out{j} signal layout")

    def canonical_babybear(value):
        if isinstance(value, bool):
            return False
        if isinstance(value, int):
            parsed = value
        elif isinstance(value, str) and value.isdecimal() and value == str(int(value)):
            parsed = int(value)
        else:
            return False
        return 0 <= parsed < 2_013_265_921

    if not all(canonical_babybear(value) for value in inputs.values()):
        raise SystemExit("input document contains a noncanonical Babybear scalar")
    if not all(canonical_babybear(value) for value in signals.values()):
        raise SystemExit("full witness contains a noncanonical Babybear scalar")
    corrupt_all(witness, witness_keys, sys.argv[2], "witness signals", "witness")
else:
    corrupt_positions(witness, witness_keys, sys.argv[2], "witness signals", "witness")

with open(sys.argv[3]) as source:
    public = json.load(source)
if not public:
    raise SystemExit("expected public output has no value to perturb")
public_keys = numbered_keys(public, "out")
if len(public_keys) != len(public):
    raise SystemExit("public expectation contains a key other than out{j}")
if mode == "strict-sampled" and len(public_keys) < 3:
    raise SystemExit(f"widest artifact has only {len(public_keys)} distinct public outputs; need 3")
if mode in ("exhaustive-outputs", "exhaustive-interface"):
    count = int(expected_output_count)
    exact_keys = [f"out{i}" for i in range(count)]
    if output_keys != exact_keys:
        raise SystemExit(f"full witness outputs are {output_keys}, expected exactly {exact_keys}")
    if public_keys != exact_keys:
        raise SystemExit(f"public outputs are {public_keys}, expected exactly {exact_keys}")
    if mode == "exhaustive-interface" and not all(
            canonical_babybear(value) for value in public.values()):
        raise SystemExit("public output contains a noncanonical Babybear scalar")
    if any(str(signals[key]) != str(public[key]) for key in exact_keys):
        raise SystemExit("full and public output expectations disagree")
    corrupt_all(witness, output_keys, sys.argv[2], "full-witness outputs", "output")
    corrupt_all(public, public_keys, sys.argv[4], "public output", "output")
else:
    corrupt_positions(witness, output_keys, sys.argv[2], "full-witness outputs", "output")
    corrupt_positions(public, public_keys, sys.argv[4], "public output", "output")

alternate_full_path, alternate_public_path, alternate_full_probe, alternate_public_probe = \
    sys.argv[10:14]
if alternate_full_path:
    with open(alternate_full_path) as source:
        alternate_witness = json.load(source)
    with open(alternate_public_path) as source:
        alternate_public = json.load(source)
    alternate_signals = alternate_witness.get("signals", {})
    if alternate_witness.get("inputs") != witness.get("inputs"):
        raise SystemExit("alternate full expectation belongs to different inputs")
    if set(alternate_signals) != set(signals):
        raise SystemExit("alternate full expectation has a different signal key set")
    if set(alternate_public) != set(public):
        raise SystemExit("alternate public expectation has a different output key set")
    for key in output_keys:
        if str(alternate_signals[key]) != str(alternate_public[key]):
            raise SystemExit(f"alternate full/public output {key} disagrees")
        if str(alternate_public[key]) == str(public[key]):
            raise SystemExit(f"alternate output {key} does not differ from the baseline")
    with open(alternate_full_probe, "w") as output:
        json.dump(alternate_witness, output)
    with open(alternate_public_probe, "w") as output:
        json.dump(alternate_public, output)
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

    local position corrupted
    for position in "${witness_positions[@]}"; do
      corrupted="${corrupted_prefix}-witness-${position}.json"
      [[ -f "${corrupted}" ]] || continue
      if "${LLZK_WITGEN}" "${artifact}" --inputs "${inputs}" --backend="${backend}" \
           --output-scope=full-witness --check-output "${corrupted}" >/dev/null 2>&1; then
        llzk_fail "llzk-witgen self-test (${backend}): ${LLZK_WITGEN} accepted a full witness \
with its witness group's ${position} field perturbed, so --check-output is incomplete. Every \
G5/G6/G7 green below would be vacuous."
      fi
    done
    for position in "${output_positions[@]}"; do
      corrupted="${corrupted_prefix}-output-${position}.json"
      if "${LLZK_WITGEN}" "${artifact}" --inputs "${inputs}" --backend="${backend}" \
           --output-scope=full-witness --check-output "${corrupted}" >/dev/null 2>&1; then
        llzk_fail "llzk-witgen self-test (${backend}): ${LLZK_WITGEN} accepted a full witness \
with its output group's ${position} field perturbed, so --check-output is incomplete. Every \
G5/G6/G7 green below would be vacuous."
      fi
    done
    if [[ -n "${alternate_full}" ]] && \
         "${LLZK_WITGEN}" "${artifact}" --inputs "${inputs}" --backend="${backend}" \
           --output-scope=full-witness --check-output "${alternate_full_probe}" >/dev/null 2>&1; then
      llzk_fail "llzk-witgen self-test (${backend}): ${LLZK_WITGEN} accepted the alternate full witness"
    fi

    "${LLZK_WITGEN}" "${artifact}" --inputs "${inputs}" --backend="${backend}" \
      --output-scope=public --check-output "${public_expected}" >/dev/null \
      || llzk_fail "llzk-witgen public-output self-test (${backend}): ${artifact} does not match \
its own expected output; every later public-scope green would be meaningless"

    local public_corrupted
    for position in "${output_positions[@]}"; do
      public_corrupted="${public_corrupted_prefix}-output-${position}.json"
      if "${LLZK_WITGEN}" "${artifact}" --inputs "${inputs}" --backend="${backend}" \
           --output-scope=public --check-output "${public_corrupted}" >/dev/null 2>&1; then
        llzk_fail "llzk-witgen public-output self-test (${backend}): ${LLZK_WITGEN} accepted an \
expectation with its ${position} public output perturbed, so the visibility/value gate is \
incomplete."
      fi
    done
    if [[ -n "${alternate_public}" ]] && \
         "${LLZK_WITGEN}" "${artifact}" --inputs "${inputs}" --backend="${backend}" \
           --output-scope=public --check-output "${alternate_public_probe}" >/dev/null 2>&1; then
      llzk_fail "llzk-witgen public-output self-test (${backend}): ${LLZK_WITGEN} accepted the alternate public output"
    fi
  done
  local position
  for position in "${witness_positions[@]}"; do
    rm -f -- "${corrupted_prefix}-witness-${position}.json"
  done
  for position in "${output_positions[@]}"; do
    rm -f -- "${corrupted_prefix}-output-${position}.json"
    rm -f -- "${public_corrupted_prefix}-output-${position}.json"
  done
  rm -f -- "${alternate_full_probe}" "${alternate_public_probe}"
  if [[ "${mode}" == "strict-sampled" ]]; then
    echo "llzk-witgen self-test: both backends and both scopes green on expected JSON, \
red on distinct first/middle/last witness-cell, full-output, and public-output perturbations"
  elif [[ "${mode}" == "exhaustive-interface" ]]; then
    echo "llzk-witgen self-test: both backends and both scopes green on exact \
${expected_inputs}-input/${expected_witnesses}-witness/${expected_outputs}-output JSON, \
red on every witness cell and every full/public output"
  elif [[ "${mode}" == "exhaustive-outputs" ]]; then
    echo "llzk-witgen self-test: both backends and both scopes green on expected JSON, \
red on first/middle/last witness cells and every one of ${expected_outputs} full/public outputs${alternate_full:+ plus alternate expectations}"
  else
    echo "llzk-witgen self-test: both backends and both scopes green on expected JSON, \
red on every available first/middle/last probe (positions can coincide; empty groups are skipped)"
  fi
}

# llzk_xor32_raw_expectations INPUTS EXPECTED PUBLIC_EXPECTED RAW_FULL RAW_PUBLIC
#
# Build the old pre-D035 Xor32 result directly from the eight canonical input
# representatives. It is a discriminator, not another source of expected green
# values: the checked baseline must equal low-byte XOR in every lane, while the
# old raw XOR after field reduction must differ in all four lanes.
llzk_xor32_raw_expectations() {
  local inputs="$1" expected="$2" public_expected="$3" raw_full="$4" raw_public="$5"
  python3 - "${inputs}" "${expected}" "${public_expected}" "${raw_full}" "${raw_public}" <<'PYEOF' \
    || llzk_fail "Xor32 raw-reference discriminator could not be built"
import json, sys

input_path, full_path, public_path, raw_full_path, raw_public_path = sys.argv[1:]
with open(input_path) as source:
    inputs = json.load(source)
with open(full_path) as source:
    full = json.load(source)
with open(public_path) as source:
    public = json.load(source)

input_keys = [f"arg{i}" for i in range(8)]
signal_keys = [f"w{i}" for i in range(4)] + [f"out{i}" for i in range(4)]
output_keys = [f"out{i}" for i in range(4)]
if not isinstance(inputs, dict) or set(inputs) != set(input_keys):
    raise SystemExit("Xor32 inputs must be exactly canonical arg0 through arg7")
def decimal_representative(value):
    if isinstance(value, bool):
        raise ValueError
    if isinstance(value, int):
        return value
    if isinstance(value, str) and value.isdecimal():
        parsed = int(value)
        if value == str(parsed):
            return parsed
    raise ValueError

try:
    values = [decimal_representative(inputs[key]) for key in input_keys]
except ValueError:
    raise SystemExit("Xor32 inputs must be integers or canonical decimal strings")
prime = 2_013_265_921
if any(value < 0 or value >= prime for value in values):
    raise SystemExit("Xor32 input is not a canonical Babybear representative")

if full.get("inputs") != inputs or set(full.get("signals", {})) != set(signal_keys):
    raise SystemExit("Xor32 full expectation has the wrong inputs or signal layout")
if set(public) != set(output_keys):
    raise SystemExit("Xor32 public expectation must be exactly out0 through out3")

narrowed = [(values[i] % 256) ^ (values[4 + i] % 256) for i in range(4)]
raw = [(values[i] ^ values[4 + i]) % prime for i in range(4)]
signals = full["signals"]
for i, value in enumerate(narrowed):
    if str(signals[f"w{i}"]) != str(value) or str(signals[f"out{i}"]) != str(value) \
            or str(public[f"out{i}"]) != str(value):
        raise SystemExit(f"Xor32 checked expectation is not narrowed at lane {i}")
    if raw[i] == value:
        raise SystemExit(f"Xor32 raw XOR does not differ at lane {i}")

raw_signals = {f"w{i}": str(value) for i, value in enumerate(raw)}
raw_signals.update({f"out{i}": str(value) for i, value in enumerate(raw)})
with open(raw_full_path, "w") as output:
    json.dump({"inputs": inputs, "signals": raw_signals}, output)
with open(raw_public_path, "w") as output:
    json.dump({f"out{i}": str(value) for i, value in enumerate(raw)}, output)
PYEOF
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
# Exercises the exact command families used by the gates, rather than assuming
# that discrimination in plain verification implies discrimination under a
# pass flag. A wrapper can delegate every plain invocation to the real tool but
# exit zero only for `--verify-roundtrip` or `--llzk-product-program`; that made
# G4 or G10a vacuous while this helper stayed green (R8).
#
# Plain verification and `--verify-roundtrip` each get a real emitted positive,
# a non-MLIR negative, and a well-formed-MLIR/invalid-LLZK negative. Those three
# have the same accept/reject partition, so they cannot distinguish a wrapper
# which merely strips `--verify-roundtrip` and delegates to plain verification.
# A fourth canary is therefore plain-positive and roundtrip-negative: the
# accepted LLZK 3.0 tool parses an SMT keyword containing a hyphen, but its
# current printer emits a generic keyword spelling which neither its textual nor
# bytecode round-trip parser accepts. This deliberately pins that behavior; a
# future tool which closes the parser/printer bug needs a reviewed replacement
# canary, not a silent deletion of the check.
#
# The product pipeline gets a real emitted positive and a negative which is
# deliberately stronger than malformed input: a plain-valid LLZK module whose
# root is not the literal `@Main` required by `--llzk-product-program`.
# Full inlining alone must accept that control, isolating the product pass as the
# reason the combined command rejects it.
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
  local roundtrip_canary="${workdir}/llzk-opt-selftest-${tag}.roundtrip-canary.llzk"
  local wrongroot="${workdir}/llzk-opt-selftest-${tag}.wrong-root.llzk"
  local product_output="${workdir}/llzk-opt-selftest-${tag}.product.llzk"

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

  "${LLZK_OPT}" --verify-roundtrip "${artifact}" -o /dev/null >/dev/null 2>&1 \
    || llzk_fail "llzk-opt round-trip self-test: ${artifact} does not round-trip; every G4 green \
would be meaningless"
  if "${LLZK_OPT}" --verify-roundtrip "${garbage}" -o /dev/null >/dev/null 2>&1; then
    llzk_fail "llzk-opt round-trip self-test: ${LLZK_OPT} accepted a file that is not MLIR under \
--verify-roundtrip, so G4 is not checking anything."
  fi
  if "${LLZK_OPT}" --verify-roundtrip "${nonllzk}" -o /dev/null >/dev/null 2>&1; then
    llzk_fail "llzk-opt round-trip self-test: ${LLZK_OPT} accepted well-formed MLIR that is not \
valid LLZK under --verify-roundtrip, so G4 is not running LLZK's verifier."
  fi

  cat > "${roundtrip_canary}" <<'LLZKEOF'
module {
  smt.solver () : () -> () {
    smt.set_info ":a-b" "x"
    smt.yield
  }
}
LLZKEOF
  "${LLZK_OPT}" "${roundtrip_canary}" -o /dev/null >/dev/null 2>&1 \
    || llzk_fail "llzk-opt round-trip self-test: the round-trip canary is not plain-valid"
  if "${LLZK_OPT}" --verify-roundtrip "${roundtrip_canary}" \
       -o /dev/null >/dev/null 2>&1; then
    llzk_fail "llzk-opt round-trip self-test: ${LLZK_OPT} accepted the plain-valid round-trip \
canary under --verify-roundtrip. The accepted LLZK 3.0 tool rejects this current \
parser/printer boundary, so --verify-roundtrip may have been ignored."
  fi

  cat > "${wrongroot}" <<'LLZKEOF'
module attributes {llzk.lang = "clean", llzk.main = !struct.type<@NotMain>} {
  struct.def @NotMain {
    function.def @compute() -> !struct.type<@NotMain> {
      %v0 = struct.new : !struct.type<@NotMain>
      function.return %v0 : !struct.type<@NotMain>
    }
    function.def @constrain(%self: !struct.type<@NotMain>) {
      function.return
    }
  }
}
LLZKEOF
  "${LLZK_OPT}" "${wrongroot}" -o /dev/null >/dev/null 2>&1 \
    || llzk_fail "llzk-opt product self-test: the wrong-root control is not plain-valid LLZK"
  "${LLZK_OPT}" --llzk-full-inlining "${wrongroot}" \
    -o /dev/null >/dev/null 2>&1 \
    || llzk_fail "llzk-opt product self-test: the wrong-root control did not survive full \
inlining, so its combined-pipeline rejection would not isolate --llzk-product-program"
  "${LLZK_OPT}" --llzk-full-inlining --llzk-product-program \
    "${artifact}" -o "${product_output}" >/dev/null 2>&1 \
    || llzk_fail "llzk-opt product self-test: ${artifact} is not admitted; every G10a green would \
be meaningless"
  [[ -s "${product_output}" ]] \
    || llzk_fail "llzk-opt product self-test: the admitted artifact did not materialize product \
IR, so --llzk-product-program may have been ignored"
  grep -Eq 'function\.def @product\(' "${product_output}" \
    && grep -q 'product_source = "compute"' "${product_output}" \
    && grep -q 'product_source = "constrain"' "${product_output}" \
    || llzk_fail "llzk-opt product self-test: the admitted artifact lacks the generated @product \
function or its compute/constrain provenance, so --llzk-product-program may have been ignored"
  if "${LLZK_OPT}" --llzk-full-inlining --llzk-product-program \
       "${wrongroot}" -o /dev/null >/dev/null 2>&1; then
    llzk_fail "llzk-opt product self-test: ${LLZK_OPT} accepted a plain-valid LLZK module whose \
root is not @Main under --llzk-product-program, so G10a is not checking its analysis pipeline."
  fi

  rm -f "${garbage}" "${nonllzk}" "${roundtrip_canary}" "${wrongroot}" \
    "${product_output}"
  echo "llzk-opt self-test: plain and round-trip green on an emitted artifact and red on \
non-MLIR/invalid LLZK; round-trip flag distinguished by a plain-positive canary; product \
pipeline green on the artifact and red on a full-inlining-valid non-Main root"
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
