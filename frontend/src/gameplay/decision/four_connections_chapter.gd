extends RefCounted
## A service corroborates two deliveries. Attribution remains withheld.
const ID: String = "mod_05_ch_04"
const NUMBER: int = 4
const TITLE: String = "Four Connections"
const PROTAGONIST: String = "Mika"
const PHONE_PATH: String = "res://src/gameplay/decision/four_connections_phone.gd"
const BACKGROUND_ASSET: String = "story_bg_mod5_incident_desk_v1"
const NIGHT_BACKGROUND: String = "mod5_incident_desk_v1"
const DAY_LABEL: String = "AFTERNOON"
const FULL_WIDTH_INVESTIGATION: bool = true
const FIRST_PHASE: String = "route"
const NEXT_CHAPTER: String = "mod_05_ch_05"
const INVESTIGATION_TAGLINE: String = "Two linked deliveries. One unanswered question."
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const Request: GDScript = preload("res://src/gameplay/decision/exception_chapter.gd")
const Gift: GDScript = preload("res://src/gameplay/decision/gift_for_club_chapter.gd")
const REPORT: String = "SCHOOL SUPPORT / SANITIZED DELIVERY REVIEW\nOur service review corroborates a connection between the coordinator request and the event-pack offer. Compare references DL-041 and DL-052 with the preserved messages below. These references are supplied in this new service export.\nDirecting account: WITHHELD — verification pending.\nThis report does not yet establish who directed the earlier survey, text or call. No student contact list is included."
const TASKS: Dictionary = {
 "route":{"title":"01 / Trace the report","tip":"Use the existing school directory, the established School Office and its support case. The suspicious sender did not supply this route.","line":"Who supplied this new evidence?","field":"flags","total":1,"next":"match"},
 "match":{"title":"02 / Pair the deliveries","tip":"Read each service excerpt and inspect its preserved original. Match the contact-list request and the event-pack offer separately.","line":"The references must match the actual messages.","field":"domains","total":1,"next":"note"},
 "note":{"title":"03 / Keep conclusions precise","tip":"Review the earlier case outcomes. The service links these two deliveries; its directing-account field is still withheld.","line":"A connection is confirmed. The directing account is still a question.","field":"captures","total":1,"next":"seal"}
}
const ROUTE: Array[Dictionary] = [
 {"id":"directory","title":"Existing school directory","body":"Sir Rham opens the school's established directory. This shortcut was available before the suspicious messages."},
 {"id":"office","title":"Established School Office","body":"The same independently selected office that denied the coordinator's assignment opens the existing support case."},
 {"id":"case","title":"Support case / delivery review","body":REPORT}
]
const DELIVERIES: Array[Dictionary] = [
 {"id":"coordinator","reference":"DL-041","quote":"Send the club contact list here: student names, sections and contact numbers.","title":"Coordinator's private request"},
 {"id":"pack","reference":"DL-052","quote":"Here's a complete event pack: posters, arrows, room signs and table numbers.","title":"Event Recovery Desk offer"}
]
const EARLIER: Array[Dictionary] = [
 {"id":"survey","title":"John / Survey hearing","body":"John's hearing established Jobert's involvement in his case. That outcome remains intact. This new delivery report does not by itself establish who directed Jobert."},
 {"id":"code","title":"Amani / Device request","body":"Amani rejected the device-approval request and kept the code private. Similar pressure does not establish the same sender."},
 {"id":"call","title":"Liza / Independent support","body":"Liza independently contacted wallet support, which contradicted the supposed security caller. This outcome does not identify the caller's director."}
]
const CHAT_MESSAGES: Array[Dictionary] = []
const MESSAGES: Array[Dictionary] = [{"id":"connections","sender":"School Support","address":"Existing directory / School Office / support case","subject":"Delivery review available","body":REPORT,"phrase":"Two corroborated delivery links; directing account withheld.","suspicious":false}]
const STORY: Array[Dictionary] = [
 {"who":"Mika","face":4,"bg":NIGHT_BACKGROUND,"cast":["mika"],"caption":"Afternoon. Student services incident desk.","line":"My warning is in the club chat. The pack is still closed. Sir Rham asked me to bring the preserved messages."},
 {"who":"Sir Rham","face":4,"bg":NIGHT_BACKGROUND,"cast":["mika","sir rham"],"line":"I opened our support case through the School Office in the existing directory. A delivery review has arrived.","mail":true},
 {"who":"Mika","face":2,"bg":NIGHT_BACKGROUND,"cast":["mika","sir rham"],"line":"Two references. The coordinator request, then the gift offer. They checked the deliveries?"},
 {"who":"Sir Rham","face":3,"bg":NIGHT_BACKGROUND,"cast":["mika","sir rham"],"line":"The report corroborates that connection. We still need to compare its excerpts with our originals."},
 {"who":"Mika","face":2,"bg":NIGHT_BACKGROUND,"cast":["mika","sir rham"],"line":"And the directing account is withheld. So we have a link, but not the answer to who's directing it."},
 {"who":"Sir Rham","face":0,"bg":NIGHT_BACKGROUND,"cast":["mika","sir rham"],"line":"Exactly. Keep John's, Amani's and Liza's findings separate. Similar tricks don't fill a missing account field."},
 {"who":"Mika","face":1,"bg":NIGHT_BACKGROUND,"cast":["mika","sir rham"],"line":"For once, an empty box is telling us something useful: don't guess."},
 {"who":"Sir Rham","face":5,"bg":NIGHT_BACKGROUND,"cast":["mika","sir rham"],"line":"Save what we can support. We'll bring the unanswered question to the hearing."}
]
const SEAL_LINE: String = "Independent report and both originals paired. Directing account still withheld."
const EVIDENCE: String = "The report came through the established school directory, School Office and support case.\nService references DL-041 and DL-052 match the preserved contact-list request and event-pack offer. The service corroborates a connection between these two deliveries.\nThe directing account remains withheld pending verification. Earlier case outcomes stay separate; this report alone does not attribute the wider campaign."
const SLEEP_LINE: String = "Two deliveries linked. Our earlier findings kept intact.\n\nMy question for the hearing: Who directed the switch?"
const END_CAPTION: String = ""

static func record(id: String) -> Dictionary:
	if id == "coordinator": return {"title":"PRESERVED ORIGINAL / MODULE 4", "body":Request.REQUEST}
	if id == "pack": return {"title":"PRESERVED ORIGINAL / MODULE 5", "body":str(Gift.MESSAGES[0].body)}
	return {}

static func fresh() -> Dictionary:
	return {"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"mistakes":0,"hint_used":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{}}

static func message(id: String) -> Dictionary:
	return MESSAGES[0] if id == "connections" else {}

static func suspicious_ids() -> Array[String]:
	return ["connections"]

static func complete_evidence(state: Dictionary) -> bool:
	return state.get("captures",[]).has("connections")

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	var read: Variant = raw.get("read")
	var marks: Variant = raw.get("sorted")
	if read is Array and read.has("connections"): state.read = ["connections"]
	var limit: int = int(not state.read.is_empty())
	if limit == 1 and marks is Array:
		for step: Dictionary in ROUTE:
			var key: String = "route_"+str(step.id)
			if not marks.has(key): break
			state.sorted.append(key)
		if state.sorted.size() == ROUTE.size() and _marked(raw,"flags"):
			state.flags = ["connections"]
			limit = 2
			for item: Dictionary in DELIVERIES:
				var key: String = str(item.id)
				if marks.has("read_"+key): state.sorted.append("read_"+key)
				if state.sorted.has("read_"+key) and marks.has("match_"+key): state.sorted.append("match_"+key)
			if state.sorted.has("match_coordinator") and state.sorted.has("match_pack") and _marked(raw,"domains"):
				state.domains = ["connections"]
				limit = 3
				for item: Dictionary in EARLIER:
					if marks.has("case_"+str(item.id)): state.sorted.append("case_"+str(item.id))
				if state.sorted.has("case_survey") and state.sorted.has("case_code") and state.sorted.has("case_call") and _marked(raw,"captures"):
					state.captures = ["connections"]
					limit = 4
	for key: String in ["beat","mistakes"]:
		var value: Variant = raw.get(key)
		if (value is int or value is float) and is_finite(float(value)):
			state[key] = clampi(int(value),0,STORY.size()-1 if key == "beat" else 9999)
	state.hint_used = raw.get("hint_used",false) == true
	state.perk_run = Perks.clean_run(raw.get("perk_run",{}))
	if state.perk_run.get("chapter",ID) != ID: state.perk_run = {}
	state.sealed = limit == 4 and raw.get("sealed",false) == true
	state.completed = state.sealed and raw.get("completed",false) == true
	var phases: Array[String] = ["day","route","match","note","seal","sleep","done"]
	state.phase = phases[clampi(phases.find(str(raw.get("phase","day"))),0,5 if state.sealed else limit)]
	if state.completed:
		state.phase = "done"
		state.reward = 100 + (25 if state.mistakes == 0 and Perks.status(state.perk_run,state.hint_used) != "assisted" else 0)
	return state

static func _marked(raw: Dictionary, field: String) -> bool:
	var values: Variant = raw.get(field)
	return values is Array and values.has("connections")
