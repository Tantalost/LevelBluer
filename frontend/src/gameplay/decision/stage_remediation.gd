class_name StageRemediation
extends RefCounted
## Shared policy/evidence, enabled only after each stage's authored mapping is verified.
## Every supported item is explicitly mapped; unknown content never guesses a lesson.
const Content: GDScript = preload("res://src/gameplay/decision/remediation_content.gd")
static var TOPICS: Dictionary = _topics()
static var MAPPINGS: Dictionary = _mappings()
const ORIGINAL_TOPICS: Dictionary = {
	"sender": {"lesson": 1, "title": "Check the real sender", "why": "A familiar name or project detail does not prove who sent a message.", "rule": "Inspect the full address. Never send a password by reply; contact the office through saved details."},
	"link": {"lesson": 2, "title": "Spot the lookalike destination", "why": "An urgent sign-in request needs an independent check, not a click on its own link.", "rule": "Compare the full destination with your saved school portal. Open the bookmark yourself; a deadline is not proof."},
	"verify": {"lesson": 4, "title": "Verify, then decide", "why": "A message can be legitimate when independent evidence supports its ordinary request.", "rule": "Check the request through a known class page or trusted person. Do not label every message safe or unsafe just from its appearance."},
	"project_link": {"stage": 2, "lesson": 2, "title": "Personal details are not proof", "why": "Knowing your names and project title does not make a document link trustworthy.", "rule": "Check the destination against your saved class page. Verify there or with a trusted teacher; do not forward an unverified link for a friend to try.", "example": "The robotics display lists your team publicly. An email repeats those details but asks for a login at team-notes.example.\nOpen your saved class page yourself. Public details are clues, not identity checks."},
	"urgent_identity": {"stage": 2, "lesson": 1, "title": "Check the person behind the deadline", "why": "A teacher's name, school badge and urgent deadline can all be copied.", "rule": "Use the teacher's saved contact or the usual portal. Replying to the suspicious sender lets that same person claim the request is genuine.", "example": "A coach's name appears on a last-minute tournament form from sports-confirm.example. Your saved contact is coach@campus.example.\nAsk through the saved contact before acting. A quick reply from the new address proves nothing."},
	"sharing_identity": {"stage": 2, "lesson": 1, "title": "Verify who gets your files", "why": "A real sharing service does not prove who is requesting access. View-only can still expose private files.", "rule": "Compare the exact account with your saved contact. Leave access unchanged until you verify the person and task; then share only the necessary file and permissions.", "example": "A new account requests your whole club folder on the real school drive. Your adviser already has access to the poster.\nKeep the contact sheet private. Check with the saved adviser before granting anything."},
}
const ORIGINAL_MAPPINGS: Dictionary = {
	"mod01_s1_t1": "link", "mod01_s1_t2": "sender", "mod01_s1_t3": "verify",
	"mod01_stage02_incident01": "project_link",
	"mod01_stage02_incident02": "urgent_identity",
	"mod01_stage02_incident03": "sharing_identity",
}
const GUIDED_THRESHOLD: float = 0.40 # Matches PlayerManager.AT_RISK_MASTERY.

static func enabled(module_id: String, stage: int) -> bool:
	return module_id in ["mod_01", "mod_02"] and stage >= 1 and stage <= 10

static func _topics() -> Dictionary:
	var result: Dictionary = ORIGINAL_TOPICS.duplicate(true)
	result.merge(Content.topics())
	return result

static func _mappings() -> Dictionary:
	var result: Dictionary = ORIGINAL_MAPPINGS.duplicate(true)
	result.merge(Content.mappings())
	return result

static func skill(module_id: String) -> String:
	return "smishing" if module_id == "mod_02" else "phishing"

static func _topic_matches_stage(topic: String, stage: int, module_id: String) -> bool:
	return TOPICS.has(topic) and int(TOPICS[topic].get("stage", 1)) == stage and str(TOPICS[topic].get("module", "mod_01")) == module_id

static func latest(account: Object, module_id: String, stage: int) -> Dictionary:
	var sessions: Array = account.remediation_state.get("sessions", [])
	for index: int in range(sessions.size() - 1, -1, -1):
		var session: Dictionary = sessions[index]
		if session.module_id == module_id and int(session.stage) == stage:
			return session.duplicate(true)
	return {}

static func _persist(account: Object, session: Dictionary) -> void:
	var state: Dictionary = account.remediation_state.duplicate(true)
	var sessions: Array = state.get("sessions", [])
	var found: bool = false
	for index: int in sessions.size():
		if sessions[index].id == session.id:
			sessions[index] = session.duplicate(true)
			found = true
			break
	if not found:
		sessions.append(session.duplicate(true))
	state["sessions"] = sessions
	account.save_remediation(state)

static func _seen(account: Object, item_id: String) -> bool:
	for session: Dictionary in account.remediation_state.get("sessions", []):
		for response: Dictionary in session.get("decisions", []):
			if response.item_id == item_id:
				return true
		if session.get("practice", {}).has(item_id):
			return true
	return false

static func observe(account: Object, module_id: String, stage: int, result: Dictionary, timed_out: bool, grade_allowed: bool = true, params: Dictionary = {}) -> void:
	if not enabled(module_id, stage):
		return
	var item_id: String = str(result.threat.get("id", ""))
	if not MAPPINGS.has(item_id) or not _topic_matches_stage(str(MAPPINGS[item_id]), stage, module_id):
		return
	var session: Dictionary = latest(account, module_id, stage)
	if session.is_empty() or str(session.status) in ["retried", "cleared", "tactical_retry"]:
		session = {"id": account.learning_id(), "previous_session_id": str(session.get("id", "")), "module_id": module_id, "stage": stage, "status": "playing", "grade_allowed": grade_allowed, "decisions": [], "practice": {}, "created_at": Time.get_unix_time_from_system()}
	if session.status != "playing":
		return
	# One observation per original incident. Correction/reopened choices are practice.
	for response: Dictionary in session.decisions:
		if response.item_id == item_id:
			return
	var before: float = account.get_mastery(skill(module_id))
	var scored: bool = grade_allowed and not timed_out and not _seen(account, item_id)
	if scored:
		account.update_mastery(skill(module_id), bool(result.bkt_correct), params, false)
	session.decisions.append({"item_id": item_id, "topic": MAPPINGS[item_id], "outcome": str(result.outcome), "timed_out": timed_out, "scored": scored, "mastery_before": before, "mastery_after": account.get_mastery(skill(module_id))})
	_persist(account, session)

static func assign(account: Object, module_id: String, stage: int) -> Dictionary:
	var session: Dictionary = latest(account, module_id, stage)
	if session.is_empty():
		return {}
	if str(session.status) in ["pending", "review", "ready"]:
		return session
	if session.status != "playing":
		return {}
	var selected: String = ""
	var weights: Dictionary[String, int] = {}
	for response: Dictionary in session.decisions:
		if response.outcome == DecisionScenarios.OUTCOME_SAFE and not bool(response.timed_out):
			continue
		var topic: String = str(response.topic)
		weights[topic] = weights.get(topic, 0) + (2 if response.outcome == DecisionScenarios.OUTCOME_CRITICAL else 1)
		if selected.is_empty() or weights[topic] >= weights.get(selected, 0):
			selected = topic
	# A battle-only failure has no unsafe decision to remediate.
	if selected.is_empty():
		return {}
	var mastery: float = account.get_mastery(skill(module_id))
	session.merge({"status": "pending", "topic": selected, "lesson_index": int(TOPICS[selected].lesson), "mastery_at_assignment": mastery,
		"support": "guided" if mastery < GUIDED_THRESHOLD else "focused", "question_count": 3 if mastery < GUIDED_THRESHOLD else 2,
		"assigned_at": Time.get_unix_time_from_system()}, true)
	_persist(account, session)
	return session

static func pending(account: Object, module_id: String, stage: int) -> bool:
	if not enabled(module_id, stage):
		return false
	return str(latest(account, module_id, stage).get("status", "")) in ["pending", "review", "ready"]

static func start_review(account: Object, module_id: String, stage: int) -> Dictionary:
	var session: Dictionary = latest(account, module_id, stage)
	if not pending(account, module_id, stage):
		return {}
	if session.status == "pending":
		session.status = "review"
		_persist(account, session)
	return session

static func questions(topic: String) -> Array[Dictionary]:
	if TOPICS.has(topic) and TOPICS[topic].has("concept"):
		return Content.questions(TOPICS[topic])
	# Separate scenarios from the stage and existing mini-quizzes. Stable IDs prevent
	# repeated exposure from inflating BKT; correction attempts never update mastery.
	var rows: Array = []
	match topic:
		"sender": rows = [
			["The art club's name appears on an email asking you to reply with your school password. What verifies the sender?", ["Knowing your club name", "Contacting the club adviser through saved details", "A signature saying Official"], 1, "Names and signatures can be copied. Use an independent contact and never email a password."],
			["A message says 'Library Team', but its full address is desk@library-help.example. Your handbook lists library@campus.example. What next?", ["Reply with your login to test it", "Trust the display name", "Use the handbook contact to check the request"], 2, "The display name is not identity proof. Use the independently saved contact."],
			["An email includes your public science-fair title and asks for a login code. Which response protects the account?", ["Keep the code private and verify with the teacher independently", "Send the code because the project title matches", "Forward the code to classmates"], 0, "Public project details do not authorize access to your account."],
		]
		"link": rows = [
			["Your saved portal is portal.campus.example. A message threatens to cancel your library booking unless you sign in at campus-check.example. What do you open?", ["The urgent message's link", "Your saved portal bookmark", "Both pages and enter the password twice"], 1, "Use the independently saved portal, not the link supplied by the message."],
			["A site has a padlock and the school logo, but a different address from your saved portal. What does the padlock establish?", ["The school owns the page", "The request must be safe", "The connection is encrypted, not that the school owns it"], 2, "Encryption does not prove the sender or website is legitimate."],
			["A sign-in email says 'only five minutes left'. How should that affect verification?", ["Keep checking through your known portal", "Skip checks because time is short", "Send your password by reply instead"], 0, "Urgency is not evidence. A real deadline does not validate an unfamiliar sign-in page."],
		]
		"verify": rows = [
			["Your adviser confirms a poster deadline in person. The same reminder is on your saved class page and asks for no secrets. What is reasonable?", ["Report it solely because it is an email", "Follow the ordinary task through the saved class page", "Send your password to prove you read it"], 1, "Independent confirmation supports the task without sharing secrets."],
			["Two reminders show the same teacher name. One is independently confirmed; the other asks for a password at a new link. Which evidence matters most?", ["Their matching logos", "Which one arrived first", "The independent confirmation and what each request asks you to do"], 2, "Evaluate the request and evidence, not just its appearance."],
			["An independently verified event notice contains a normal deadline. Which statement is accurate?", ["A deadline alone does not make a request malicious or safe", "All deadline messages are attacks", "Deadlines make every attached link safe"], 0, "A deadline is context, not proof; verify the actual request."],
		]
		"project_link": rows = [
			["An email names your robotics team and offers judging notes at team-notes.example. Your saved class page is on portal.campus.example. What next?", ["Open the saved class page and check with the adviser", "Sign in because the team details match", "Trust the document's school logo"], 0, "Team details may be public. Verify through an independent class page or contact before using a new login link."],
			["You are unsure about a shared-document link. A teammate offers to test it. What protects both of you?", ["Forward the link and ask them to sign in first", "Send it to the whole group for a vote", "Warn them without passing on the active link; report through the school channel"], 2, "Passing an unverified link to a friend spreads the risk. Use the school's reporting process instead of asking someone else to open it."],
			["A sender knows your names and the title printed on the public exhibition board. What does that establish?", ["They are authorized to collect your school login", "They know details that anyone could copy", "Their shared document is a school resource"], 1, "Personalization can come from public information. It does not establish who controls the sender or destination."],
		]
		"urgent_identity": rows = [
			["A message signed by your coach says your tournament place expires in ten minutes. It uses a new registration address. What should you do?", ["Use the saved coach contact or usual portal to verify", "Sign in quickly to keep your place", "Trust the copied team badge"], 0, "Check urgent requests through a channel you already trust. A deadline does not prove the sender is your coach."],
			["You reply 'Is this really you?' to a suspicious teacher email. The sender immediately says yes. Is that an independent check?", ["Yes, a fast response proves identity", "Yes, if the reply repeats the teacher's name", "No, the same sender controls both messages"], 2, "The sender can confirm their own story. Contact the teacher using previously saved details instead."],
			["Your saved portal shows the event place is reserved. A new email threatens to cancel it unless you enter a password on its form. Which evidence should guide you?", ["The strongest warning in the email", "The independently opened portal and saved organizer contact", "The matching school colors"], 1, "Use the independently verified status and contact, not branding or pressure from the new message."],
		]
		"sharing_identity": rows = [
			["On the real school drive, a new account using your adviser's name requests your club folder. What is the safest next step?", ["Leave access unchanged and check the exact account with your saved adviser", "Approve because the website itself is genuine", "Give viewer access while waiting for proof"], 0, "The platform can be real while the requester is an impostor. Verify the account before sharing."],
			["An unverified viewer is added to a folder containing classmates' phone numbers. What risk remains even without edit permission?", ["None: viewers cannot change files", "Only a risk if the viewer later becomes an editor", "They can read and may copy the private information"], 2, "View-only limits editing, not exposure. Do not give an unknown account access to private information."],
			["Your adviser confirms their saved account in person and only needs to read your poster. Which permission fits the task?", ["Editor access to the whole folder and contact sheet", "Viewer access to the poster only", "Public access to the entire folder"], 1, "Once identity and the task are verified, grant only the necessary file and permission. Keep unrelated information private."],
		]
	var result: Array[Dictionary] = []
	for index: int in rows.size():
		var row: Array = rows[index]
		result.append({"id": "m1s%d_%s_%d_v1" % [int(TOPICS[topic].get("stage", 1)), topic, index], "question": row[0], "options": row[1], "correct": row[2], "feedback": row[3]})
	return result

static func answer(account: Object, module_id: String, stage: int, question_index: int, choice: int) -> Dictionary:
	var session: Dictionary = latest(account, module_id, stage)
	if session.get("status", "") != "review" or question_index < 0 or question_index >= int(session.question_count):
		return {}
	var bank: Array[Dictionary] = questions(str(session.topic))
	var question: Dictionary = bank[question_index]
	if choice < 0 or choice >= question.options.size():
		return {}
	# Reject out-of-order answers, including programmatic presses on hidden controls.
	for prior: int in question_index:
		if not bool(session.practice.get(bank[prior].id, {}).get("solved", false)):
			return {}
	var item_id: String = str(question.id)
	var correct: bool = choice == int(question.correct)
	var observation: Dictionary = session.practice.get(item_id, {})
	if bool(observation.get("solved", false)):
		return observation
	if observation.is_empty():
		var before: float = account.get_mastery(skill(module_id))
		var scored: bool = bool(session.get("grade_allowed", true)) and not _seen(account, item_id)
		if scored:
			account.update_mastery(skill(module_id), correct, {}, false)
		observation = {"correct": correct, "choice": choice, "scored": scored, "mastery_before": before, "mastery_after": account.get_mastery(skill(module_id)), "solved": correct}
	else:
		observation["solved"] = correct
	session.practice[item_id] = observation
	var finished: bool = true
	for index: int in int(session.question_count):
		finished = finished and bool(session.practice.get(bank[index].id, {}).get("solved", false))
	if finished:
		session.status = "ready"
		session["completed_at"] = Time.get_unix_time_from_system()
		session["mastery_after_review"] = account.get_mastery(skill(module_id))
	_persist(account, session)
	return observation

static func mark(account: Object, module_id: String, stage: int, status: String) -> void:
	var session: Dictionary = latest(account, module_id, stage)
	if session.is_empty():
		return
	if status == "retried" and session.status != "ready":
		return
	if status not in ["retried", "cleared", "tactical_retry"]:
		return
	session.status = status
	_persist(account, session)

static func consume_review(account: Object, module_id: String, stage: int) -> bool:
	if not enabled(module_id, stage) or latest(account, module_id, stage).get("status", "") != "ready":
		return false
	# Clear the failed incident before releasing the gate. A crash between saves
	# leaves the review ready, never an old incident playable as a fresh attempt.
	account.clear_decision_stage_state(DecisionScenarios.stage_key(module_id, stage))
	if stage == 10:
		account.unlock_stage(module_id, stage)
	mark(account, module_id, stage, "retried")
	return true

static func restore(raw: Variant) -> Dictionary:
	var result: Dictionary = {"sessions": []}
	if not raw is Dictionary or not raw.get("sessions", []) is Array:
		return result
	for item: Variant in raw.get("sessions", []):
		if not item is Dictionary:
			continue
		var row: Dictionary = item.duplicate(true)
		if not _integer_between(row.get("stage"), 1, 10):
			continue
		if not enabled(str(row.get("module_id", "")), int(row.get("stage", 0))) or str(row.get("id", "")).is_empty():
			continue
		if row.get("status", "") not in ["playing", "pending", "review", "ready", "retried", "cleared", "tactical_retry"] or not row.get("decisions") is Array or not row.get("practice") is Dictionary:
			continue
		var has_review: bool = row.has("topic")
		if row.status in ["pending", "review", "ready", "retried"] and not has_review:
			continue
		if has_review:
			if not _integer_between(row.get("question_count"), 2, 3):
				continue
			row.question_count = int(row.question_count)
			if not _topic_matches_stage(str(row.topic), int(row.stage), str(row.module_id)) or row.get("support", "") not in ["guided", "focused"]:
				continue
			row["lesson_index"] = int(TOPICS[row.topic].lesson)
		var valid: bool = true
		var decision_ids: Array[String] = []
		for response: Variant in row.decisions:
			if not response is Dictionary or not MAPPINGS.has(str(response.get("item_id", ""))):
				valid = false
				break
			var item_id: String = str(response.item_id)
			if not _topic_matches_stage(str(MAPPINGS[item_id]), int(row.stage), str(row.module_id)):
				valid = false
				break
			if item_id in decision_ids or response.get("outcome", "") not in [DecisionScenarios.OUTCOME_SAFE, DecisionScenarios.OUTCOME_RISKY, DecisionScenarios.OUTCOME_CRITICAL] or not response.get("timed_out") is bool or not _valid_observation(response):
				valid = false
				break
			response["topic"] = MAPPINGS[item_id]
			decision_ids.append(item_id)
		var bank: Array[Dictionary] = questions(str(row.get("topic", "")))
		var expected: Array[String] = []
		for index: int in int(row.get("question_count", 0)) if has_review else 0:
			expected.append(str(bank[index].id))
		for key: Variant in row.practice:
			var response: Variant = row.practice[key]
			if key not in expected or not response is Dictionary or not _valid_observation(response):
				valid = false
				break
			if not response.get("correct") is bool or not response.get("solved") is bool or not _integer_between(response.get("choice"), 0, 2):
				valid = false
				break
		if valid:
			var previous_solved: bool = true
			for key: String in expected:
				if row.practice.has(key) and not previous_solved:
					valid = false
				previous_solved = previous_solved and bool(row.practice.get(key, {}).get("solved", false))
			if row.status in ["ready", "retried"] and not previous_solved:
				valid = false
		if valid:
			result.sessions.append(row)
	return result

static func _valid_observation(response: Dictionary) -> bool:
	if not response.get("scored") is bool:
		return false
	for key: String in ["mastery_before", "mastery_after"]:
		var value: Variant = response.get(key)
		if not (value is float or value is int):
			return false
		if not is_finite(float(value)) or float(value) < 0.0 or float(value) > 1.0:
			return false
	return true

static func _integer_between(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum
