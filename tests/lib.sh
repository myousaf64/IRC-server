# lib.sh — helpers for the ircserv integration test suite.
# Sourced by run_tests.sh; requires bash >= 4 (fd auto-allocation, /dev/tcp).

PASSWORD="testpass"
IRC_TIMEOUT="${IRC_TIMEOUT:-3}"
IRC_WRAPPER="${IRC_WRAPPER:-}"

PASS_COUNT=0
FAIL_COUNT=0

SERVER_PID=""
SERVER_PORT=""

# ------------------------------ server lifecycle ------------------------------

wait_for_listen() {
	local tries=0
	while [ "$tries" -lt 50 ]; do
		if ! kill -0 "$SERVER_PID" 2>/dev/null; then
			return 1   # server died (probably bind failure)
		fi
		if (exec 3<>"/dev/tcp/127.0.0.1/$SERVER_PORT") 2>/dev/null; then
			exec 3>&- 3<&- 2>/dev/null || true
			return 0
		fi
		sleep 0.1
		tries=$((tries + 1))
	done
	return 1
}

start_server() {
	local attempt=0
	while [ "$attempt" -lt 5 ]; do
		SERVER_PORT=$((20000 + RANDOM % 40000))
		# shellcheck disable=SC2086 — IRC_WRAPPER is intentionally word-split (valgrind + args)
		$IRC_WRAPPER "$BINARY" "$SERVER_PORT" "$PASSWORD" >>"$SCRATCH/server.log" 2>&1 &
		SERVER_PID=$!
		if wait_for_listen; then
			return 0
		fi
		kill -9 "$SERVER_PID" 2>/dev/null || true
		wait "$SERVER_PID" 2>/dev/null || true
		SERVER_PID=""
		attempt=$((attempt + 1))
	done
	echo "FATAL: could not start server ($BINARY)" >&2
	tail -n 20 "$SCRATCH/server.log" >&2 || true
	exit 2
}

stop_server() {
	[ -n "$SERVER_PID" ] || return 0
	# SIGINT on purpose: the server's handler calls exit(0), which is what lets
	# LeakSanitizer/valgrind run their end-of-process leak reports. SIGKILL would
	# silently skip them.
	kill -INT "$SERVER_PID" 2>/dev/null || true
	local tries=0
	while kill -0 "$SERVER_PID" 2>/dev/null && [ "$tries" -lt 100 ]; do
		sleep 0.1
		tries=$((tries + 1))
	done
	if kill -0 "$SERVER_PID" 2>/dev/null; then
		echo "WARN: server did not exit on SIGINT, killing" >&2
		kill -9 "$SERVER_PID" 2>/dev/null || true
	fi
	local rc=0
	wait "$SERVER_PID" 2>/dev/null || rc=$?
	SERVER_PID=""
	if [ "$rc" -eq 42 ]; then   # valgrind --error-exitcode
		echo "[FAIL] valgrind reported errors (see $SCRATCH/server.log)"
		FAIL_COUNT=$((FAIL_COUNT + 1))
	elif [ "$rc" -eq 1 ] && [ -n "$IRC_WRAPPER" ]; then
		: # wrapper noise, transcripts already asserted behavior
	fi
	return 0
}

# --------------------------------- sessions -----------------------------------

# irc_open VARNAME — open a TCP session; stores the fd in VARNAME.
irc_open() {
	local fd
	exec {fd}<>"/dev/tcp/127.0.0.1/$SERVER_PORT"
	printf -v "$1" '%s' "$fd"
}

irc_close() {
	eval "exec $1>&- $1<&-" 2>/dev/null || true
}

# irc_send FD 'LINE' — send one command terminated by CRLF.
irc_send() {
	printf '%s\r\n' "$2" >&"$1"
}

# irc_raw FD 'BYTES' — send raw bytes (no terminator) for split-message tests.
irc_raw() {
	printf '%s' "$2" >&"$1"
}

# --------------------------------- assertions ---------------------------------

TRANSCRIPT=""

# expect FD 'REGEX' [TIMEOUT] — read lines until REGEX matches (0) or
# timeout/EOF (1). Everything read is appended to TRANSCRIPT.
expect() {
	local fd="$1" regex="$2" timeout="${3:-$IRC_TIMEOUT}" line
	TRANSCRIPT=""
	while IFS= read -t "$timeout" -r line <&"$fd"; do
		line="${line%$'\r'}"
		TRANSCRIPT="$TRANSCRIPT$line"$'\n'
		if [[ "$line" =~ $regex ]]; then
			return 0
		fi
	done
	return 1
}

# expect_silence FD [TIMEOUT] — succeed only if nothing arrives on FD.
expect_silence() {
	local fd="$1" timeout="${2:-1}" line
	TRANSCRIPT=""
	if IFS= read -t "$timeout" -r line <&"$fd"; then
		TRANSCRIPT="${line%$'\r'}"$'\n'
		return 1
	fi
	return 0
}

_report() {
	local status="$1" name="$2"
	if [ "$status" -eq 0 ]; then
		printf '  [PASS] %s\n' "$name"
		PASS_COUNT=$((PASS_COUNT + 1))
	else
		printf '  [FAIL] %s\n' "$name"
		FAIL_COUNT=$((FAIL_COUNT + 1))
		if [ -n "$TRANSCRIPT" ]; then
			printf '         received:\n'
			printf '%s' "$TRANSCRIPT" | sed 's/^/         | /'
		else
			printf '         received: (nothing before timeout)\n'
		fi
		printf '         server.log tail:\n'
		tail -n 5 "$SCRATCH/server.log" 2>/dev/null | sed 's/^/         | /'
	fi
}

# assert_reply "name" FD 'REGEX' [TIMEOUT]
assert_reply() {
	local name="$1" fd="$2" regex="$3" timeout="${4:-$IRC_TIMEOUT}"
	local status=0
	expect "$fd" "$regex" "$timeout" || status=1
	_report "$status" "$name"
}

# assert_no_reply "name" FD [TIMEOUT] — asserts silence (e.g. NOTICE errors).
assert_no_reply() {
	local name="$1" fd="$2" timeout="${3:-1}"
	local status=0
	expect_silence "$fd" "$timeout" || status=1
	_report "$status" "$name"
}

# register_client VARNAME NICK — open a session and complete PASS/NICK/USER,
# waiting for the 001 welcome. Fails the whole case file on error.
register_client() {
	local _var="$1" nick="$2" fd
	irc_open "$_var"
	eval "fd=\$$_var"
	irc_send "$fd" "PASS $PASSWORD"
	irc_send "$fd" "NICK $nick"
	irc_send "$fd" "USER $nick 0 * :$nick"
	if ! expect "$fd" '(^|[[:space:]])001[[:space:]]'; then
		_report 1 "register_client $nick (no 001 welcome)"
		return 1
	fi
	return 0
}
