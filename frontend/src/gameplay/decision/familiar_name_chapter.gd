extends RefCounted
## Coached story activity; completion is not a BKT mastery observation.
const ID: String = "mod_02_ch_03"
const NUMBER: int = 3
const TITLE: String = "The Familiar Name"
const PROTAGONIST: String = "Amani"
const PHONE_PATH: String = "res://src/gameplay/decision/familiar_name_phone.gd"
const BACKGROUND_ASSET: String = "story_bg_club_corridor_afternoon"
const NIGHT_BACKGROUND: String = "club_corridor_afternoon"
const MORNING: bool = true
const DAY_LABEL: String = "AFTERNOON"
const FULL_WIDTH_INVESTIGATION: bool = true
const INVESTIGATION_TAGLINE: String = "A familiar face does not verify a sender."
const FIRST_PHASE: String = "sources"
const NEXT_CHAPTER: String = "mod_02_ch_04"
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const TASKS: Dictionary = {
 "sources":{"title":"01 / Match the copied details", "tip":"Compare the profile photo and delivery detail with the public event post. Both were visible publicly.", "line":"Which details were already public?", "field":"flags", "total":1, "next":"contact"},
 "contact":{"title":"02 / Compare the contacts", "tip":"The new-number message is a separate contact. Open the conversation used before this request.", "line":"Same name. Is it the same conversation?", "field":"domains", "total":1, "next":"verify"},
 "verify":{"title":"03 / Facts before assumptions", "tip":"Signal loss does not establish its cause. Verify through the established chat and warn the club there.", "line":"What do we know, and what are we only guessing?", "field":"captures", "total":1, "next":"seal"}
}
const REQUEST: String = "It's Amani. New number for today. Club parcel is stuck—pay the small fee here and I'll return it."
const WARNING: String = "That new-number payment message isn't mine. Check with me here before sending anything."
const CHAT_MESSAGES: Array[Dictionary] = []
const MESSAGES: Array[Dictionary] = [{"id":"identity","sender":"Amani · New number","address":"Unfamiliar contact","subject":"Copied identity / payment request","body":REQUEST,"phrase":REQUEST,"suspicious":true}]
const STORY: Array[Dictionary] = [
 {"who":"John","face":4,"bg":"club_corridor_afternoon","cast":["amani","john"],"caption":"Outside the clubroom. Later that afternoon.","line":"Did you tell Dan the parcel needs another payment?"},
 {"who":"Amani","face":1,"bg":"club_corridor_afternoon","cast":["amani","john"],"line":"I told Dan to find tape. That's the only transaction I've authorized."},
 {"who":"John","face":4,"bg":"club_corridor_afternoon","cast":["amani","john"],"line":"He forwarded this to me.","mail":true},
 {"who":"Amani","face":3,"bg":"club_corridor_afternoon","cast":["amani","john"],"line":"That's my photo. And my phone has no signal. Did they get into it?"},
 {"who":"John","face":0,"bg":"club_corridor_afternoon","cast":["amani","john"],"line":"Let's check what we actually know before we decide that."},
 {"who":"Amani","face":4,"bg":"club_corridor_afternoon","cast":["amani"],"line":"School Wi-Fi connected. My usual chat still opens. Let's compare it with that new contact."},
 {"who":"Dan · Off-screen","face":0,"bg":"club_corridor_afternoon","cast":["amani"],"line":"I knew the delivery was today too. I posted the reminder."},
 {"who":"Amani","face":1,"bg":"club_corridor_afternoon","cast":["amani"],"line":"So knowing the delivery day isn't exactly a secret handshake."},
 {"who":"John","face":0,"bg":"club_corridor_afternoon","cast":["amani","john"],"line":"And a copied name doesn't tell us who is behind the account."}
]
const EVIDENCE: String = "01 · The photo and delivery detail were visible in the public event post.\n02 · The payment request comes from a different contact, not Amani's established conversation.\n03 · Amani denies the request and warns the club through its established chat over Wi-Fi.\n\nThe loss of cellular signal is observed; its cause is unknown. Neither that observation nor Dan's knowledge identifies the sender."
const SEAL_LINE: String = "They copied my name. That doesn't make the request mine."
const SLEEP_LINE: String = "The warning is in our usual club chat. Nobody needs to pay that new contact.\n\nMy cellular signal is still missing. I have a problem to check, not a culprit to guess."
const END_CAPTION: String = ""

static func fresh() -> Dictionary:
	return {"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"mistakes":0,"hint_used":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{}}

static func message(id: String) -> Dictionary:
	return MESSAGES[0] if id == "identity" else {}

static func suspicious_ids() -> Array[String]:
	return ["identity"]

static func complete_evidence(state: Dictionary) -> bool:
	for field: String in ["read","flags","domains","captures"]:
		if not (state.get(field, []) as Array).has("identity"): return false
	return true

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	# Findings form a prerequisite chain; malformed saves cannot skip an activity.
	var preceding: bool = true
	for field: String in ["read","flags","domains","captures"]:
		var values: Variant = raw.get(field, [])
		if field == "flags":
			var matches: Variant = raw.get("sorted", [])
			preceding = preceding and matches is Array and matches.has("photo") and matches.has("schedule")
		if field == "captures":
			var matches: Variant = raw.get("sorted", [])
			preceding = preceding and matches is Array and matches.has("facts")
		preceding = preceding and values is Array and values.has("identity")
		if preceding: state[field] = ["identity"]
	for field: String in ["beat","mistakes"]:
		var value: Variant = raw.get(field, 0)
		if (value is int or value is float) and is_finite(float(value)):
			state[field] = clampi(int(value), 0, STORY.size() - 1 if field == "beat" else 9999)
	var saved_matches: Variant = raw.get("sorted", [])
	if saved_matches is Array and not state.read.is_empty():
		for item: String in ["photo","schedule","facts"]:
			if saved_matches.has(item) and (item != "facts" or not state.domains.is_empty()): state.sorted.append(item)
	state.hint_used = raw.get("hint_used", false) == true
	state.perk_run = Perks.clean_run(raw.get("perk_run", {}))
	if state.perk_run.get("chapter", ID) != ID: state.perk_run = {}
	var phase: String = str(raw.get("phase", "day"))
	if phase in ["day","sources","contact","verify","seal","sleep","done"]: state.phase = phase
	if state.phase != "day" and state.read.is_empty(): state.phase = "day"
	if state.phase in ["contact","verify","seal","sleep","done"] and state.flags.is_empty(): state.phase = "sources"
	if state.phase in ["verify","seal","sleep","done"] and state.domains.is_empty(): state.phase = "contact"
	if state.phase in ["seal","sleep","done"] and state.captures.is_empty(): state.phase = "verify"
	state.sealed = raw.get("sealed", false) == true and complete_evidence(state)
	state.completed = raw.get("completed", false) == true and state.sealed
	if state.completed:
		state.phase = "done"
		state.reward = 100 + (25 if state.mistakes == 0 and Perks.status(state.perk_run, state.hint_used) != "assisted" else 0)
	elif state.phase == "done": state.phase = "seal"
	return state
