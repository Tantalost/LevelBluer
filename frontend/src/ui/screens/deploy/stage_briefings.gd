extends RefCounted
## Spoiler-light flavor copy, not enemy intelligence or gameplay configuration.
## NOTES is keyed by stage number alone and shared across every module — do
## not rely on it for a single module's story. MODULE_NOTES overrides it for
## one authored "module_id:stage_id" card at a time, so giving Module 1
## Stage 2 its own copy never touches Module 1 Stage 1 or any other module's
## same-numbered stage.
const NOTES := {
	1: ["FIRST CONTACT", "A quiet inbox. A signal that does not belong. Your first defense begins with a simple question: what can you trust?", "Establish your defense. Stay curious."],
	2: ["PATTERN BREAK", "The familiar rhythm is slipping. What looked predictable a moment ago may deserve a second look.", "Observe first. Be ready to reconsider."],
	3: ["BETWEEN THE LINES", "There is noise in the traffic. Somewhere inside it, a small detail refuses to fit.", "Look beyond the first impression."],
	4: ["HOLD THE LINE", "The boundary is drawn. On the other side, something is testing how carefully you are watching.", "Every decision at the edge matters."],
	5: ["HIDDEN IN PLAIN SIGHT", "The message looks ordinary. The feeling it leaves behind does not. Keep your attention on what seems too easy.", "Familiar does not always mean safe."],
	6: ["STATIC RISING", "The channel grows restless. As the noise builds, the hardest signal to hear may be the one worth noticing.", "Keep a clear head under pressure."],
	7: ["SECOND LOOK", "A clean surface can hide an untidy story. This time, the first glance may not tell you enough.", "Ask what the details are really saying."],
	8: ["UNKNOWN FREQUENCY", "Something unfamiliar is cutting through the signal. Old assumptions feel less comfortable here.", "Expect uncertainty. Trust careful judgment."],
	9: ["BEYOND THE PERIMETER", "The edge of the network no longer feels far away. A familiar-looking message deserves an unfamiliar level of caution.", "Watch what you choose to trust."],
	10: ["FINAL CHECKPOINT", "The last checkpoint is waiting. Everything you have learned comes with you; the decisions ahead are yours.", "Bring your knowledge. Leave assumptions behind."],
}

const MODULE_NOTES := {
	"mod_01:2": [
		"THEY KNOW WHO WE ARE",
		"The phishing campaign becomes more targeted. Investigate messages that use real BlueTech information before employees trust the wrong source.",
		"Real details do not prove a message is real.",
	],
}

static func get_note(stage_id: int, module_id: String = "") -> Dictionary:
	var key: String = "%s:%d" % [module_id.strip_edges(), stage_id]
	var note: Array = MODULE_NOTES.get(key, NOTES.get(stage_id, ["SIGNAL PENDING", "This operation has not been revealed yet.", "More information will arrive with the mission."]))
	return {"eyebrow": note[0], "teaser": note[1], "hint": note[2]}
