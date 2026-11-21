extends RefCounted
const Rewards: GDScript = preload("res://src/gameplay/decision/story_rewards.gd")
## Contact content stays outside the reusable phone view. No invented numbers.
const CONTACTS: Array[Dictionary] = [
	{"id":"dan", "title":"Dan", "body":"Saved contact: Dan", "portrait":"chapter1_dan"},
	{"id":"eric", "title":"Eric", "body":"Saved contact: Eric", "portrait":"chapter1_eric"},
	{"id":"jobert", "title":"Jobert", "body":"Saved contact: Jobert", "portrait":"chapter1_jobert", "action":"message"},
	{"id":"sir_rham", "title":"Sir Rham", "body":"Saved contact: Sir Rham", "portrait":"story_rham_poses"}
]
## Authored case data and validation, independent of presentation and persistence.
const ID: String = "mod_01_ch_02"
const STAR_GOALS: Dictionary = Rewards.GOALS[ID]
const STAR_IDS: Array[String] = ["compare", "report", "headers"]
const STAR_CREDITS: int = 25
const NUMBER: int = 2
const TITLE: String = "The Advisor Email"
const NIGHT_BACKGROUND: String = "john_bed_night"
const BASE_REWARD: int = 100
const CLEAN_BONUS: int = 25
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const FIRST_PHASE: String = "compare"
const TASKS: Dictionary = {
	"compare":{"title":"01 / Spot the differences", "tip":"Compare sender, wording and signature.", "line":"Same name. Different details.", "voice":"v1794556879/levelblue/voice/mod_01/ch_02/M01_CH02_26_John.mp3", "field":"flags", "total":3, "next":"report"},
	"report":{"title":"02 / Report to IT", "tip":"Retype the sender domain. The reference stays visible.", "line":"One character nearly fooled me.", "voice":"v1794556880/levelblue/voice/mod_01/ch_02/M01_CH02_27_John.mp3", "field":"domains", "total":1, "next":"headers"},
	"headers":{"title":"03 / Follow the reply", "tip":"Drag labels onto fields, or tap a label then a field.", "line":"Where would my answer actually go?", "voice":"v1794556881/levelblue/voice/mod_01/ch_02/M01_CH02_28_John.mp3", "field":"headers", "total":3, "next":"seal"}
}
const EVIDENCE: String = "3 evidence bundles\n\n01 · Lookalike sender domain\n02 · Reply-To differs from From\n03 · Urgency, generic wording and familiar club format\n\nDan knows the format. That is context, not proof that he sent this."
const SEAL_LINE: String = "I need more than a bad feeling. Now I can show exactly what changed."
const SEAL_VOICE: String = "v1794556882/levelblue/voice/mod_01/ch_02/M01_CH02_29_John.mp3"
const SLEEP_LINE: String = "The sender. The reply address. The message itself.\nSaved.\nTomorrow, I'll ask Sir Rham myself."
const SLEEP_VOICE: String = "v1794556882/levelblue/voice/mod_01/ch_02/M01_CH02_30_John.mp3"
const END_CAPTION: String = "I caught this one.\nI thought that meant I was getting better."
const END_VOICE: String = "v1794556883/levelblue/voice/mod_01/ch_02/M01_CH02_31_John.mp3"
# Subtitle page starts measured from the original recordings; playback keeps its natural pace.
const VOICE_TIMINGS: Dictionary = {
	"M01_CH02_01_John.mp3": [0.0, 1.76],
	"M01_CH02_02_John.mp3": [0.0, 4.02],
	"M01_CH02_03_John.mp3": [0.0, 1.98, 7.28, 7.8, 8.32],
	"M01_CH02_04_John.mp3": [0.0, 1.5, 4.86, 7.1],
	"M01_CH02_05_Jobert.mp3": [0.0],
	"M01_CH02_06_John.mp3": [0.0],
	"M01_CH02_07_Jobert.mp3": [0.0],
	"M01_CH02_08_John.mp3": [0.0],
	"M01_CH02_09_John.mp3": [0.0],
	"M01_CH02_10_Jobert.mp3": [0.0],
	"M01_CH02_11_John.mp3": [0.0, 1.98],
	"M01_CH02_12_Jobert.mp3": [0.0],
	"M01_CH02_13_John.mp3": [0.0],
	"M01_CH02_14_Jobert.mp3": [0.0, 3.1],
	"M01_CH02_15_John.mp3": [0.0, 2.98],
	"M01_CH02_16_Jobert.mp3": [0.0],
	"M01_CH02_17_John.mp3": [0.0, 2.98],
	"M01_CH02_18_Jobert.mp3": [0.0, 1.34],
	"M01_CH02_19_John.mp3": [0.0],
	"M01_CH02_20_Jobert.mp3": [0.0, 2.32],
	"M01_CH02_21.mp3": [0.0, 3.14],
	"M01_CH02_22_John.mp3": [0.0, 2.78, 4.78],
	"M01_CH02_23_John.mp3": [0.0, 2.74, 5.88],
	"M01_CH02_24_John.mp3": [0.0, 2.72, 5.46, 6.44],
	"M01_CH02_25_John.mp3": [0.0, 2.66, 5.64, 7.98, 10.26, 13.26],
	"M01_CH02_26_John.mp3": [0.0, 2.06],
	"M01_CH02_27_John.mp3": [0.0],
	"M01_CH02_28_John.mp3": [0.0],
	"M01_CH02_29_John.mp3": [0.0, 2.9],
	"M01_CH02_30_John.mp3": [0.0, 1.58, 3.24, 5.06, 6.32],
	"M01_CH02_31_John.mp3": [0.0, 2.3],
}
const MESSAGES: Array[Dictionary] = [
	{"id":"real", "sender":"Sir Rham", "address":"sir.rham@school.example", "reply":"sir.rham@school.example", "subject":"[CLUB UPDATE] Friday Meeting Reminder", "body":"Hi, everyone,\n\nOur meeting starts at 3 PM in the clubroom. Bring your project notes.\n\nPlease leave the chairs in their usual arrangement this time.", "signature":"Sir Rham\nClub Advisor", "phrase":"Known earlier email · Confirmed meeting details", "suspicious":false},
	{"id":"fake", "sender":"Sir Rham — Club Advisor", "address":"sir.rham@schoo1.example", "reply":"club.records@member-support.example", "subject":"[CLUB UPDATE] Member Details Confirmation", "body":"Dear Club Member,\n\nWe are updating club records. Confirm your full name, section, mobile number, and home address by replying within 24 hours.\n\nMembers who do not respond may be removed from the active list.", "signature":"Regards,\nClub Administration", "phrase":"A familiar club format does not establish who sent this message.", "suspicious":true}
]
const STORY: Array[Dictionary] = [
	{"mood":"calm", "thought":true, "who":"John", "face":1, "bg":"hallway_day", "cast":["john"], "caption":"Four days before everything went wrong.", "voice":"v1794556861/levelblue/voice/mod_01/ch_02/M01_CH02_01_John.mp3", "line":"Whew! Made it before the bell."},
	{"mood":"mystery", "thought":true, "who":"John", "face":2, "bg":"hallway_day", "cast":["john"], "caption":"This time, the message had a familiar name.", "voice":"v1794556861/levelblue/voice/mod_01/ch_02/M01_CH02_02_John.mp3", "line":"I should stop celebrating so early.\nClub records?", "mail":true, "email":"fake", "notification":true},
	{"mood":"suspense", "thought":true, "who":"John", "face":2, "bg":"hallway_day", "cast":["john"], "voice":"v1794556865/levelblue/voice/mod_01/ch_02/M01_CH02_03_John.mp3", "line":"Removed?\nI finally arrive on time, and now I might not even be a member.\nName.\nSection.\nNumber…", "mail":true, "email":"fake", "draft":true},
	{"thought":true, "who":"John", "face":4, "bg":"hallway_day", "cast":["john"], "voice":"v1794556861/levelblue/voice/mod_01/ch_02/M01_CH02_04_John.mp3", "line":"Wait.\nDidn't we already fill this out?\nJobert said to ask if I wasn't sure.\nOne message won't hurt.", "chat":true, "chat_id":"private"},
	{"mood":"mystery", "who":"Jobert", "face":0, "bg":"hallway_day", "cast":["john","jobert"], "voice":"v1794556863/levelblue/voice/mod_01/ch_02/M01_CH02_05_Jobert.mp3", "line":"Open his email about last week's meeting."},
	{"mood":"calm", "who":"John", "face":1, "bg":"hallway_day", "cast":["john","jobert"], "voice":"v1794556864/levelblue/voice/mod_01/ch_02/M01_CH02_06_John.mp3", "line":"The one telling us not to move the chairs?"},
	{"who":"Jobert", "face":1, "bg":"hallway_day", "cast":["john","jobert"], "voice":"v1794556864/levelblue/voice/mod_01/ch_02/M01_CH02_07_Jobert.mp3", "line":"After Eric built a throne?"},
	{"who":"John", "face":1, "bg":"hallway_day", "cast":["john","jobert"], "voice":"v1794556866/levelblue/voice/mod_01/ch_02/M01_CH02_08_John.mp3", "line":"It was a very unstable throne.", "mail":true, "email":"real"},
	{"mood":"mystery", "who":"John", "face":0, "bg":"hallway_day", "cast":["john","jobert"], "voice":"v1794556866/levelblue/voice/mod_01/ch_02/M01_CH02_09_John.mp3", "line":"Same name."},
	{"who":"Jobert", "face":4, "bg":"hallway_day", "cast":["john","jobert"], "voice":"v1794556867/levelblue/voice/mod_01/ch_02/M01_CH02_10_Jobert.mp3", "line":"Now compare the part after the @."},
	{"who":"John", "face":2, "bg":"hallway_day", "cast":["john","jobert"], "voice":"v1794556867/levelblue/voice/mod_01/ch_02/M01_CH02_11_John.mp3", "line":"School…\nThat's a one."},
	{"who":"Jobert", "face":0, "bg":"hallway_day", "cast":["john","jobert"], "voice":"v1794556869/levelblue/voice/mod_01/ch_02/M01_CH02_12_Jobert.mp3", "line":"Not an L."},
	{"who":"John", "face":2, "bg":"hallway_day", "cast":["john","jobert"], "voice":"v1794556869/levelblue/voice/mod_01/ch_02/M01_CH02_13_John.mp3", "line":"I nearly sent my home address to a typo."},
	{"who":"Jobert", "face":4, "bg":"hallway_day", "cast":["john","jobert"], "voice":"v1794556871/levelblue/voice/mod_01/ch_02/M01_CH02_14_Jobert.mp3", "line":"An address that looks like his.\nWe still need to check the rest."},
	{"who":"John", "face":0, "bg":"hallway_day", "cast":["john","jobert"], "voice":"v1794556870/levelblue/voice/mod_01/ch_02/M01_CH02_15_John.mp3", "line":"The real one sounds like him.\nEspecially the chairs."},
	{"who":"Jobert", "face":0, "bg":"hallway_day", "cast":["john","jobert"], "voice":"v1794556871/levelblue/voice/mod_01/ch_02/M01_CH02_16_Jobert.mp3", "line":"And this one?"},
	{"who":"John", "face":2, "bg":"hallway_day", "cast":["john","jobert"], "voice":"v1794556872/levelblue/voice/mod_01/ch_02/M01_CH02_17_John.mp3", "line":"Dear Club Member.\nSuddenly I don't even have a name."},
	{"who":"Jobert", "face":4, "bg":"hallway_day", "cast":["john","jobert"], "voice":"v1794556873/levelblue/voice/mod_01/ch_02/M01_CH02_18_Jobert.mp3", "line":"Keep both emails.\nAnd leave that reply unsent."},
	{"mood":"resolve", "who":"John", "face":1, "bg":"hallway_day", "cast":["john","jobert"], "voice":"v1794556873/levelblue/voice/mod_01/ch_02/M01_CH02_19_John.mp3", "line":"You just saved me from introducing myself to a stranger."},
	{"who":"Jobert", "face":1, "bg":"hallway_day", "cast":["john","jobert"], "voice":"v1794556874/levelblue/voice/mod_01/ch_02/M01_CH02_20_Jobert.mp3", "line":"You stopped and asked.\nThat part was you."},
	{"thought":true, "who":"John", "face":0, "bg":"clubroom", "cast":["john"], "voice":"v1794556876/levelblue/voice/mod_01/ch_02/M01_CH02_21.mp3", "line":"I'm the first one back in the clubroom.\nMaybe someone else got that email.", "chat":true, "chat_id":"club"},
	{"mood":"mystery", "thought":true, "who":"John", "face":6, "sentence_faces":[6,1,0], "bg":"clubroom", "cast":["john"], "voice":"v1794556877/levelblue/voice/mod_01/ch_02/M01_CH02_22_John.mp3", "line":"I laughed.\nIt was a joke.\nSo why did I read it twice?"},
	{"thought":true, "who":"John", "face":2, "bg":"john_bed_night", "time":"night", "voice":"v1794556877/levelblue/voice/mod_01/ch_02/M01_CH02_23_John.mp3", "line":"The draft is still here.\nMy name, halfway typed.\nI'm deleting the draft, not the email.", "mail":true, "email":"fake", "draft":true},
	{"thought":true, "who":"John", "face":2, "bg":"john_bed_night", "time":"night", "voice":"v1794556878/levelblue/voice/mod_01/ch_02/M01_CH02_24_John.mp3", "line":"Jobert caught the address.\nBut something else is bothering me.\nHold on.\nThat isn't the address it came from.", "mail":true, "email":"fake", "reply_preview":true},
	{"thought":true, "who":"John", "face":2, "bg":"john_bed_night", "time":"night", "voice":"v1794556879/levelblue/voice/mod_01/ch_02/M01_CH02_25_John.mp3", "line":"It wears Sir Rham's name.\nUses our club's format.\nThen sends my answer somewhere else.\nDan said the format was easy.\nThat doesn't mean he sent it.\nI need more than a bad feeling."}
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
	return {"performance_version":1,"star_tracking":true,"star_blocked":[],"hotspot_order":[],"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"headers":[],"report_draft":"","mistakes":0,"hint_used":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{}}

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
	Rewards.track(state, raw, ID)
	if state.completed and state.performance_version == 1:
		state.reward = Rewards.base(ID, state)
	return state

static func domain_matches(answer: String, _id: String = "fake") -> bool:
	return answer.strip_edges().to_lower() == "schoo1.example"
