# Operator commands: TOPIC, INVITE, KICK, and non-operator rejections.
# The channel creator is the operator.

test_topic_set_and_query() {
	local a b
	register_client a opa || return
	register_client b userb || return
	irc_send "$a" "JOIN #topictest"
	expect "$a" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$b" "JOIN #topictest"
	expect "$b" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$a" "TOPIC #topictest :today: testing"
	assert_reply "TOPIC change broadcast to members" "$b" 'TOPIC #topictest'
	irc_send "$b" "TOPIC #topictest"
	assert_reply "TOPIC query returns 332" "$b" '(^|[[:space:]])332[[:space:]]'
	irc_close "$a"
	irc_close "$b"
}

test_topic_no_topic_set() {
	local a
	register_client a opa || return
	irc_send "$a" "JOIN #blank"
	expect "$a" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$a" "TOPIC #blank"
	assert_reply "TOPIC query on fresh channel returns 331" "$a" '(^|[[:space:]])331[[:space:]]'
	irc_close "$a"
}

test_invite() {
	local a c
	register_client a opa || return
	register_client c invitee || return
	irc_send "$a" "JOIN #vip"
	expect "$a" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$a" "INVITE invitee #vip"
	assert_reply "inviter gets 341 confirmation" "$a" '(^|[[:space:]])341[[:space:]]'
	assert_reply "invitee receives INVITE" "$c" 'INVITE invitee'
	irc_close "$a"
	irc_close "$c"
}

test_kick() {
	local a b
	register_client a opa || return
	register_client b victim || return
	irc_send "$a" "JOIN #kicktest"
	expect "$a" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$b" "JOIN #kicktest"
	expect "$b" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$a" "KICK #kicktest victim :out"
	assert_reply "kicked client sees KICK message" "$b" 'KICK #kicktest victim'
	irc_close "$a"
	irc_close "$b"
}

test_kick_not_operator() {
	local a b
	register_client a opa || return
	register_client b peon || return
	irc_send "$a" "JOIN #fort"
	expect "$a" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$b" "JOIN #fort"
	expect "$b" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$b" "KICK #fort opa :coup"
	assert_reply "non-operator KICK rejected (482)" "$b" '(^|[[:space:]])482[[:space:]]'
	irc_close "$a"
	irc_close "$b"
}

test_mode_not_operator() {
	local a b
	register_client a opa || return
	register_client b peon || return
	irc_send "$a" "JOIN #locked"
	expect "$a" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$b" "JOIN #locked"
	expect "$b" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$b" "MODE #locked +i"
	assert_reply "non-operator MODE rejected (482)" "$b" '(^|[[:space:]])482[[:space:]]'
	irc_close "$a"
	irc_close "$b"
}
