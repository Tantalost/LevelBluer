extends RefCounted
## Returns to the intro's morning. Investigation is reconstruction, not a later night.
const ID: String = "mod_01_ch_04"
const NUMBER: int = 4
const TITLE: String = "The Prize"
const MORNING: bool = true
const BACKGROUND_ASSET: String = "opening_john_room_wake_v1"
const CLAIM_ASSET: String = "opening_john_claim_prize_v1"
const EPILOGUE_PHONE: bool = true
const NIGHT_BACKGROUND: String = "intro_morning"
const BASE_REWARD: int = 100
const CLEAN_BONUS: int = 25
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const FIRST_PHASE: String = "timeline"
const TASKS: Dictionary = {
	"timeline":{"title":"01 / Reconstruct the morning", "tip":"Place all four records from earliest to latest. Read the timestamps, not the order of the cards.", "line":"Pause the moment. Reconstruct what happened.", "field":"timeline_checked", "total":1, "next":"board"},
	"board":{"title":"02 / Connect the pattern", "tip":"Connect coffee to the group message, the repeated typo to the earlier email, and the ten-second gap to the matching last seen.", "line":"A connection is not the same as a confession.", "field":"connections", "total":3, "next":"case_note"},
	"case_note":{"title":"03 / Record the gap", "tip":"1. Count the minutes: 08:12 → 08:13 → 08:14. That is 2 minutes. Type 2 in the first box, not 08:14.\n2. The earlier event was the survey confirmation reply. Type survey confirmation reply in the second box.", "line":"Write what the records show. Not who I suspect.", "field":"notes", "total":1, "next":"seal"}
}
const TIMELINE: Array[Dictionary] = [
	{"id":"survey","time":"08:12:00","label":"Survey confirmation reply received"},
	{"id":"eric","time":"08:13:45","label":"Eric · recorded last seen"},
	{"id":"jobert","time":"08:13:50","label":"Jobert · recorded last seen"},
	{"id":"prize","time":"08:14:00","label":"Prize email received"}
]
const ORDER: Array[String] = ["survey","eric","jobert","prize"]
const PINS: Array[Dictionary] = [
	{"id":"coffee","text":"PRIZE EMAIL\nStill missing your coffee, John?"},
	{"id":"group","text":"CH1 / GROUP CHAT\nI miss coffee. I need a side gig before my wallet gives up."},
	{"id":"typo","text":"PRIZE EMAIL\nTo recieve your prize…"},
	{"id":"earlier","text":"CH1 / SURVEY EMAIL\nTo recieve your reward…"},
	{"id":"time","text":"EMAIL / 08:14:00\nMatch the ten-second gap"},
	{"id":"jobert","text":"JOBERT / LAST SEEN\n08:13:50 · now offline"},
	{"id":"amount","text":"PRIZE AMOUNT\n₱1,000,000"},
	{"id":"eric","text":"ERIC / LAST SEEN\n08:13:45 · now offline"}
]
const PAIRS: Dictionary = {
	"coffee|group":"The coffee comment was visible to everyone in the group. It does not identify the sender.",
	"earlier|typo":"Both emails use 'recieve'. Repeated wording may connect messages, but a common typo does not prove authorship.",
	"jobert|time":"The email arrived 10 seconds after Jobert's recorded last seen. Eric's gap is 15 seconds. Neither timestamp proves who sent it."
}
const EVIDENCE: String = "3 evidence bundles\n\n01 · The coffee reference repeats John's group message, visible to everyone\n02 · The prize email arrived 2 minutes after the survey confirmation and 10 seconds after Jobert's recorded last seen\n03 · 'Recieve' repeats the Chapter 1 survey email\n\nEric's last seen is also close: 15 seconds earlier. Presence status and a shared typo do not establish authorship."
const SEAL_LINE: String = "These records connect the messages.\nThey do not tell me who was behind the screen.\nSave the exhibit before returning to that morning."
const SLEEP_LINE: String = "Back to that morning.\nJobert would know what to do.\nHe still hasn't replied.\nI just need something to go right today."
const END_CAPTION: String = "This time, nobody called.\nTo be continued in Chapter 5."
const MESSAGES: Array[Dictionary] = [{"id":"prize","sender":"Prize Desk","address":"awards@prize-claim.example","subject":"You won ₱1,000,000","body":"Congratulations, John!\n\nYour address was selected for ₱1,000,000.\nStill missing your coffee, John?\n\nClaim within 10 minutes.\nFollow the link and confirm your account password to recieve your prize.","phrase":"Claim within 10 minutes. Confirm your account password.","suspicious":true}]
const CHAT_MESSAGES: Array[Dictionary] = []
const PRIVATE_CHAT: Array[Dictionary] = [
	{"who":"John","face":2,"text":"Is this legit?"},
	{"who":"John","face":4,"text":"It mentions what I said about coffee."},
	{"who":"John","face":2,"text":"Jobert?"}
]
const STORY: Array[Dictionary] = [
	{"who":"John","face":2,"bg":"intro_morning","caption":"That morning.\nThe room. The message. The button.","line":"Five more minutes.\nPlease."},
	{"who":"John","face":2,"bg":"intro_morning","art":"opening_john_reaching_phone_v1","line":"No payout.\nNo breakfast.\nEven my phone has more energy than me.","mail":true,"event":"notification"},
	{"who":"John","face":1,"bg":"intro_morning","line":"A million pesos?\nOkay. I'm awake.","mail":true,"event":"email"},
	{"who":"John","face":4,"bg":"intro_morning","line":"Still missing my coffee?\nThat's unfairly specific.\nWait.\nHow do they know about the coffee?"},
	{"who":"John","face":2,"bg":"intro_morning","line":"Jobert will know.","chat":true,"messages":PRIVATE_CHAT,"contact":"Jobert"},
	{"who":"John","face":2,"bg":"intro_morning","line":"Offline.\nYou picked a really bad time to disappear."},
	{"who":"John","face":4,"bg":"intro_morning","line":"Right. I did say it here.\nEveryone could see it.\nBut that doesn't explain who copied it.","mail":true,"event":"coffee"},
	{"who":"John","face":4,"bg":"intro_morning","line":"Recieve.\nAgain.\nAnd these times…\nHold on."},
	{"who":"John","face":4,"bg":"intro_morning","caption":"Before the tap.\nPause the memory. Follow the records.","line":"The morning hasn't moved on.\nWe're reconstructing the evidence."}
]

static func fresh() -> Dictionary:
	return {"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"timeline_order":["","","",""],"timeline_checked":[],"connections":[],"wrong_pairs":[],"notes":[],"minutes_draft":"","event_draft":"","mistakes":0,"hint_used":false,"sealed":false,"claimed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{}}

static func message(id: String) -> Dictionary:
	return MESSAGES[0] if id == "prize" else {}

static func suspicious_ids() -> Array[String]:
	return ["prize"]

static func pair_key(a: String, b: String) -> String:
	var values: Array[String] = [a,b]
	values.sort()
	return "|".join(values)

static func note_matches(minutes: String, event: String) -> bool:
	var normalized: String = " ".join(event.strip_edges().to_lower().replace("-", " ").replace(".", "").split(" ", false))
	return minutes.strip_edges().to_lower() in ["2","two","2 minutes","two minutes"] and normalized in ["survey","survey reply","survey confirmation","survey confirmation reply","survey confirmation reply received","the survey reply","the survey confirmation","the survey confirmation reply"]

static func complete_evidence(state: Dictionary) -> bool:
	return state.get("timeline_checked", []).has("prize") and state.get("connections", []).size() == 3 and state.get("notes", []).has("prize")

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	for field: String in ["read","captures","timeline_checked","connections","notes","wrong_pairs"]:
		var values: Variant = raw.get(field, [])
		if values is Array:
			for value: Variant in values:
				var valid: bool = value == "prize" if field not in ["connections","wrong_pairs"] else PAIRS.has(value)
				if field == "wrong_pairs" and value is String:
					var parts: PackedStringArray = value.split("|")
					valid = parts.size() == 2 and parts[0] != parts[1] and parts[0] in ["coffee","group","typo","earlier","time","jobert","amount","eric"] and parts[1] in ["coffee","group","typo","earlier","time","jobert","amount","eric"] and not PAIRS.has(value)
				if valid and not state[field].has(value): state[field].append(value)
	var order: Variant = raw.get("timeline_order", [])
	if order is Array and order.size() == 4:
		for index: int in 4:
			if order[index] in ORDER and not state.timeline_order.has(order[index]): state.timeline_order[index] = order[index]
	if state.timeline_order != ORDER: state.timeline_checked = []
	for field: String in ["beat","mistakes"]:
		var value: Variant = raw.get(field, 0)
		if (value is int or value is float) and is_finite(float(value)): state[field] = clampi(int(value), 0, STORY.size() - 1 if field == "beat" else 9999)
	state.mistakes = maxi(state.mistakes, state.wrong_pairs.size())
	state.minutes_draft = str(raw.get("minutes_draft", "")).left(32)
	state.event_draft = str(raw.get("event_draft", "")).left(100)
	if not note_matches(state.minutes_draft, state.event_draft): state.notes = []
	state.hint_used = raw.get("hint_used", false) == true
	state.perk_run = Perks.clean_run(raw.get("perk_run", {}))
	if state.perk_run.get("chapter", ID) != ID: state.perk_run = {}
	var phase: String = str(raw.get("phase", "day"))
	if phase in ["day","timeline","board","case_note","seal","sleep","closing","done"]: state.phase = phase
	if state.phase in ["board","case_note","seal","sleep","closing","done"] and state.timeline_checked.is_empty(): state.phase = "timeline"
	if state.phase in ["case_note","seal","sleep","closing","done"] and state.connections.size() < 3: state.phase = "board"
	if state.phase in ["seal","sleep","closing","done"] and not complete_evidence(state): state.phase = "case_note"
	state.sealed = raw.get("sealed", false) == true and complete_evidence(state)
	state.claimed = raw.get("claimed", false) == true and state.sealed
	state.completed = raw.get("completed", false) == true and state.claimed
	if state.completed:
		state.phase = "done"
		state.next_chapter_unlocked = true
		state.reward = BASE_REWARD + (CLEAN_BONUS if Perks.status(state.perk_run, state.hint_used) != "assisted" and state.mistakes == 0 else 0)
	elif state.phase in ["sleep","closing","done"] and not state.sealed: state.phase = "seal"
	elif state.phase in ["closing","done"] and not state.claimed: state.phase = "sleep"
	return state
