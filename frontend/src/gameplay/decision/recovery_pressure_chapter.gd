extends RefCounted
## Coached story activity; completion is not a BKT mastery observation.
const ID: String = "mod_02_ch_04"
const NUMBER: int = 4
const TITLE: String = "Last Chance"
const PROTAGONIST: String = "Amani"
const PHONE_PATH: String = "res://src/gameplay/decision/recovery_pressure_phone.gd"
const BACKGROUND_ASSET: String = "story_bg_event_room_day"
const NIGHT_BACKGROUND: String = "event_room_day"
const MORNING: bool = true
const DAY_LABEL: String = "AFTER CLASSES"
const FULL_WIDTH_INVESTIGATION: bool = true
const INVESTIGATION_TAGLINE: String = "Check who chooses the recovery route."
const FIRST_PHASE: String = "sequence"
const NEXT_CHAPTER: String = "mod_02_ch_05"
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const TASKS: Dictionary = {
 "sequence":{"title":"01 / Rebuild the message sequence", "tip":"Delivery request, genuine wallet code, copied identity, then recovery pressure. Tap events in that order.", "line":"Different stories. The same push to act.", "field":"flags", "total":1, "next":"route"},
 "route":{"title":"02 / Choose who verifies", "tip":"Open support through the service you already use. A number supplied by the warning cannot independently verify that warning.", "line":"Who chose the number I'm about to trust?", "field":"domains", "total":1, "next":"verify"},
 "verify":{"title":"03 / Keep the services separate", "tip":"The wallet issued the code. Read wallet support and independently opened carrier help, then attach the messages to the wallet case.", "line":"The wallet code cannot repair my mobile signal.", "field":"captures", "total":1, "next":"seal"}
}
const ORDER: Array[String] = ["delivery","code","identity","recovery"]
const EVENT_NAMES: Dictionary = {"delivery":"Delivery payment request","code":"Genuine wallet code","identity":"Copied-name payment message","recovery":"Recovery pressure"}
const REQUEST: String = "Your mobile account is at risk. Call our recovery desk now and give the verification code to restore access. Three minutes remaining."
const WALLET_REPLY: String = "Do not read the device authorization code to a caller. Your rejected device request is under review. Keep the case reference in this app."
const CARRIER_REPLY: String = "A wallet authorization code is not a mobile-service recovery code. We need to check the signal issue separately. No cause has been confirmed."
const CHAT_MESSAGES: Array[Dictionary] = []
const MESSAGES: Array[Dictionary] = [{"id":"recovery","sender":"Recovery Desk","address":"Unverified SMS sender","subject":"Recovery pressure / supplied contact","body":REQUEST,"phrase":"Use the number supplied in this warning and give the wallet code.","suspicious":true}]
const STORY: Array[Dictionary] = [
 {"who":"Amani","face":2,"bg":"event_room_day","cast":["amani"],"caption":"Back in the clubroom. After classes.","line":"Another text. This one says it can fix my signal.","mail":true},
 {"who":"Amani","face":1,"bg":"event_room_day","cast":["amani","john"],"line":"They've gone from delivering tape to repairing my entire life."},
 {"who":"John","face":4,"bg":"event_room_day","cast":["amani","john"],"line":"Which service issued that code?"},
 {"who":"Amani","face":4,"bg":"event_room_day","cast":["amani","john"],"line":"The wallet. Not my mobile provider."},
 {"who":"Sir Rham · Off-screen","face":0,"bg":"event_room_day","cast":["amani"],"line":"Use the contact details you already trust. Don't let the message choose who confirms its own story."},
 {"who":"Amani","face":4,"bg":"event_room_day","cast":["amani","john"],"line":"So calling the number in the warning would still leave me inside their instructions."},
 {"who":"John","face":0,"bg":"event_room_day","cast":["amani","john"],"line":"Exactly."},
 {"who":"Amani","face":5,"bg":"event_room_day","cast":["amani"],"line":"I'm keeping the messages. Then I'll open support myself, over school Wi-Fi."}
]
const EVIDENCE: String = "01 · Delivery, wallet code, copied identity, then recovery pressure: the pretext changes across services.\n02 · The warning supplies its own verification contact.\n03 · Independent wallet support says to keep the device code private; carrier help has not diagnosed the signal loss.\n\nThe saved messages are attached to the wallet support case. No code was shared and the sender remains unidentified."
const SEAL_LINE: String = "Their deadline doesn't get to choose who I trust."
const SLEEP_LINE: String = "Case LB-204 is saved inside the wallet app, with the messages attached. The device request is still under review.\n\nI'll check the response here. My signal problem needs its own investigation."
const END_CAPTION: String = ""

static func fresh() -> Dictionary:
	return {"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"mistakes":0,"hint_used":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{}}

static func message(id: String) -> Dictionary:
	return MESSAGES[0] if id == "recovery" else {}

static func suspicious_ids() -> Array[String]:
	return ["recovery"]

static func complete_evidence(state: Dictionary) -> bool:
	for field: String in ["read","flags","domains","captures"]:
		if not (state.get(field, []) as Array).has("recovery"): return false
	return true

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	# Findings form a prerequisite chain; malformed saves cannot skip an activity.
	var saved_order: Variant = raw.get("sorted", [])
	if saved_order is Array and raw.get("read", []) is Array and raw.get("read", []).has("recovery"):
		for id: String in ORDER:
			if saved_order.size() <= state.sorted.size() or saved_order[state.sorted.size()] != id: break
			state.sorted.append(id)
		if state.sorted.size() == ORDER.size():
			for id: String in ["wallet_support","carrier_support"]:
				if saved_order.has(id): state.sorted.append(id)
	var preceding: bool = true
	for field: String in ["read","flags","domains","captures"]:
		var values: Variant = raw.get(field, [])
		if field == "flags": preceding = preceding and state.sorted.size() >= ORDER.size()
		if field == "captures": preceding = preceding and state.sorted.has("wallet_support") and state.sorted.has("carrier_support")
		preceding = preceding and values is Array and values.has("recovery")
		if preceding: state[field] = ["recovery"]
	for field: String in ["beat","mistakes"]:
		var value: Variant = raw.get(field, 0)
		if (value is int or value is float) and is_finite(float(value)):
			state[field] = clampi(int(value), 0, STORY.size() - 1 if field == "beat" else 9999)
	state.hint_used = raw.get("hint_used", false) == true
	state.perk_run = Perks.clean_run(raw.get("perk_run", {}))
	if state.perk_run.get("chapter", ID) != ID: state.perk_run = {}
	var phase: String = str(raw.get("phase", "day"))
	if phase in ["day","sequence","route","verify","seal","sleep","done"]: state.phase = phase
	if state.phase != "day" and state.read.is_empty(): state.phase = "day"
	if state.phase in ["route","verify","seal","sleep","done"] and state.flags.is_empty(): state.phase = "sequence"
	if state.phase in ["verify","seal","sleep","done"] and state.domains.is_empty(): state.phase = "route"
	if state.phase in ["seal","sleep","done"] and state.captures.is_empty(): state.phase = "verify"
	state.sealed = raw.get("sealed", false) == true and complete_evidence(state)
	state.completed = raw.get("completed", false) == true and state.sealed
	if state.completed:
		state.phase = "done"
		state.reward = 100 + (25 if state.mistakes == 0 and Perks.status(state.perk_run, state.hint_used) != "assisted" else 0)
	elif state.phase == "done": state.phase = "seal"
	return state
