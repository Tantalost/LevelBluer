extends RefCounted
## Coached story activity; completion is not a BKT mastery observation.
const ID: String = "mod_02_ch_02"
const NUMBER: int = 2
const TITLE: String = "A Code I Didn't Request"
const PROTAGONIST: String = "Amani"
const PHONE_PATH: String = "res://src/gameplay/decision/wallet_code_phone.gd"
const BACKGROUND_ASSET: String = "story_bg_event_room_day"
const NIGHT_BACKGROUND: String = "event_room_day"
const MORNING: bool = true
const DAY_LABEL: String = "LUNCHTIME"
const FULL_WIDTH_INVESTIGATION: bool = true
const INVESTIGATION_TAGLINE: String = "One code. Two opposite instructions."
const FIRST_PHASE: String = "purpose"
const NEXT_CHAPTER: String = "mod_02_ch_03"
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const TASKS: Dictionary = {
	"purpose":{"title":"01 / Read the code's purpose", "tip":"Read what the wallet alert says the code authorizes. The separate SMS cannot change that purpose.", "line":"What would sharing this code actually allow?", "field":"flags", "total":1, "next":"contradiction"},
	"contradiction":{"title":"02 / Compare the instructions", "tip":"Authorize a new device is the opposite of cancel. Select the request that misrepresents what the code does.", "line":"Same code. Two very different promises.", "field":"domains", "total":1, "next":"verify"},
	"verify":{"title":"03 / Reject through the wallet", "tip":"Open the wallet from your own apps, inspect the unfamiliar request, then reject and report it there.", "line":"I'll check the attempt in the wallet itself.", "field":"captures", "total":1, "next":"seal"}
}
const ALERT: String = "Use code 824106 to authorize a new device. Do not share it. If this was not you, open the wallet app directly."
const REQUEST: String = "The delivery payment triggered a verification error. Reply with the code to cancel it. Do not open another app while cancellation is pending."
const CHAT_MESSAGES: Array[Dictionary] = []
const MESSAGES: Array[Dictionary] = [{"id":"wallet", "sender":"Delivery Support", "address":"Unknown SMS sender", "subject":"Cancellation request", "body":REQUEST, "phrase":"Reply with the code to cancel it.", "suspicious":true}]
const STORY: Array[Dictionary] = [
	{"who":"Amani","face":3,"bg":"event_room_day","cast":["amani"],"caption":"Same clubroom. A few minutes after the delivery message.","line":"A wallet code? Now there's another text.","mail":true},
	{"who":"Amani","face":2,"bg":"event_room_day","cast":["amani"],"line":"I didn't even pay. Why is my wallet involved?"},
	{"who":"John","face":4,"bg":"event_room_day","cast":["amani","john"],"line":"What does the wallet say the code will do?"},
	{"who":"Amani","face":4,"bg":"event_room_day","cast":["amani","john"],"line":"Authorize a new device."},
	{"who":"John","face":0,"bg":"event_room_day","cast":["amani","john"],"line":"And what does this person say it will do?"},
	{"who":"Amani","face":4,"bg":"event_room_day","cast":["amani","john"],"line":"Cancel one. That's the opposite instruction wearing a customer-service voice."},
	{"who":"Amani","face":5,"bg":"event_room_day","cast":["amani"],"line":"The message wants me to stay here. I'm opening the wallet myself."}
]
const EVIDENCE: String = "01 · The genuine wallet alert authorizes a new device.\n02 · The separate sender claims the same code will cancel an attempt.\n03 · Amani opens the wallet independently and rejects and reports the unfamiliar device request.\n\nA genuine alert does not authenticate a separate sender. Nobody has been identified by these messages."
const SEAL_LINE: String = "A real security code. A false reason to share it."
const SLEEP_LINE: String = "The code can stay on my phone. It didn't ask for a field trip.\n\nThe wallet confirms the request was rejected and reported. I save both messages. Whoever sent the cancellation text is still unknown."
const END_CAPTION: String = ""

static func fresh() -> Dictionary:
	return {"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"mistakes":0,"hint_used":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{}}

static func message(id: String) -> Dictionary:
	return MESSAGES[0] if id == "wallet" else {}

static func suspicious_ids() -> Array[String]:
	return ["wallet"]

static func complete_evidence(state: Dictionary) -> bool:
	for field: String in ["read","flags","domains","captures"]:
		if not (state.get(field, []) as Array).has("wallet"): return false
	return true

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	# Findings form a prerequisite chain; malformed saves cannot skip an activity.
	var preceding: bool = true
	for field: String in ["read","flags","domains","captures"]:
		var values: Variant = raw.get(field, [])
		preceding = preceding and values is Array and values.has("wallet")
		if preceding: state[field] = ["wallet"]
	for field: String in ["beat","mistakes"]:
		var value: Variant = raw.get(field, 0)
		if (value is int or value is float) and is_finite(float(value)):
			state[field] = clampi(int(value), 0, STORY.size() - 1 if field == "beat" else 9999)
	state.hint_used = raw.get("hint_used", false) == true
	state.perk_run = Perks.clean_run(raw.get("perk_run", {}))
	if state.perk_run.get("chapter", ID) != ID: state.perk_run = {}
	var phase: String = str(raw.get("phase", "day"))
	if phase in ["day","purpose","contradiction","verify","seal","sleep","done"]: state.phase = phase
	if state.phase != "day" and state.read.is_empty(): state.phase = "day"
	if state.phase in ["contradiction","verify","seal","sleep","done"] and state.flags.is_empty(): state.phase = "purpose"
	if state.phase in ["verify","seal","sleep","done"] and state.domains.is_empty(): state.phase = "contradiction"
	if state.phase in ["seal","sleep","done"] and state.captures.is_empty(): state.phase = "verify"
	state.sealed = raw.get("sealed", false) == true and complete_evidence(state)
	state.completed = raw.get("completed", false) == true and state.sealed
	if state.completed:
		state.phase = "done"
		state.reward = 100 + (25 if state.mistakes == 0 and Perks.status(state.perk_run, state.hint_used) != "assisted" else 0)
	elif state.phase == "done": state.phase = "seal"
	return state
