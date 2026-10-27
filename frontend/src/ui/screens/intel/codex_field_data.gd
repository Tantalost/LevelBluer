extends RefCounted
## Editorial field notes plus live combat rules. No duplicate damage tables.
const Survey: GDScript = preload("res://src/gameplay/decision/survey_chapter.gd")
const CHARACTER_IDS: Array[String] = ["john", "eric", "jobert"]
const CHARACTERS: Dictionary = {
	"john": {"name":"John", "role":"Student / Protagonist", "background":"A student whose perspective you follow in Chapter 1.", "relationship":"You follow John's experiences and investigation."},
	"eric": {"name":"Eric", "role":"Club member", "background":"A member of John's school club.", "relationship":"John's fellow club member."},
	"jobert": {"name":"Jobert", "role":"Club member", "background":"A member of John's school club.", "relationship":"John's fellow club member."}
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

static func story_snapshot(raw: Dictionary) -> Dictionary:
	# Read-only projection of existing saves. No migration or new unlock flags.
	return Survey.clean(raw)

static func seen_beat(snapshot: Dictionary, index: int) -> bool:
	return snapshot.get("completed", false) == true or str(snapshot.get("phase", "day")) != "day" or int(snapshot.get("beat", 0)) > index

static func observations(snapshot: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for authored: Dictionary in OBSERVATIONS:
		var discovered: bool = (snapshot.get("read", []) as Array).has(authored.read_id) if authored.has("read_id") else seen_beat(snapshot, int(authored.after_beat))
		if not discovered:
			result.append({"id":authored.id, "title":"Undiscovered observation", "status":"Unknown", "source":"Chapter 1", "text":"Continue Chapter 1 to discover this record.", "people":[], "discovered":false})
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
	for index: int in OBSERVATIONS.size():
		if not person.is_empty() and person not in OBSERVATIONS[index].people: continue
		total += 1
		if records[index].discovered: found += 1
	return {"found":found, "total":total}

static func character(id: String, snapshot: Dictionary) -> Dictionary:
	if not CHARACTERS.has(id): return {}
	var data: Dictionary = (CHARACTERS[id] as Dictionary).duplicate(true)
	data.id = id
	data.behavior = "More observations unlock as you meet this character in Chapter 1."
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
