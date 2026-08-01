# Shared helpers for the Clean → LLZK scripts. Source, do not execute.

llzk_fail() { echo "error: $*" >&2; exit 1; }

# Expected LLZK version. Overridable so a pin update is one variable, not a grep
# through the scripts.
LLZK_EXPECTED_VERSION="${LLZK_EXPECTED_VERSION:-3.0.0}"

# require_llzk_tool VAR PATH
#
# Fails unless PATH is an executable whose --version mentions the pinned LLZK
# version. The version check is the point: an LLZK 2.0 binary is on this machine
# and would otherwise satisfy a bare existence check while accepting different
# syntax.
require_llzk_tool() {
  local var="$1" path="${2:-}" version
  [[ -n "${path}" ]] || llzk_fail "${var} is not set; see doc/llzk/CURRENT.md for provisioning"
  [[ -x "${path}" ]] || llzk_fail "${var}=${path} is not an executable"
  version="$("${path}" --version 2>&1 || true)"
  grep -q -- "${LLZK_EXPECTED_VERSION}" <<<"${version}" \
    || llzk_fail "${var}=${path} reports a version that does not mention the pinned LLZK ${LLZK_EXPECTED_VERSION}:
$(sed 's/^/    /' <<<"${version}")"
  echo "${var}: ${path}"
  echo "  version: $(grep -m1 -i 'llzk version' <<<"${version}" || head -n 1 <<<"${version}")"
}
