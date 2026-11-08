extends RefCounted
## Independent confirmation, limited conclusions, and a source-preserving case record.
const ID: String = "mod_04_ch_04"
const NUMBER: int = 4
const TITLE: String = "Ask the Real Office"
const PROTAGONIST: String = "Sir Rham"
const PHONE_PATH: String = "res://src/gameplay/decision/real_office_phone.gd"
const BACKGROUND_ASSET: String = "story_bg_mod4_records_office_v1"
const NIGHT_BACKGROUND: String = "mod4_records_office_v1"
const DAY_LABEL: String = "LATE AFTERNOON"
const FULL_WIDTH_INVESTIGATION: bool = true
const INVESTIGATION_TAGLINE: String = "An independent answer. Keep its limits clear."
const FIRST_PHASE: String = "route"
const NEXT_CHAPTER: String = "mod_04_ch_05"
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const Appointment: GDScript = preload("res://src/gameplay/decision/here_to_help_chapter.gd")
const ExceptionChapter: GDScript = preload("res://src/gameplay/decision/exception_chapter.gd")
const TASKS: Dictionary = {
 "route":{"title":"01 / Trace the office response","tip":"Follow the existing school directory to School Office, then its response. The route was chosen outside the unverified conversation.","line":"Who did I ask, and how did I reach them?","field":"flags","total":1,"next":"match"},
 "match":{"title":"02 / Match statement to conclusion","tip":"No assignment contradicts the coordinator role. No approval contradicts permission for this request. Neither statement identifies the operator or guarantees every system is safe.","line":"Let the office's words set the limits.","field":"domains","total":1,"next":"report"},
 "report":{"title":"03 / Preserve the case record","tip":"Review and attach the supplied appointment, actual private request and independent office response. Keep their sources. The student roster and culprit guesses do not belong in this record.","line":"Keep the messages, not the student list.","field":"captures","total":1,"next":"seal"}
}
const OFFICE_REPLY: String = "SCHOOL OFFICE / INDEPENDENT DIRECTORY ROUTE\nWe have not assigned an external coordinator to this club case. We did not approve this request for student contacts. The internal event meeting was separate. Keep the original messages for review."
const ROUTE: Array[Dictionary] = [
 {"id":"directory","title":"SCHOOL DIRECTORY","body":"The existing school shortcut Sir Rham used before this response. It was not a link or contact supplied by the unverified coordinator."},
 {"id":"office","title":"SCHOOL OFFICE","body":"The established office entry selected through that directory. Sir Rham asks about both the external appointment and permission to share contacts."},
 {"id":"reply","title":"OFFICE RESPONSE","body":OFFICE_REPLY}
]
const MATCHES: Array[Dictionary] = [
 {"id":"assignment","quote":"We have not assigned an external coordinator to this club case.","question":"What does this statement establish?","correct":"NO ASSIGNMENT TO THIS CASE","wrong":"EVERY SCHOOL ACCOUNT IS SAFE","explanation":"The office denies this assignment. It does not report the security of every school account."},
 {"id":"permission","quote":"We did not approve this request for student contacts.","question":"Which claim does this contradict?","correct":"THIS REQUEST WAS APPROVED","wrong":"THE MEETING TIME WAS CORRECTED","explanation":"The denial concerns permission for this contact request. A separate meeting-time correction does not establish or refute that permission."},
 {"id":"limits","quote":"No assignment. No approval for this request.","question":"How far can the conclusion go?","correct":"FALSE CLAIMS IN THIS CASE","wrong":"THE OPERATOR IS IDENTIFIED","explanation":"The response contradicts the assignment and approval claims in this case. It does not identify who operated the contact."}
]
const CHAT_MESSAGES: Array[Dictionary] = []
const MESSAGES: Array[Dictionary] = [{"id":"office","sender":"School Office","address":"Existing school directory / School Office","subject":"Appointment and authorization response","body":OFFICE_REPLY,"phrase":"An independent denial of this assignment and request, not an operator identification.","suspicious":false}]
const STORY: Array[Dictionary] = [
 {"who":"Sir Rham","face":4,"bg":"mod4_records_office_v1","cast":["sir rham"],"caption":"Late afternoon. The records-office consultation counter.","line":"I followed the School Office entry from the existing directory. My list is still restricted. This time, I'm asking the office itself."},
 {"who":"Sir Rham","face":3,"bg":"mod4_records_office_v1","cast":["sir rham"],"line":"Please confirm both the appointment and the request. A real role would still need the right permission."},
 {"who":"Sir Rham","face":4,"bg":"mod4_records_office_v1","cast":["sir rham"],"line":"The reply has arrived through the office route I selected. Let's keep the actual words.","mail":true},
 {"who":"Sir Rham","face":2,"bg":"mod4_records_office_v1","cast":["sir rham"],"line":"No external coordinator assigned to this case. No approval for this request. That's the independent answer I was missing."},
 {"who":"Sir Rham","face":0,"bg":"mod4_records_office_v1","cast":["sir rham"],"line":"The internal meeting was separate. Its schedule correction wasn't evidence against the staff member who made it."},
 {"who":"Sir Rham","face":1,"bg":"mod4_records_office_v1","cast":["sir rham"],"line":"The most useful message today has no dramatic logo. Just a clear answer to the questions I actually asked."},
 {"who":"Sir Rham","face":3,"bg":"mod4_records_office_v1","cast":["sir rham"],"line":"That exposes the false claims. It still doesn't tell me who sent them—or guarantee that every account is safe."},
 {"who":"Sir Rham","face":5,"bg":"mod4_records_office_v1","cast":["sir rham"],"line":"Now I have an independent answer. I'll preserve what arrived and keep the list restricted. The case record gets the messages, not my students' contacts."}
]
const EVIDENCE: String = "01 · Sir Rham reaches the School Office through his existing school directory, outside the unverified sender's conversation.\n02 · The office explicitly denies assigning an external coordinator to this club case and approving this request for student contacts. The internal meeting was separate. These findings contradict the claims in this case; they do not identify the operator or guarantee system-wide safety.\n03 · The supplied appointment, actual private request and independent office response are retained together with their sources. The student roster is excluded."
const SEAL_LINE: String = "An independent answer makes the contradiction clear."
const SLEEP_LINE: String = "The original appointment, private request and office response are preserved for review. The student list remains restricted.\n\nThe claims are contradicted. The operator's identity remains unknown. Next, we can explain how the story tried to turn trust into permission."
const END_CAPTION: String = ""

static func fresh() -> Dictionary:
	return {"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"mistakes":0,"hint_used":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{}}

static func message(id: String) -> Dictionary:
	return MESSAGES[0] if id == "office" else {}

static func suspicious_ids() -> Array[String]:
	# Shared evidence API; this ID represents the response, not a suspicious verdict.
	return ["office"]

static func report_record(id: String) -> Dictionary:
	match id:
		"appointment": return {"title":"SUPPLIED APPOINTMENT / UNVERIFIED SENDER","body":str(Appointment.MESSAGES[0].body)}
		"request": return {"title":"PRIVATE REQUEST / UNVERIFIED SENDER","body":ExceptionChapter.REQUEST}
		"reply": return {"title":"OFFICE RESPONSE / EXISTING DIRECTORY","body":OFFICE_REPLY}
	return {}

static func complete_evidence(state: Dictionary) -> bool:
	for field: String in ["read","flags","domains","captures"]:
		if not (state.get(field,[]) as Array).has("office"): return false
	return true

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	var reads: Variant = raw.get("read",[])
	if reads is Array and reads.has("office"): state.read = ["office"]
	var marks: Variant = raw.get("sorted",[])
	if marks is Array and not state.read.is_empty():
		for item: Dictionary in ROUTE:
			var id: String = "route_"+str(item.id)
			if not marks.has(id): break
			state.sorted.append(id)
	var preceding: bool = state.sorted.has("route_reply")
	for field: String in ["flags","domains","captures"]:
		if field == "domains" and preceding and marks is Array:
			for item: Dictionary in MATCHES:
				var id: String = "match_"+str(item.id)
				if not marks.has(id): break
				state.sorted.append(id)
			preceding = state.sorted.has("match_limits")
		if field == "captures" and preceding and marks is Array:
			for id: String in ["appointment","request","reply"]:
				if marks.has("report_"+id): state.sorted.append("report_"+id)
			preceding = state.sorted.has("report_appointment") and state.sorted.has("report_request") and state.sorted.has("report_reply")
		var values: Variant = raw.get(field,[])
		preceding = preceding and values is Array and values.has("office")
		if preceding: state[field] = ["office"]
	for field: String in ["beat","mistakes"]:
		var value: Variant = raw.get(field,0)
		if (value is int or value is float) and is_finite(float(value)):
			state[field] = clampi(int(value),0,STORY.size()-1 if field == "beat" else 9999)
	state.hint_used = raw.get("hint_used",false) == true
	state.perk_run = Perks.clean_run(raw.get("perk_run",{}))
	if state.perk_run.get("chapter",ID) != ID: state.perk_run = {}
	var phase: String = str(raw.get("phase","day"))
	if phase in ["day","route","match","report","seal","sleep","done"]: state.phase = phase
	if state.phase != "day" and state.read.is_empty(): state.phase = "day"
	if state.phase in ["match","report","seal","sleep","done"] and state.flags.is_empty(): state.phase = "route"
	if state.phase in ["report","seal","sleep","done"] and state.domains.is_empty(): state.phase = "match"
	if state.phase in ["seal","sleep","done"] and state.captures.is_empty(): state.phase = "report"
	state.sealed = raw.get("sealed",false) == true and complete_evidence(state)
	state.completed = raw.get("completed",false) == true and state.sealed
	if state.completed:
		state.phase = "done"
		state.reward = 100 + (25 if state.mistakes == 0 and Perks.status(state.perk_run,state.hint_used) != "assisted" else 0)
	elif state.phase == "done": state.phase = "seal"
	return state
