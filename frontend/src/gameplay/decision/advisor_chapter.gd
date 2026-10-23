extends RefCounted
## Authored case data and validation, independent of presentation and persistence.
const ID: String = "mod_01_ch_02"
const NUMBER: int = 2
const TITLE: String = "The Advisor Email"
const NIGHT_BACKGROUND: String = "john_bed_night"
const BASE_REWARD: int = 100
const CLEAN_BONUS: int = 25
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const FIRST_PHASE: String = "compare"
const TASKS: Dictionary = {
	"compare":{"title":"01 / Spot the differences", "tip":"Compare sender, wording and signature.", "line":"Same name. Different details.", "field":"flags", "total":3, "next":"report"},
	"report":{"title":"02 / Report to IT", "tip":"Retype the sender domain. The reference stays visible.", "line":"One character nearly fooled me.", "field":"domains", "total":1, "next":"headers"},
	"headers":{"title":"03 / Follow the reply", "tip":"Drag labels onto fields, or tap a label then a field.", "line":"Where would my answer actually go?", "field":"headers", "total":3, "next":"seal"}
}
const EVIDENCE: String = "3 evidence bundles\n\n01 · Lookalike sender domain\n02 · Reply-To differs from From\n03 · Urgency, generic wording and familiar club format\n\nDan knows the format. That is context, not proof that he sent this."
const SEAL_LINE: String = "I need more than a bad feeling. Now I can show exactly what changed."
const SLEEP_LINE: String = "The sender. The reply address. The message itself.\nSaved.\nTomorrow, I'll ask Sir Rham myself."
const END_CAPTION: String = "I caught this one.\nI thought that meant I was getting better."
const MESSAGES: Array[Dictionary] = [
	{"id":"real", "sender":"Sir Rham", "address":"sir.rham@school.example", "reply":"sir.rham@school.example", "subject":"[CLUB UPDATE] Friday Meeting Reminder", "body":"Hi, everyone,\n\nOur meeting starts at 3 PM in the clubroom. Bring your project notes.\n\nPlease leave the chairs in their usual arrangement this time.", "signature":"Sir Rham\nClub Advisor", "phrase":"Known earlier email · Confirmed meeting details", "suspicious":false},
	{"id":"fake", "sender":"Sir Rham — Club Advisor", "address":"sir.rham@schoo1.example", "reply":"club.records@member-support.example", "subject":"[CLUB UPDATE] Member Details Confirmation", "body":"Dear Club Member,\n\nWe are updating club records. Confirm your full name, section, mobile number, and home address by replying within 24 hours.\n\nMembers who do not respond may be removed from the active list.", "signature":"Regards,\nClub Administration", "phrase":"A familiar club format does not establish who sent this message.", "suspicious":true}
]
const STORY: Array[Dictionary] = [
	{"who":"John", "face":1, "bg":"hallway_day", "cast":["john"], "caption":"Four days before everything went wrong.", "line":"Made it before the bell.\nNo running.\nNo excuses."},
	{"who":"John", "face":2, "bg":"hallway_day", "cast":["john"], "caption":"This time, the message had a familiar name.", "line":"I should stop celebrating so early.\nClub records?", "mail":true, "email":"fake", "notification":true},
	{"who":"John", "face":2, "bg":"hallway_day", "cast":["john"], "line":"Removed?\nI finally arrive on time, and now I might not even be a member.\nName.\nSection.\nNumber…", "mail":true, "email":"fake", "draft":true},
	{"who":"John", "face":4, "bg":"hallway_day", "cast":["john"], "line":"Wait.\nDidn't we already fill this out?\nJobert said to ask if I wasn't sure.\nOne message won't hurt.", "chat":true, "chat_id":"private"},
	{"who":"Jobert", "face":0, "bg":"hallway_day", "cast":["john","jobert"], "line":"Open his email about last week's meeting."},
	{"who":"John", "face":1, "bg":"hallway_day", "cast":["john","jobert"], "line":"The one telling us not to move the chairs?"},
	{"who":"Jobert", "face":1, "bg":"hallway_day", "cast":["john","jobert"], "line":"After Eric built a throne?"},
	{"who":"John", "face":1, "bg":"hallway_day", "cast":["john","jobert"], "line":"It was a very unstable throne.", "mail":true, "email":"real"},
	{"who":"John", "face":0, "bg":"hallway_day", "cast":["john","jobert"], "line":"Same name."},
	{"who":"Jobert", "face":4, "bg":"hallway_day", "cast":["john","jobert"], "line":"Now compare the part after the @."},
	{"who":"John", "face":2, "bg":"hallway_day", "cast":["john","jobert"], "line":"School…\nThat's a one."},
	{"who":"Jobert", "face":0, "bg":"hallway_day", "cast":["john","jobert"], "line":"Not an L."},
	{"who":"John", "face":2, "bg":"hallway_day", "cast":["john","jobert"], "line":"I nearly sent my home address to a typo."},
	{"who":"Jobert", "face":4, "bg":"hallway_day", "cast":["john","jobert"], "line":"An address that looks like his.\nWe still need to check the rest."},
	{"who":"John", "face":0, "bg":"hallway_day", "cast":["john","jobert"], "line":"The real one sounds like him.\nEspecially the chairs."},
	{"who":"Jobert", "face":0, "bg":"hallway_day", "cast":["john","jobert"], "line":"And this one?"},
	{"who":"John", "face":2, "bg":"hallway_day", "cast":["john","jobert"], "line":"Dear Club Member.\nSuddenly I don't even have a name."},
	{"who":"Jobert", "face":4, "bg":"hallway_day", "cast":["john","jobert"], "line":"Keep both emails.\nAnd leave that reply unsent."},
	{"who":"John", "face":1, "bg":"hallway_day", "cast":["john","jobert"], "line":"You just saved me from introducing myself to a stranger."},
	{"who":"Jobert", "face":1, "bg":"hallway_day", "cast":["john","jobert"], "line":"You stopped and asked.\nThat part was you."},
	{"who":"John", "face":0, "bg":"clubroom", "cast":["john"], "line":"Later, I'm the first one back in the clubroom.\nMaybe someone else got that email.", "chat":true, "chat_id":"club"},
	{"who":"John", "face":6, "sentence_faces":[6,1,0], "bg":"clubroom", "cast":["john"], "line":"I laughed.\nIt was a joke.\nSo why did I read it twice?"},
	{"who":"John", "face":2, "bg":"john_bed_night", "time":"night", "line":"The draft is still here.\nMy name, halfway typed.\nI'm deleting the draft, not the email.", "mail":true, "email":"fake", "draft":true},
	{"who":"John", "face":2, "bg":"john_bed_night", "time":"night", "line":"Jobert caught the address.\nBut something else is bothering me.\nHold on.\nThat isn't the address it came from.", "mail":true, "email":"fake", "reply_preview":true},
	{"who":"John", "face":2, "bg":"john_bed_night", "time":"night", "line":"It wears Sir Rham's name.\nUses our club's format.\nThen sends my answer somewhere else.\nDan said the format was easy.\nThat doesn't mean he sent it.\nI need more than a bad feeling."}
]
const PRIVATE_CHAT: Array[Dictionary] = [
	{"who":"John","face":0,"text":"Did Sir Rham ask you to confirm your club details?"},
	{"who":"Jobert","face":0,"text":"What details?"},
	{"who":"John","face":0,"text":"Name, section, number, home address."},
	{"who":"John","face":2,"text":"Says I have 24 hours or I'm off the list."},
	{"who":"Jobert","face":2,"text":"Did you reply?"},
	{"who":"John","face":2,"text":"Almost."},
	{"who":"Jobert","face":0,"text":"Good thing you asked."},
	{"who":"Jobert","face":4,"text":"Check the sender first."},
	{"who":"John","face":0,"text":"It says Sir Rham."},
	{"who":"Jobert","face":4,"text":"Tap the name. The address underneath."},
	{"who":"John","face":0,"text":"Looks right to me."},
	{"who":"Jobert","face":0,"text":"I'm by the stairs. Coming over."}
]
const CHAT_MESSAGES: Array[Dictionary] = [
	{"who":"John","face":0,"text":"Anyone else get a weird email pretending to be Sir Rham?"},
	{"who":"Eric","face":2,"text":"Please tell me it's not about the chairs."},
	{"who":"John","face":1,"text":"Different crime."},
	{"who":"Dan","face":0,"text":"Maybe somebody finally hacked Sir's inbox 😂"},
	{"who":"Dan","face":0,"text":"Imagine sending 'meeting cancelled' from his account."},
	{"who":"Eric","face":0,"text":"Imagine explaining that to him."},
	{"who":"Dan","face":0,"text":"Relax. I'm joking."},
	{"who":"John","face":2,"text":"It even had our [CLUB UPDATE] subject."},
	{"who":"Dan","face":0,"text":"That part's easy."},
	{"who":"Dan","face":0,"text":"Same format every time. I could write one in my sleep."},
	{"who":"Jobert","face":4,"text":"Knowing the format doesn't tell us who sent it."},
	{"who":"Dan","face":0,"text":"Exactly. Don't arrest me over punctuation."},
	{"who":"Eric","face":1,"text":"The chair investigation remains open."}
]

static func fresh() -> Dictionary:
	return {"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"headers":[],"report_draft":"","mistakes":0,"hint_used":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{}}

static func message(id: String) -> Dictionary:
	for entry: Dictionary in MESSAGES:
		if entry.id == id: return entry
	return {}

static func suspicious_ids() -> Array[String]:
	return ["fake"]

static func complete_evidence(state: Dictionary) -> bool:
	return state.get("flags", []).size() == 3 and state.get("domains", []).has("fake") and state.get("headers", []).size() == 3

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	var valid: Dictionary = {"read":["real","fake"],"captures":["real","fake"],"flags":["domain","wording","signature"],"domains":["fake"],"headers":["From","Reply-To","Subject"]}
	for field: String in valid:
		var values: Variant = raw.get(field, [])
		if values is Array:
			for value: Variant in values:
				if value in valid[field] and not state[field].has(value): state[field].append(value)
	for field: String in ["beat","mistakes"]:
		var value: Variant = raw.get(field, 0)
		if (value is int or value is float) and is_finite(float(value)): state[field] = clampi(int(value), 0, STORY.size() - 1 if field == "beat" else 9999)
	state.report_draft = str(raw.get("report_draft", "")).left(80)
	state.hint_used = raw.get("hint_used", false) == true
	state.perk_run = Perks.clean_run(raw.get("perk_run", {}))
	if state.perk_run.get("chapter", ID) != ID: state.perk_run = {}
	var phase: String = str(raw.get("phase", "day"))
	if phase in ["day","compare","report","headers","seal","sleep","closing","done"]: state.phase = phase
	if state.phase in ["report","headers","seal","sleep","closing","done"] and state.flags.size() < 3: state.phase = "compare"
	if state.phase in ["headers","seal","sleep","closing","done"] and state.domains.is_empty(): state.phase = "report"
	if state.phase in ["seal","sleep","closing","done"] and state.headers.size() < 3: state.phase = "headers"
	state.sealed = raw.get("sealed", false) == true and complete_evidence(state)
	state.completed = raw.get("completed", false) == true and state.sealed
	if state.completed:
		state.phase = "done"
		state.next_chapter_unlocked = true
		state.reward = BASE_REWARD + (CLEAN_BONUS if Perks.status(state.perk_run, state.hint_used) != "assisted" and state.mistakes == 0 else 0)
	elif state.phase in ["sleep","closing","done"] and not state.sealed: state.phase = "seal"
	return state

static func domain_matches(answer: String, _id: String = "fake") -> bool:
	return answer.strip_edges().to_lower() == "schoo1.example"
