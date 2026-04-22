#!/usr/bin/env bash
# Tests for the --auto flag.
# Verifies flag parsing, help text, and the resolve_claude_default_flags helper output.
# shellcheck disable=SC1090,SC2034

set -euo pipefail

cd "$(dirname "$0")/.."

CCO_BIN="$PWD/cco"

PASSED=0
FAILED=0

pass() {
	echo "PASS: $1"
	PASSED=$((PASSED + 1))
}

fail() {
	echo "FAIL: $1"
	FAILED=$((FAILED + 1))
}

echo "=== Permission-mode Flag Tests ==="
echo "Platform: $(uname -s) ($(uname -m))"
echo ""

TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

# -------------------------------------------------------------------
# 1. Help text lists --auto
# -------------------------------------------------------------------
echo "--- Help text ---"

help_output=$("$CCO_BIN" --help 2>&1 || true)

if grep -q -- '--auto' <<<"$help_output"; then
	pass "--help mentions --auto"
else
	fail "--help does not mention --auto"
fi

# -------------------------------------------------------------------
# 2. resolve_claude_default_flags unit test via sourced function bundle
#    (mirrors the FUNCTIONS_ONLY pattern used by test_startup_preflights.sh)
# -------------------------------------------------------------------
echo ""
echo "--- resolve_claude_default_flags ---"

FUNCTIONS_ONLY="$TEST_ROOT/cco_functions.sh"
sed '/^# Initialize variables$/q' "$CCO_BIN" >"$FUNCTIONS_ONLY"

check_flags() {
	local label="$1"
	local auto="$2"
	shift 2
	local expected=("$@")

	local output exit_code
	output=$(
		auto_mode="$auto"
		claude_default_flags=()
		# shellcheck disable=SC1091
		source "$FUNCTIONS_ONLY" 2>/dev/null || true
		resolve_claude_default_flags
		# Print each element on its own line to avoid quoting ambiguity.
		for f in "${claude_default_flags[@]}"; do
			printf '%s\n' "$f"
		done
	) && exit_code=0 || exit_code=$?

	if [[ "$exit_code" -ne 0 ]]; then
		fail "$label: resolve_claude_default_flags exited non-zero"
		return
	fi

	local actual=()
	if [[ -n "$output" ]]; then
		while IFS= read -r line; do
			actual+=("$line")
		done <<<"$output"
	fi

	if [[ "${#actual[@]}" -ne "${#expected[@]}" ]]; then
		echo "  expected (${#expected[@]}): ${expected[*]}"
		echo "  actual   (${#actual[@]}): ${actual[*]}"
		fail "$label: wrong number of flags"
		return
	fi

	local i
	for i in "${!expected[@]}"; do
		if [[ "${actual[$i]}" != "${expected[$i]}" ]]; then
			echo "  expected[$i]: ${expected[$i]}"
			echo "  actual[$i]:   ${actual[$i]}"
			fail "$label: flag mismatch at index $i"
			return
		fi
	done

	pass "$label"
}

# Default (flag not set) -> --dangerously-skip-permissions
check_flags "default => --dangerously-skip-permissions" \
	false \
	--dangerously-skip-permissions

# --auto -> --permission-mode auto
check_flags "--auto => --permission-mode auto" \
	true \
	--permission-mode auto

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
echo ""
echo "=== Results ==="
echo "Passed:  $PASSED"
echo "Failed:  $FAILED"

if [[ $FAILED -gt 0 ]]; then
	exit 1
fi
