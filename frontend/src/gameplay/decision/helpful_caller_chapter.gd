extends RefCounted
## Coached call inspection, never a graded mastery observation.
const ID: String = "mod_03_ch_01"
const NUMBER: int = 1
const TITLE: String = "The Helpful Caller"
const PROTAGONIST: String = "Liza"
const PHONE_PATH: String = "res://src/gameplay/decision/helpful_caller_phone.gd"
const BACKGROUND_ASSET: String = "story_bg_covered_courtyard_rain"
const NIGHT_BACKGROUND: String = "covered_courtyard_rain"
const MORNING: bool = true
const DAY_LABEL: String = "AFTERNOON"
const FULL_WIDTH_INVESTIGATION: bool = true
const INVESTIGATION_TAGLINE: String = "A professional voice. An unverified claim."
const FIRST_PHASE: String = "claims"
const NEXT_CHAPTER: String = ""
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const TASKS: Dictionary = {
 "claims":{"title":"01 / Claim or fact?","tip":"A display label makes a claim. Receiving a call is observable. Neither independently verifies the caller.","line":"What do I actually know?","field":"flags","total":1,"next":"identity"},
 "identity":{"title":"02 / Inspect the identity","tip":"The caller's label and any reference they supply come from the same unverified source.","line":"Something that sounds official still needs checking.","field":"domains","total":1,"next":"verify"},
 "verify":{"title":"03 / Choose an independent check","tip":"Open the service through an app you already use. Do not let the caller choose their own verifier.","line":"I'll choose where I check this.","field":"captures","total":1,"next":"seal"}
}
const CALL_LINES: Array[String] = ["Liza? I'm following up on the scam reported by your school. Before anything else, please don't open another message from them.","I'm with your wallet's account-security team. Reference SC-318. I can walk you through the security check."]
const CHAT_MESSAGES: Array[Dictionary] = []
const MESSAGES: Array[Dictionary] = [{"id":"call","sender":"Account Security (displayed label)","address":"Unverified incoming contact","subject":"Account-security claim","body":"The phone displayed Account Security. The service has not independently verified this caller.","phrase":"A displayed name does not verify who is calling.","suspicious":true}]
const STORY: Array[Dictionary] = [
 {"who":"Liza","face":0,"bg":"covered_courtyard_rain","cast":["liza"],"caption":"After Amani's hearing. The covered courtyard, following the club event briefing.","line":"Eric just called about reimbursements. Keep the receipts, he said. Apparently 'trust me' is no longer an accounting method."},
 {"who":"Liza","face":1,"bg":"covered_courtyard_rain","cast":["liza"],"line":"I have receipts. What I don't have is a stapler that believes in teamwork."},
 {"who":"Liza","face":3,"bg":"covered_courtyard_rain","cast":["liza"],"line":"Another call. Account Security?","mail":true},
 {"who":"Liza","face":4,"bg":"covered_courtyard_rain","cast":["liza","john"],"line":"An official-looking label. That's something my phone displayed, not something I've verified."},
 {"who":"John","face":0,"bg":"covered_courtyard_rain","cast":["liza","john"],"line":"Keep what you observed separate from what the caller wants you to believe."},
 {"who":"Liza","face":5,"bg":"covered_courtyard_rain","cast":["liza"],"line":"Then let's check the claim somewhere this caller doesn't control."}
]
const EVIDENCE: String = "01 · The displayed Account Security label is a claim, not authenticated identity.\n02 · Receiving a call is observable; any caller-supplied reference still needs independent verification.\n03 · Liza chooses the service's existing app as her verification route.\n\nOnly received statements are retained in the call notes. Eric's earlier expense call does not identify this caller."
const SEAL_LINE: String = "A helpful-sounding claim is still a claim."
const SLEEP_LINE: String = "The call is over. I keep the label and only the words I actually received.\n\nNext, I'll compare the caller's information with sources outside their conversation. No account code was shared."
const END_CAPTION: String = ""

static func fresh() -> Dictionary:
	return {"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"mistakes":0,"hint_used":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{},"call_started":false,"call_ended":false,"call_received":0}

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
	state.call_started = raw.get("call_started",false) == true
	state.call_ended = raw.get("call_ended",false) == true
	var received: Variant = raw.get("call_received",0)
	if state.call_started and (received is int or received is float) and is_finite(float(received)):
		state.call_received = clampi(int(received),1,CALL_LINES.size())
	var matches: Variant = raw.get("sorted",[])
	if state.call_ended and matches is Array:
		for id: String in ["claim","observed","unverified"]:
			if matches.has(id): state.sorted.append(id)
	# Findings form a prerequisite chain; malformed saves cannot skip an activity.
	var preceding: bool = state.call_ended
	for field: String in ["read","flags","domains","captures"]:
		if field == "flags": preceding = preceding and state.sorted.size() == 3
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
	if phase in ["day","claims","identity","verify","seal","sleep","done"]: state.phase = phase
	if state.phase != "day" and state.read.is_empty(): state.phase = "day"
	if state.phase in ["identity","verify","seal","sleep","done"] and state.flags.is_empty(): state.phase = "claims"
	if state.phase in ["verify","seal","sleep","done"] and state.domains.is_empty(): state.phase = "identity"
	if state.phase in ["seal","sleep","done"] and state.captures.is_empty(): state.phase = "verify"
	state.sealed = raw.get("sealed", false) == true and complete_evidence(state)
	state.completed = raw.get("completed", false) == true and state.sealed
	if state.completed:
		state.phase = "done"
		state.reward = 100 + (25 if state.mistakes == 0 and Perks.status(state.perk_run, state.hint_used) != "assisted" else 0)
	elif state.phase == "done": state.phase = "seal"
	return state
