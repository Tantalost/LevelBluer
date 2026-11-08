extends RefCounted
## Mika's coached baiting case. The supplier's reply belongs to Chapter 2.
const ID: String = "mod_05_ch_01"
const NUMBER: int = 1
const TITLE: String = "A Gift for the Club"
const PROTAGONIST: String = "Mika"
const PHONE_PATH: String = "res://src/gameplay/decision/gift_for_club_phone.gd"
const BACKGROUND_ASSET: String = "story_bg_mod5_auditorium_wings_v1"
const NIGHT_BACKGROUND: String = "mod5_auditorium_wings_v1"
const DAY_LABEL: String = "EVENING"
const FULL_WIDTH_INVESTIGATION: bool = true
const INVESTIGATION_TAGLINE: String = "The signs are ready. Who made them?"
const FIRST_PHASE: String = "offer"
const NEXT_CHAPTER: String = "mod_05_ch_02"
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const TASKS: Dictionary = {
 "offer":{"title":"01 / Inspect the offer","tip":"You can read the promised items. The sender's role still needs a separate check.","line":"A promise I can read. A role I need to check.","field":"flags","total":1,"next":"sources"},
 "sources":{"title":"02 / Trace the sources","tip":"Open both records. The club's pinned plan puts the design desk in charge of the signs.","line":"Who supplied each record?","field":"domains","total":1,"next":"route"},
 "route":{"title":"03 / Ask the design desk","tip":"Go through the contact pinned in the established club chat.","line":"I'll check where we booked the work.","field":"captures","total":1,"next":"seal"}
}
const PLAN: String = "CLUB EVENT CHAT / PINNED MATERIALS PLAN\nPosters, signs and table numbers: Student Design Desk. Collect the artwork in our established club folder.\nContact: Design Desk (pinned by the club)."
const CHAT_MESSAGES: Array[Dictionary] = []
const MESSAGES: Array[Dictionary] = [{"id":"gift","sender":"Event Recovery Desk","address":"Separate incoming conversation","subject":"Your event materials are ready","body":"You've had enough disruptions. Here's a complete event pack: posters, arrows, room signs and table numbers. Our desk prepared it for your club. For confirmation, reply to our verification desk here.","phrase":"A useful offer still needs a source check.","suspicious":true}]
const STORY: Array[Dictionary] = [
 {"who":"Mika","face":1,"bg":NIGHT_BACKGROUND,"cast":["mika"],"caption":"Auditorium wings, early evening. A few minutes after the hearing.","line":"There. One arrow pointing at the auditorium instead of the broom closet."},
 {"who":"John","face":1,"bg":NIGHT_BACKGROUND,"cast":["mika","john"],"line":"The broom closet thanks you. What was that message during the hearing?"},
 {"who":"Mika","face":3,"bg":NIGHT_BACKGROUND,"cast":["mika","john"],"line":"It's still unread. Let me see what they offered.","mail":true},
 {"who":"Mika","face":0,"bg":NIGHT_BACKGROUND,"cast":["mika","john"],"line":"They even have table numbers. That would give us our whole evening back."},
 {"who":"John","face":4,"bg":NIGHT_BACKGROUND,"cast":["mika","john"],"line":"Did we order table numbers from them?"},
 {"who":"Mika","face":2,"bg":NIGHT_BACKGROUND,"cast":["mika","john"],"line":"I wished for them quite loudly. I don't think that counts."},
 {"who":"Mika","face":3,"bg":NIGHT_BACKGROUND,"cast":["mika"],"line":"We pinned the materials plan in our club chat. I'll compare it with the offer before I touch the pack."}
]
const SEAL_LINE: String = "Offer preserved. Pack unopened. Design desk contacted."
const EVIDENCE: String = "The offer promises finished event materials. The sender claims to have prepared them for the club.\nThe club's own pinned plan names the Student Design Desk and established club folder.\nMika saved the offer and asked the pinned contact to confirm. The reply is pending."
const SLEEP_LINE: String = "Keep the crooked arrow, John. It's the only sign whose maker I can personally identify."
const END_CAPTION: String = ""
const REVIEW_MARKS: Array[String] = ["offer_open","offer_source","plan_open","plan_source","contact_open"]

static func fresh() -> Dictionary:
	return {"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"mistakes":0,"hint_used":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{}}

static func message(id: String) -> Dictionary:
	return MESSAGES[0] if id == "gift" else {}

static func suspicious_ids() -> Array[String]:
	return ["gift"]

static func complete_evidence(state: Dictionary) -> bool:
	return state.get("captures",[]).has("gift")

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	var marks: Variant = raw.get("sorted",[])
	var valid: bool = true
	for field: String in ["read","flags","domains","captures"]:
		if field == "domains" and valid:
			for id: String in REVIEW_MARKS.slice(0,4):
				if marks is Array and marks.has(id) and (not id.ends_with("_source") or state.sorted.has(id.replace("_source","_open"))):
					state.sorted.append(id)
			valid = state.sorted.size() == 4
		if field == "captures" and valid:
			valid = marks is Array and marks.has("contact_open")
			if valid: state.sorted.append("contact_open")
		var values: Variant = raw.get(field,[])
		valid = valid and values is Array and values.has("gift")
		if valid: state[field] = ["gift"]
	for key: String in ["mistakes","beat"]:
		var value: Variant = raw.get(key,0)
		if (value is int or value is float) and is_finite(float(value)):
			state[key] = clampi(int(value),0,STORY.size()-1 if key == "beat" else 9999)
	state.hint_used = raw.get("hint_used",false) == true
	state.perk_run = Perks.clean_run(raw.get("perk_run",{}))
	if state.perk_run.get("chapter",ID) != ID: state.perk_run = {}
	var phases: Array[String] = ["day","offer","sources","route","seal","sleep","done"]
	var limit: int = 0
	for field: String in ["read","flags","domains","captures"]:
		if state[field].is_empty(): break
		limit += 1
	state.sealed = limit == 4 and raw.get("sealed",false) == true
	state.completed = state.sealed and raw.get("completed",false) == true
	if state.sealed: limit = 5
	state.phase = phases[clampi(phases.find(str(raw.get("phase","day"))),0,limit)]
	if state.completed:
		state.phase = "done"
		state.reward = 100 + (25 if state.mistakes == 0 and Perks.status(state.perk_run,state.hint_used) != "assisted" else 0)
	return state
