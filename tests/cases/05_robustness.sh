# Robustness: partial/split packets, batched commands, unknown commands,
# and staying alive through garbage input.

test_split_packet_registration() {
	local c
	irc_open c
	irc_raw "$c" "PA"
	sleep 0.2
	irc_raw "$c" "SS $PASSWORD"$'\r\n'"NI"
	sleep 0.2
	irc_raw "$c" "CK splitty"$'\r\n'
	irc_raw "$c" "USER splitty 0 * :Split"$'\r\n'
	assert_reply "registration works across split packets" "$c" '(^|[[:space:]])001[[:space:]]'
	irc_close "$c"
}

test_batched_commands_single_write() {
	local c
	irc_open c
	irc_raw "$c" "PASS $PASSWORD"$'\r\n'"NICK batch"$'\r\n'"USER batch 0 * :Batch"$'\r\n'
	assert_reply "three commands in one write are all processed" "$c" '(^|[[:space:]])001[[:space:]]'
	irc_close "$c"
}

test_unknown_command() {
	local c
	register_client c curious || return
	irc_send "$c" "FLURB #nope"
	assert_reply "unknown command gets 421" "$c" '(^|[[:space:]])421[[:space:]]'
	irc_close "$c"
}

test_survives_garbage() {
	local c1 c2
	irc_open c1
	irc_raw "$c1" $'\r\n'
	irc_raw "$c1" "   "$'\r\n'
	irc_send "$c1" "PASS"
	irc_close "$c1"
	# server must still accept and serve a fresh client afterwards
	register_client c2 phoenix || { _report 1 "server survives garbage input"; return; }
	_report 0 "server survives garbage input"
	irc_close "$c2"
}

test_quit_disconnects() {
	local a b
	register_client a alice || return
	register_client b bob || return
	irc_send "$a" "JOIN #farewell"
	expect "$a" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$b" "JOIN #farewell"
	expect "$b" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$a" "QUIT :gone"
	assert_reply "QUIT broadcast to shared channel" "$b" 'QUIT'
	irc_close "$a"
	irc_close "$b"
}
