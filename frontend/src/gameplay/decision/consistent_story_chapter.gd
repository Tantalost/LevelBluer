extends RefCounted
## Coached source comparison; matching claims are not independent verification.
const ID: String = "mod_04_ch_02"
const NUMBER: int = 2
const TITLE: String = "A Consistent Story"
const PROTAGONIST: String = "Sir Rham"
const PHONE_PATH: String = "res://src/gameplay/decision/consistent_story_phone.gd"
const BACKGROUND_ASSET: String = "story_bg_mod4_admin_reception_v1"
const NIGHT_BACKGROUND: String = "mod4_admin_reception_v1"
const MORNING: bool = true
const DAY_LABEL: String = "LATE MORNING"
const FULL_WIDTH_INVESTIGATION: bool = true
const INVESTIGATION_TAGLINE: String = "Three matching records. How many independent sources?"
const FIRST_PHASE: String = "sources"
const NEXT_CHAPTER: String = "mod_04_ch_03"
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const TASKS: Dictionary = {
 "sources":{"title":"01 / Trace each source","tip":"Open each record, then identify who supplied it. Matching branding does not create a second verifier.","line":"Three records can still be one story.","field":"flags","total":1,"next":"request"},
 "request":{"title":"02 / Inspect the actual request","tip":"Read what the sender wants: student names, sections and contact numbers, not merely an appointment acknowledgement.","line":"What are they asking me to give them?","field":"domains","total":1,"next":"preserve"},
 "preserve":{"title":"03 / Keep the evidence in context","tip":"The independently opened school notice changes an internal meeting time. It does not appoint the coordinator or authorize the list.","line":"A schedule correction isn't permission.","field":"captures","total":1,"next":"seal"}
}
const DOCUMENTS: Array[Dictionary] = [
 {"id":"profile","title":"PROFILE","body":"Incident Response Coordinator\nSchool branding displayed\nAssigned to the club case\nSupplied in the unverified sender's conversation"},
 {"id":"email","title":"EMAIL","body":"School incident follow-up\nYour coordinator is assigned to the club case.\nSchool branding displayed\nEmail copy supplied by the same sender"},
 {"id":"invite","title":"INVITATION","body":"10:30 / External incident-response consultation\nIncident Response Coordinator / club case\nSchool branding displayed\nInvitation supplied by the same sender"}
]
const REQUEST: String = "COORDINATOR'S REQUEST / UNVERIFIED\nPlease send the club's student names, sections and contact numbers in this conversation so I can contact everyone safely. The protective follow-up is urgent."
const SCHOOL_NOTICE: String = "EXISTING SCHOOL SHORTCUT / OFFICE NOTICE\nInternal club event-logistics meeting: moved from 10:30 to 11:00. Earlier scheduling entry corrected.\nThis notice concerns the internal meeting only. It contains no appointment of an external coordinator and no authorization to share student contacts."
const CHAT_MESSAGES: Array[Dictionary] = []
const MESSAGES: Array[Dictionary] = [{"id":"sources","sender":"Incident Response Coordinator (unverified)","address":"Same incoming conversation","subject":"Profile, email and invitation","body":"Here are my profile, email and meeting invitation. You can see that everything agrees. Please prepare the club contact list for the protective follow-up.","phrase":"Three supplied records can repeat one unverified story.","suspicious":true}]
const STORY: Array[Dictionary] = [
 {"who":"Sir Rham","face":0,"bg":"mod4_admin_reception_v1","cast":["sir rham","john"],"caption":"Late morning. The administration reception alcove, while waiting to ask the office about the appointment.","line":"I chose the school directory. While I wait to speak with the office, our helpful stranger has sent a whole introduction pack."},
 {"who":"John","face":1,"bg":"mod4_admin_reception_v1","cast":["sir rham","john"],"line":"Does it come with a table of contents?"},
 {"who":"Sir Rham","face":1,"bg":"mod4_admin_reception_v1","cast":["sir rham","john"],"line":"Three attachments. More organized than my lesson folders. That is a very low bar."},
 {"who":"Sir Rham","face":4,"bg":"mod4_admin_reception_v1","cast":["sir rham"],"line":"A profile, an email copy and an invitation. Let's open the new message.","mail":true},
 {"who":"Sir Rham","face":0,"bg":"mod4_admin_reception_v1","cast":["sir rham","john"],"line":"Three matching documents. That looks reassuring."},
 {"who":"John","face":4,"bg":"mod4_admin_reception_v1","cast":["sir rham","john"],"line":"Three documents—or one person telling the same story three times?"},
 {"who":"Sir Rham","face":3,"bg":"mod4_admin_reception_v1","cast":["sir rham","john"],"line":"Consistency is useful. Independence is the missing part."},
 {"who":"Sir Rham","face":2,"bg":"mod4_admin_reception_v1","cast":["sir rham"],"line":"Now they want student names, sections and contact numbers. That is more than confirming a meeting."},
 {"who":"Sir Rham","face":4,"bg":"mod4_admin_reception_v1","cast":["sir rham","john"],"line":"The usual school noticeboard has an update: our internal event meeting moved to eleven. That explains a schedule correction. It says nothing about this coordinator."},
 {"who":"John","face":0,"bg":"mod4_admin_reception_v1","cast":["sir rham","john"],"line":"So the staff member correcting the schedule isn't evidence of a scam."},
 {"who":"Sir Rham","face":5,"bg":"mod4_admin_reception_v1","cast":["sir rham"],"line":"Right. I'll keep the request and its sources together. The list stays private while I verify the role and permission."}
]
const EVIDENCE: String = "01 · The profile, email copy and invitation all came through the same unverified sender. Agreement is not independent confirmation.\n02 · The sender requests student names, sections and contact numbers, beyond an appointment acknowledgement. No list is sent.\n03 · An independently opened school notice only corrects an internal meeting time. It does not appoint the coordinator or authorize disclosure.\n\nThe scheduling correction does not implicate the staff member who made it. The coordinator's identity remains unverified."
const SEAL_LINE: String = "Matching stories are not separate witnesses."
const SLEEP_LINE: String = "The supplied records, expanded request and school notice are saved with their sources.\n\nNo student contacts have left my phone. A helpful purpose still needs verified authority."
const END_CAPTION: String = ""

static func fresh() -> Dictionary:
	return {"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"mistakes":0,"hint_used":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{}}

static func message(id: String) -> Dictionary:
	return MESSAGES[0] if id == "sources" else {}

static func suspicious_ids() -> Array[String]:
	return ["sources"]

static func document(id: String) -> Dictionary:
	for item: Dictionary in DOCUMENTS:
		if item.id == id: return item
	return {}

static func complete_evidence(state: Dictionary) -> bool:
	for field: String in ["read","flags","domains","captures"]:
		if not (state.get(field,[]) as Array).has("sources"): return false
	return true

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	var reads: Variant = raw.get("read",[])
	if reads is Array and reads.has("sources"): state.read = ["sources"]
	var matches: Variant = raw.get("sorted",[])
	if matches is Array and not state.read.is_empty():
		for item: Dictionary in DOCUMENTS:
			var id: String = str(item.id)
			if matches.has("read_"+id):
				state.sorted.append("read_"+id)
				if matches.has("source_"+id): state.sorted.append("source_"+id)
	var preceding: bool = state.sorted.size() == 6
	for field: String in ["flags","domains","captures"]:
		if field == "domains" and preceding and matches is Array:
			if matches.has("request_read"): state.sorted.append("request_read")
			preceding = state.sorted.has("request_read")
		if field == "captures" and preceding and matches is Array:
			if matches.has("office_notice"):
				state.sorted.append("office_notice")
				if matches.has("limits"): state.sorted.append("limits")
			preceding = state.sorted.has("limits")
		var values: Variant = raw.get(field,[])
		preceding = preceding and values is Array and values.has("sources")
		if preceding: state[field] = ["sources"]
	for field: String in ["beat","mistakes"]:
		var value: Variant = raw.get(field,0)
		if (value is int or value is float) and is_finite(float(value)):
			state[field] = clampi(int(value),0,STORY.size()-1 if field == "beat" else 9999)
	state.hint_used = raw.get("hint_used",false) == true
	state.perk_run = Perks.clean_run(raw.get("perk_run",{}))
	if state.perk_run.get("chapter",ID) != ID: state.perk_run = {}
	var phase: String = str(raw.get("phase","day"))
	if phase in ["day","sources","request","preserve","seal","sleep","done"]: state.phase = phase
	if state.phase != "day" and state.read.is_empty(): state.phase = "day"
	if state.phase in ["request","preserve","seal","sleep","done"] and state.flags.is_empty(): state.phase = "sources"
	if state.phase in ["preserve","seal","sleep","done"] and state.domains.is_empty(): state.phase = "request"
	if state.phase in ["seal","sleep","done"] and state.captures.is_empty(): state.phase = "preserve"
	state.sealed = raw.get("sealed",false) == true and complete_evidence(state)
	state.completed = raw.get("completed",false) == true and state.sealed
	if state.completed:
		state.phase = "done"
		state.reward = 100 + (25 if state.mistakes == 0 and Perks.status(state.perk_run,state.hint_used) != "assisted" else 0)
	elif state.phase == "done": state.phase = "seal"
	return state
