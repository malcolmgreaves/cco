#!/usr/bin/env bash
<<<<<<< Updated upstream
# Tests for --ask-permissions and --auto flags.
=======
# Tests for --ask and --auto flags.
>>>>>>> Stashed changes
# Verifies flag parsing, mutual exclusion, help text, and the
# resolve_claude_default_flags helper output.
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
# 1. Help text lists both flags
# -------------------------------------------------------------------
echo "--- Help text ---"

help_output=$("$CCO_BIN" --help 2>&1 || true)

<<<<<<< Updated upstream
if grep -q -- '--ask-permissions' <<<"$help_output"; then
	pass "--help mentions --ask-permissions"
else
	fail "--help does not mention --ask-permissions"
=======
if grep -q -- '--ask' <<<"$help_output"; then
	pass "--help mentions --ask"
else
	fail "--help does not mention --ask"
>>>>>>> Stashed changes
fi

if grep -q -- '--auto' <<<"$help_output"; then
	pass "--help mentions --auto"
else
	fail "--help does not mention --auto"
fi

# -------------------------------------------------------------------
<<<<<<< Updated upstream
# 2. Mutual exclusion: --ask-permissions + --auto errors and exits 1
=======
# 2. Mutual exclusion: --ask + --auto errors and exits 1
>>>>>>> Stashed changes
# -------------------------------------------------------------------
echo ""
echo "--- Mutual exclusion ---"

set +e
<<<<<<< Updated upstream
mutex_output=$("$CCO_BIN" --ask-permissions --auto 2>&1)
=======
mutex_output=$("$CCO_BIN" --ask --auto 2>&1)
>>>>>>> Stashed changes
mutex_exit=$?
set -e

if [[ "$mutex_exit" -ne 0 ]]; then
<<<<<<< Updated upstream
	pass "--ask-permissions --auto exits non-zero (got $mutex_exit)"
else
	fail "--ask-permissions --auto should exit non-zero, got 0"
fi

if [[ "$mutex_output" == *"--ask-permissions and --auto are mutually exclusive"* ]]; then
=======
	pass "--ask --auto exits non-zero (got $mutex_exit)"
else
	fail "--ask --auto should exit non-zero, got 0"
fi

if [[ "$mutex_output" == *"--ask and --auto are mutually exclusive"* ]]; then
>>>>>>> Stashed changes
	pass "mutex error message mentions both flags"
else
	echo "  output: $mutex_output"
	fail "mutex error message missing expected wording"
fi

# Order-independent: reversed args should also error
set +e
<<<<<<< Updated upstream
mutex_output2=$("$CCO_BIN" --auto --ask-permissions 2>&1)
=======
mutex_output2=$("$CCO_BIN" --auto --ask 2>&1)
>>>>>>> Stashed changes
mutex_exit2=$?
set -e

if [[ "$mutex_exit2" -ne 0 ]] && [[ "$mutex_output2" == *"mutually exclusive"* ]]; then
	pass "mutex is order-independent"
else
	fail "mutex did not fire with reversed flag order"
fi

# -------------------------------------------------------------------
# 3. resolve_claude_default_flags unit test via sourced function bundle
#    (mirrors the FUNCTIONS_ONLY pattern used by test_startup_preflights.sh)
# -------------------------------------------------------------------
echo ""
echo "--- resolve_claude_default_flags ---"

FUNCTIONS_ONLY="$TEST_ROOT/cco_functions.sh"
sed '/^# Initialize variables$/q' "$CCO_BIN" >"$FUNCTIONS_ONLY"

check_flags() {
	local label="$1"
	local ask="$2"
	local auto="$3"
	shift 3
	local expected=("$@")

	local output exit_code
	output=$(
		ask_permissions="$ask"
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

# Default (neither flag set) -> --dangerously-skip-permissions
check_flags "default => --dangerously-skip-permissions" \
	false false \
	--dangerously-skip-permissions

<<<<<<< Updated upstream
# --ask-permissions -> empty array (no permission flag appended)
check_flags "--ask-permissions => no flag" \
=======
# --ask -> empty array (no permission flag appended)
check_flags "--ask => no flag" \
>>>>>>> Stashed changes
	true false

# --auto -> --permission-mode auto
check_flags "--auto => --permission-mode auto" \
	false true \
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
