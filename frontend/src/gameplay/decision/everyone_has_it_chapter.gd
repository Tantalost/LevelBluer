extends RefCounted
## Restore the source context of a cropped endorsement before warning the club.
const ID: String = "mod_05_ch_03"
const NUMBER: int = 3
const TITLE: String = "Everyone Already Has It"
const PROTAGONIST: String = "Mika"
const PHONE_PATH: String = "res://src/gameplay/decision/everyone_has_it_phone.gd"
const BACKGROUND_ASSET: String = "story_bg_mod5_sign_shelter_v1"
const NIGHT_BACKGROUND: String = "mod5_sign_shelter_v1"
const DAY_LABEL: String = "LATE MORNING"
const FULL_WIDTH_INVESTIGATION: bool = true
const FIRST_PHASE: String = "compare"
const NEXT_CHAPTER: String = "mod_05_ch_04"
const INVESTIGATION_TAGLINE: String = "What was Amani actually talking about?"
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const QUOTE: String = "Tried it. Looks great!"
const OFFER: String = "Everyone already has the event pack. Even Amani recommends it."
const ORIGINAL: String = "Mika: I hung my hand-painted banner by the walkway. Does the arrow work from the gate?"
const REPLY: String = "That was about Mika's hand-painted banner. Look one message up."
const WARNING: String = "The Event Recovery Desk pack asks you to install an app. Amani's praise was about our banner. Use the pinned club folder for signs. I haven't attached the package."
const TASKS: Dictionary = {
 "compare":{"title":"01 / Restore the context","tip":"Read the supplied crop, then open the original through the existing club chat. Find what was removed.","line":"The same words can point to a different thing.","field":"flags","total":1,"next":"meaning"},
 "meaning":{"title":"02 / Check the endorsement","tip":"Read Mika's banner message and Amani's clarification. What did Amani try?","line":"A familiar name isn't a recommendation for every file.","field":"domains","total":1,"next":"warn"},
 "warn":{"title":"03 / Warn without forwarding","tip":"Name the offer, explain the requested action and point to the pinned club folder. Leave the package out.","line":"The warning should help without spreading the file.","field":"captures","total":1,"next":"seal"}
}
const CHAT_MESSAGES: Array[Dictionary] = []
const MESSAGES: Array[Dictionary] = [{"id":"endorsement","sender":"Event Recovery Desk","address":"Separate offer conversation","subject":"Everyone already has it","body":OFFER+"\nCropped quote: "+QUOTE+" — Amani","phrase":"The supplied crop removes the banner context.","suspicious":true}]
const STORY: Array[Dictionary] = [
 {"who":"Mika","face":1,"bg":NIGHT_BACKGROUND,"cast":["mika"],"caption":"Late morning. Covered sign-painting shelter.","line":"The signs are drying. The helper is still closed. For once, my phone is doing less work than my paintbrush."},
 {"who":"Mika","face":3,"bg":NIGHT_BACKGROUND,"cast":["mika"],"line":"Event Recovery Desk again. Now they're saying Amani tried the pack.","mail":true},
 {"who":"Mika","face":2,"bg":NIGHT_BACKGROUND,"cast":["mika"],"line":"I'll ask her in our existing club chat. I already have that conversation."},
 {"who":"Amani","face":2,"bg":NIGHT_BACKGROUND,"cast":["mika","amani"],"line":"That was about Mika's hand-painted banner. Look one message up."},
 {"who":"Mika","face":2,"bg":NIGHT_BACKGROUND,"cast":["mika","amani"],"line":"They kept your sentence and cut away what you were replying to?"},
 {"who":"Amani","face":0,"bg":NIGHT_BACKGROUND,"cast":["mika","amani"],"line":"I tried following the arrow from the gate. I didn't try their download."},
 {"who":"Liza","face":2,"bg":NIGHT_BACKGROUND,"cast":["mika","liza"],"line":"Can you warn us without sending us the thing?"},
 {"who":"Mika","face":5,"bg":NIGHT_BACKGROUND,"cast":["mika"],"line":"Yes. First I'll keep the crop beside the original. The missing message matters."}
]
const SEAL_LINE: String = "Crop and original saved with their sources. Club warned. No package forwarded."
const EVIDENCE: String = "Event Recovery Desk presents Amani's words as praise for its event pack.\nThe existing club thread shows Mika's hand-painted banner above Amani's reply. Amani confirms she followed its arrow from the gate.\nMika preserves both records and posts a warning pointing classmates to the pinned club folder. The package stays closed and is not forwarded. The crop does not make Amani an accomplice."
const SLEEP_LINE: String = "Warning posted. No attachment. And the arrow has one independently confirmed satisfied customer."
const END_CAPTION: String = ""

static func fresh() -> Dictionary:
	return {"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"mistakes":0,"hint_used":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{}}

static func message(id: String) -> Dictionary:
	return MESSAGES[0] if id == "endorsement" else {}

static func suspicious_ids() -> Array[String]:
	return ["endorsement"]

static func complete_evidence(state: Dictionary) -> bool:
	return state.get("captures",[]).has("endorsement")

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	var read: Variant = raw.get("read")
	var marks: Variant = raw.get("sorted")
	if read is Array and read.has("endorsement"): state.read = ["endorsement"]
	var limit: int = int(not state.read.is_empty())
	if limit == 1 and marks is Array:
		for key: String in ["crop","original"]:
			if marks.has(key): state.sorted.append(key)
		if state.sorted.size() == 2 and _marked(raw,"flags"):
			state.flags = ["endorsement"]
			limit = 2
			if marks.has("clarification"): state.sorted.append("clarification")
			if state.sorted.has("clarification") and _marked(raw,"domains"):
				state.domains = ["endorsement"]
				limit = 3
				if _marked(raw,"captures"):
					state.captures = ["endorsement"]
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
	var phases: Array[String] = ["day","compare","meaning","warn","seal","sleep","done"]
	state.phase = phases[clampi(phases.find(str(raw.get("phase","day"))),0,5 if state.sealed else limit)]
	if state.completed:
		state.phase = "done"
		state.reward = 100 + (25 if state.mistakes == 0 and Perks.status(state.perk_run,state.hint_used) != "assisted" else 0)
	return state

static func _marked(raw: Dictionary, field: String) -> bool:
	var values: Variant = raw.get(field)
	return values is Array and values.has("endorsement")
