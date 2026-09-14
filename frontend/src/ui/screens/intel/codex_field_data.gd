extends RefCounted
## Editorial field notes plus live combat rules. No duplicate damage tables.
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
