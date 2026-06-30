#!/usr/bin/env bash
# Tests for the --ramdisk flag: cco-provisioned ephemeral RAM disk.
# Verifies the disk is writable inside the sandbox via $CCO_RAMDISK, that it is
# absent unless requested, that macOS RAM disks are detached on exit (provenance:
# cco only ever tears down the device it created), and that the size helpers parse
# correctly.

set -euo pipefail

cd "$(dirname "$0")/.."
CCO_BIN="$PWD/cco"

PASSED=0
FAILED=0
SKIPPED=0

pass() {
	echo "PASS: $1"
	PASSED=$((PASSED + 1))
}

fail() {
	echo "FAIL: $1"
	FAILED=$((FAILED + 1))
}

skip() {
	echo "SKIP: $1"
	SKIPPED=$((SKIPPED + 1))
}

supports_backend() {
	local backend="$1"
	case "$backend" in
	native)
		if [[ "$(uname -s)" == "Darwin" ]]; then
			command -v sandbox-exec >/dev/null 2>&1
		else
			command -v bwrap >/dev/null 2>&1
		fi
		;;
	docker)
		command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1
		;;
	*)
		return 1
		;;
	esac
}

echo "=== RAM disk Tests (--ramdisk flag) ==="
echo "Platform: $(uname -s) ($(uname -m))"
echo ""

TEST_ROOT=$(mktemp -d)
TEST_HOME="$TEST_ROOT/home"
PROJ_DIR="$TEST_ROOT/project"
mkdir -p "$TEST_HOME" "$PROJ_DIR"
git init "$PROJ_DIR" >/dev/null 2>&1
git -C "$PROJ_DIR" config user.email "test@example.com"
git -C "$PROJ_DIR" config user.name "tester"
trap 'rm -rf "$TEST_ROOT"' EXIT

# Run a shell command inside the sandbox for a given backend. Extra flags (e.g.
# --ramdisk=64M) are passed before the `shell` subcommand. Only stdout is
# returned; cco's own logs go to stderr and are discarded by the caller.
run_shell() {
	local backend="$1"
	local cmd="$2"
	shift 2
	(
		cd "$PROJ_DIR" && HOME="$TEST_HOME" "$CCO_BIN" --backend "$backend" "$@" shell "$cmd" </dev/null
	)
}

# Count currently-mounted cco RAM disk volumes (macOS), glob-based to avoid ls|grep.
count_cco_ramdisks() {
	local n=0 d
	for d in /Volumes/cco-ramdisk-*; do
		[[ -d "$d" ]] && n=$((n + 1))
	done
	printf '%s' "$n"
}

for backend in native docker; do
	if ! supports_backend "$backend"; then
		skip "backend unavailable: $backend"
		continue
	fi

	# A) $CCO_RAMDISK is set and points at a writable directory.
	# shellcheck disable=SC2016
	if out=$(run_shell "$backend" 'printf yes > "$CCO_RAMDISK/probe" && cat "$CCO_RAMDISK/probe"' --ramdisk=64M 2>/dev/null) && [[ "$out" == "yes" ]]; then
		pass "ramdisk is writable via \$CCO_RAMDISK ($backend)"
	else
		fail "ramdisk writable ($backend): got '$out'"
	fi

	# B) Off by default: CCO_RAMDISK is unset when the flag is absent.
	# shellcheck disable=SC2016
	if out=$(run_shell "$backend" 'echo ">${CCO_RAMDISK:-}<"' 2>/dev/null) && [[ "$out" == "><" ]]; then
		pass "ramdisk off by default ($backend)"
	else
		fail "ramdisk off by default ($backend): got '$out'"
	fi

	# C) macOS native only: the RAM disk is detached after the sandbox exits, so
	# no cco-ramdisk-* volume is left mounted (proves detach-by-device cleanup).
	if [[ "$backend" == "native" && "$(uname -s)" == "Darwin" ]]; then
		before=$(count_cco_ramdisks)
		run_shell "$backend" 'true' --ramdisk=64M >/dev/null 2>&1 || true
		after=$(count_cco_ramdisks)
		if [[ "$after" -le "$before" ]]; then
			pass "macOS RAM disk detached on exit (no leak)"
		else
			fail "macOS RAM disk leaked: before=$before after=$after"
		fi
	fi
done

#
# Size-parsing unit tests (pure helpers extracted from cco, same pattern as
# test_additional_directories.sh).
#
echo ""
echo "--- size parsing unit tests ---"
eval "$(sed -n '/^parse_size_to_bytes()/,/^}/p; /^is_valid_ramdisk_size()/,/^}/p' "$CCO_BIN")"

check_size() {
	local in="$1" want="$2" got
	got=$(parse_size_to_bytes "$in" 2>/dev/null) || got="REJECT"
	if [[ "$got" == "$want" ]]; then
		pass "parse_size_to_bytes '$in' -> $want"
	else
		fail "parse_size_to_bytes '$in': want $want got $got"
	fi
}

check_size 512M 536870912
check_size 2G 2147483648
check_size 1g 1073741824
check_size 1024 1024
check_size 1GiB 1073741824
check_size 256k 262144
check_size bogus REJECT
check_size "" REJECT

if is_valid_ramdisk_size 64M && ! is_valid_ramdisk_size shell && ! is_valid_ramdisk_size 0; then
	pass "is_valid_ramdisk_size accepts sizes, rejects subcommands and zero"
else
	fail "is_valid_ramdisk_size predicate"
fi

echo ""
echo "=== Results ==="
echo "Passed:  $PASSED"
echo "Failed:  $FAILED"
echo "Skipped: $SKIPPED"

if [[ $FAILED -gt 0 ]]; then
	exit 1
fi
