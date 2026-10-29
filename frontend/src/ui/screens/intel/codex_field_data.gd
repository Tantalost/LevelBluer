extends RefCounted
## Editorial field notes plus live combat rules. No duplicate damage tables.
const Survey: GDScript = preload("res://src/gameplay/decision/survey_chapter.gd")
const Advisor: GDScript = preload("res://src/gameplay/decision/advisor_chapter.gd")
const Payout: GDScript = preload("res://src/gameplay/decision/payout_chapter.gd")
const Prize: GDScript = preload("res://src/gameplay/decision/prize_chapter.gd")
const Hearing: GDScript = preload("res://src/gameplay/decision/confrontation_chapter.gd")
const CHAPTERS: Array[GDScript] = [Survey, Advisor, Payout, Prize, Hearing]
const CHARACTER_IDS: Array[String] = ["john", "eric", "jobert"]
const CHARACTERS: Dictionary = {
	"john": {"name":"John", "role":"Student / Protagonist", "background":"A student whose perspective you follow through the investigation.", "relationship":"You follow John's experiences and investigation."},
	"eric": {"name":"Eric", "role":"Club member", "background":"A member of John's school club.", "relationship":"John's fellow club member."},
	"jobert": {"name":"Jobert", "role":"Club member", "background":"A member of John's school club.", "relationship":"John's fellow club member."},
	"dan": {"name":"Dan", "role":"Club member", "background":"A member of John's school club.", "relationship":"John's fellow club member."},
	"mika": {"name":"Mika", "role":"Club member", "background":"A member of John's school club.", "relationship":"John's fellow club member."},
	"rham": {"name":"Sir Rham", "role":"Club advisor", "background":"The advisor whose identity appears on the club's legitimate emails.", "relationship":"The students' club advisor."}
}
# after_beat means the player has advanced past the entire authored story beat.
# A saved beat points to the CURRENT dialogue, not proof that it has been read.
const OBSERVATIONS: Array[Dictionary] = [
	{"id":"income", "title":"Looking for extra income", "people":["john"], "after_beat":4, "status":"Known", "source":"Chapter 1 / Club chat", "text":"John tells the group he misses coffee and needs a side gig. This is what John shared with the club."},
	{"id":"offer", "title":"The survey opportunity", "people":["john","eric"], "after_beat":4, "status":"Known", "source":"Chapter 1 / Club chat", "text":"Eric introduces a survey job. John asks him to send it over. The conversation establishes the offer, not whether the job is legitimate."},
	{"id":"warning", "title":"Jobert's warning", "people":["john","jobert"], "after_beat":4, "status":"Known", "source":"Chapter 1 / Club chat", "text":"Jobert warns John to be careful with random surveys and offers help if he is unsure. Giving advice does not establish a person's trustworthiness."},
	{"id":"client_claim", "title":"Eric's connection to the client", "people":["john","eric"], "after_beat":5, "status":"Unverified", "source":"Chapter 1 / Eric in the clubroom", "text":"Eric says the work is easy and that he knows the client personally. These are Eric's claims; Chapter 1 does not independently verify them."},
	{"id":"client_identity", "title":"Who is the client?", "people":["john","eric"], "after_beat":7, "status":"Unknown", "source":"Chapter 1 / John's question and Eric's reply", "text":"John asks for the client's name. Eric says he will send the contact and that they use email. He does not give a name in this exchange. The client's identity remains unknown."},
	{"id":"verification", "title":"An offer to check", "people":["john","jobert"], "after_beat":9, "status":"Known", "source":"Chapter 1 / Jobert in the clubroom", "text":"Jobert offers to help John check who is behind the survey. This records his recommendation to verify; it does not mean the survey has been verified."},
	{"id":"pay", "title":"Payment amount withheld", "people":["john"], "read_id":"survey", "status":"Known", "source":"Chapter 1 / Your first survey job", "text":"The message promises rewards but says the payment amount will be given after the work is finished. The promise of payment is unverified."},
	{"id":"pressure", "title":"Pressure to reply", "people":["john"], "read_id":"urgent", "status":"Known", "source":"Chapter 1 / Keep your survey slot", "text":"The message asks for a contact number, sets a ten-minute deadline, and tells John not to ask the school. These requests are visible in the message; the sender's authority is not verified."},
	{"id":"personal_data", "title":"Personal information requested", "people":["john"], "read_id":"profile", "status":"Known", "source":"Chapter 1 / Complete your reward profile", "text":"The message asks for a full birth date and home address and spells receive as 'recieve'. A typo alone does not prove who wrote it or whether they intended harm."}
]

const CHAPTER_OBSERVATIONS: Dictionary = {
	2:[
		{"id":"c2_request", "title":"A familiar name asks for details", "people":["john","rham"], "after_beat":2, "status":"Unverified", "source":"Chapter 2 / New advisor email", "text":"An email using Sir Rham's name asks for personal details within 24 hours and threatens removal from the club. A display name and a deadline do not verify the sender."},
		{"id":"c2_help", "title":"Check the sender first", "people":["john","jobert"], "after_beat":3, "status":"Known", "source":"Chapter 2 / Private conversation", "text":"John asks Jobert before replying. Jobert tells him to inspect the address beneath the sender's name. This records helpful advice, not proof of who sent the email."},
		{"id":"c2_domain", "title":"A digit in the school domain", "people":["john","jobert","rham"], "after_beat":11, "status":"Known", "source":"Chapter 2 / Email comparison", "text":"The new address uses schoo1.example, with digit 1, instead of school.example, with lowercase L. Jobert helps John notice the difference. The lookalike reveals impersonation, not the author's identity."},
		{"id":"c2_dan", "title":"Dan's inbox joke", "people":["john","dan","eric","jobert"], "after_beat":20, "status":"Unverified", "source":"Chapter 2 / Club chat", "text":"Dan jokes about hacking Sir Rham's inbox and says he knows the club's subject format. Knowing a format and joking about an inbox do not establish that he accessed it or sent the message."},
		{"id":"c2_reply", "title":"Replies go to another address", "people":["john","rham"], "field":"headers", "value":"Reply-To", "status":"Known", "source":"Chapter 2 / Header investigation", "text":"From is sir.rham@schoo1.example, while Reply-To is club.records@member-support.example. A reply would go somewhere else. Neither address identifies the person operating it."},
		{"id":"c2_wording", "title":"Generic wording and signature", "people":["john","rham"], "field":"flags", "value":"signature", "status":"Known", "source":"Chapter 2 / Signature comparison", "text":"The new message signs off as Club Administration rather than Sir Rham, Club Advisor. Compare the signature alongside the address and the request; a familiar subject format is not verification."}
	],
	3:[
		{"id":"c3_borrow", "title":"Eric asks to borrow money", "people":["john","eric"], "after_beat":3, "status":"Known", "source":"Chapter 3 / Eric's private chat", "text":"Eric asks to borrow some of the survey payout and promises to repay John. The request does not establish that Eric sent the payout email."},
		{"id":"c3_whisper", "title":"A conversation at the doorway", "people":["john","eric","mika"], "after_beat":7, "status":"Unknown", "source":"Chapter 3 / Outside the clubroom", "text":"John hears Mika ask 'Did you ask him?' and Eric answer 'Yeah. Not yet.' John only hears part of their conversation. Its connection to the emails is unresolved."},
		{"id":"c3_call", "title":"An interruption while typing", "people":["john","jobert"], "after_beat":23, "status":"Known", "source":"Chapter 3 / Jobert's call", "text":"Jobert calls while John is on the fake wallet page and tells him to stop entering information and send a screenshot. John says he started typing a username but did not submit. At this point, John has not verified whether the page captured any input."},
		{"id":"c3_destination", "title":"Link text and destination differ", "people":["john"], "field":"revealed", "value":"payout", "status":"Known", "source":"Chapter 3 / Link inspection", "text":"The displayed wallet link differs from its real destination. The destination is http://pocket-wallet-verify.example/login. Check where a link leads before trusting its label."},
		{"id":"c3_short", "title":"The short link conceals a destination", "people":["john"], "field":"expanded", "value":"payout", "status":"Known", "source":"Chapter 3 / Link expander", "text":"Expanding short.example/payout reveals the same fake wallet destination. A shortened address hides where it leads; shortening alone does not establish who created a link."},
		{"id":"c3_page", "title":"The login page's warning signs", "people":["john"], "field":"reviewed", "status":"Known", "source":"Chapter 3 / Reviewed page inspection", "text":"The page uses an odd domain and HTTP. The missing secure-connection indicator supports the HTTP finding; blurry branding and LOGN IN are supporting clues. Even HTTPS would not prove a page genuine."}
	],
	4:[
		{"id":"c4_morning", "title":"Back in John's room", "people":["john"], "after_beat":2, "status":"Known", "source":"Chapter 4 / The morning from the intro", "text":"John wakes in his room to a prize email. Its promised reward is a claim, not a verified payout. This is the same morning shown in the module introduction."},
		{"id":"c4_silence", "title":"No reply from Jobert", "people":["john","jobert"], "after_beat":5, "status":"Known", "source":"Chapter 4 / Private messages", "text":"John asks whether the prize is legitimate. Jobert appears offline and does not reply. A presence status alone does not show what someone is doing."},
		{"id":"c4_coffee", "title":"The coffee comment was in the group", "people":["john","eric","jobert","dan","mika"], "field":"connections", "value":"coffee|group", "status":"Known", "source":"Chapter 4 / Coffee and group-message connection", "text":"The prize email repeats John's coffee comment from the club chat. The comment was available to the group; it was not a secret known only to Eric. This does not identify who copied it."},
		{"id":"c4_gap", "title":"Ten seconds after last seen", "people":["john","jobert","eric"], "field":"timeline_checked", "value":"prize", "status":"Known", "source":"Chapter 4 / Verified timeline order", "text":"The prize email arrived at 08:14:00, ten seconds after Jobert's last seen and fifteen after Eric's. Arrival time and presence status do not establish the sender or when either person was asleep."},
		{"id":"c4_typo", "title":"The spelling appears again", "people":["john"], "field":"connections", "value":"earlier|typo", "status":"Known", "source":"Chapter 4 / Repeated-wording connection", "text":"The survey and prize emails both spell receive as 'recieve'. The repeated wording supports comparing the messages. A common typo is not a unique fingerprint."},
		{"id":"c4_claim", "title":"John taps the prize button", "people":["john"], "field":"claimed", "status":"Known", "source":"Chapter 4 / Return to that morning", "text":"The reconstruction ends. Still in his room, John taps Claim Prize and the screen glitches. The next chapter continues the confrontation."}
	],
	5:[
		{"id":"c5_briefing", "title":"New records for the hearing", "people":["john","rham","jobert"], "field":"briefed", "status":"Known", "source":"Chapter 5 / Sir Rham's briefing", "text":"The roster lists 20 members with access to the coffee message, not proof they all read it. IT's recovered page record shows input transmission at 18:41:12; John's incoming Jobert call has the same timestamp. These records establish timing and page behavior, not the operator's identity."},
		{"id":"c5_eric", "title":"The accusation against Eric is unsupported", "people":["john","eric","jobert","rham"], "field":"solved", "value":0, "status":"Known", "source":"Chapter 5 / First rebuttal", "text":"The group-chat exhibit contradicts the claim that only Eric knew about the coffee comment. Access to a message does not identify who authored the scam."},
		{"id":"c5_dan", "title":"Knowing a format does not prove authorship", "people":["john","dan","jobert","rham"], "field":"solved", "value":1, "status":"Known", "source":"Chapter 5 / Second rebuttal", "text":"The advisor headers show impersonation but do not identify Dan. His joke and knowledge of the club format do not support Jobert's accusation."},
		{"id":"c5_input", "title":"Submit was not required for capture", "people":["john","jobert","rham"], "field":"solved", "value":2, "status":"Known", "source":"Chapter 5 / Third rebuttal", "text":"The recovered record contradicts Jobert's claim that nothing was captured before Submit. John asks how Jobert knew when to call. Timing raises a question; it does not identify the page operator by itself."},
		{"id":"c5_status", "title":"Offline is not an alibi", "people":["john","jobert","eric","rham"], "field":"solved", "value":3, "status":"Known", "source":"Chapter 5 / Fourth rebuttal", "text":"Neither Jobert's nor Eric's last-seen status proves sleep or authorship. The timeline challenges Jobert's claimed alibi without establishing a culprit on its own."},
		{"id":"c5_typo", "title":"A repeated word in the hearing chat", "people":["john","jobert"], "field":"final_matched", "status":"Known", "source":"Chapter 5 / Final comparison", "text":"Jobert types 'recieve' in the hearing chat. John matches it to the two emails. The spelling is a reason to ask for an explanation, not a verdict."},
		{"id":"c5_admission", "title":"Jobert's admission", "people":["john","jobert","rham"], "field":"admitted", "status":"Known", "source":"Chapter 5 / Recorded admission", "text":"Jobert admits sending the survey, advisor, payout, and prize messages. He says he called when the page showed input so John would trust him. His admission resolves authorship in this story; the typo and online status alone did not."},
		{"id":"c5_outcome", "title":"The hearing's outcome", "people":["john","eric","dan","mika","jobert","rham"], "field":"aftermath_done", "status":"Known", "source":"Chapter 5 / Sir Rham's decision", "text":"Sir Rham says the accusations against Eric and Dan were unsupported and Mika's conversation was not proof. Jobert is removed from the club; the accounts will be reported and he faces a disciplinary hearing."}
	]
}

static func chapter_definition(number: int) -> GDScript:
	return CHAPTERS[clampi(number - 1, 0, CHAPTERS.size() - 1)]

static func chapter_records(snapshot: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(CHAPTER_OBSERVATIONS.get(int(snapshot.get("_chapter", 1)), OBSERVATIONS))
	return result

static func character_ids(snapshot: Dictionary) -> Array[String]:
	var ids: Array[String] = CHARACTER_IDS.duplicate()
	var number: int = int(snapshot.get("_chapter", 1))
	if number >= 2: ids.append("rham")
	if number > 2 or (number == 2 and seen_beat(snapshot, 20)): ids.append("dan")
	if number > 3 or (number == 3 and seen_beat(snapshot, 7)): ids.append("mika")
	return ids

static func story_snapshot(raw: Dictionary, chapter: int = 1) -> Dictionary:
	# Read-only projection of existing saves. No migration or new unlock flags.
	var snapshot: Dictionary = chapter_definition(chapter).clean(raw)
	snapshot["_chapter"] = clampi(chapter, 1, CHAPTERS.size())
	return snapshot

static func seen_beat(snapshot: Dictionary, index: int) -> bool:
	return snapshot.get("completed", false) == true or str(snapshot.get("phase", "day")) != "day" or int(snapshot.get("beat", 0)) > index

static func observations(snapshot: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var number: int = int(snapshot.get("_chapter", 1))
	for authored: Dictionary in chapter_records(snapshot):
		var discovered: bool = false
		if authored.has("field"):
			var saved: Variant = snapshot.get(str(authored.field))
			discovered = (saved is Array and saved.has(authored.value)) if authored.has("value") else saved == true
		elif authored.has("read_id"):
			discovered = (snapshot.get("read", []) as Array).has(authored.read_id)
		else:
			discovered = seen_beat(snapshot, int(authored.after_beat))
		if not discovered:
			result.append({"id":authored.id, "title":"Undiscovered observation", "status":"Unknown", "source":"Chapter %d" % number, "text":"Continue Chapter %d to discover this record." % number, "people":[], "discovered":false})
			continue
		var item: Dictionary = authored.duplicate(true)
		item.discovered = true
		if authored.has("read_id"):
			var message_id: String = str(authored.read_id)
			if (snapshot.get("flags", []) as Array).has(message_id): item.text += "\n\nInvestigation: you marked the concerning request."
			if (snapshot.get("domains", []) as Array).has(message_id):
				item.text += "\n\nRecorded sender domain: " + str(Survey.message(message_id).address).get_slice("@", 1) + ". A mailbox domain alone does not identify the author."
			if (snapshot.get("captures", []) as Array).has(message_id): item.text += "\n\nMessage capture saved in your Chapter 1 exhibit."
		result.append(item)
	return result

static func discovery_progress(snapshot: Dictionary, person: String = "") -> Dictionary:
	var total: int = 0
	var found: int = 0
	var records: Array[Dictionary] = observations(snapshot)
	var authored: Array[Dictionary] = chapter_records(snapshot)
	for index: int in authored.size():
		if not person.is_empty() and person not in authored[index].people: continue
		total += 1
		if records[index].discovered: found += 1
	return {"found":found, "total":total}

static func character(id: String, snapshot: Dictionary) -> Dictionary:
	if not CHARACTERS.has(id): return {}
	var data: Dictionary = (CHARACTERS[id] as Dictionary).duplicate(true)
	data.id = id
	data.behavior = "More observations unlock as you meet this character in Chapter 1."
	if int(snapshot.get("_chapter", 1)) > 1:
		data.behavior = "This file records only what you have discovered in the selected chapter."
		data.interactions = []
		for observation: Dictionary in observations(snapshot):
			if observation.discovered and id in observation.people: data.interactions.append(observation)
		return data
	match id:
		"john":
			if seen_beat(snapshot, 4):
				data.background += " He is seeking extra income and agrees to look at a survey opportunity."
				data.behavior = "He asks the club about a side gig and is willing to examine Eric's offer."
			if seen_beat(snapshot, 6): data.behavior += " He asks Eric for the client's name."
		"eric":
			if seen_beat(snapshot, 3): data.behavior = "He greets John and offers to save him a seat at the club meeting."
			if seen_beat(snapshot, 4): data.relationship += " He introduces John to the survey opportunity."
			if seen_beat(snapshot, 5): data.background += " He claims to know the client personally; this remains unverified."
		"jobert":
			if seen_beat(snapshot, 4):
				data.behavior = "He voices caution about random surveys and tells John to ask if unsure."
				data.relationship += " He gives John a warning about the survey."
			if seen_beat(snapshot, 9): data.background += " He recommends checking who is behind the survey and offers to help."
	data.interactions = []
	for observation: Dictionary in observations(snapshot):
		if observation.discovered and id in observation.people: data.interactions.append(observation)
	return data

const NOTES := {
	"base": ["Precision defender", "Direct fire rewards careful placement against durable targets. Pair it with crowd control to keep enemies in range.", "Network defense", "Basic Node is a fictional defender inspired by network protection. A real firewall controls traffic using security rules; it does not shoot malware or guarantee protection against every attack.", "NIST / Firewall", "https://csrc.nist.gov/glossary/term/firewall"],
	"scanner": ["Rapid-fire defender", "A fast-firing specialist with a damage advantage against swarm threats. Heavy targets resist its damage.", "Vulnerability scanning", "Security scanning helps identify systems and potential weaknesses. Finding a problem is different from fixing it. The Scanner's rapid-fire attack is a game mechanic, not how real scanning removes threats.", "NIST / Vulnerability scanning", "https://csrc.nist.gov/glossary/term/vulnerability_scanning"],
	"sandbox": ["Control specialist", "Deals no direct damage. Its field buys firing time for nearby defenders, with the strongest slowdown against stealth threats.", "Sandboxing", "A sandbox runs software in a controlled environment with limited permissions and access to resources. The tower's slowing field represents containment; real software is not physically slowed like an enemy on a path.", "NIST / Sandbox", "https://csrc.nist.gov/glossary/term/Sandbox"],
	"basic": ["Stealth intruder", "A steady-moving intruder. Direct damage has no special type modifier against it, but Sandbox applies its strongest slow.", "Unauthorized access", "This enemy represents an intruder, not everyone who uses the word hacker. Protect accounts with unique passwords and multifactor authentication, and report suspicious messages instead of following their instructions.", "CISA / Staying safe online", "https://www.cisa.gov/sites/default/files/2024-09/Secure-Our-World-4-Easy-Ways-Stay-Safe-Online-Tip-Sheet.pdf"],
	"fast": ["Swarm runner", "Low health and high speed make this threat dangerous in groups. Scanner has a damage advantage; Basic Node is less effective.", "Phishing", "Phishing messages impersonate a trusted source to obtain information or make you open harmful links or files. Pause when a message pressures you to act. Report it using a trusted channel instead of engaging with the sender.", "CISA / Recognize and report phishing", "https://www.cisa.gov/sites/default/files/2024-09/Secure-Our-World-4-Easy-Ways-Stay-Safe-Online-Tip-Sheet.pdf"],
	"heavy": ["Heavy intruder", "A slow, durable threat. Focus Basic Node fire on it; Scanner's damage is reduced against this profile.", "Ransomware", "Ransomware can deny access to systems or data, and attackers may also steal information for extortion. Backups and incident planning help organizations recover. Report a suspected incident to your IT team promptly.", "CISA / StopRansomware guide", "https://www.cisa.gov/resources-tools/resources/stopransomware-guide"],
	"boss": ["Heavy / boss variant", "The heavy profile with a much larger health pool. It shares the same matchups as the regular heavy intruder.", "Ransomware incidents", "The boss is a game variant, not a separate real-world malware category. Ransomware incidents can disrupt whole organizations. Recovery requires coordinated response; a single tool is not a complete defense.", "CISA / StopRansomware guide", "https://www.cisa.gov/resources-tools/resources/stopransomware-guide"]
}

static func ids(tab: StringName) -> Array[String]:
	var available := ContentDB.get_all_tower_ids() if tab == &"units" else ContentDB.get_all_enemy_ids()
	var preferred := ["base", "scanner", "sandbox"] if tab == &"units" else ["basic", "fast", "heavy", "boss"]
	var ordered: Array[String] = []
	for id in preferred:
		if id in available:
			ordered.append(id)
	for id in available:
		if id not in ordered:
			ordered.append(id)
	return ordered

static func display_name(tab: StringName, id: String) -> String:
	if tab == &"units":
		return str(ContentDB.get_tower(id).get("name", id.capitalize()))
	return str({"basic": "Hacker", "fast": "Phisherman", "heavy": "Ransomware", "boss": "Ransomware Prime"}.get(id, id.capitalize()))

static func profile(id: String) -> String:
	return EnemyBase.profile_for_character(EnemyBase.character_for_wave(id))

static func entry(tab: StringName, id: String) -> Dictionary:
	var notes: Array = NOTES.get(id, ["Field entry", "Inspect the authored stats and matchup rules below.", "Field notes pending", "No real-world notes have been authored for this entry yet.", "", ""])
	var stats: Dictionary = ContentDB.get_tower(id) if tab == &"units" else ContentDB.get_enemy(id)
	return {"name": display_name(tab, id), "type": str(stats.get("role", "DEFENDER")) if tab == &"units" else profile(id).to_upper(), "subtitle": notes[0], "tactics": notes[1], "real_title": notes[2], "real_body": notes[3], "source": notes[4], "url": notes[5], "stats": stats}

static func matchup(tower_id: String, enemy_id: String) -> Dictionary:
	# No tree membership, assets, initialization or gameplay side effects.
	var probe := EnemyBase.new()
	probe.threat_profile = profile(enemy_id)
	var result: Dictionary
	if tower_id == "sandbox":
		var factor := probe.sandbox_slow_factor()
		result = {"value": factor, "kind": "slow", "tier": str(EnemyBase.matchup_tier(factor, 0.4, 0.8)), "effect": "%d%% slow" % roundi((1.0 - factor) * 100.0)}
	else:
		var multiplier := probe.damage_multiplier_vs(tower_id)
		result = {"value": multiplier, "kind": "damage", "tier": str(EnemyBase.matchup_tier(multiplier, 1.5, 0.5)), "effect": "%.1fx damage" % multiplier}
	probe.free()
	return result

static func matchups(tab: StringName, id: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if tab == &"units":
		var seen: Array[String] = []
		for enemy_id in ids(&"enemies"):
			var type := profile(enemy_id)
			if type in seen:
				continue
			seen.append(type)
			var row := matchup(id, enemy_id)
			row["name"] = type.capitalize()
			row["id"] = enemy_id
			rows.append(row)
	else:
		for tower_id in ids(&"units"):
			var row := matchup(tower_id, id)
			row["name"] = display_name(&"units", tower_id)
			row["id"] = tower_id
			rows.append(row)
	return rows
