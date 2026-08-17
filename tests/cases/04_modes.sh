# Channel modes: i, t, k, o, l — plus mode error numerics.

test_mode_invite_only() {
	local a c
	register_client a opa || return
	register_client c outsider || return
	irc_send "$a" "JOIN #invonly"
	expect "$a" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$a" "MODE #invonly +i"
	expect "$a" 'MODE #invonly.*\+i' || true
	irc_send "$c" "JOIN #invonly"
	assert_reply "JOIN on +i channel rejected (473)" "$c" '(^|[[:space:]])473[[:space:]]'
	irc_close "$a"
	irc_close "$c"
}

test_mode_invite_then_join() {
	local a c
	register_client a opa || return
	register_client c guest || return
	irc_send "$a" "JOIN #gated"
	expect "$a" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$a" "MODE #gated +i"
	expect "$a" 'MODE #gated.*\+i' || true
	irc_send "$a" "INVITE guest #gated"
	expect "$c" 'INVITE guest' || true
	irc_send "$c" "JOIN #gated"
	assert_reply "invited client can join +i channel" "$c" '(^|[[:space:]])366[[:space:]]'
	irc_close "$a"
	irc_close "$c"
}

test_mode_key() {
	local a c
	register_client a opa || return
	register_client c guest || return
	irc_send "$a" "JOIN #keyed"
	expect "$a" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$a" "MODE #keyed +k sekret"
	expect "$a" 'MODE #keyed.*\+k' || true
	irc_send "$c" "JOIN #keyed wrongkey"
	assert_reply "JOIN with bad key rejected (475)" "$c" '(^|[[:space:]])475[[:space:]]'
	irc_send "$c" "JOIN #keyed sekret"
	assert_reply "JOIN with correct key succeeds" "$c" '(^|[[:space:]])366[[:space:]]'
	irc_close "$a"
	irc_close "$c"
}

test_mode_limit() {
	local a c
	register_client a opa || return
	register_client c late || return
	irc_send "$a" "JOIN #tiny"
	expect "$a" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$a" "MODE #tiny +l 1"
	expect "$a" 'MODE #tiny.*\+l' || true
	irc_send "$c" "JOIN #tiny"
	assert_reply "JOIN over +l limit rejected (471)" "$c" '(^|[[:space:]])471[[:space:]]'
	irc_close "$a"
	irc_close "$c"
}

test_mode_op_grant() {
	local a b
	register_client a opa || return
	register_client b newop || return
	irc_send "$a" "JOIN #promote"
	expect "$a" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$b" "JOIN #promote"
	expect "$b" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$a" "MODE #promote +o newop"
	assert_reply "+o broadcast to channel" "$b" 'MODE #promote.*\+o'
	irc_send "$b" "MODE #promote +t"
	assert_reply "newly opped client can set modes" "$b" 'MODE #promote.*\+t'
	irc_close "$a"
	irc_close "$b"
}

test_mode_missing_param() {
	local a
	register_client a opa || return
	irc_send "$a" "JOIN #needsarg"
	expect "$a" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$a" "MODE #needsarg +k"
	assert_reply "MODE +k without key gets 696" "$a" '(^|[[:space:]])696[[:space:]]'
	irc_close "$a"
}

test_mode_unknown_flag() {
	local a
	register_client a opa || return
	irc_send "$a" "JOIN #modes"
	expect "$a" '(^|[[:space:]])366[[:space:]]' || true
	irc_send "$a" "MODE #modes +z"
	assert_reply "unknown mode flag gets 472" "$a" '(^|[[:space:]])472[[:space:]]'
	irc_close "$a"
}
