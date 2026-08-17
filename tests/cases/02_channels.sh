# Channels: JOIN, NAMES replies, PRIVMSG delivery, PART, error numerics.

test_join_replies() {
	local a
	register_client a alice || return
	irc_send "$a" "JOIN #room"
	assert_reply "JOIN echoes JOIN message" "$a" 'JOIN #room'
	assert_reply "JOIN sends 353 names list" "$a" '(^|[[:space:]])353[[:space:]]'
	assert_reply "JOIN sends 366 end of names" "$a" '(^|[[:space:]])366[[:space:]]'
	irc_close "$a"
}

test_privmsg_channel_delivery() {
	local a b
	register_client a alice || return
	register_client b bob || return
	irc_send "$a" "JOIN #chat"
	expect "$a" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$b" "JOIN #chat"
	expect "$b" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$a" "PRIVMSG #chat :hello bob"
	assert_reply "channel PRIVMSG delivered to other member" "$b" 'alice.*PRIVMSG #chat :hello bob'
	irc_close "$a"
	irc_close "$b"
}

test_privmsg_direct() {
	local a b
	register_client a alice || return
	register_client b bob || return
	irc_send "$a" "PRIVMSG bob :psst"
	assert_reply "direct PRIVMSG delivered to nick" "$b" 'alice.*PRIVMSG bob :psst'
	irc_close "$a"
	irc_close "$b"
}

test_privmsg_no_such_nick() {
	local a
	register_client a alice || return
	irc_send "$a" "PRIVMSG ghost :anyone?"
	assert_reply "PRIVMSG to unknown nick gets 401" "$a" '(^|[[:space:]])401[[:space:]]'
	irc_close "$a"
}

test_privmsg_no_text() {
	local a
	register_client a alice || return
	irc_send "$a" "PRIVMSG bob"
	assert_reply "PRIVMSG without text gets 412" "$a" '(^|[[:space:]])412[[:space:]]'
	irc_close "$a"
}

test_join_bad_channel_name() {
	local a
	register_client a alice || return
	irc_send "$a" "JOIN badname"
	assert_reply "JOIN without # gets 403" "$a" '(^|[[:space:]])403[[:space:]]'
	irc_close "$a"
}

test_part_channel() {
	local a b
	register_client a alice || return
	register_client b bob || return
	irc_send "$a" "JOIN #leave"
	expect "$a" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$b" "JOIN #leave"
	expect "$b" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$a" "PART #leave :bye"
	assert_reply "PART broadcast to channel members" "$b" 'alice.*PART #leave'
	irc_close "$a"
	irc_close "$b"
}

test_part_not_on_channel() {
	local a b
	register_client a alice || return
	register_client b bob || return
	irc_send "$a" "JOIN #private"
	expect "$a" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$b" "PART #private"
	assert_reply "PART when not on channel gets 442" "$b" '(^|[[:space:]])442[[:space:]]'
	irc_close "$a"
	irc_close "$b"
}
