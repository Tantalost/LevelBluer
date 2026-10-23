extends RefCounted
## Authored Chapter 1 content and validation. No scene, account or network access.
const ID: String = "mod_01_ch_01"
const NUMBER: int = 1
const TITLE: String = "The Survey"
const NIGHT_BACKGROUND: String = "john_desk_night"
const FIRST_PHASE: String = "sort"
const TASKS: Dictionary = {
	"sort":{"title":"01 / Sort the inbox", "tip":"Open a message, then drag or tap to sort.", "line":"Six messages. Which ones deserve another look?", "field":"sorted", "total":6, "next":"highlight"},
	"highlight":{"title":"02 / Read between the lines", "tip":"Tap the request that feels wrong.", "line":"Something about these requests feels off.", "field":"flags", "total":3, "next":"notes"},
	"notes":{"title":"03 / Trace the senders", "tip":"Check Mail → record the domain in Notepad.", "line":"Alright, what else feels wrong? Who actually sent these?", "field":"domains", "total":3, "next":"capture"},
	"capture":{"title":"04 / Keep the context", "tip":"Frame the sender, subject and request.", "line":"I'd better keep a copy. The sender, the subject, the whole request.", "field":"captures", "total":3, "next":"seal"}
}
const EVIDENCE: String = "3 evidence bundles\n\n01 · Three message captures\n02 · Sender-domain notes\n03 · Payment, pressure and personal-data clues\n\nA typo or free mailbox alone is not proof. Keep each clue connected to its request."
const SEAL_LINE: String = "I still don't know who the client is. But now I have something more useful than a feeling."
const SLEEP_LINE: String = "I put my phone down. Eric said he knew the client. Tomorrow, I'll ask him again.\n\nFor now, I need some sleep."
const END_CAPTION: String = ""
const BASE_REWARD: int = 100
const CLEAN_BONUS: int = 25
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const MESSAGES: Array[Dictionary] = [
	{"id":"club", "sender":"Jobert", "address":"jobert@club.school.example", "subject":"Tomorrow's club meeting", "body":"Meeting at 3 PM in our usual clubroom. The same details are on the club noticeboard. Bring your project notes.", "suspicious":false},
	{"id":"survey", "sender":"Survey Rewards Team", "address":"survey.rewards@gmail.com", "subject":"Your first survey job", "body":"Thanks for joining!", "suspicious":true, "flag":"pay", "phrase":"Earn big rewards. We will tell you the payment amount after you finish.", "thought":"They want my time, but won't tell me what the job pays. Who is actually hiring me?"},
	{"id":"library", "sender":"School Library", "address":"library@school.example", "subject":"Book renewal confirmed", "body":"Your requested renewal is complete. Return your book by Friday. You can check the date at the library desk; no reply is needed.", "suspicious":false},
	{"id":"urgent", "sender":"Survey Coordinator", "address":"survey.coordinator@yahoo.com", "subject":"Keep your survey slot", "body":"Your application is nearly ready.", "suspicious":true, "flag":"pressure", "phrase":"Reply with your contact number now. Do not ask the school; this offer expires in ten minutes.", "thought":"A deadline AND a reason not to check with anyone. Why would verification cost me the job?"},
	{"id":"receipt", "sender":"Campus Print Desk", "address":"receipts@print.school.example", "subject":"Receipt for your print order", "body":"Your paid print order is ready for collection. This matches the order you made at the desk. No new payment or personal details are requested.", "suspicious":false},
	{"id":"profile", "sender":"Survey Profile Desk", "address":"survey.profile@gmail.com", "subject":"Complete your reward profile", "body":"Welcome to the rewards list.", "suspicious":true, "flag":"spelling", "phrase":"To recieve your reward, send your full birth date and home address in your reply.", "thought":"'Recieve' could just be bad grammar. But my birth date AND my home address? They haven't even explained why they need them."}
]
const STORY: Array[Dictionary] = [
	{"who":"John", "face":2, "bg":"school_gate_morning", "caption":"Five days before everything went wrong.", "line":"And here I was, late again. Come on, John. Just get through the gate before the bell."},
	{"who":"Eric", "face":1, "bg":"hallway_day", "line":"John! You look like you ran the whole way. No coffee today?"},
	{"who":"John", "face":2, "bg":"hallway_day", "line":"No coffee. No spare money either. Please tell me the meeting hasn't started."},
	{"who":"Eric", "face":1, "bg":"clubroom", "line":"Relax, you're fine. Come on. I'll save you a seat."},
	{"who":"John", "face":0, "bg":"clubroom", "chat":true, "line":"Eric and Jobert have stepped outside. Maybe someone in the club knows a side gig. Can't hurt to ask, right?"},
	{"who":"Eric", "face":1, "bg":"clubroom", "line":"We're back. That survey gig I mentioned? Easy work. I know the client personally."},
	{"who":"John", "face":4, "bg":"clubroom", "line":"Really? What's their name?"},
	{"who":"Eric", "face":2, "bg":"clubroom", "line":"Uh… I'll send you the contact. They handle everything by email."},
	{"who":"John", "face":0, "bg":"clubroom", "line":"Why did he look away? Maybe I'm overthinking it. I could really use that money."},
	{"who":"Jobert", "face":2, "bg":"clubroom", "line":"Careful with random surveys, John. Ask me if you're unsure. We can check who's behind it."},
	{"who":"John", "face":1, "bg":"clubroom", "line":"Thanks. I'll take a look first. It's just a survey… right?"},
	{"who":"John", "face":0, "bg":"classroom_sunset", "mail":true, "line":"Six new messages already? Some from school. Some about the survey. I'd better answer before I lose the job."},
	{"who":"John", "face":2, "bg":"john_desk_night", "time":"night", "line":"That night, I open my inbox again. Three messages keep bothering me. Maybe I should have looked closer."}
]
const CHAT_MESSAGES: Array[Dictionary] = [
	{"who":"John", "face":0, "text":"I miss coffee. I need a side gig before my wallet gives up."},
	{"who":"Eric", "face":1, "text":"I have a survey job. Interested?"},
	{"who":"Jobert", "face":2, "text":"Careful with random surveys. Ask me if you're unsure."},
	{"who":"John", "face":1, "text":"Send it over. I'll have a look."},
]

static func fresh() -> Dictionary:
	return {"version":1, "beat":0, "phase":"day", "read":[], "sorted":[], "flags":[], "domains":[], "captures":[], "mistakes":0, "hint_used":false, "sealed":false, "completed":false, "next_chapter_unlocked":false, "reward":0}

static func suspicious_ids() -> Array[String]:
	return ["survey", "urgent", "profile"]

static func message(id: String) -> Dictionary:
	for entry: Dictionary in MESSAGES:
		if entry["id"] == id:
			return entry
	return {}

static func complete_evidence(state: Dictionary) -> bool:
	for id: String in suspicious_ids():
		for field: String in ["flags", "domains", "captures"]:
			if not (state.get(field, []) as Array).has(id):
				return false
	return (state.get("sorted", []) as Array).size() == MESSAGES.size() and (state.get("read", []) as Array).size() == MESSAGES.size()

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	for field: String in ["read", "sorted", "flags", "domains", "captures"]:
		var values: Variant = raw.get(field, [])
		if values is Array:
			for value: Variant in values:
				var id: String = str(value)
				if not message(id).is_empty() and (field in ["read", "sorted"] or id in suspicious_ids()) and not state[field].has(id):
					state[field].append(id)
	for field: String in ["beat", "mistakes"]:
		var value: Variant = raw.get(field, 0)
		if (value is int or value is float) and is_finite(float(value)):
			state[field] = clampi(int(value), 0, STORY.size() - 1 if field == "beat" else 9999)
	state["hint_used"] = raw.get("hint_used", false) == true
	state["perk_run"] = Perks.clean_run(raw.get("perk_run", {}))
	if state.perk_run.get("chapter", ID) != ID: state.perk_run = {}
	var phase: String = str(raw.get("phase", "day"))
	if phase in ["day", "sort", "highlight", "notes", "capture", "seal", "sleep", "done"]:
		state["phase"] = phase
	# Repair incomplete prerequisites rather than trusting a saved phase.
	if state["phase"] != "day" and state["read"].size() < 6:
		state["phase"] = "day"
		state["beat"] = mini(int(state["beat"]), 11)
	if state["phase"] not in ["day", "sort"] and state["sorted"].size() < 6:
		state["phase"] = "sort"
	if state["phase"] in ["notes", "capture", "seal", "sleep", "done"] and state["flags"].size() < 3:
		state["phase"] = "highlight"
	if state["phase"] in ["capture", "seal", "sleep", "done"] and state["domains"].size() < 3:
		state["phase"] = "notes"
	if state["phase"] in ["seal", "sleep", "done"] and state["captures"].size() < 3:
		state["phase"] = "capture"
	state["sealed"] = raw.get("sealed", false) == true and complete_evidence(state)
	state["completed"] = raw.get("completed", false) == true and state["sealed"]
	if state["completed"]:
		state["next_chapter_unlocked"] = true
		state["phase"] = "done"
		state["reward"] = BASE_REWARD + (CLEAN_BONUS if Perks.status(state["perk_run"], state["hint_used"]) != "assisted" and int(state["mistakes"]) == 0 else 0)
	elif state["phase"] == "done":
		state["phase"] = "seal"
	return state

static func domain_matches(answer: String, id: String) -> bool:
	# Tolerate formatting, never a different/lookalike domain.
	var domain: String = str(message(id).get("address", "")).get_slice("@", 1)
	return not domain.is_empty() and answer.strip_edges().to_lower().trim_suffix(".") == domain
