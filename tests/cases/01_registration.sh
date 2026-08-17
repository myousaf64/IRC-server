# Registration: PASS/NICK/USER flow and its error paths.

test_welcome_001() {
	local c
	irc_open c
	irc_send "$c" "PASS $PASSWORD"
	irc_send "$c" "NICK alice"
	irc_send "$c" "USER alice 0 * :Alice"
	assert_reply "full registration gets 001 welcome" "$c" '(^|[[:space:]])001[[:space:]].*Welcome'
	irc_close "$c"
}

test_wrong_password() {
	local c
	irc_open c
	irc_send "$c" "PASS wrongpass"
	assert_reply "wrong PASS gets 464" "$c" '(^|[[:space:]])464[[:space:]]'
	irc_close "$c"
}

test_pass_after_registered() {
	local c
	register_client c bob || return
	irc_send "$c" "PASS $PASSWORD"
	assert_reply "re-PASS after register gets 462" "$c" '(^|[[:space:]])462[[:space:]]'
	irc_close "$c"
}

test_nick_collision() {
	local c1 c2
	register_client c1 carol || return
	irc_open c2
	irc_send "$c2" "PASS $PASSWORD"
	irc_send "$c2" "NICK carol"
	assert_reply "duplicate NICK gets 433" "$c2" '(^|[[:space:]])433[[:space:]]'
	irc_close "$c1"
	irc_close "$c2"
}

test_erroneous_nick() {
	local c
	irc_open c
	irc_send "$c" "PASS $PASSWORD"
	irc_send "$c" "NICK #bad"
	assert_reply "invalid NICK gets 432" "$c" '(^|[[:space:]])432[[:space:]]'
	irc_close "$c"
}

test_empty_nick() {
	local c
	irc_open c
	irc_send "$c" "PASS $PASSWORD"
	irc_send "$c" "NICK"
	assert_reply "NICK without argument gets 461" "$c" '(^|[[:space:]])461[[:space:]]'
	irc_close "$c"
}

test_command_before_registration() {
	local c
	irc_open c
	irc_send "$c" "JOIN #test"
	assert_reply "JOIN before registering gets 451" "$c" '(^|[[:space:]])451[[:space:]]'
	irc_close "$c"
}
