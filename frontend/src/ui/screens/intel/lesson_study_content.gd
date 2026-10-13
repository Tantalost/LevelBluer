extends RefCounted
## Adapts the existing thirty lessons, keeping their scenarios and correct answers.
const Quiz: GDScript = preload("res://src/gameplay/quiz_content.gd")
const MINI_COUNT: int = 5
const MINI_PASS: int = 3
# Four curated transfer checks supplement each lesson's original question.
# Suffixes refer to the existing module bank, not random module-wide samples.
const MINI_CHECKS: Dictionary = {
	"mod_01": [
		["sa_08", "tv_04", "sa_01", "tf_01"], # Sender and safe school notices.
		["sa_05", "tv_09", "tf_02", "st_03"], # Display name versus the real request.
		["us_01", "us_06", "tf_06", "st_09"], # Lookalike and compound domains.
		["tv_03", "st_02", "tf_03", "sa_03"], # Disguised file and library source.
		["it_01", "it_05", "it_06", "tf_04"], # Mixed inbox and pressure.
		["us_05", "tv_10", "tf_05", "tf_08"], # Safe navigation and reporting.
	],
	"mod_02": [
		["sa_01", "tv_03", "st_01", "tf_07"],
		["sa_03", "tv_05", "us_02", "tf_04"],
		["sa_05", "tv_02", "tf_01", "st_08"],
		["tv_01", "tv_04", "st_06", "tf_09"],
		["st_07", "tv_07", "tf_02", "tf_10"],
		["st_04", "us_03", "tf_05", "tf_06"],
	],
	"mod_03": [
		["sa_01", "st_01", "us_01", "tf_01"],
		["sa_03", "st_03", "us_08", "tf_02"],
		["st_05", "us_06", "tf_03", "sa_10"],
		["st_07", "us_07", "tf_10", "sa_09"],
		["sa_04", "st_02", "tf_07", "us_04"],
		["sa_08", "st_08", "tf_04", "tf_09"],
	],
	"mod_04": [
		["sa_01", "st_01", "us_01", "tf_01"],
		["sa_03", "st_02", "us_02", "tf_04"],
		["sa_02", "st_03", "us_03", "tf_06"],
		["sa_04", "st_04", "us_07", "tf_03"],
		["sa_05", "st_05", "us_06", "tf_07"],
		["sa_07", "st_10", "us_10", "tf_09"],
	],
	"mod_05": [
		["sa_01", "tv_02", "us_01", "tf_01"],
		["sa_03", "tv_05", "st_02", "tf_03"],
		["sa_02", "tv_01", "st_03", "tf_02"],
		["sa_10", "tv_03", "st_09", "tf_04"],
		["it_03", "it_04", "it_05", "it_07"],
		["st_07", "tv_08", "us_06", "tf_07"],
	],
}

static func mini_quiz(module_id: String, index: int) -> Array[Dictionary]:
	var sets: Array = MINI_CHECKS.get(module_id, [])
	if index < 0 or index >= sets.size():
		return []
	var original: Dictionary = build(module_id, index)
	original["id"] = "%s_l%d_mini_v1" % [module_id, index + 1]
	original["quiz_scenario"] = original.get("quiz_scenario", original.scenario)
	original["bkt"] = {"p_g": 0.2 if original.multi else 1.0 / original.options.size()}
	var result: Array[Dictionary] = [original]
	var bank: Dictionary = {}
	for raw: Dictionary in ContentDB.get_module_questions(module_id):
		bank[str(raw.get("id", ""))] = raw
	for suffix: String in sets[index]:
		var id: String = module_id.replace("_", "") + "_" + suffix
		if not bank.has(id):
			return [] # Fail closed: never shorten the assessment silently.
		var raw: Dictionary = bank[id]
		var choices: Array[Dictionary] = Quiz.options(raw)
		var row: Dictionary = {"id": id, "module_id": module_id, "question": Quiz._format_prompt(raw), "quiz_scenario": Quiz._format_scenario(raw), "options": [], "correct": [], "multi": false, "feedback": Quiz.explanation(raw, true, null), "bkt": raw.get("bkt", {})}
		for choice: Dictionary in choices:
			if Quiz.grade(raw, choice.value):
				row.correct.append(row.options.size())
			row.options.append("Suspicious / attack" if choice.text == "Phishing" else str(choice.text))
		if row.correct.size() != 1 or row.options.size() < 2 or str(row.question).is_empty():
			return []
		result.append(row)
	return result
const DOMAIN := {
	"phishing": {"term": "Phishing", "definition": "Phishing is a deceptive message that impersonates a trusted sender to steal information or make you open an unsafe link or file.", "rule": "Check the full sender address and destination. Verify through a known site; never reply with a password or one-time code.", "app": "Mail", "inspect": "Inspect sender and request", "verify": "Open trusted contact directory", "action": "Report phishing", "unsafe": "Open link / attachment"},
	"smishing": {"term": "Smishing", "definition": "Smishing is phishing delivered by text message. Familiar names, short links and urgent warnings can hide a request for your login or code.", "rule": "Read the request, not just the sender name. Check in the official app or use contact details you already trust.", "app": "Messages", "inspect": "Inspect message details", "verify": "Check the official app", "action": "Block and report sender", "unsafe": "Reply with the code"},
	"vishing": {"term": "Vishing", "definition": "Vishing uses a phone call to impersonate a trusted person or office and pressure you into sharing secrets or taking an unsafe action.", "rule": "Do not share a one-time code. End the call and contact the organization using a number you found independently.", "app": "Calls", "inspect": "Review caller request", "verify": "End call; open trusted directory", "action": "Report suspicious call", "unsafe": "Read out the code"},
	"pretexting": {"term": "Pretexting", "definition": "Pretexting uses an invented role or story to make an unusual request seem legitimate. A name, badge or deadline is not proof of permission.", "rule": "Confirm the request with the real person or office. Do not share files, approve payments or grant access based on a stranger's story.", "app": "Service Desk", "inspect": "Inspect access request", "verify": "Contact the named office", "action": "Deny and report request", "unsafe": "Approve requested access"},
	"baiting": {"term": "Baiting", "definition": "Baiting offers a tempting reward or interesting find to make you install software, connect an unknown device or give away information.", "rule": "Do not trade your login for a prize or connect an unknown USB drive. Ask trusted staff to handle the item or verify the offer.", "app": "Device Security", "inspect": "Inspect item without opening", "verify": "Check with trusted staff", "action": "Reject and report item", "unsafe": "Open / install the offer"},
}

const PHISHING_BRIEFINGS: Array[Dictionary] = [
	{
		"title": "Operation: Inbox Impostor",
		"hook": "An IT email just landed. Official business, or someone wearing a digital disguise?",
		"mission": "Open Mail, inspect the sender, then search the Directory for University IT. Compare your findings in Evidence before handling the message.",
		"why": "A familiar name is not proof. Checking the real source helps keep school accounts out of the wrong hands.",
		"icon": IntelPixelIcon.Kind.ENVELOPE,
	},
	{
		"title": "Operation: Name Tag",
		"hook": "The help desk says your ticket is back. Time to check who is actually behind that name tag.",
		"mission": "Read the ticket email in Mail and inspect its details. Ask the trusted Directory contact to verify the request, then choose your response.",
		"why": "Anyone can type an official-looking name. Independent checks protect your password, even when a message sounds helpful.",
		"icon": IntelPixelIcon.Kind.BADGE,
	},
	{
		"title": "Operation: Double Take",
		"hook": "Campus Wi-Fi needs attention. That web address looks familiar... but does it deserve your login?",
		"mission": "Inspect the email in Mail. Use Browser to preview its destination without visiting it, then verify through Directory before responding.",
		"why": "Lookalike addresses can lead somewhere completely different. A second look can keep your login from becoming someone else's.",
		"icon": IntelPixelIcon.Kind.TERMINAL,
	},
	{
		"title": "Operation: File in Disguise",
		"hook": "A library notice brought an attachment. Your mission: investigate the file without waking it up.",
		"mission": "Read the email, then open Files to inspect the attachment's properties without running it. Verify with Directory and handle the message safely.",
		"why": "A document-looking name can hide a program. Checking the file type first helps protect the whole computer.",
		"icon": IntelPixelIcon.Kind.BOOKS,
	},
	{
		"title": "Operation: No Rush",
		"hook": "Mia shared notes, and the email wants you to hurry. You set the pace here, not the inbox.",
		"mission": "Open the shared-notes request in Mail. Inspect its details, check with the trusted Directory contact, and use your evidence to respond.",
		"why": "A deadline can make a risky request feel normal. Pausing to verify helps protect you and the classmates sharing your files.",
		"icon": IntelPixelIcon.Kind.CODEX,
	},
	{
		"title": "Operation: Keep the Keys",
		"hook": "One link promises to save your Wi-Fi. Your school login is the key: decide who gets near it.",
		"mission": "Inspect the Wi-Fi email, preview the address in Browser, and verify with Directory. Choose a safe response before handing over any account access.",
		"why": "A stolen login can let someone act as you. Practicing the checks now helps prevent the cleanup later.",
		"icon": IntelPixelIcon.Kind.LOCK,
	},
]

static func build(module_id: String, index: int) -> Dictionary:
	var lessons := LessonCatalog.lessons_for(module_id)
	if index < 0 or index >= lessons.size():
		return {}
	var source: Dictionary = lessons[index]
	var domain: Dictionary = DOMAIN.get(str(source.get("domain", "phishing")), DOMAIN.phishing)
	var explanation := str(source.get("explanation", source.get("hint", source.get("brief", domain.rule))))
	var result := {
		"module_id": module_id, "lesson_index": index,
		"title": source.title, "term": domain.term, "definition": domain.definition,
		"takeaway": explanation, "rule": domain.rule, "summary": source.get("beat4_summary", "Practice complete."),
		"scenario": _scenario(source), "domain": domain,
		"question": "What is the safest response to this request?",
		"options": ["Verify through an independent, trusted channel.", "Follow the request because the sender sounds official.", "Act quickly so you do not miss the deadline."],
		"correct": [0], "multi": false, "feedback": domain.rule,
	}
	match str(source.get("activity", "guided")):
		"guided":
			result.definition = source.beat2_name_it.definition
			var notes: PackedStringArray = []
			for note in source.beat1_guided_example.observations:
				notes.append(str(note.plain_language_note))
			result.takeaway = "\n\n".join(notes)
			var practice: Dictionary = source.beat3_practice[0]
			result.quiz_scenario = practice.scenario.content
			result.question = "Is this message a social-engineering attempt?"
			result.options = ["Yes — treat it as suspicious.", "No — this is a routine, verified request."]
			result.correct = [0 if practice.is_attack else 1]
			result.feedback = practice.explanation
		"trust":
			result.question = "Should you trust this request?"
			result.options = ["No — stop and verify independently.", "Yes — carry out the request."]
			result.correct = [0 if source.is_attack else 1]
			result.feedback = source.explanation
		"spot":
			result.question = "Which detail exposes the suspicious message?"
			result.options = source.options
			result.correct = [source.tell_index]
		"tap":
			result.question = "Select ALL suspicious details. Leave ordinary details unselected."
			result.options = []
			result.correct = []
			result.multi = true
			var reasons: PackedStringArray = []
			for i in source.segments.size():
				result.options.append(source.segments[i].text)
				if source.segments[i].is_tell:
					result.correct.append(i)
				reasons.append(source.segments[i].why)
			result.feedback = " ".join(reasons)
		"triage":
			var item: Dictionary = source.items[0]
			result.question = "How should this item be handled?"
			result.options = ["Safe: keep as a normal message.", "Report: flag a suspicious request.", "Ignore: skip non-actionable junk."]
			result.correct = [["safe", "report", "ignore"].find(str(item.correct))]
			result.feedback = item.why
		"reverse":
			result.question = "Select ALL phrases that manipulate someone into the trap."
			result.options = []
			result.correct = []
			result.multi = true
			for i in source.phrases.size():
				result.options.append(source.phrases[i].text)
				if source.phrases[i].good:
					result.correct.append(i)
		"timeline":
			result.question = "At which step should you stop and question the request?"
			result.options = source.events
			result.correct = [source.suspicion_index]
		"consequence":
			result.feedback = source.ignore_debrief
	# Rotate choices by lesson index so the safe answer is not always first.
	var options: Array = result.options.duplicate()
	var correct: Array = result.correct.duplicate()
	var shift := (index + 1) % options.size()
	result.options = []
	result.correct = []
	for i in options.size():
		var original := (i + shift) % options.size()
		result.options.append(options[original])
		if original in correct:
			result.correct.append(i)
	if module_id == "mod_01" and index == 0:
		result["simulation_id"] = "sender_cross_check"
	if module_id == "mod_01" and index < PHISHING_BRIEFINGS.size():
		result["simulation_briefing"] = PHISHING_BRIEFINGS[index].duplicate(true)
	return result

static func _scenario(source: Dictionary) -> String:
	var scenario: Dictionary = source.get("scenario", {})
	if not str(scenario.get("content", "")).is_empty():
		return str(scenario.content)
	if source.has("beat1_guided_example"):
		return str(source.beat1_guided_example.scenario.content)
	if source.has("fake"):
		return str(source.fake.content)
	if source.has("segments"):
		var parts: PackedStringArray = []
		for segment in source.segments:
			parts.append(str(segment.text))
		return "\n".join(parts)
	if source.has("nodes"):
		return str(source.nodes.start.line)
	if source.has("items"):
		return str(source.items[0].content)
	if source.has("events"):
		return "\n".join(source.events)
	return str(source.get("goal", source.get("title", "")))
