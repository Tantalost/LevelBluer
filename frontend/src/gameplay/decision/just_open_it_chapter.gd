extends RefCounted
## Coached inspection of an inert attachment record.
const ID: String = "mod_05_ch_02"
const NUMBER: int = 2
const TITLE: String = "Just Open It"
const PROTAGONIST: String = "Mika"
const PHONE_PATH: String = "res://src/gameplay/decision/just_open_it_phone.gd"
const BACKGROUND_ASSET: String = "story_bg_mod5_print_studio_v1"
const NIGHT_BACKGROUND: String = "mod5_print_studio_v1"
const DAY_LABEL: String = "MORNING"
const FULL_WIDTH_INVESTIGATION: bool = true
const FIRST_PHASE: String = "sources"
const NEXT_CHAPTER: String = "mod_05_ch_03"
const INVESTIGATION_TAGLINE: String = "What would opening this actually do?"
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const REPLY: String = "Our signs are in the club folder. We didn't send a helper."
const INSTRUCTION: String = "The preview shows our finished poster. Install our Preview Helper and allow installation from this source to see the full set."
const TASKS: Dictionary = {
 "sources":{"title":"01 / Check who replied","tip":"Compare the reply from the pinned design desk with the message asking you to install a helper.","line":"Who actually asked me to install it?","field":"flags","total":1,"next":"inspect"},
 "inspect":{"title":"02 / Inspect the attachment","tip":"Tap the poster, file details and requested setting. Read what the phone would be asked to do.","line":"The thumbnail and the file tell different stories.","field":"domains","total":1,"next":"preserve"},
 "preserve":{"title":"03 / Keep the evidence","tip":"Keep the package closed. Save its details and the independently reached desk's reply.","line":"I can keep the record without opening the package.","field":"captures","total":1,"next":"seal"}
}
const PARTS: Dictionary = {
 "preview":"The thumbnail shows a cream event poster and a teal arrow. An image in a message can depict anything.",
 "type":"EventPreview.apk · Android app package. The attachment is software. Its file type alone does not establish whether it contains malware.",
 "permission":"The sender asks Mika to allow installation from this source. That setting would permit an installation attempt. Mika has kept it off."
}
const CHAT_MESSAGES: Array[Dictionary] = []
const MESSAGES: Array[Dictionary] = [{"id":"desk","sender":"Student Design Desk","address":"Established club chat / pinned contact","subject":"Re: Did you send the event pack?","body":REPLY,"phrase":"The independent supplier denies sending the helper.","suspicious":false},{"id":"helper","sender":"Event Recovery Desk","address":"Separate offer conversation","subject":"Just open the preview","body":INSTRUCTION,"phrase":"The supplied attachment requests installation.","suspicious":true}]
const STORY: Array[Dictionary] = [
 {"who":"Mika","face":1,"bg":NIGHT_BACKGROUND,"cast":["mika"],"caption":"The next morning. School print and design studio.","line":"Table six is drying. Table nine is also drying, because I painted one card upside down."},
 {"who":"Mika","face":3,"bg":NIGHT_BACKGROUND,"cast":["mika"],"line":"There's a reply to the question I sent last night. Same pinned design-desk conversation.","mail":true},
 {"who":"John","face":4,"bg":NIGHT_BACKGROUND,"cast":["mika","john"],"line":"So the signs are in the club folder. Where did the helper come from?"},
 {"who":"Mika","face":3,"bg":NIGHT_BACKGROUND,"cast":["mika","john"],"line":"The other conversation. Event Recovery Desk sent a poster thumbnail and instructions to install a preview helper."},
 {"who":"Mika","face":2,"bg":NIGHT_BACKGROUND,"cast":["mika","john"],"line":"I asked to see a poster. Why am I being asked to install anything?"},
 {"who":"John","face":4,"bg":NIGHT_BACKGROUND,"cast":["mika","john"],"line":"Can you see the file details without opening it?"},
 {"who":"Mika","face":3,"bg":NIGHT_BACKGROUND,"cast":["mika"],"line":"Right here in the message. Let's read the details first."}
]
const SEAL_LINE: String = "Desk reply saved. Package closed. Installation setting unchanged."
const EVIDENCE: String = "The pinned Student Design Desk says it did not send a helper. The separate offer asks Mika to install one.\nThe thumbnail depicts a poster. The attached file is an Android app package and the sender asks to allow installation from this source.\nMika preserved the message, metadata and reply. She kept the package closed."
const SLEEP_LINE: String = "The club folder has the signs we actually ordered. I'll start with table six. Or nine."
const END_CAPTION: String = ""

static func fresh() -> Dictionary:
	return {"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"mistakes":0,"hint_used":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{}}

static func message(id: String) -> Dictionary:
	for item: Dictionary in MESSAGES:
		if item.id == id: return item
	return {}

static func suspicious_ids() -> Array[String]:
	return ["helper"]

static func complete_evidence(state: Dictionary) -> bool:
	return state.get("captures",[]).has("helper")

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	var read: Variant = raw.get("read")
	var marks: Variant = raw.get("sorted")
	if read is Array and read.has("desk"): state.read = ["desk"]
	var limit: int = int(not state.read.is_empty())
	if limit == 1 and marks is Array:
		for key: String in ["desk_record","offer_record"]:
			if marks.has(key): state.sorted.append(key)
		if state.sorted.size() == 2 and _marked(raw,"flags"):
			state.flags = ["helper"]
			limit = 2
			for part: String in PARTS:
				if marks.has(part): state.sorted.append(part)
			if state.sorted.size() == 5 and _marked(raw,"domains"):
				state.domains = ["helper"]
				limit = 3
				if _marked(raw,"captures"):
					state.captures = ["helper"]
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
	var phases: Array[String] = ["day","sources","inspect","preserve","seal","sleep","done"]
	state.phase = phases[clampi(phases.find(str(raw.get("phase","day"))),0,5 if state.sealed else limit)]
	if state.completed:
		state.phase = "done"
		state.reward = 100 + (25 if state.mistakes == 0 and Perks.status(state.perk_run,state.hint_used) != "assisted" else 0)
	return state

static func _marked(raw: Dictionary, field: String) -> bool:
	var values: Variant = raw.get(field)
	return values is Array and values.has("helper")
