extends RefCounted
## Guided independent verification; not a BKT or assessment observation.
const ID: String = "mod_03_ch_04"
const NUMBER: int = 4
const TITLE: String = "Call Back, Safely"
const PROTAGONIST: String = "Liza"
const PHONE_PATH: String = "res://src/gameplay/decision/safe_callback_phone.gd"
const BACKGROUND_ASSET: String = "story_bg_mod3_quiet_study_room_v1"
const NIGHT_BACKGROUND: String = "mod3_quiet_study_room_v1"
const MORNING: bool = true
const DAY_LABEL: String = "AFTERNOON"
const FULL_WIDTH_INVESTIGATION: bool = true
const INVESTIGATION_TAGLINE: String = "Choose the source of your second opinion."
const FIRST_PHASE: String = "route"
const NEXT_CHAPTER: String = "mod_03_ch_05"
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const PriorCall: GDScript = preload("res://src/gameplay/decision/dont_hang_up_chapter.gd")
const TASKS: Dictionary = {
 "route":{"title":"01 / Find an independent contact","tip":"Open the wallet app you already use, then Support and Contact us. A number supplied in the suspicious message is not an independent verifier.","line":"Where did the number come from?","field":"flags","total":1,"next":"compare"},
 "compare":{"title":"02 / Check the service's response","tip":"The service says it did not request the call or ask for the reset code. The reset was not completed; this does not establish that every account is safe.","line":"A claimed title meets a checked source.","field":"domains","total":1,"next":"report"},
 "report":{"title":"03 / Preserve the incident","tip":"Attach the wallet alert and the call notes you actually received. A declined call has no transcript. Keep the code private.","line":"A useful report keeps the source with the claim.","field":"captures","total":1,"next":"seal"}
}
const REQUEST: String = "I'm the supervisor for your Account Security agent. Our team requested that call to protect your payment. Call the callback number in this message so I can confirm the agent is genuine. Keep this within our team."
const CONTACT: String = "Callback number / supplied by this message's sender"
const SUPPORT_REPLY: String = "WALLET / SUPPORT RESPONSE\nWe did not request that call or ask you to share a password-reset code.\nThe password-reset request was not completed. Review your account activity and report unfamiliar entries through this app. Keep your codes private."
const CHAT_MESSAGES: Array[Dictionary] = []
const MESSAGES: Array[Dictionary] = [{"id":"callback","sender":"Security Supervisor (unverified)","address":CONTACT,"subject":"Independent callback / Incident record","body":REQUEST,"phrase":"Verify through a contact you obtained independently.","suspicious":true}]
const STORY: Array[Dictionary] = [
 {"who":"Liza","voice":"v1794323897/levelblue/voice/mod_03/ch_04/liza_01.mp3","face":4,"bg":"mod3_rain_courtyard_v1","cast":["liza"],"caption":"The covered courtyard. Just after ending the call.","line":"The call ended. My code stayed private. For one beautiful second, my phone was quiet.","art":"story_bg_mod3_rain_courtyard_v1"},
 {"who":"Liza","voice":"v1794323911/levelblue/voice/mod_03/ch_04/liza_02.mp3","face":3,"bg":"mod3_rain_courtyard_v1","cast":["liza"],"line":"A supervisor now? This operation has more management than our club.","mail":true,"art":"story_bg_mod3_rain_courtyard_v1"},
 {"who":"Liza","voice":"v1794323924/levelblue/voice/mod_03/ch_04/liza_03.mp3","face":4,"bg":"mod3_quiet_study_room_v1","cast":["liza","john"],"line":"Maybe I can call this number and check with someone else.","art":"story_bg_mod3_quiet_study_room_v1","caption":"Liza and John step into a quiet study room beside the courtyard."},
 {"who":"John","face":4,"bg":"mod3_quiet_study_room_v1","cast":["liza","john"],"line":"Where did that number come from?","art":"story_bg_mod3_quiet_study_room_v1"},
 {"who":"Liza","voice":"v1794323954/levelblue/voice/mod_03/ch_04/liza_04.mp3","face":4,"bg":"mod3_quiet_study_room_v1","cast":["liza","john"],"line":"The same conversation I'm trying to verify. Right.","art":"story_bg_mod3_quiet_study_room_v1"},
 {"who":"Liza","voice":"v1794323972/levelblue/voice/mod_03/ch_04/liza_05.mp3","face":1,"bg":"mod3_quiet_study_room_v1","cast":["liza"],"line":"Two names. One source. That's not a second opinion. That's an echo with a promotion.","art":"story_bg_mod3_quiet_study_room_v1"},
 {"who":"John","face":0,"bg":"mod3_quiet_study_room_v1","cast":["liza","john"],"line":"Use the wallet app you already have. Find Support there, outside this message.","art":"story_bg_mod3_quiet_study_room_v1"},
 {"who":"Liza","voice":"v1794323989/levelblue/voice/mod_03/ch_04/liza_06.mp3","face":5,"bg":"mod3_quiet_study_room_v1","cast":["liza"],"line":"My route. My pace. And a report that says what happened, without guessing who was behind it.","art":"story_bg_mod3_quiet_study_room_v1"}
]
const EVIDENCE: String = "01 / The supposed supervisor supplied a callback contact in the same suspicious conversation. The name and number remain unverified.\n02 / Independently reached wallet Support says it did not request the call or ask for the reset code. It confirms this reset was not completed and recommends reviewing account activity.\n03 / Liza attaches the alert and her actual saved call notes to a simulated incident record. No code is attached.\n\nThe response does not identify the caller or prove every account is safe."
const SEAL_LINE: String = "I didn't ask the caller to verify the caller. I checked with the service."
const SLEEP_LINE: String = "The reset wasn't completed. That's a specific answer I can use, not a promise that nothing else could be wrong.\n\nMy incident record keeps the message, the alert, and the call notes together. Next, we can challenge the claims with their sources in front of us."
const END_CAPTION: String = ""

static func fresh() -> Dictionary:
	return {"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"mistakes":0,"hint_used":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{}}

static func message(id: String) -> Dictionary:
	return MESSAGES[0] if id == "callback" else {}

static func suspicious_ids() -> Array[String]:
	return ["callback"]

static func complete_evidence(state: Dictionary) -> bool:
	for field: String in ["read","flags","domains","captures"]:
		if not (state.get(field, []) as Array).has("callback"): return false
	return true

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	# Findings form a prerequisite chain; malformed saves cannot skip an activity.
	var preceding: bool = true
	for field: String in ["read","flags","domains","captures"]:
		var values: Variant = raw.get(field, [])
		var checked: Variant = raw.get("sorted", [])
		if field == "domains": preceding = preceding and checked is Array and checked.has("response")
		if field == "captures": preceding = preceding and checked is Array and checked.has("alert") and checked.has("call_notes")
		preceding = preceding and values is Array and values.has("callback")
		if preceding: state[field] = ["callback"]
	for field: String in ["beat","mistakes"]:
		var value: Variant = raw.get(field, 0)
		if (value is int or value is float) and is_finite(float(value)):
			state[field] = clampi(int(value), 0, STORY.size() - 1 if field == "beat" else 9999)
	var saved_matches: Variant = raw.get("sorted", [])
	if saved_matches is Array:
		if not state.flags.is_empty() and saved_matches.has("response"): state.sorted.append("response")
		if not state.domains.is_empty():
			for item: String in ["alert","call_notes"]:
				if saved_matches.has(item): state.sorted.append(item)
	state.hint_used = raw.get("hint_used", false) == true
	state.perk_run = Perks.clean_run(raw.get("perk_run", {}))
	if state.perk_run.get("chapter", ID) != ID: state.perk_run = {}
	var phase: String = str(raw.get("phase", "day"))
	if phase in ["day","route","compare","report","seal","sleep","done"]: state.phase = phase
	if state.phase != "day" and state.read.is_empty(): state.phase = "day"
	if state.phase in ["compare","report","seal","sleep","done"] and state.flags.is_empty(): state.phase = "route"
	if state.phase in ["report","seal","sleep","done"] and state.domains.is_empty(): state.phase = "compare"
	if state.phase in ["seal","sleep","done"] and state.captures.is_empty(): state.phase = "report"
	state.sealed = raw.get("sealed", false) == true and complete_evidence(state)
	state.completed = raw.get("completed", false) == true and state.sealed
	if state.completed:
		state.phase = "done"
		state.reward = 100 + (25 if state.mistakes == 0 and Perks.status(state.perk_run, state.hint_used) != "assisted" else 0)
	elif state.phase == "done": state.phase = "seal"
	return state
