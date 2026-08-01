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
# installation, which is the property that actually matters.
require_llzk_sibling() {
  local var="$1" path="$2" ref_var="$3" ref_path="$4"
  [[ "$(dirname -- "${path}")" == "$(dirname -- "${ref_path}")" ]] \
    || llzk_fail "${var}=${path} is not in the same directory as ${ref_var}=${ref_path}; \
both must come from the same LLZK installation"
  echo "${var}: ${path}"
  echo "  version: not self-reported; provenance from ${ref_var} (same installation)"
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
