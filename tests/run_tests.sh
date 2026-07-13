#!/usr/bin/env bash
# run_tests.sh — ircserv integration test suite entrypoint.
# Usage: bash tests/run_tests.sh ./ircserv
# Env:   IRC_TIMEOUT (per-read seconds, default 3)
#        IRC_WRAPPER (e.g. "valgrind --leak-check=full --error-exitcode=42")

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -lt 1 ] || [ ! -x "$1" ]; then
	echo "usage: $0 <path-to-ircserv-binary>" >&2
	exit 2
fi
case "$1" in
	/*) BINARY="$1" ;;
	*)  BINARY="$(pwd)/${1#./}" ;;
esac

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/ircserv-tests.XXXXXX")"

source "$TESTS_DIR/lib.sh"

cleanup() {
	stop_server
	rm -rf "$SCRATCH"
}
trap cleanup EXIT INT TERM

for case_file in "$TESTS_DIR"/cases/*.sh; do
	echo "== $(basename "$case_file") =="

	# Discover every test_* function defined by this case file.
	before="$(declare -F | awk '{print $3}')"
	# shellcheck disable=SC1090
	source "$case_file"
	after="$(declare -F | awk '{print $3}')"
	for fn in $(comm -13 <(LC_ALL=C sort <<<"$before") <(LC_ALL=C sort <<<"$after")); do
		case "$fn" in
			test_*)
				# Fresh server per test: avoids nickname/channel collisions and
				# disconnect-timing races between unrelated test functions.
				: >"$SCRATCH/server.log"
				start_server
				"$fn"
				stop_server
				;;
		esac
		unset -f "$fn"
	done
done

echo
echo "== Summary: $PASS_COUNT passed, $FAIL_COUNT failed =="
exit $((FAIL_COUNT > 0))
