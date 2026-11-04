extends RefCounted
## Guided call/alert comparison; no graded or BKT observation is submitted.
const ID: String = "mod_03_ch_03"
const NUMBER: int = 3
const TITLE: String = "Don't Hang Up"
const PROTAGONIST: String = "Liza"
const PHONE_PATH: String = "res://src/gameplay/decision/dont_hang_up_phone.gd"
const BACKGROUND_ASSET: String = "story_bg_mod3_rain_courtyard_v1"
const NIGHT_BACKGROUND: String = "mod3_rain_courtyard_v1"
const MORNING: bool = true
const DAY_LABEL: String = "AFTERNOON"
const FULL_WIDTH_INVESTIGATION: bool = true
const INVESTIGATION_TAGLINE: String = "Read the purpose. Keep the code."
const FIRST_PHASE: String = "purpose"
const NEXT_CHAPTER: String = "mod_03_ch_04"
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const TASKS: Dictionary = {
 "purpose":{"title":"01 / Read the alert's purpose","tip":"The wallet alert names a password reset. It does not say the code stops a payment.","line":"What would this code actually do?","field":"flags","total":1,"next":"contradiction"},
 "contradiction":{"title":"02 / Compare the instructions","tip":"Switch between the alert and call review. Highlight RESET PASSWORD and STOP PAYMENT; they describe different actions.","line":"Two sources. Two different instructions.","field":"domains","total":1,"next":"refusal"},
 "refusal":{"title":"03 / Keep control","tip":"Keep the code private. End the unexpected call and verify through Support in the wallet app you already use. Ending a call never costs points.","line":"A deadline does not grant permission.","field":"captures","total":1,"next":"seal"}
}
const CALL_LINES: Array[String] = [
 "Read me the code and I'll stop the payment. Don't hang up - we'll lose the protection session.",
 "That's the security procedure. We need to act before the window closes."
]
const ALERT: String = "WALLET / SECURITY ALERT\nPassword reset requested.\nUse this code to reset your password. Never share it.\nCode: [kept private]\nDidn't request this? Open Support in your wallet app."
const CHAT_MESSAGES: Array[Dictionary] = []
const MESSAGES: Array[Dictionary] = [{"id":"call","sender":"Account Security (unverified)","address":"New incoming call / Wallet alert","subject":"Password reset versus payment claim","body":ALERT,"phrase":"A reset code does not cancel a payment.","suspicious":true}]
const STORY: Array[Dictionary] = [
 {"who":"Liza","face":4,"bg":"mod3_rain_courtyard_v1","cast":["liza"],"caption":"Back under the courtyard roof. The moment from the opening.","line":"The library is closing. Back under the courtyard roof, I reach for the wallet's Support page. Rain, receipts, and one very persistent phone.","art":"story_bg_mod3_rain_courtyard_v1"},
 {"who":"Liza","face":3,"bg":"mod3_rain_courtyard_v1","cast":["liza"],"line":"Account Security is calling again. And my wallet has a password-reset alert. I didn't request that.","mail":true,"art":"story_bg_mod3_rain_courtyard_v1"},
 {"who":"Liza","face":4,"bg":"mod3_rain_courtyard_v1","cast":["liza"],"line":"The call is over. My code stays private. Now I can read without someone setting the pace for me.","art":"story_bg_mod3_rain_courtyard_v1"},
 {"who":"Liza","face":2,"bg":"mod3_rain_courtyard_v1","cast":["liza"],"line":"Password reset. That's what the alert says. A promise about stopping a payment would have to explain that difference.","art":"story_bg_mod3_rain_courtyard_v1"},
 {"who":"Liza","face":5,"bg":"mod3_rain_courtyard_v1","cast":["liza"],"line":"I don't need a caller's permission to check with the service. First, save what I actually received.","art":"story_bg_mod3_rain_courtyard_v1"}
]
const EVIDENCE: String = "01 / The wallet alert states that the code resets a password. It does not cancel a payment.\n02 / Compare the received call notes with the alert. Missed statements stay marked as review guidance, never call evidence.\n03 / Liza ends or declines the call and keeps the code private. A claimed deadline does not authenticate a request.\n\nThe caller remains unidentified. The service has not yet independently confirmed what happened to the reset request."
const SEAL_LINE: String = "The alert tells me what the code does. A stranger doesn't get to rename it."
const SLEEP_LINE: String = "The call is over. No code was entered or shared. I save the wallet alert and only the caller statements I received.\n\nNext, I need an answer from the service through a route I choose myself."
const END_CAPTION: String = ""

static func fresh() -> Dictionary:
	return {"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"mistakes":0,"hint_used":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{},"call_started":false,"call_ended":false,"call_received":0,"alert_read":false}

static func message(id: String) -> Dictionary:
	return MESSAGES[0] if id == "call" else {}

static func suspicious_ids() -> Array[String]:
	return ["call"]

static func complete_evidence(state: Dictionary) -> bool:
	for field: String in ["read","flags","domains","captures"]:
		if not (state.get(field, []) as Array).has("call"): return false
	return true

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	state.alert_read = raw.get("alert_read", false) == true
	state.call_started = raw.get("call_started",false) == true
	state.call_ended = raw.get("call_ended",false) == true
	var received: Variant = raw.get("call_received",0)
	if state.call_started and (received is int or received is float) and is_finite(float(received)):
		state.call_received = clampi(int(received),1,CALL_LINES.size())
	var matches: Variant = raw.get("sorted",[])
	if state.call_ended and state.alert_read and matches is Array:
		for id: String in ["reset","payment"]:
			if matches.has(id): state.sorted.append(id)
	# Findings form a prerequisite chain; malformed saves cannot skip an activity.
	var preceding: bool = state.call_ended and state.alert_read
	for field: String in ["read","flags","domains","captures"]:
		if field == "domains": preceding = preceding and state.sorted.has("reset") and state.sorted.has("payment")
		var values: Variant = raw.get(field, [])
		preceding = preceding and values is Array and values.has("call")
		if preceding: state[field] = ["call"]
	for field: String in ["beat","mistakes"]:
		var value: Variant = raw.get(field, 0)
		if (value is int or value is float) and is_finite(float(value)):
			state[field] = clampi(int(value), 0, STORY.size() - 1 if field == "beat" else 9999)
	state.hint_used = raw.get("hint_used", false) == true
	state.perk_run = Perks.clean_run(raw.get("perk_run", {}))
	if state.perk_run.get("chapter", ID) != ID: state.perk_run = {}
	var phase: String = str(raw.get("phase", "day"))
	if phase in ["day","purpose","contradiction","refusal","seal","sleep","done"]: state.phase = phase
	if state.phase != "day" and state.read.is_empty(): state.phase = "day"
	if state.phase in ["contradiction","refusal","seal","sleep","done"] and state.flags.is_empty(): state.phase = "purpose"
	if state.phase in ["refusal","seal","sleep","done"] and state.domains.is_empty(): state.phase = "contradiction"
	if state.phase in ["seal","sleep","done"] and state.captures.is_empty(): state.phase = "refusal"
	state.sealed = raw.get("sealed", false) == true and complete_evidence(state)
	state.completed = raw.get("completed", false) == true and state.sealed
	if state.completed:
		state.phase = "done"
		state.reward = 100 + (25 if state.mistakes == 0 and Perks.status(state.perk_run, state.hint_used) != "assisted" else 0)
	elif state.phase == "done": state.phase = "seal"
	return state
