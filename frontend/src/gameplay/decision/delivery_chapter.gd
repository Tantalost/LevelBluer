extends RefCounted
## Module 2's first chapter. Story activity is not a graded BKT observation.
const ID: String = "mod_02_ch_01"
const NUMBER: int = 1
const TITLE: String = "The Missing Delivery"
const PROTAGONIST: String = "Amani"
const PHONE_PATH: String = "res://src/gameplay/decision/delivery_phone.gd"
const BACKGROUND_ASSET: String = "story_bg_event_room_day"
const NIGHT_BACKGROUND: String = "event_room_day"
const MORNING: bool = true
const FULL_WIDTH_INVESTIGATION: bool = true
const FIRST_PHASE: String = "reveal"
const NEXT_CHAPTER: String = ""
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const TASKS: Dictionary = {
	"reveal":{"title":"01 / Inspect the message", "tip":"Reveal the address without visiting it. The message asks for a payment, not just a delivery update.", "line":"Eighteen pesos. What exactly am I being asked to do?", "field":"flags", "total":1, "next":"expand"},
	"expand":{"title":"02 / Expand the link", "tip":"Select the shortened link, then tap Expand. A short address hides the destination; it does not prove fraud on its own.", "line":"Let's find out where this actually leads.", "field":"domains", "total":1, "next":"verify"},
	"verify":{"title":"03 / Check my order", "tip":"Open the saved order using its own app. Compare the payment request with the order you already placed.", "line":"I already paid for this order. What does its own record say?", "field":"captures", "total":1, "next":"seal"}
}
const SHORT_URL: String = "https://go-parcel.example/r/8K2"
const DESTINATION: String = "https://parcel-redelivery.example/pay"
const KNOWN_URL: String = "https://parcel.example"
const CHAT_MESSAGES: Array[Dictionary] = []
const MESSAGES: Array[Dictionary] = [{"id":"parcel", "sender":"Parcel Update", "address":"Unknown SMS sender", "subject":"Delivery failed / ₱18 redelivery", "body":"Delivery failed. Pay ₱18 to reschedule today.", "phrase":"Track delivery: https://go-parcel.example/r/8K2. No matching order reference supplied.", "suspicious":true}]
const STORY: Array[Dictionary] = [
	{"who":"Amani","face":4,"bg":"event_room_day","cast":["amani"],"caption":"After John's hearing. The club prepares for its next event.","line":"Twenty name tags. Zero tape. Somehow I'm managing a club event and a national supply crisis."},
	{"who":"Dan · Off-screen","face":0,"bg":"event_room_day","cast":["amani"],"line":"Did you try tracking the tape?"},
	{"who":"Amani","face":1,"bg":"event_room_day","cast":["amani"],"line":"I am tracking the tape. The tape is apparently having a better lunch break than us."},
	{"who":"Amani","face":3,"bg":"event_room_day","cast":["amani"],"line":"Wait. A delivery update.","mail":true},
	{"who":"Amani","face":0,"bg":"event_room_day","cast":["amani"],"line":"Eighteen pesos? Fine. That's cheaper than walking to the depot."},
	{"who":"John","face":4,"bg":"event_room_day","cast":["amani","john"],"line":"Maybe. What does the order you already have say?"},
	{"who":"Amani","face":2,"bg":"event_room_day","cast":["amani","john"],"line":"You're asking me to check my delivery in two places?"},
	{"who":"John","face":0,"bg":"event_room_day","cast":["amani","john"],"line":"Start with the place you used before this message arrived."},
	{"who":"Amani","face":4,"bg":"event_room_day","cast":["amani"],"line":"Alright. I'll keep the message here and open my order separately."}
]
const EVIDENCE: String = "01 · SMS asks for an unexplained ₱18 payment.\n02 · Its short link leads to parcel-redelivery.example/pay.\n03 · The independently opened order is paid, out for delivery, with no redelivery fee.\n\nA short link or HTTPS alone does not settle trust. Compare the request with information obtained independently."
const SEAL_LINE: String = "My parcel isn't asking for eighteen pesos. Someone else is."
const SLEEP_LINE: String = "I save the message without paying. Then my phone buzzes again.\n\nA wallet security code? I didn't request one."
const END_CAPTION: String = ""

static func fresh() -> Dictionary:
	return {"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"mistakes":0,"hint_used":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{}}

static func message(id: String) -> Dictionary:
	return MESSAGES[0] if id == "parcel" else {}

static func suspicious_ids() -> Array[String]:
	return ["parcel"]

static func complete_evidence(state: Dictionary) -> bool:
	for field: String in ["read","flags","domains","captures"]:
		if not (state.get(field, []) as Array).has("parcel"): return false
	return true

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	for field: String in ["read","flags","domains","captures"]:
		var values: Variant = raw.get(field, [])
		if values is Array and values.has("parcel"): state[field] = ["parcel"]
	for field: String in ["beat","mistakes"]:
		var value: Variant = raw.get(field, 0)
		if (value is int or value is float) and is_finite(float(value)):
			state[field] = clampi(int(value), 0, STORY.size() - 1 if field == "beat" else 9999)
	state.hint_used = raw.get("hint_used", false) == true
	state.perk_run = Perks.clean_run(raw.get("perk_run", {}))
	if state.perk_run.get("chapter", ID) != ID: state.perk_run = {}
	var phase: String = str(raw.get("phase", "day"))
	if phase in ["day","reveal","expand","verify","seal","sleep","done"]: state.phase = phase
	if state.phase != "day" and state.read.is_empty(): state.phase = "day"
	if state.phase in ["expand","verify","seal","sleep","done"] and state.flags.is_empty(): state.phase = "reveal"
	if state.phase in ["verify","seal","sleep","done"] and state.domains.is_empty(): state.phase = "expand"
	if state.phase in ["seal","sleep","done"] and state.captures.is_empty(): state.phase = "verify"
	state.sealed = raw.get("sealed", false) == true and complete_evidence(state)
	state.completed = raw.get("completed", false) == true and state.sealed
	if state.completed:
		state.phase = "done"
		state.reward = 100 + (25 if state.mistakes == 0 and Perks.status(state.perk_run, state.hint_used) != "assisted" else 0)
	elif state.phase == "done": state.phase = "seal"
	return state
