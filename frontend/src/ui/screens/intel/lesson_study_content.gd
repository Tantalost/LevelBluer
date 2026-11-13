extends RefCounted
## Adapts the existing thirty lessons, keeping their scenarios and correct answers.
const Quiz: GDScript = preload("res://src/gameplay/quiz_content.gd")
const MINI_COUNT: int = 5
const MINI_PASS: int = 3
const CONTEXT_CUES: Dictionary = {
	"mod_01:0": [["help@harb0r-civic.net", "WHO / The zero in harb0r imitates the school name. A familiar display name is not proof."], ["Open this page now and type it again", "REQUEST / They want your campus password entered on their page."], ["12 minutes", "PRESSURE / The countdown is meant to rush you past verification."]],
	"mod_01:1": [["it.help@gmail.com", "WHO / Check the mailbox, not just the Helpdesk name."], ["Reply with your campus password", "REQUEST / Never send your password in an email reply."], ["before lab starts", "PRESSURE / A familiar school deadline does not make this safe."]],
	"mod_01:2": [["westfie1d.edu", "ADDRESS / The digit 1 replaces the letter l. Lookalike spelling matters."], ["Re-enter your password", "REQUEST / Open your saved school portal instead of this login link."]],
	"mod_01:4": [["mia.santos.group@outlook.com", "WHO / A classmate's name does not verify this public mailbox."], ["sign in with your campus account", "REQUEST / Verify the shared folder with Mia using a known contact."], ["before 10", "PRESSURE / Pause even when the message sets a deadline."]],
	"mod_01:5": [["wifi@westfie1d.edu", "ADDRESS / This is the lookalike school name again."], ["Re-enter your password here", "REQUEST / This would hand your password to the linked page."], ["at noon", "PRESSURE / Don't let a threatened disconnection choose for you."]],
	"mod_02:0": [["metro-ride-help.tk", "DESTINATION / A familiar brand name does not verify a different website."], ["10 minutes", "PRESSURE / Verify the charge in the app you already have, not under this timer."]],
	"mod_02:1": [["bit.ly/navo-hold", "DESTINATION / The short link hides the destination."], ["student number plus password", "REQUEST / A book reservation is no reason to give away your password."], ["about to be given away", "PRESSURE / Fear of losing the book is the hook."]],
	"mod_02:3": [["metro-ride-help.tk/refund", "DESTINATION / Check the charge through your installed app, not this odd site."], ["10 minutes", "PRESSURE / The timer encourages a rushed tap."]],
	"mod_02:4": [["tap a link and type a password", "ATTACKER'S GOAL / Notice the action and secret the trick is designed to get."], ["under a minute", "PRESSURE / Rushing removes time to check the request."]],
}

static func context_clues(module_id: String, index: int) -> Array[Dictionary]:
	var source: Dictionary = LessonCatalog.lessons_for(module_id)[index]
	var scenario: String = _scenario(source)
	var clues: Array[Dictionary] = []
	for pair: Array in CONTEXT_CUES.get("%s:%d" % [module_id, index], []):
		if scenario.contains(str(pair[0])):
			clues.append({"quote": str(pair[0]), "note": str(pair[1])})
	if not clues.is_empty():
		return clues
	for segment: Dictionary in source.get("segments", []):
		if bool(segment.is_tell):
			clues.append({"quote": str(segment.text), "note": str(segment.why)})
	if source.has("events"):
		clues.append({"quote": str(source.events[int(source.suspicion_index)]), "note": str(source.explanation)})
	if clues.is_empty():
		# Other authored formats retain their own explanation, never a guessed tell.
		var note: String = str(source.get("hint", source.get("explanation", source.get("beat4_summary", "Compare this request with the safe response."))))
		if source.has("items"):
			note = str(source.items[0].why)
		if source.has("beat1_guided_example"):
			note = str(source.beat1_guided_example.observations[0].plain_language_note)
		clues.append({"quote": scenario.split("\n")[0], "note": note})
	return clues
## Eight clue checks, eight verification checks and four decisions per lesson.
## These are authored curriculum assignments, never a module-wide random fallback.
const MINI_POOLS: Dictionary = {
	"mod_01": [
		["tv_01 tv_02 tv_04 st_01 st_03 tf_01 tf_04 tf_10", "sa_01 sa_02 sa_07 sa_08 sa_10 us_01 us_04 us_07", "cc_01 cc_04 cc_05 cc_10"],
		["tv_05 tv_08 tv_09 st_03 st_07 st_08 tf_02 tf_09", "sa_01 sa_03 sa_04 sa_05 sa_08 sa_09 sa_10 us_08", "cc_03 cc_04 cc_05 cc_08"],
		["tv_02 tv_10 st_01 st_05 st_06 st_09 st_10 tf_06", "us_01 us_02 us_04 us_05 us_06 us_07 us_09 us_10", "cc_01 cc_05 cc_06 cc_10"],
		["tv_03 tv_04 tv_06 st_02 st_03 tf_01 tf_03 tf_04", "sa_01 sa_03 sa_08 sa_10 us_02 us_04 us_05 us_09", "cc_02 cc_04 cc_05 cc_09"],
		["tv_01 tv_04 tv_07 tv_08 tv_09 st_04 tf_04 tf_10", "sa_04 sa_05 sa_08 sa_09 us_03 us_05 us_08 us_09", "cc_03 cc_06 cc_07 cc_08"],
		["tv_02 tv_07 tv_09 tv_10 st_03 st_06 tf_05 tf_08", "sa_01 sa_05 sa_06 sa_07 us_01 us_04 us_05 us_10", "cc_01 cc_04 cc_05 cc_10"],
	],
	"mod_02": [
		["tv_01 tv_04 tv_06 st_03 st_04 st_06 tf_05 tf_07", "sa_01 sa_02 sa_04 sa_06 us_01 us_03 us_07 us_08", "cc_01 cc_03 cc_05 cc_07"],
		["tv_03 tv_05 tv_07 tv_10 st_02 st_05 st_10 tf_04", "sa_03 sa_04 sa_08 sa_09 us_02 us_04 us_09 us_10", "cc_02 cc_04 cc_06 cc_09"],
		["tv_02 tv_08 st_01 st_08 tf_01 tf_02 tf_03 tf_06", "sa_02 sa_05 sa_06 sa_07 sa_08 sa_10 us_03 us_07", "cc_01 cc_03 cc_07 cc_08"],
		["tv_01 tv_03 tv_04 tv_06 tv_09 st_06 tf_07 tf_09", "sa_01 sa_03 sa_06 sa_10 us_01 us_03 us_05 us_07", "cc_01 cc_04 cc_05 cc_10"],
		["tv_04 tv_05 tv_07 tv_08 st_02 st_07 tf_05 tf_10", "sa_01 sa_04 sa_05 sa_09 us_02 us_04 us_06 us_10", "cc_02 cc_06 cc_08 cc_09"],
		["tv_04 tv_05 tv_08 tv_10 st_04 st_10 tf_06 tf_10", "sa_02 sa_06 sa_07 sa_09 us_01 us_03 us_07 us_08", "cc_01 cc_07 cc_09 cc_10"],
	],
	"mod_03": [
		["tv_01 tv_02 tv_04 st_01 st_03 tf_01 tf_03 tf_10", "sa_01 sa_05 sa_07 sa_09 us_01 us_02 us_06 us_07", "cc_01 cc_02 cc_05 cc_07"],
		["tv_03 tv_07 tv_08 st_03 st_04 st_05 tf_02 tf_04", "sa_01 sa_02 sa_03 sa_06 sa_07 sa_08 us_03 us_08", "cc_02 cc_03 cc_06 cc_09"],
		["tv_04 tv_05 tv_06 tv_10 st_02 st_10 tf_03 tf_08", "sa_05 sa_07 sa_09 sa_10 us_01 us_02 us_06 us_09", "cc_01 cc_02 cc_04 cc_10"],
		["tv_02 tv_05 tv_09 st_01 st_06 st_09 tf_01 tf_10", "sa_02 sa_04 sa_05 sa_09 us_01 us_05 us_07 us_08", "cc_01 cc_05 cc_07 cc_08"],
		["tv_02 tv_07 tv_09 st_02 st_04 st_07 tf_04 tf_07", "sa_02 sa_04 sa_05 sa_08 us_01 us_04 us_05 us_09", "cc_03 cc_04 cc_08 cc_10"],
		["tv_05 tv_07 tv_09 st_04 st_08 st_09 tf_07 tf_09", "sa_04 sa_06 sa_08 sa_10 us_04 us_05 us_09 us_10", "cc_03 cc_06 cc_09 cc_10"],
	],
	"mod_04": [
		["tv_01 tv_02 tv_07 st_01 st_05 st_08 tf_01 tf_07", "sa_01 sa_05 sa_06 sa_10 us_01 us_04 us_06 us_08", "cc_01 cc_05 cc_06 cc_10"],
		["tv_03 tv_06 tv_08 st_02 st_07 st_09 tf_02 tf_04", "sa_03 sa_04 sa_06 sa_09 us_02 us_07 us_08 us_09", "cc_02 cc_04 cc_07 cc_09"],
		["tv_04 tv_05 tv_08 st_03 st_09 tf_05 tf_06 tf_10", "sa_02 sa_06 sa_07 sa_08 us_03 us_05 us_07 us_09", "cc_03 cc_04 cc_08 cc_10"],
		["tv_03 tv_06 tv_09 st_02 st_04 st_10 tf_03 tf_09", "sa_03 sa_04 sa_07 sa_09 us_02 us_05 us_07 us_10", "cc_02 cc_04 cc_07 cc_09"],
		["tv_01 tv_02 tv_07 tv_10 st_01 st_05 st_08 tf_07", "sa_01 sa_05 sa_06 sa_10 us_01 us_04 us_06 us_08", "cc_01 cc_05 cc_06 cc_10"],
		["tv_06 tv_08 tv_09 st_04 st_06 st_10 tf_08 tf_09", "sa_04 sa_06 sa_07 sa_09 us_05 us_07 us_08 us_10", "cc_02 cc_04 cc_08 cc_09"],
	],
	"mod_05": [
		["tv_01 tv_02 tv_08 st_01 st_07 tf_01 tf_06 tf_07", "sa_01 sa_02 sa_07 sa_09 us_01 us_06 us_08 us_09", "cc_01 cc_03 cc_07 cc_09"],
		["tv_03 tv_04 tv_05 tv_07 st_02 st_06 tf_03 tf_08", "sa_03 sa_04 sa_05 sa_10 us_02 us_03 us_04 us_10", "cc_02 cc_04 cc_06 cc_10"],
		["tv_01 tv_02 tv_07 tv_10 st_01 st_03 st_10 tf_02", "sa_01 sa_02 sa_07 sa_09 us_01 us_05 us_06 us_09", "cc_01 cc_03 cc_05 cc_07"],
		["tv_03 tv_04 tv_05 tv_06 st_02 st_04 st_09 tf_04", "sa_03 sa_04 sa_05 sa_10 us_02 us_03 us_04 us_10", "cc_02 cc_04 cc_06 cc_10"],
		["tv_04 tv_06 tv_07 tv_09 st_05 st_08 tf_05 tf_10", "sa_03 sa_04 sa_06 sa_08 us_02 us_04 us_05 us_07", "cc_02 cc_04 cc_05 cc_08"],
		["tv_01 tv_08 tv_09 st_01 st_07 tf_06 tf_07 tf_10", "sa_01 sa_02 sa_07 sa_08 us_01 us_05 us_06 us_08", "cc_01 cc_03 cc_07 cc_09"],
	],
}

static func mini_pool(module_id: String, index: int) -> Array[Dictionary]:
	var assignments: Array = MINI_POOLS.get(module_id, [])
	if index < 0 or index >= assignments.size(): return []
	var bank: Dictionary = {}
	for raw: Dictionary in ContentDB.get_module_questions(module_id): bank[str(raw.id)] = raw
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for category: int in 3:
		for suffix: String in str(assignments[index][category]).split(" ", false):
			var id: String = module_id.replace("_", "") + "_" + suffix
			if not bank.has(id) or seen.has(id): return []
			seen[id] = true
			var raw: Dictionary = bank[id]
			var row: Dictionary = {"id":id, "module_id":module_id, "category":category, "difficulty":raw.get("difficulty","medium"), "question":Quiz._format_prompt(raw), "quiz_scenario":Quiz._format_scenario(raw), "options":[], "correct":[], "multi":false, "feedback":Quiz.explanation(raw,true,null), "bkt":raw.get("bkt",{})}
			if row.question == "Phishing or legitimate?":
				row.question = "Is this request suspicious or legitimate?"
			if not str(raw.get("explanation", "")).strip_edges().is_empty():
				row.feedback = str(raw.explanation)
			else:
				row["feedback_incorrect"] = str(raw.get("incorrect_feedback", "")).strip_edges()
			if raw.get("type_id","") == "consequence_choice":
				row.feedback = str(raw.get("ignore_debrief", ""))
			for choice: Dictionary in Quiz.options(raw):
				if Quiz.grade(raw,choice.value): row.correct.append(row.options.size())
				row.options.append("Suspicious / attack" if choice.text == "Phishing" else str(choice.text))
			if row.correct.size() != 1 or row.options.size() < 2 or str(row.question).is_empty() or str(row.feedback).is_empty(): return []
			result.append(row)
	return result if result.size() >= 20 else []

static func select_mini(pool: Array[Dictionary], seen: Array, previous: Array, preferred: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for category: int in 3:
		var candidates: Array[Dictionary] = []
		for row: Dictionary in pool:
			if int(row.category) == category: candidates.append(row)
		candidates.shuffle()
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var ac: int = (100 if a.id in seen else 0) + (10 if a.id in previous else 0) + (0 if a.difficulty == preferred else 1)
			var bc: int = (100 if b.id in seen else 0) + (10 if b.id in previous else 0) + (0 if b.difficulty == preferred else 1)
			return ac < bc)
		var count: int = 1 if category == 2 else 2
		if candidates.size() < count: return []
		for i: int in count: result.append(candidates[i].duplicate(true))
	result.shuffle()
	return result

static func mini_quiz(module_id: String, index: int) -> Array[Dictionary]:
	return select_mini(mini_pool(module_id,index), [], [], "medium")

static func new_mini_session(pool: Array[Dictionary], previous: Dictionary, preferred: String) -> Dictionary:
	if pool.size() < 20: return {}
	var seen: Array[String] = []
	var last: Array[String] = []
	var previous_seen: Array = previous.get("seen",[]) if previous.get("seen",[]) is Array else []
	var previous_ids: Array = previous.get("ids",[]) if previous.get("ids",[]) is Array else []
	for row: Dictionary in pool:
		if row.id in previous_seen: seen.append(str(row.id))
		if row.id in previous_ids: last.append(str(row.id))
	if seen.size() == pool.size(): seen.clear()
	var selected: Array[Dictionary] = select_mini(pool,seen,last,preferred)
	if selected.size() != MINI_COUNT: return {}
	var result: Dictionary = {"version":1, "attempt_id":Crypto.new().generate_random_bytes(16).hex_encode(), "ids":[], "orders":[], "responses":[], "seen":seen, "read_passed":false, "reviewing_answer":false, "closed":false}
	for row: Dictionary in selected:
		result.ids.append(str(row.id))
		if row.id not in seen: seen.append(str(row.id))
		var order: Array[int] = []
		for i: int in row.options.size(): order.append(i)
		order.shuffle()
		result.orders.append(order)
	return result

static func restore_mini_items(pool: Array[Dictionary], session: Dictionary) -> Array[Dictionary]:
	if session.get("version",0) != 1 or not session.get("ids") is Array or not session.get("orders") is Array: return []
	if session.ids.size() != MINI_COUNT or session.orders.size() != MINI_COUNT: return []
	var result: Array[Dictionary] = []
	var used: Array[String] = []
	var categories: Array[int] = [0,0,0]
	for i: int in MINI_COUNT:
		var found: Dictionary = {}
		for row: Dictionary in pool:
			if row.id == session.ids[i]: found = row.duplicate(true)
		if found.is_empty() or str(found.id) in used: return []
		used.append(str(found.id))
		var order: Variant = session.orders[i]
		if not order is Array or order.size() != found.options.size(): return []
		var options: Array[String] = []
		var correct: Array[int] = []
		var indices: Array[int] = []
		for value: Variant in order:
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)): return []
			var index: int = int(value)
			if index < 0 or index >= found.options.size() or index in indices: return []
			indices.append(index)
			if index in found.correct: correct.append(options.size())
			options.append(str(found.options[index]))
		found.options = options
		found.correct = correct
		categories[int(found.category)] += 1
		result.append(found)
	return result if categories == [2,2,1] else []

static func quiz_feedback(item: Dictionary, is_correct: bool) -> String:
	if not is_correct and item.has("feedback_incorrect"):
		return str(item.feedback_incorrect)
	return str(item.get("feedback", ""))

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
