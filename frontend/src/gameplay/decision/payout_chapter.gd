extends RefCounted
const Rewards: GDScript = preload("res://src/gameplay/decision/story_rewards.gd")
## Fictional, offline case. No credential collection or external navigation.
const ID: String = "mod_01_ch_03"
const STAR_GOALS: Dictionary = Rewards.GOALS[ID]
const STAR_IDS: Array[String] = ["links", "thorough", "priority"]
const STAR_CREDITS: int = 25
const NUMBER: int = 3
const TITLE: String = "The Payout"
const NIGHT_BACKGROUND: String = "john_bed_night"
const BASE_REWARD: int = 100
const CLEAN_BONUS: int = 25
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const FIRST_PHASE: String = "reveal"
const DISPLAY_URL: String = "https://pocketwallet.example/verify"
const SHORT_URL: String = "https://short.example/payout"
const DESTINATION: String = "http://pocket-wallet-verify.example/login"
const TASKS: Dictionary = {
	"reveal":{"title":"01 / Read the destination", "tip":"Hold the link to reveal its destination. Compare both addresses.", "line":"Read the destination. Not the promise.", "voice":"v1794708965/levelblue/voice/mod_01/ch_03/M01_CH03_35_John.mp3", "field":"revealed", "total":1, "next":"expand"},
	"expand":{"title":"02 / Follow the short link", "tip":"Drag the short link into Expand Link, or tap it then tap the box.", "line":"What is this little link hiding?", "voice":"v1794708965/levelblue/voice/mod_01/ch_03/M01_CH03_36_John.mp3", "field":"expanded", "total":1, "next":"flaws"},
	"flaws":{"title":"03 / Inspect the login page", "tip":"Find three clues, then review the address and connection before saving.", "line":"I saw the logo. I didn't look at the address.", "voice":"v1794708966/levelblue/voice/mod_01/ch_03/M01_CH03_37_John.mp3", "field":"hotspots", "total":5, "next":"seal"}
}
const CLUES: Dictionary = {
	"domain":"This domain does not match pocketwallet.example, the wallet's known address.",
	"http":"The destination uses HTTP, not HTTPS. Do not enter login details. HTTPS alone would not prove a site is genuine.",
	"security":"The missing secure-connection indicator supports the HTTP warning. These are related observations, not independent proof.",
	"logo":"The logo is blurry. Copied branding is a supporting clue, not proof on its own.",
	"spelling":"The button says 'LOGN IN'. Consider the spelling error alongside the address and connection."
}
const EVIDENCE: String = "3 evidence bundles\n\n01 · Displayed link and actual address do not match\n02 · A shortened link conceals the destination\n03 · The login page uses an odd domain and HTTP\n\nThe missing secure indicator supports the HTTP finding. Branding and spelling are supporting clues.\n\nEric's request and Mika's whispering are context, not proof of who sent the email."
const SEAL_LINE: String = "I saw the logo.\nI didn't look at the address.\nNow I can show where the link really leads."
const SEAL_VOICE: String = "v1794708967/levelblue/voice/mod_01/ch_03/M01_CH03_38_John.mp3"
const SLEEP_LINE: String = "I should tell Jobert what I found."
const SLEEP_VOICE: String = "v1794708967/levelblue/voice/mod_01/ch_03/M01_CH03_39_John.mp3"
const END_CAPTION: String = "Eric needed money. Mika knew he was asking.\nBut that didn't tell me who sent the email.\nSomeone promised me a payout.\nSomeone else knew exactly when to call.\nFor now, I knew who I trusted."
const END_VOICE: String = "v1794708968/levelblue/voice/mod_01/ch_03/M01_CH03_40_John.mp3"
const SLEEP_CHAT: Array[Dictionary] = [
	{"who":"John","face":0,"text":"The address was wrong. The short link hid it."},
	{"who":"John","face":1,"text":"And that login page had more problems than my first project."},
	{"who":"Jobert","face":0,"text":"But you stopped before submitting."},
	{"who":"John","face":0,"text":"Because you called."},
	{"who":"Jobert","face":0,"text":"Next time, check before opening it."},
	{"who":"John","face":1,"text":"Next time, you're getting the screenshot first."},
	{"who":"Eric","face":0,"channel":"Eric","text":"Any update on the money?"}
]
# Subtitle page starts measured from the original recordings; playback keeps its natural pace.
const VOICE_TIMINGS: Dictionary = {
	"M01_CH03_01_John.mp3": [0.0],
	"M01_CH03_02_John.mp3": [0.0, 2.28, 3.96],
	"M01_CH03_03_John.mp3": [0.0, 2.72],
	"M01_CH03_04_John.mp3": [0.0],
	"M01_CH03_05_John.mp3": [0.0, 2.7],
	"M01_CH03_06_John.mp3": [0.0],
	"M01_CH03_07_Mika.mp3": [0.0],
	"M01_CH03_08_Eric.mp3": [0.0, 1.98],
	"M01_CH03_09_John.mp3": [0.0],
	"M01_CH03_10_Mika.mp3": [0.0],
	"M01_CH03_11_John.mp3": [0.0, 2.72],
	"M01_CH03_12_Eric.mp3": [0.0],
	"M01_CH03_13_John.mp3": [0.0],
	"M01_CH03_14_John.mp3": [0.0, 2.08],
	"M01_CH03_15_John.mp3": [0.0, 1.02, 4.3],
	"M01_CH03_16_John.mp3": [0.0, 2.6],
	"M01_CH03_17_John.mp3": [0.0, 1.68],
	"M01_CH03_18_Jobert.mp3": [0.0, 1.14],
	"M01_CH03_19_John.mp3": [0.0, 1.88],
	"M01_CH03_20_Jobert.mp3": [0.0, 2.4],
	"M01_CH03_21_John.mp3": [0.0],
	"M01_CH03_22_Jobert.mp3": [0.0],
	"M01_CH03_23_John.mp3": [0.0, 1.9],
	"M01_CH03_24_Jobert.mp3": [0.0, 1.24],
	"M01_CH03_25_John.mp3": [0.0],
	"M01_CH03_26_Jobert.mp3": [0.0],
	"M01_CH03_27_John.mp3": [0.0],
	"M01_CH03_28_Jobert.mp3": [0.0],
	"M01_CH03_29_John.mp3": [0.0],
	"M01_CH03_30_Jobert.mp3": [0.0, 2.4, 5.1],
	"M01_CH03_31_John.mp3": [0.0],
	"M01_CH03_32_Jobert.mp3": [0.0],
	"M01_CH03_33_John.mp3": [0.0],
	"M01_CH03_34_John.mp3": [0.0, 2.82],
	"M01_CH03_35_John.mp3": [0.0, 2.26],
	"M01_CH03_36_John.mp3": [0.0],
	"M01_CH03_37_John.mp3": [0.0, 2.28],
	"M01_CH03_38_John.mp3": [0.0, 2.24, 4.12],
	"M01_CH03_39_John.mp3": [0.0],
	"M01_CH03_40_John.mp3": [0.0, 2.16, 4.26, 7.62, 9.96, 13.6],
}
const MESSAGES: Array[Dictionary] = [{"id":"payout", "sender":"Survey Rewards", "address":"rewards@survey-release.example", "subject":"Your survey payout is ready", "body":"Hi John,\n\nYour survey reward is ready for release.\n\nVerify your e-wallet account using the link below to receive your payout.\n\nComplete verification today to avoid a payment delay.", "signature":"Survey Rewards Team", "phrase":"Verify your e-wallet", "suspicious":true}]
const CHAT_MESSAGES: Array[Dictionary] = []
const ERIC_CHAT: Array[Dictionary] = [
	{"who":"Eric","face":0,"text":"Hey. Did the survey money arrive?"},
	{"who":"John","face":1,"text":"Just got the payout email."},
	{"who":"Eric","face":2,"text":"Nice. Could I borrow a little when it comes through?"},
	{"who":"Eric","face":2,"text":"Just until Friday."},
	{"who":"John","face":1,"text":"My money hasn't even arrived and it already has plans."},
	{"who":"Eric","face":2,"text":"Seriously though. I'll pay you back."},
	{"who":"John","face":0,"text":"Let me actually receive it first."},
	{"who":"Eric","face":0,"text":"Yeah. Of course."}
]
const CHECK_CHAT: Array[Dictionary] = [
	{"who":"John","face":0,"text":"Survey payout finally came."},
	{"who":"John","face":0,"text":"It wants me to verify my wallet first."}
]
const NIGHT_CHAT: Array[Dictionary] = [
	{"who":"Jobert","face":0,"text":"Keep the email and screenshot."},
	{"who":"Jobert","face":0,"text":"Let's compare what the link says with where it actually goes."},
	{"who":"John","face":1,"text":"You're turning my payout into homework."},
	{"who":"Jobert","face":1,"text":"This homework might save your wallet."},
	{"who":"John","face":1,"text":"Fine. You win."}
]
const STORY: Array[Dictionary] = [
	{"mood":"calm", "thought":true, "who":"John","face":2,"bg":"hallway_day","cast":["john"],"caption":"The next afternoon.\nSome messages arrive exactly when you want to believe them.","voice":"v1794708945/levelblue/voice/mod_01/ch_03/M01_CH03_01_John.mp3", "line":"If that's another assignment, I'm turning this phone into a calculator."},
	{"thought":true, "who":"John","face":1,"bg":"hallway_day","cast":["john"],"voice":"v1794708945/levelblue/voice/mod_01/ch_03/M01_CH03_02_John.mp3", "line":"Oh.\nFinally. An email that pays me instead of assigning homework.","mail":true,"event":"notification"},
	{"thought":true, "who":"John","face":4,"bg":"hallway_day","cast":["john"],"voice":"v1794708945/levelblue/voice/mod_01/ch_03/M01_CH03_03_John.mp3", "line":"I did finish their survey.\nMaybe this one's actually good news.","mail":true,"event":"email"},
	{"thought":true, "who":"John","face":1,"bg":"hallway_day","cast":["john"],"voice":"v1794708945/levelblue/voice/mod_01/ch_03/M01_CH03_04_John.mp3", "line":"And that was fast.","chat":true,"contact":"Eric","messages":ERIC_CHAT},
	{"mood":"mystery", "thought":true, "who":"John","face":4,"bg":"hallway_day","cast":["john"],"voice":"v1794708948/levelblue/voice/mod_01/ch_03/M01_CH03_05_John.mp3", "line":"He remembered the survey.\nI guess he really needs the money."},
	{"thought":true, "who":"John","face":4,"bg":"hallway_day","cast":["john","eric"],"caption":"Outside the club room.\nMika leans toward Eric, just beyond the doorway.","voice":"v1794708948/levelblue/voice/mod_01/ch_03/M01_CH03_06_John.mp3", "line":"Their voices are low."},
	{"who":"Mika · Off-screen","face":0,"bg":"hallway_day","cast":["john","eric"],"voice":"v1794708948/levelblue/voice/mod_01/ch_03/M01_CH03_07_Mika.mp3", "line":"Did you ask him?"},
	{"who":"Eric","face":2,"bg":"hallway_day","cast":["john","eric"],"voice":"v1794708948/levelblue/voice/mod_01/ch_03/M01_CH03_08_Eric.mp3", "line":"Yeah. Not yet."},
	{"mood":"calm", "who":"John","face":1,"bg":"hallway_day","cast":["john","eric"],"voice":"v1794708950/levelblue/voice/mod_01/ch_03/M01_CH03_09_John.mp3", "line":"Should I knock, or is the secret meeting over?"},
	{"who":"Mika · Off-screen","face":0,"bg":"hallway_day","cast":["john","eric"],"voice":"v1794708950/levelblue/voice/mod_01/ch_03/M01_CH03_10_Mika.mp3", "line":"We're outside the door."},
	{"who":"John","face":1,"bg":"hallway_day","cast":["john","eric"],"voice":"v1794708951/levelblue/voice/mod_01/ch_03/M01_CH03_11_John.mp3", "line":"Advanced security. Nobody suspects the hallway."},
	{"who":"Eric","face":1,"bg":"hallway_day","cast":["john","eric"],"voice":"v1794708951/levelblue/voice/mod_01/ch_03/M01_CH03_12_Eric.mp3", "line":"Heading home?"},
	{"who":"John","face":0,"bg":"hallway_day","cast":["john","eric"],"voice":"v1794708952/levelblue/voice/mod_01/ch_03/M01_CH03_13_John.mp3", "line":"Soon."},
	{"mood":"mystery", "thought":true, "who":"John","face":4,"bg":"hallway_day","cast":["john"],"voice":"v1794708952/levelblue/voice/mod_01/ch_03/M01_CH03_14_John.mp3", "line":"Probably about the money.\nProbably."},
	{"thought":true, "who":"John","face":1,"bg":"john_desk_night","time":"night","cast":["john"],"caption":"Early evening. At home.","voice":"v1794708953/levelblue/voice/mod_01/ch_03/M01_CH03_15_John.mp3", "line":"Right. Let's collect this before someone else borrows it.\nActually…","chat":true,"contact":"Jobert","messages":CHECK_CHAT},
	{"thought":true, "who":"John","face":0,"bg":"john_desk_night","time":"night","cast":["john"],"voice":"v1794708954/levelblue/voice/mod_01/ch_03/M01_CH03_16_John.mp3", "line":"He's probably busy.\nI'll just take a look.","mail":true,"event":"open_link"},
	{"mood":"suspense", "thought":true, "who":"John","face":1,"bg":"john_desk_night","time":"night","cast":["john"],"voice":"v1794708954/levelblue/voice/mod_01/ch_03/M01_CH03_17_John.mp3", "line":"Okay. I know this screen.","mail":true,"event":"interrupt"},
	{"who":"Jobert · Phone","face":2,"bg":"john_desk_night","time":"night","cast":["john"],"voice":"v1794708955/levelblue/voice/mod_01/ch_03/M01_CH03_18_Jobert.mp3", "line":"John. Have you opened that payout link?"},
	{"who":"John","face":2,"bg":"john_desk_night","time":"night","cast":["john"],"voice":"v1794708955/levelblue/voice/mod_01/ch_03/M01_CH03_19_John.mp3", "line":"Yeah. I'm just—"},
	{"who":"Jobert · Phone","face":2,"bg":"john_desk_night","time":"night","cast":["john"],"voice":"v1794708956/levelblue/voice/mod_01/ch_03/M01_CH03_20_Jobert.mp3", "line":"Don't enter anything else.\nSend me a screenshot."},
	{"who":"John","face":2,"bg":"john_desk_night","time":"night","cast":["john"],"voice":"v1794708957/levelblue/voice/mod_01/ch_03/M01_CH03_21_John.mp3", "line":"You called like my phone was about to explode."},
	{"who":"Jobert · Phone","face":0,"bg":"john_desk_night","time":"night","cast":["john"],"voice":"v1794708957/levelblue/voice/mod_01/ch_03/M01_CH03_22_Jobert.mp3", "line":"Did you submit anything?"},
	{"who":"John","face":2,"bg":"john_desk_night","time":"night","cast":["john"],"voice":"v1794708958/levelblue/voice/mod_01/ch_03/M01_CH03_23_John.mp3", "line":"No.\nI started typing my username."},
	{"who":"Jobert · Phone","face":0,"bg":"john_desk_night","time":"night","cast":["john"],"voice":"v1794708959/levelblue/voice/mod_01/ch_03/M01_CH03_24_Jobert.mp3", "line":"Okay. Stop there."},
	{"who":"John","face":0,"bg":"john_desk_night","time":"night","cast":["john"],"voice":"v1794708959/levelblue/voice/mod_01/ch_03/M01_CH03_25_John.mp3", "line":"Sent.","mail":true,"event":"screenshot"},
	{"who":"Jobert · Phone","face":0,"bg":"john_desk_night","time":"night","cast":["john"],"voice":"v1794708959/levelblue/voice/mod_01/ch_03/M01_CH03_26_Jobert.mp3", "line":"Don't use that page."},
	{"who":"John","face":2,"bg":"john_desk_night","time":"night","cast":["john"],"voice":"v1794708960/levelblue/voice/mod_01/ch_03/M01_CH03_27_John.mp3", "line":"But it has the wallet logo."},
	{"who":"Jobert · Phone","face":4,"bg":"john_desk_night","time":"night","cast":["john"],"voice":"v1794708961/levelblue/voice/mod_01/ch_03/M01_CH03_28_Jobert.mp3", "line":"The logo isn't the address."},
	{"who":"John","face":2,"bg":"john_desk_night","time":"night","cast":["john"],"voice":"v1794708961/levelblue/voice/mod_01/ch_03/M01_CH03_29_John.mp3", "line":"So the money…"},
	{"who":"Jobert · Phone","face":0,"bg":"john_desk_night","time":"night","cast":["john"],"voice":"v1794708962/levelblue/voice/mod_01/ch_03/M01_CH03_30_Jobert.mp3", "line":"We don't know that it's real.\nOpen the wallet through its own app if you want to check. Not through that email."},
	{"mood":"resolve", "who":"John","face":1,"bg":"john_desk_night","time":"night","cast":["john"],"voice":"v1794708963/levelblue/voice/mod_01/ch_03/M01_CH03_31_John.mp3", "line":"Good thing you called."},
	{"who":"Jobert · Phone","face":1,"bg":"john_desk_night","time":"night","cast":["john"],"voice":"v1794708963/levelblue/voice/mod_01/ch_03/M01_CH03_32_Jobert.mp3", "line":"Good thing you messaged."},
	{"who":"John","face":4,"bg":"john_bed_night","time":"night","caption":"I was one tap away.\nAnd I hadn't even checked where the tap would take me.","voice":"v1794708964/levelblue/voice/mod_01/ch_03/M01_CH03_33_John.mp3", "line":"Let's keep the screenshot.","chat":true,"contact":"Jobert","messages":NIGHT_CHAT},
	{"mood":"mystery", "thought":true, "who":"John","face":4,"bg":"john_bed_night","time":"night","voice":"v1794708964/levelblue/voice/mod_01/ch_03/M01_CH03_34_John.mp3", "line":"The sender had a story.\nLet's see if the link tells the same one."}
]

static func fresh() -> Dictionary:
	return {"performance_version":1,"star_tracking":true,"star_blocked":[],"hotspot_order":[],"version":1,"beat":0,"phase":"day","read":[],"sorted":[],"flags":[],"domains":[],"captures":[],"revealed":[],"expanded":[],"hotspots":[],"reviewed":false,"mistakes":0,"hint_used":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"perk_run":{}}

static func message(id: String) -> Dictionary:
	return MESSAGES[0] if id == "payout" else {}

static func suspicious_ids() -> Array[String]:
	return ["payout"]

static func complete_evidence(state: Dictionary) -> bool:
	return state.get("revealed", []).has("payout") and state.get("expanded", []).has("payout") and state.get("hotspots", []).size() >= 3 and state.get("reviewed", false)

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	for field: String in ["read","captures","revealed","expanded","hotspots"]:
		var values: Variant = raw.get(field, [])
		if values is Array:
			for value: Variant in values:
				if ((field == "hotspots" and CLUES.has(value)) or (field != "hotspots" and value == "payout")) and not state[field].has(value): state[field].append(value)
	for field: String in ["beat","mistakes"]:
		var value: Variant = raw.get(field, 0)
		if (value is int or value is float) and is_finite(float(value)): state[field] = clampi(int(value), 0, STORY.size() - 1 if field == "beat" else 9999)
	state.reviewed = raw.get("reviewed", false) == true and state.hotspots.size() >= 3
	state.hint_used = raw.get("hint_used", false) == true
	state.perk_run = Perks.clean_run(raw.get("perk_run", {}))
	if state.perk_run.get("chapter", ID) != ID: state.perk_run = {}
	var phase: String = str(raw.get("phase", "day"))
	if phase in ["day","reveal","expand","flaws","seal","sleep","closing","done"]: state.phase = phase
	if state.phase in ["expand","flaws","seal","sleep","closing","done"] and state.revealed.is_empty(): state.phase = "reveal"
	if state.phase in ["flaws","seal","sleep","closing","done"] and state.expanded.is_empty(): state.phase = "expand"
	if state.phase in ["seal","sleep","closing","done"] and not complete_evidence(state): state.phase = "flaws"
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
