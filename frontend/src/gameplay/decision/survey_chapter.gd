extends RefCounted
## Authored Chapter 1 content and validation. No scene, account or network access.
const ID: String = "mod_01_ch_01"
const BASE_REWARD: int = 100
const CLEAN_BONUS: int = 25
const MESSAGES: Array[Dictionary] = [
	{"id":"club", "sender":"Jobert", "address":"jobert@club.school.example", "subject":"Tomorrow's club meeting", "body":"Meeting at 3 PM in our usual clubroom. The same details are on the club noticeboard. Bring your project notes.", "suspicious":false},
	{"id":"survey", "sender":"Survey Rewards Team", "address":"survey.rewards@gmail.com", "subject":"Your first survey job", "body":"Thanks for joining!", "suspicious":true, "flag":"pay", "phrase":"Earn big rewards. We will tell you the payment amount after you finish.", "thought":"They want my time, but won't tell me what the job pays. Who is actually hiring me?"},
	{"id":"library", "sender":"School Library", "address":"library@school.example", "subject":"Book renewal confirmed", "body":"Your requested renewal is complete. Return your book by Friday. You can check the date at the library desk; no reply is needed.", "suspicious":false},
	{"id":"urgent", "sender":"Survey Coordinator", "address":"survey.coordinator@yahoo.com", "subject":"Keep your survey slot", "body":"Your application is nearly ready.", "suspicious":true, "flag":"pressure", "phrase":"Reply with your contact number now. Do not ask the school; this offer expires in ten minutes.", "thought":"A deadline AND a reason not to check with anyone. Why would verification cost me the job?"},
	{"id":"receipt", "sender":"Campus Print Desk", "address":"receipts@print.school.example", "subject":"Receipt for your print order", "body":"Your paid print order is ready for collection. This matches the order you made at the desk. No new payment or personal details are requested.", "suspicious":false},
	{"id":"profile", "sender":"Survey Profile Desk", "address":"survey.profile@gmail.com", "subject":"Complete your reward profile", "body":"Welcome to the rewards list.", "suspicious":true, "flag":"spelling", "phrase":"To recieve your reward, send your full birth date and home address in your reply.", "thought":"'Recieve' could just be bad grammar. Asking for my birth date and home address without explaining why is the bigger concern."}
]
const STORY: Array[Dictionary] = [
	{"who":"John", "face":2, "bg":"school_gate_morning", "line":"Five days before the disaster. I was late again. Back then, my biggest problem was getting through the gate before the bell."},
	{"who":"Eric", "face":1, "bg":"hallway_day", "line":"John! You look like you ran the whole way. No coffee today?"},
	{"who":"John", "face":2, "bg":"hallway_day", "line":"No coffee. No spare money either. Please tell me the meeting hasn't started."},
	{"who":"Eric", "face":1, "bg":"clubroom", "line":"You're fine. Come on—I'll save you a seat."},
	{"who":"John", "face":0, "bg":"clubroom", "chat":true, "line":"I drop a message into our club chat. It feels harmless. Just friends talking."},
	{"who":"Eric", "face":1, "bg":"clubroom", "line":"That survey gig I mentioned? Easy work. I know the client personally."},
	{"who":"John", "face":4, "bg":"clubroom", "line":"Really? What's their name?"},
	{"who":"Eric", "face":2, "bg":"clubroom", "line":"Uh… I'll send you the contact. They handle everything by email."},
	{"who":"John", "face":0, "bg":"clubroom", "line":"He looks away for a second. I notice it. Then I think about the money instead."},
	{"who":"Jobert", "face":2, "bg":"clubroom", "line":"Careful with random surveys, John. Ask me if you're unsure. We can check who's behind it."},
	{"who":"John", "face":1, "bg":"clubroom", "line":"Thanks. I'll take a look first. It's just a survey… right?"},
	{"who":"John", "face":0, "bg":"classroom_sunset", "mail":true, "line":"By afternoon, six messages are waiting. Familiar school updates. Survey requests. I answer before I stop to compare them."},
	{"who":"John", "face":2, "bg":"room", "line":"That night, I open my inbox again. Three messages keep bothering me. Maybe I should have looked closer."}
]
const CHAT: String = "CLUB GROUP CHAT\n\nJohn: I miss coffee. I need a side gig before my wallet gives up.\n\nEric: I have a survey job. Interested?\n\nJobert: Careful with random surveys. Ask me if you're unsure.\n\nJohn: Send it over. I'll have a look."

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
		state["reward"] = BASE_REWARD + (CLEAN_BONUS if not state["hint_used"] and int(state["mistakes"]) == 0 else 0)
	elif state["phase"] == "done":
		state["phase"] = "seal"
	return state

static func domain_matches(answer: String, id: String) -> bool:
	# Tolerate formatting, never a different/lookalike domain.
	var domain: String = str(message(id).get("address", "")).get_slice("@", 1)
	return not domain.is_empty() and answer.strip_edges().to_lower().trim_suffix(".") == domain
