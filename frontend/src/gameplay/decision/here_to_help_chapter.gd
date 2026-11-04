extends RefCounted
## Coached pretext inspection. Never emits graded BKT observations.
const ID: String = "mod_04_ch_01"
const NUMBER: int = 1
const TITLE: String = "Here to Help"
const PROTAGONIST: String = "Sir Rham"
const PHONE_PATH: String = "res://src/gameplay/decision/here_to_help_phone.gd"
const BACKGROUND_ASSET: String = "story_bg_mod4_faculty_workroom_v1"
const NIGHT_BACKGROUND: String = "mod4_faculty_workroom_v1"
const MORNING: bool = true
const DAY_LABEL: String = "MORNING"
const FULL_WIDTH_INVESTIGATION: bool = true
const INVESTIGATION_TAGLINE: String = "A convincing appointment. An unverified role."
const FIRST_PHASE: String = "claims"
const NEXT_CHAPTER: String = "mod_04_ch_02"
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const TASKS: Dictionary = {
 "claims":{"title":"01 / Claim or observation?","tip":"Branding is visible. Authority needs independent confirmation.","line":"What has actually been verified?","field":"flags","total":1,"next":"compare"},
 "compare":{"title":"02 / Compare the appointment","tip":"Open both records. The time matches, but the purpose and external visitor do not.","line":"Same time. Different appointment.","field":"domains","total":1,"next":"verify"},
 "verify":{"title":"03 / Choose an independent check","tip":"Use the school directory you already know, not a verifier chosen by the sender.","line":"I'll choose who confirms this.","field":"captures","total":1,"next":"seal"}
}
const APPOINTMENT: String = "SUPPLIED APPOINTMENT\n10:30 / External incident-response consultation\nIncident Response Coordinator\nAppointment confirmed / School branding displayed\nSource: the same unverified sender"
const SCHEDULE: String = "EXISTING SCHOOL SCHEDULE / TODAY\n10:30 / Club event logistics\nInternal staff only\nNo external coordinator recorded\nOpened through Sir Rham's existing school shortcut"
const CLAIMS: Array[Dictionary] = [
 {"id":"role","text":"A coordinator contacted me.","answer":"claim","explanation":"Someone claiming that role contacted Sir Rham. The role has not been independently confirmed."},
 {"id":"branding","text":"The message displays school branding.","answer":"observation","explanation":"The branding is visible. Seeing it does not establish who sent the message."},
 {"id":"approval","text":"The school approved this coordinator.","answer":"claim","explanation":"Approval is claimed by the sender. The school has not independently confirmed it."}
]
const CHAT_MESSAGES: Array[Dictionary] = []
const MESSAGES: Array[Dictionary] = [{"id":"appointment","sender":"Incident Response Coordinator (unverified)","address":"Incoming school-related message","subject":"School incident follow-up","body":"Good morning, Sir Rham. I am the incident-response coordinator assigned to your club's case. Your 10:30 consultation has been approved. Please acknowledge so I can prepare the protective follow-up.","phrase":"A plausible role still needs independent verification.","suspicious":true}]
const STORY: Array[Dictionary] = [
 {"who":"Sir Rham","face":1,"bg":"mod4_faculty_workroom_v1","cast":["sir rham"],"caption":"The next school morning, after Liza's hearing. The faculty workroom.","line":"I finally made coffee. Naturally, the paperwork arrived first."},
 {"who":"John","face":1,"bg":"mod4_faculty_workroom_v1","cast":["sir rham","john"],"line":"At least nobody promised to pay you for drinking it."},
 {"who":"Sir Rham","face":1,"bg":"mod4_faculty_workroom_v1","cast":["sir rham","john"],"line":"Progress. We're learning."},
 {"who":"Sir Rham","face":4,"bg":"mod4_faculty_workroom_v1","cast":["sir rham"],"line":"An appointment notification. School incident follow-up?","mail":true},
 {"who":"Sir Rham","face":0,"bg":"mod4_faculty_workroom_v1","cast":["sir rham","john"],"line":"They know about the club incidents. A follow-up would make sense."},
 {"who":"John","face":4,"bg":"mod4_faculty_workroom_v1","cast":["sir rham","john"],"line":"Did the office arrange it, or does the message say the office arranged it?"},
 {"who":"Sir Rham","face":4,"bg":"mod4_faculty_workroom_v1","cast":["sir rham","john"],"line":"Fair question. I'll check the schedule I already use."},
 {"who":"Sir Rham","face":3,"bg":"mod4_faculty_workroom_v1","cast":["sir rham","john"],"line":"The internal schedule lists club event logistics. Same time. Different purpose. This could be an update I haven't received. It still isn't confirmation."},
 {"who":"John","face":0,"bg":"mod4_faculty_workroom_v1","cast":["sir rham","john"],"line":"So the appointment is a claim to check."},
 {"who":"Sir Rham","face":5,"bg":"mod4_faculty_workroom_v1","cast":["sir rham"],"line":"Exactly. Helpful is a description. Authorized is something we verify."}
]
const EVIDENCE: String = "01 · The role, branding and approval claim do not independently verify the sender.\n02 · The independently opened schedule lists an internal meeting, not the proposed external consultation. This needs clarification; it does not alone prove fraud.\n03 · Sir Rham selects the existing school directory as his verification route.\n\nNo office response has been received and no student list has been shared."
const SEAL_LINE: String = "A helpful story still needs an independent source."
const SLEEP_LINE: String = "I haven't confirmed the appointment. I haven't shared a list.\n\nFirst, I need to understand exactly what they're asking for."
const END_CAPTION: String = ""

static func fresh() -> Dictionary:
	return {"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"mistakes":0,"hint_used":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{}}

static func message(id: String) -> Dictionary:
	return MESSAGES[0] if id == "appointment" else {}

static func suspicious_ids() -> Array[String]:
	return ["appointment"]

static func complete_evidence(state: Dictionary) -> bool:
	for field: String in ["read","flags","domains","captures"]:
		if not (state.get(field,[]) as Array).has("appointment"): return false
	return true

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	var reads: Variant = raw.get("read",[])
	if reads is Array and reads.has("appointment"): state.read = ["appointment"]
	var matches: Variant = raw.get("sorted",[])
	if matches is Array and not state.read.is_empty():
		for id: String in ["role","branding","approval"]:
			if matches.has(id): state.sorted.append(id)
	var preceding: bool = state.sorted.size() == 3
	for field: String in ["flags","domains","captures"]:
		if field == "domains" and preceding and matches is Array:
			for id: String in ["supplied","schedule"]:
				if matches.has(id): state.sorted.append(id)
			preceding = state.sorted.has("supplied") and state.sorted.has("schedule")
		if field == "captures" and preceding and matches is Array:
			if matches.has("directory"): state.sorted.append("directory")
			preceding = state.sorted.has("directory")
		var values: Variant = raw.get(field,[])
		preceding = preceding and values is Array and values.has("appointment")
		if preceding: state[field] = ["appointment"]
	for field: String in ["beat","mistakes"]:
		var value: Variant = raw.get(field,0)
		if (value is int or value is float) and is_finite(float(value)):
			state[field] = clampi(int(value),0,STORY.size()-1 if field == "beat" else 9999)
	state.hint_used = raw.get("hint_used",false) == true
	state.perk_run = Perks.clean_run(raw.get("perk_run",{}))
	if state.perk_run.get("chapter",ID) != ID: state.perk_run = {}
	var phase: String = str(raw.get("phase","day"))
	if phase in ["day","claims","compare","verify","seal","sleep","done"]: state.phase = phase
	if state.phase != "day" and state.read.is_empty(): state.phase = "day"
	if state.phase in ["compare","verify","seal","sleep","done"] and state.flags.is_empty(): state.phase = "claims"
	if state.phase in ["verify","seal","sleep","done"] and state.domains.is_empty(): state.phase = "compare"
	if state.phase in ["seal","sleep","done"] and state.captures.is_empty(): state.phase = "verify"
	state.sealed = raw.get("sealed",false) == true and complete_evidence(state)
	state.completed = raw.get("completed",false) == true and state.sealed
	if state.completed:
		state.phase = "done"
		state.reward = 100 + (25 if state.mistakes == 0 and Perks.status(state.perk_run,state.hint_used) != "assisted" else 0)
	elif state.phase == "done": state.phase = "seal"
	return state
