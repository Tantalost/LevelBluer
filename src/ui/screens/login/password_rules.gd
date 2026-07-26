class_name PasswordRules
extends RefCounted
## Validation for the Security Alert password-change modal, kept out of the UI
## so it can be unit tested and reused.
##
## This is a UX aid, not a security control. Supabase enforces its own policy
## server-side, and it has to — anyone can decompile the APK and call the auth
## endpoint directly, skipping this file entirely. Given what Level Blue is
## teaching, that distinction is worth being precise about.

const MIN_LENGTH: int = 8

const RULE_LENGTH: StringName = &"length"
const RULE_UPPERCASE: StringName = &"uppercase"
const RULE_LOWERCASE: StringName = &"lowercase"
const RULE_NUMBER: StringName = &"number"
const RULE_SPECIAL: StringName = &"special"

## Display order for the checklist. Keep the UI driven by this array rather
## than five hardcoded rows, so adding a rule later is a one-line change.
const RULE_ORDER: Array[StringName] = [
	RULE_LENGTH,
	RULE_UPPERCASE,
	RULE_LOWERCASE,
	RULE_NUMBER,
	RULE_SPECIAL,
]

## Translation keys, not literal strings — these have to render in Tagalog too.
const RULE_KEYS: Dictionary = {
	RULE_LENGTH: "PWD_RULE_LENGTH",
	RULE_UPPERCASE: "PWD_RULE_UPPERCASE",
	RULE_LOWERCASE: "PWD_RULE_LOWERCASE",
	RULE_NUMBER: "PWD_RULE_NUMBER",
	RULE_SPECIAL: "PWD_RULE_SPECIAL",
}


## Returns {rule_name: bool} for every rule. Call this from LineEdit's
## text_changed signal — it is a single pass over the string and costs nothing
## at typing speed.
static func evaluate(password: String) -> Dictionary:
	var has_upper := false
	var has_lower := false
	var has_digit := false
	var has_special := false

	for i in password.length():
		var code := password.unicode_at(i)
		if code >= 65 and code <= 90:
			has_upper = true
		elif code >= 97 and code <= 122:
			has_lower = true
		elif code >= 48 and code <= 57:
			has_digit = true
		elif code > 32:
			# Any printable non-alphanumeric character counts. Spaces are
			# excluded on purpose: a trailing space is nearly always a typo,
			# and satisfying "one special character" with an invisible one
			# leads to a login that fails for no visible reason.
			has_special = true

	return {
		RULE_LENGTH: password.length() >= MIN_LENGTH,
		RULE_UPPERCASE: has_upper,
		RULE_LOWERCASE: has_lower,
		RULE_NUMBER: has_digit,
		RULE_SPECIAL: has_special,
	}


static func all_satisfied(results: Dictionary) -> bool:
	for passed in results.values():
		if not passed:
			return false
	return true


## The confirm field is a separate concern from strength — surface it as its
## own message near the confirm box, not as a sixth checklist item, or players
## read "5 of 6" and go hunting for a missing character class.
static func confirmation_matches(password: String, confirmation: String) -> bool:
	return not password.is_empty() and password == confirmation


## Convenience for enabling the submit button.
static func is_acceptable(password: String, confirmation: String) -> bool:
	return all_satisfied(evaluate(password)) \
		and confirmation_matches(password, confirmation)
