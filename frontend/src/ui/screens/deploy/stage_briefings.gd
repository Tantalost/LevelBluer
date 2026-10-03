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
	"mod_01:9": [
		"CUT THE LINE",
		"The fair is nearly ready, but recovery is not finished. Help Alex compare active sessions, hidden mail copies, and a laptop report before the final containment simulation.",
		"Check every remaining path. Let trusted staff handle recovery.",
	],
	"mod_01:10": [
		"READY FOR THE NEXT MESSAGE",
		"The Water Wise team is ready for the fair. Now apply what you learned on your own: fifteen short evidence challenges, with five before each defense wave.",
		"Defend through all three waves and score at least 75% (12 of 15). Answers award no gold.",
	],
	"mod_02:1": [
		"FIRST LOGIN",
		"College orientation brings a new timetable, a new classmate, and an urgent text. Help Alex check the campus portal on his laptop, then protect two entrances in a guided defense simulation.",
		"Check an independent source. Cover both routes.",
	],
	"mod_01:1": [
		"BEFORE THE BELL",
		"One week before the school fair, Alex's inbox interrupts a morning with Mia. A familiar name, a worrying deadline — what should you trust before first period?",
		"Inspect the message. Check a trusted source. Then decide.",
	],
	"mod_01:2": [
		"THEY KNOW OUR PROJECT",
		"Alex and Mia finally have a school-fair project title. Now unfamiliar messages know it too. Check shared notes, fair registration, and folder access before trusting a familiar name.",
		"Real details do not prove a message is real.",
	],
	"mod_01:3": [
		"SOMEONE GOT IN",
		"Alex receives a finished poster from Mia's usual address. But Mia is right beside him, still working on it. Check the request, account activity, and messages reaching classmates.",
		"A familiar account does not guarantee a safe request.",
	],
	"mod_01:4": [
		"THE IMPOSTOR INSIDE",
		"The Water Wise poster is ready, but official-sounding requests keep changing the plan. Check a printing payment, private folder access, and an urgent security instruction before acting.",
		"Verify the request, not just the title behind it.",
	],
	"mod_01:5": [
		"THE SECOND KEY",
		"The poster is ready, but Alex's phone keeps asking about sign-ins he never started. Compare approval requests, active devices, and a suspicious shared-file page before letting anyone in.",
		"Check whose sign-in you are approving.",
	],
	"mod_01:6": [
		"TRUSTED FILES",
		"A chart, an animation app, and a rehearsal timetable should finish the group's preparations. Inspect files, permissions, and QR destinations before trusting the next shortcut.",
		"A familiar name or real sign-in page does not approve every request.",
	],
	"mod_01:7": [
		"TRUSTED SUPPLIER",
		"The display stands are ordered, but familiar-looking messages keep changing the plan. Compare payment details, supplier identities, and adviser approval before risking the group's budget.",
		"Real order details do not authorize a new payment.",
	],
	"mod_01:8": [
		"ALL HANDS",
		"Other project groups are receiving the same dangerous update. Help Alex warn classmates safely, pause affected sharing, and preserve the evidence while Ms. Reyes and School IT help.",
		"Protect people as well as files. Report without blame.",
	],
}

static func get_note(stage_id: int, module_id: String = "") -> Dictionary:
	var key: String = "%s:%d" % [module_id.strip_edges(), stage_id]
	var note: Array = MODULE_NOTES.get(key, NOTES.get(stage_id, ["SIGNAL PENDING", "This operation has not been revealed yet.", "More information will arrive with the mission."]))
	return {"eyebrow": note[0], "teaser": note[1], "hint": note[2]}
