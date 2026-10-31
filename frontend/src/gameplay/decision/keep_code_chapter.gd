extends RefCounted
## Coached story activity; completion is not a BKT mastery observation.
const ID: String = "mod_02_ch_05"
const NUMBER: int = 5
const TITLE: String = "Keep the Code"
const PROTAGONIST: String = "Amani"
const PHONE_PATH: String = "res://src/gameplay/decision/keep_code_phone.gd"
const BACKGROUND_ASSET: String = "story_bg_event_room_day"
const NIGHT_BACKGROUND: String = "event_room_day"
const MORNING: bool = true
const DAY_LABEL: String = "NEXT MORNING"
const FULL_WIDTH_INVESTIGATION: bool = true
const INVESTIGATION_TAGLINE: String = "Explain the request. Follow the evidence."
const FIRST_PHASE: String = "fee"
const NEXT_CHAPTER: String = ""
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const FINALE: bool = true
const TASKS: Dictionary = {
 "fee":{"title":"01 / Challenge the fee claim","tip":"Compare the paid order with the unexplained payment destination. A small amount does not verify a recipient.","line":"Does a small fee make the request safe?","field":"flags","total":1,"next":"code"},
 "code":{"title":"02 / Challenge the code claim","tip":"The wallet code authorizes a new device. A separate sender falsely calls it cancellation.","line":"A real code does not verify its requester.","field":"domains","total":1,"next":"public"},
 "public":{"title":"03 / Challenge the identity claim","tip":"The delivery detail and profile photo were public. Familiar information cannot authenticate a new contact.","line":"Who else could have copied those details?","field":"captures","total":1,"next":"reconstruct"},
 "reconstruct":{"title":"04 / Reconstruct the requests","tip":"Delivery request, wallet code, copied-name message, then recovery pressure.","line":"Put the requests back in order.","field":"sorted","total":4,"next":"seal"}
}
const ORDER: Array[String] = ["delivery","code","identity","recovery"]
const EVENT_NAMES: Dictionary = {"delivery":"Delivery request","code":"Wallet code","identity":"Copied-name message","recovery":"Recovery pressure"}
const CLAIMS: Dictionary = {"fee":"The fee was small, so paying was harmless.","code":"The code was genuine, so the person asking for it was genuine.","public":"They knew the delivery, so Amani must have trusted them."}
const EXHIBITS: Dictionary = {
 "order":{"title":"Paid order + destination","detail":"Chapter 1: The independent order was paid, out for delivery and requested no extra fee. The SMS led to an unexplained payment destination.","kind":"short"},
 "authorization":{"title":"Code purpose + cancellation","detail":"Chapter 2: The wallet code authorizes a new device. The sender claimed the same code would cancel access. A real alert does not verify that sender.","kind":"domain"},
 "post":{"title":"Public post + copied contact","detail":"Chapter 3: The photo and delivery date appeared publicly. The payment message came from a different contact. Dan's knowledge alone does not identify the operator.","kind":"coffee"},
 "signal":{"title":"Missing cellular signal","detail":"Amani observed signal loss. Its cause remains unknown. This does not prove a takeover, establish authorship or verify a payment request.","kind":"call"}
}
const CORRECT: Dictionary = {"fee":"order","code":"authorization","public":"post"}
const CHAT_MESSAGES: Array[Dictionary] = []
const MESSAGES: Array[Dictionary] = [{"id":"case","sender":"Wallet support / existing case","address":"Case LB-204 inside the installed wallet app","subject":"Rejected device request","body":"The rejected new-device request did not authorize access. We have recorded the messages you supplied. Review your signed-in devices and report anything unfamiliar.","phrase":"This attempt was blocked; the operator's real identity remains unknown.","suspicious":true}]
const STORY: Array[Dictionary] = [
 {"who":"Dan · Off-screen","face":0,"bg":"event_room_day","cast":["amani"],"caption":"Clubroom. The next morning. Dan arrives with the genuine parcel.","line":"Your tape has completed its character development."},
 {"who":"Amani","face":1,"bg":"event_room_day","cast":["amani"],"line":"Mine cost eighteen pesos less than expected."},
 {"who":"Amani","face":4,"bg":"event_room_day","cast":["amani"],"line":"There's a reply in the wallet support case I opened. Let me read it there.","mail":true},
 {"who":"Sir Rham · Off-screen","face":0,"bg":"event_room_day","cast":["amani","john"],"line":"Walk us through the requests. What made them unsafe?"},
 {"who":"Amani","face":5,"bg":"event_room_day","cast":["amani","john"],"line":"Let's put each claim beside what we actually checked."}
]
const EVIDENCE: String = "01 · The paid order contradicted the unexplained fee.\n02 · The real code authorized access, not cancellation.\n03 · Public details and a copied photo did not authenticate the new contact.\n\nThe support response confirms this device request was blocked. It does not identify the operator or establish that every account is safe."
const SEAL_LINE: String = "The message knew something about me. That didn't mean it was speaking for me."
const SLEEP_LINE: String = "John: And you checked without handing the check back to the person who sent it.\n\nAmani: Great. Now let's investigate who ordered twenty name tags for a nineteen-person activity."
const END_CAPTION: String = "Elsewhere — unseen by the students.\nThe masked text operator: No code. They've reported the contact.\nThat connection closes. Jobert's light stays dark. Two connections remain active.\nThe Collector: Then stop texting."

static func fresh() -> Dictionary:
	return {"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"mistakes":0,"hint_used":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{}}

static func message(id: String) -> Dictionary:
	return MESSAGES[0] if id == "case" else {}

static func suspicious_ids() -> Array[String]:
	return ["case"]

static func complete_evidence(state: Dictionary) -> bool:
	for field: String in ["read","flags","domains","captures"]:
		if not (state.get(field, []) as Array).has("case"): return false
	return state.sorted == ORDER

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	# Findings form a prerequisite chain; malformed saves cannot skip an activity.
	var preceding: bool = true
	for field: String in ["read","flags","domains","captures"]:
		var values: Variant = raw.get(field, [])
		preceding = preceding and values is Array and values.has("case")
		if preceding: state[field] = ["case"]
	for field: String in ["beat","mistakes"]:
		var value: Variant = raw.get(field, 0)
		if (value is int or value is float) and is_finite(float(value)):
			state[field] = clampi(int(value), 0, STORY.size() - 1 if field == "beat" else 9999)
	var order: Variant = raw.get("sorted", [])
	if order is Array and not state.captures.is_empty():
		for id: String in ORDER:
			if order.size() <= state.sorted.size() or order[state.sorted.size()] != id: break
			state.sorted.append(id)
	state.hint_used = raw.get("hint_used", false) == true
	state.perk_run = Perks.clean_run(raw.get("perk_run", {}))
	if state.perk_run.get("chapter", ID) != ID: state.perk_run = {}
	var phase: String = str(raw.get("phase", "day"))
	if phase in ["day","fee","code","public","reconstruct","seal","sleep","closing","done"]: state.phase = phase
	if state.phase != "day" and state.read.is_empty(): state.phase = "day"
	if state.phase in ["code","public","reconstruct","seal","sleep","closing","done"] and state.flags.is_empty(): state.phase = "fee"
	if state.phase in ["public","reconstruct","seal","sleep","closing","done"] and state.domains.is_empty(): state.phase = "code"
	if state.phase in ["reconstruct","seal","sleep","closing","done"] and state.captures.is_empty(): state.phase = "public"
	if state.phase in ["seal","sleep","closing","done"] and state.sorted.size() != 4: state.phase = "reconstruct"
	state.sealed = raw.get("sealed", false) == true and complete_evidence(state)
	state.completed = raw.get("completed", false) == true and state.sealed
	if state.completed:
		state.phase = "done"
		state.reward = 100 + (25 if state.mistakes == 0 and Perks.status(state.perk_run, state.hint_used) != "assisted" else 0)
	elif state.phase == "done": state.phase = "seal"
	return state
