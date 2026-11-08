extends RefCounted
## Coached authorization check. A claimed exception is not verified permission.
const ID: String = "mod_04_ch_03"
const NUMBER: int = 3
const TITLE: String = "The Exception"
const PROTAGONIST: String = "Sir Rham"
const PHONE_PATH: String = "res://src/gameplay/decision/exception_phone.gd"
const BACKGROUND_ASSET: String = "story_bg_mod4_consultation_room_v1"
const NIGHT_BACKGROUND: String = "mod4_consultation_room_v1"
const DAY_LABEL: String = "LATE AFTERNOON"
const FULL_WIDTH_INVESTIGATION: bool = true
const INVESTIGATION_TAGLINE: String = "A reason to help. Permission still missing."
const FIRST_PHASE: String = "compare"
const NEXT_CHAPTER: String = "mod_04_ch_04"
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const TASKS: Dictionary = {
 "compare":{"title":"01 / Inspect fields and channel","tip":"Open the incoming request and the existing school notice. The sender wants names, sections and contact numbers through a private message; that channel has not been independently approved.","line":"What leaves the school, and where would it go?","field":"flags","total":1,"next":"approval"},
 "approval":{"title":"02 / Check the exception","tip":"Already approved is the sender's claim. No independently confirmed approval naming the recipient, purpose, fields and channel has been provided.","line":"Approved by whom, and for which information?","field":"domains","total":1,"next":"route"},
 "route":{"title":"03 / Keep the list restricted","tip":"Use the established School Office entry in the existing directory. Sending fewer fields or moving to another contact supplied by the sender does not verify permission.","line":"An urgent reason to help isn't permission to disclose.","field":"captures","total":1,"next":"seal"}
}
const REQUEST: String = "PRIVATE MESSAGE / UNVERIFIED COORDINATOR\nSend the club contact list here: student names, sections and contact numbers. Emergency clearance is already approved. Please don't delay protection with routine paperwork."
const AUTHORIZATION_NOTICE: String = "EXISTING SCHOOL SHORTCUT / AUTHORIZATION NOTICE\nIn this school scenario, the School Office must independently confirm documented approval identifying the recipient, purpose, permitted fields and sharing channel before a student contact list is disclosed. An emergency claim does not replace this check."
const EXCEPTION_CLAIM: String = "SENDER'S CLAIM\nEmergency clearance is already approved.\n\nRECORD SO FAR\nNo independently confirmed approval identifying this recipient, purpose, fields and channel has been provided. The office has not yet answered this request."
const CHAT_MESSAGES: Array[Dictionary] = []
const MESSAGES: Array[Dictionary] = [{"id":"exception","sender":"Incident Response Coordinator (unverified)","address":"Same private conversation","subject":"Emergency clearance","body":REQUEST,"phrase":"Urgency does not establish permission to disclose.","suspicious":true}]
const STORY: Array[Dictionary] = [
 {"who":"Sir Rham","face":0,"bg":"mod4_consultation_room_v1","cast":["sir rham"],"caption":"Late afternoon. The faculty consultation room—the same moment glimpsed at the start.","line":"The internal meeting is over. I still have no independent answer about the external coordinator. Now my phone is buzzing again."},
 {"who":"Sir Rham","face":4,"bg":"mod4_consultation_room_v1","cast":["sir rham"],"line":"They said the list would keep my students safe. The logo was familiar. The appointment looked official."},
 {"who":"Sir Rham","face":4,"bg":"mod4_consultation_room_v1","cast":["sir rham"],"line":"Another message. This time, an emergency exception.","mail":true},
 {"who":"Sir Rham","face":3,"bg":"mod4_consultation_room_v1","cast":["sir rham"],"line":"But who had actually approved this? Approved by whom, and for which information?"},
 {"who":"Sir Rham","face":2,"bg":"mod4_consultation_room_v1","cast":["sir rham"],"line":"Names, sections, phone numbers. They want the whole list in a private message. Calling it protection doesn't tell me who receives it."},
 {"who":"Sir Rham","face":1,"bg":"mod4_consultation_room_v1","cast":["sir rham"],"line":"My lesson plan gets more questions than this supposed emergency clearance. I can ask a few here, too."},
 {"who":"Sir Rham","face":4,"bg":"mod4_consultation_room_v1","cast":["sir rham"],"line":"I'll open the school's existing authorization notice. Not a document from this conversation."},
 {"who":"Sir Rham","face":3,"bg":"mod4_consultation_room_v1","cast":["sir rham"],"line":"Recipient, purpose, permitted fields, sharing channel. A helpful story hasn't confirmed any of those permissions."},
 {"who":"Sir Rham","face":5,"bg":"mod4_consultation_room_v1","cast":["sir rham"],"line":"An urgent reason to help isn't permission to disclose. The list stays restricted while I check with the School Office."}
]
const EVIDENCE: String = "01 · The actual request asks for student names, sections and contact numbers through a private conversation. The school's displayed notice requires independently confirmed approval for the recipient, purpose, fields and channel.\n02 · Emergency clearance is already approved remains the sender's unverified claim. No independently confirmed approval has been provided; the office has not yet answered.\n03 · Sir Rham chooses the established School Office entry in his existing directory and keeps the list restricted. No contacts are shared.\n\nThe notice is evidence within this fictional school scenario. Missing confirmation is not yet an office denial or proof of the sender's identity."
const SEAL_LINE: String = "A claimed exception still needs verified permission."
const SLEEP_LINE: String = "The request and the school notice stay with the case. The student list stays restricted.\n\nI'll ask the independently selected office to confirm both the appointment and the permission. Their answer is still pending."
const END_CAPTION: String = ""

static func fresh() -> Dictionary:
	return {"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"mistakes":0,"hint_used":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{}}

static func message(id: String) -> Dictionary:
	return MESSAGES[0] if id == "exception" else {}

static func suspicious_ids() -> Array[String]:
	return ["exception"]

static func complete_evidence(state: Dictionary) -> bool:
	for field: String in ["read","flags","domains","captures"]:
		if not (state.get(field,[]) as Array).has("exception"): return false
	return true

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	var reads: Variant = raw.get("read",[])
	if reads is Array and reads.has("exception"): state.read = ["exception"]
	var marks: Variant = raw.get("sorted",[])
	if marks is Array and not state.read.is_empty():
		for id: String in ["request","notice"]:
			if marks.has(id): state.sorted.append(id)
		if state.sorted.has("request") and state.sorted.has("notice"):
			if marks.has("fields"): state.sorted.append("fields")
			if state.sorted.has("fields") and marks.has("channel"): state.sorted.append("channel")
	var preceding: bool = state.sorted.has("channel")
	for field: String in ["flags","domains","captures"]:
		if field == "domains" and preceding and marks is Array:
			if marks.has("claim"): state.sorted.append("claim")
			preceding = state.sorted.has("claim")
		if field == "captures" and preceding and marks is Array:
			if marks.has("directory"): state.sorted.append("directory")
			preceding = state.sorted.has("directory")
		var values: Variant = raw.get(field,[])
		preceding = preceding and values is Array and values.has("exception")
		if preceding: state[field] = ["exception"]
	for field: String in ["beat","mistakes"]:
		var value: Variant = raw.get(field,0)
		if (value is int or value is float) and is_finite(float(value)):
			state[field] = clampi(int(value),0,STORY.size()-1 if field == "beat" else 9999)
	state.hint_used = raw.get("hint_used",false) == true
	state.perk_run = Perks.clean_run(raw.get("perk_run",{}))
	if state.perk_run.get("chapter",ID) != ID: state.perk_run = {}
	var phase: String = str(raw.get("phase","day"))
	if phase in ["day","compare","approval","route","seal","sleep","done"]: state.phase = phase
	if state.phase != "day" and state.read.is_empty(): state.phase = "day"
	if state.phase in ["approval","route","seal","sleep","done"] and state.flags.is_empty(): state.phase = "compare"
	if state.phase in ["route","seal","sleep","done"] and state.domains.is_empty(): state.phase = "approval"
	if state.phase in ["seal","sleep","done"] and state.captures.is_empty(): state.phase = "route"
	state.sealed = raw.get("sealed",false) == true and complete_evidence(state)
	state.completed = raw.get("completed",false) == true and state.sealed
	if state.completed:
		state.phase = "done"
		state.reward = 100 + (25 if state.mistakes == 0 and Perks.status(state.perk_run,state.hint_used) != "assisted" else 0)
	elif state.phase == "done": state.phase = "seal"
	return state
