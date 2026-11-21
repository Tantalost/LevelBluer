extends RefCounted
const Rewards: GDScript = preload("res://src/gameplay/decision/story_rewards.gd")
## Authored fictional hearing. Evidence challenges claims; admission resolves identity.
const ID: String = "mod_01_ch_05"
const STAR_GOALS: Dictionary = Rewards.GOALS[ID]
const STAR_IDS: Array[String] = ["evidence", "resolve", "reconstruction"]
const STAR_CREDITS: int = 25
const NUMBER: int = 5
const HEARING: bool = true
const THEORY_CORRECT: String = "Jobert"
const PRESENTATION: Dictionary = {"aftermath_art":"story_bg_john_bed_night", "ending_art":"module1_masked_laughter_v1", "ending_disconnect_at":5.0, "ending_black_at":8.0, "ending_finish_at":9.0, "ending_seal_seconds":3.0}
const TITLE: String = "Confrontation"
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const SUSPECTS: Array[String] = ["Eric","Dan","Mika","Jobert"]
const NAME_HINTS: Array[String] = ["Who helped you at every turn?","Who knew exactly when you were on that page?","Think about who benefits from you trusting them."]
const BRIEFING: String = "SIR RHAM / NEW EXHIBITS\n\nThe club roster records 20 members with access to the coffee message. Access is not proof that every member read it.\n\nIT recovered the fake wallet page's activity record. It transmitted input before Submit. The first input and John's incoming call from Jobert both show 18:41:12. These are two new records for the hearing.\n\nThose records establish timing and page behavior, not who controlled the page. Challenge the claims. Do not guess a culprit from a typo or online status alone.\n\nKeep your case record close. Select an exhibit, then tap the orange claim it challenges. You can hold the conversation whenever you need time."
const EXHIBITS: Array[Dictionary] = [
	{"id":"coffee","title":"Coffee + club chat","source":"CH1 + CH4 / Roster supplied before hearing","detail":"John: ‘I miss coffee. I need a side gig before my wallet gives up.’ The prize email repeats the coffee reference. The roster lists 20 members with access—not just Eric.","art":"story_bg_clubroom","mark":"20"},
	{"id":"headers","title":"Advisor email headers","source":"CH2 / Sealed header exhibit","detail":"From: sir.rham@schoo1.example\nReply-To: club.records@member-support.example\nThe display name and club format were copied. Nothing in these fields identifies Dan, and they do not establish the same provider as the CH1 emails.","art":"story_chapter2_cover","mark":"@"},
	{"id":"call","title":"Input event + call log","source":"NEW / Sir Rham's IT briefing + CH3 call","detail":"Recovered page record: first input transmitted at 18:41:12. John's call log: incoming Jobert call at 18:41:12. The page could capture input before Submit. Ask how he knew; timing alone does not identify its operator.","art":"story_bg_john_desk_night","mark":"00"},
	{"id":"timeline","title":"Prize / last-seen record","source":"CH4 / Sealed timeline","detail":"Jobert last seen 08:13:50. Prize email received 08:14:00: ten seconds later. Eric last seen 08:13:45: fifteen seconds earlier. A presence indicator does not establish when someone slept or who sent an email.","art":"opening_john_room_wake_v1","mark":"10"},
	{"id":"typo1","title":"‘Recieve’ / survey","source":"CH1 / Third suspicious email: profile","detail":"‘To recieve your reward, send your full birth date and home address in your reply.’ A repeated common typo is supporting context, not identification.","art":"story_bg_john_desk_night","mark":"Aa"},
	{"id":"typo4","title":"‘Recieve’ / prize","source":"CH4 / Exhibit 03","detail":"‘Follow the link and confirm your account password to recieve your prize.’ Compare the repeated wording. Do not treat spelling as a fingerprint.","art":"opening_john_claim_prize_v1","mark":"Aa"},
	{"id":"domain","title":"Lookalike school domain","source":"CH2 / Exhibit 01","detail":"schoo1.example uses a digit 1 where school.example uses a lowercase L. This reveals impersonation, not who read the coffee comment.","art":"story_chapter2_cover","mark":"1"},
	{"id":"short","title":"Hidden link destination","source":"CH3 / Exhibits 01–02","detail":"short.example/payout hides http://pocket-wallet-verify.example/login. A misleading destination does not identify who authored the club email.","art":"story_bg_john_bed_night","mark":"↗"},
	{"id":"addresses","title":"Survey sender addresses","source":"CH1 / Sealed sender notes","detail":"survey.rewards@gmail.com; survey.coordinator@yahoo.com; survey.profile@gmail.com. Addresses alone do not identify a person or establish the caller's timing.","art":"story_bg_john_desk_night","mark":"@"},
	{"id":"urgency","title":"24-hour deadline","source":"CH2 / Exhibit 03","detail":"The fake advisor email threatened removal from the club unless John replied within 24 hours. Pressure is not evidence of when someone was asleep.","art":"story_chapter2_cover","mark":"24"},
	{"id":"borrow","title":"Eric's borrowing request","source":"CH3 / Context, not proof","detail":"Eric asked to borrow money until Friday. Needing money does not establish who sent the emails.","art":"story_bg_hallway_day","mark":"?"},
	{"id":"whisper","title":"Mika + Eric at the door","source":"CH3 / Context, not proof","detail":"Mika asked ‘Did you ask him?’ Eric replied ‘Yeah. Not yet.’ John overheard a partial conversation. That does not identify an attacker.","art":"story_bg_hallway_day","mark":"?"}
]
const ROUNDS: Array[Dictionary] = [
	{"title": "It's Eric.", "weak": "the only one who knew", "claim": "Eric brought the surveys. He's the only one who knew John needed coffee money. Obvious.", "correct": "coffee", "options": ["domain", "coffee", "borrow", "short"], "hint": "Was the coffee comment private, or visible in the club chat?", "smug": "That's a suspicious message, John. Not an answer to my point.", "result": "John: Only Eric? I posted it to the group. Twenty members had access.\nEric: You made a group message sound like a secret.\nSir Rham: That accusation is unsupported. Access is not authorship.", "flash": "CH1 / Jobert: ‘Careful with random surveys. Ask me if you're unsure.’", "art": "story_bg_clubroom", "voices": [{"who": "Eric", "text": "I shared the survey. That doesn't mean I wrote every email.", "voice": "v1794718714/levelblue/voiceovers/module1/chapter5/M01_CH05_01_Eric.mp3"}, {"who": "Jobert", "text": "Let's stop making this complicated.", "voice": "v1794718714/levelblue/voiceovers/module1/chapter5/M01_CH05_02_Jobert.mp3"}, {"who": "Mika", "text": "Then explain what actually proves it.", "voice": "v1794718714/levelblue/voiceovers/module1/chapter5/M01_CH05_03_Mika.mp3"}], "claim_voice": "v1794718714/levelblue/voiceovers/module1/chapter5/M01_CH05_04_Jobert.mp3", "result_voices": {0: "v1794718716/levelblue/voiceovers/module1/chapter5/M01_CH05_05_John.mp3", 1: "v1794718716/levelblue/voiceovers/module1/chapter5/M01_CH05_06_Eric.mp3", 2: "v1794718716/levelblue/voiceovers/module1/chapter5/M01_CH05_07_SirRham.mp3"}},
	{"title": "It's Dan.", "weak": "knowing the format proves it", "claim": "Dan bragged about our email format. Knowing the format proves it was his prank.", "correct": "headers", "options": ["typo1", "short", "headers", "whisper"], "hint": "The headers show impersonation. Do they name Dan as the sender?", "smug": "You brought another warning sign. I asked who sent it.", "result": "John: A copied format doesn't identify Dan. The From and Reply-To aren't Sir Rham's, but neither identifies Dan.\nDan: My joke was stupid. Your conclusion is worse.\nSir Rham: We will distinguish a joke from evidence. That accusation is unsupported.", "flash": "CH2 / Jobert: ‘Now compare the part after the @.’", "art": "story_chapter2_cover", "voices": [{"who": "Dan", "text": "I joked about the inbox. I never said I sent that email.", "voice": "v1794718717/levelblue/voiceovers/module1/chapter5/M01_CH05_08_Dan.mp3"}, {"who": "Jobert", "text": "You knew exactly how to make it look official.", "voice": "v1794718718/levelblue/voiceovers/module1/chapter5/M01_CH05_09_Jobert.mp3"}, {"who": "Sir Rham", "text": "Knowledge is not the same as an action.", "voice": "v1794718719/levelblue/voiceovers/module1/chapter5/M01_CH05_10_SirRham.mp3"}], "claim_voice": "v1794718719/levelblue/voiceovers/module1/chapter5/M01_CH05_11_Jobert.mp3", "result_voices": {0: "v1794718719/levelblue/voiceovers/module1/chapter5/M01_CH05_12_John.mp3", 1: "v1794718721/levelblue/voiceovers/module1/chapter5/M01_CH05_13_Dan.mp3", 2: "v1794718722/levelblue/voiceovers/module1/chapter5/M01_CH05_14_SirRham.mp3"}},
	{"title": "I saved you.", "weak": "before Submit, nothing was captured", "claim": "I called before you hit Submit. Before Submit, nothing was captured. I saved you.", "correct": "call", "options": ["addresses", "timeline", "call", "borrow"], "hint": "Review the new IT finding and call log. Was Submit required for input capture?", "smug": "You're accusing the person who answered your messages?", "result": "John: IT found input capture before Submit. The first input and your call share a timestamp.\nJohn: How did you know I was on the page at that second?\nJobert: I just... had a feeling.\nSir Rham: The timing needs an explanation. It is not proof of an operator by itself.", "flash": "CH3 / Jobert: ‘Don't enter anything else. Send me a screenshot.’", "art": "story_bg_john_desk_night", "voices": [{"who": "John", "text": "You called just as I started typing.", "voice": "v1794718722/levelblue/voiceovers/module1/chapter5/M01_CH05_15_John.mp3"}, {"who": "Jobert", "text": "Because you messaged me. Remember who helped you.", "voice": "v1794718722/levelblue/voiceovers/module1/chapter5/M01_CH05_16_Jobert.mp3"}, {"who": "Sir Rham", "text": "Helping once does not settle what happened elsewhere.", "voice": "v1794718723/levelblue/voiceovers/module1/chapter5/M01_CH05_17_SirRham.mp3"}], "claim_voice": "v1794718724/levelblue/voiceovers/module1/chapter5/M01_CH05_18_Jobert.mp3", "result_voices": {0: "v1794718725/levelblue/voiceovers/module1/chapter5/M01_CH05_19_John.mp3", 1: "v1794718724/levelblue/voiceovers/module1/chapter5/M01_CH05_20_John.mp3", 2: "v1794718726/levelblue/voiceovers/module1/chapter5/M01_CH05_21_Jobert.mp3", 3: "v1794718727/levelblue/voiceovers/module1/chapter5/M01_CH05_22_SirRham.mp3"}},
	{"title": "I was offline.", "weak": "offline proves I was asleep", "claim": "I was asleep when the prize arrived. My status was offline. Offline proves I was asleep.", "correct": "timeline", "options": ["urgency", "whisper", "addresses", "timeline"], "hint": "Compare both last-seen times. Can either status establish sleep or authorship?", "smug": "You can't turn every ordinary detail into an accusation.", "result": "John: Ten seconds after your last seen. Fifteen after Eric's.\nJohn: Neither status proves who sent it—and neither proves you were asleep.\nJobert: You keep twisting everything.\nSir Rham: Your status is not the alibi you claimed.", "flash": "CH4 / John: ‘Offline. You picked a really bad time to disappear.’", "art": "opening_john_reaching_phone_v1", "voices": [{"who": "Mika", "text": "Eric's status was close to the email too.", "voice": "v1794718727/levelblue/voiceovers/module1/chapter5/M01_CH05_23_Mika.mp3"}, {"who": "Jobert", "text": "Exactly. Check my status. I wasn't even there.", "voice": "v1794718727/levelblue/voiceovers/module1/chapter5/M01_CH05_24_Jobert.mp3"}, {"who": "John", "text": "A status isn't the whole timeline.", "voice": "v1794718728/levelblue/voiceovers/module1/chapter5/M01_CH05_25_John.mp3"}], "claim_voice": "v1794718729/levelblue/voiceovers/module1/chapter5/M01_CH05_26_Jobert.mp3", "result_voices": {0: "v1794718729/levelblue/voiceovers/module1/chapter5/M01_CH05_27_John.mp3", 1: "v1794718730/levelblue/voiceovers/module1/chapter5/M01_CH05_28_John.mp3", 2: "v1794718731/levelblue/voiceovers/module1/chapter5/M01_CH05_29_Jobert.mp3", 3: "v1794718731/levelblue/voiceovers/module1/chapter5/M01_CH05_30_SirRham.mp3"}}
]
const COMIC: Array[Dictionary] = [
	{"id": "survey", "title": "01 / An offer, then trust", "art": "story_bg_clubroom", "narration": "John: A survey offer reached me through Eric. My coffee comment was in the group chat. Jobert told me to ask him whenever I was unsure.", "voice": "v1794718735/levelblue/voiceovers/module1/chapter5/M01_CH05_37_John.mp3"},
	{"id": "advisor", "title": "02 / A familiar name", "art": "story_chapter2_cover", "narration": "John: Someone copied Sir Rham's identity. Jobert helped me spot the lookalike domain. Dan's joke made him look suspicious, but it wasn't evidence that he sent it.", "voice": "v1794718736/levelblue/voiceovers/module1/chapter5/M01_CH05_38_John.mp3"},
	{"id": "call", "title": "03 / The perfect interruption", "art": "story_bg_john_desk_night", "narration": "John: The fake wallet page captured input before Submit. Jobert's call came at the recorded first-input second. I mistook the timing for safety.", "voice": "v1794718737/levelblue/voiceovers/module1/chapter5/M01_CH05_39_John.mp3"},
	{"id": "prize", "title": "04 / That same morning", "art": "opening_john_claim_prize_v1", "narration": "John: I woke in my room to a prize promise that repeated my coffee comment. Jobert was offline. I tapped. The records linked the messages, but did not name the sender.", "voice": "v1794718738/levelblue/voiceovers/module1/chapter5/M01_CH05_40_John.mp3"},
	{"id": "challenge", "title": "05 / Claims fall apart", "art": "story_bg_john_bed_night", "narration": "John: We challenged the accusations against Eric and Dan, the claim about Submit, and the offline alibi. Then ‘recieve’ appeared again. It was a clue to question, not a verdict.", "voice": "v1794718738/levelblue/voiceovers/module1/chapter5/M01_CH05_41_John.mp3"},
	{"id": "admission", "title": "06 / His own words", "art": "hearing_debate_v1", "narration": "John: I asked for an explanation. This time, Jobert couldn't hide behind helping me. His admission—not a spelling mistake—identified him.", "voice": "v1794718739/levelblue/voiceovers/module1/chapter5/M01_CH05_42_John.mp3"},
	{"id": "dan_prank", "title": "Dan sent a harmless prank", "art": "story_chapter2_cover", "narration": "Unsupported. Knowing the format does not establish authorship."},
	{"id": "eric_alone", "title": "Only Eric knew about coffee", "art": "story_bg_clubroom", "narration": "Contradicted by the group-chat exhibit."}
]
const COMIC_ORDER: Array[String] = ["survey","advisor","call","prize","challenge","admission"]
const ADMISSION: Array[String] = ["John: You wrote ‘recieve.’ So did both emails. That alone doesn't prove anything. Explain the messages—and the call.","Jobert: I only wanted you to keep coming back to me.","John: Did you send them?","Jobert: Yes. The survey messages. The fake advisor. The payout link. The prize.","Jobert: When the page showed input, I called. If I stopped you once, you'd trust me the next time.","Sir Rham: That's enough, Jobert. We will preserve that admission with the records."]
const AFTERMATH: Array[String] = ["Sir Rham: Eric and Dan, the accusations against you were not supported. Mika's conversation was not proof either.", "Sir Rham: Jobert, you are removed from the club. The accounts used in this case will be reported, and you will face a disciplinary hearing.", "John: My phone buzzes. For the first time, I don't rush to open it."]

const ADMISSION_VOICE: Dictionary = {0: "v1794718732/levelblue/voiceovers/module1/chapter5/M01_CH05_31_John.mp3", 1: "v1794718732/levelblue/voiceovers/module1/chapter5/M01_CH05_32_Jobert.mp3", 3: "v1794718733/levelblue/voiceovers/module1/chapter5/M01_CH05_34_Jobert.mp3", 4: "v1794718734/levelblue/voiceovers/module1/chapter5/M01_CH05_35_Jobert.mp3", 5: "v1794718735/levelblue/voiceovers/module1/chapter5/M01_CH05_36_SirRham.mp3"}
const AFTERMATH_VOICE: Dictionary = {0: "v1794718740/levelblue/voiceovers/module1/chapter5/M01_CH05_43_SirRham.mp3", 1: "v1794718741/levelblue/voiceovers/module1/chapter5/M01_CH05_44_SirRham.mp3", 2: "v1794718741/levelblue/voiceovers/module1/chapter5/M01_CH05_45_John.mp3"}
## Anonymous voices retain the original recordings; no culprit identity is disclosed.
const ENDING: Array[Dictionary] = [
	{"speaker": "MASKED VOICE I", "text": "He wanted to look clever. Then he confessed in front of everyone.", "voice": "v1794718742/levelblue/voiceovers/module1/chapter5/M01_CH05_END_01_Masked1.mp3", "duration": 4.833},
	{"speaker": "MASKED VOICE II", "text": "What was he expecting? Applause?", "voice": "v1794718743/levelblue/voiceovers/module1/chapter5/M01_CH05_END_02_Masked2.mp3", "duration": 3.317},
	{"speaker": "MASKED VOICE III", "text": "He wanted to be John's hero. Couldn't even survive a few questions.", "voice": "v1794718743/levelblue/voiceovers/module1/chapter5/M01_CH05_END_03_Masked3.mp3", "duration": 5.068},
	{"speaker": "MASKED VOICE I", "text": "His execution was careless. He made it personal.", "voice": "v1794718743/levelblue/voiceovers/module1/chapter5/M01_CH05_END_04_Masked1.mp3", "duration": 3.866},
	{"speaker": "MASKED VOICE II", "text": "Careless? He practically signed his own dismissal.", "voice": "v1794718744/levelblue/voiceovers/module1/chapter5/M01_CH05_END_05_Masked2.mp3", "duration": 3.971},
	{"speaker": "MASKED VOICE III", "text": "At least he finally made himself useful. More room for us.", "voice": "v1794718745/levelblue/voiceovers/module1/chapter5/M01_CH05_END_06_Masked3.mp3", "duration": 4.911},
	{"speaker": "MASKED VOICE I", "text": "Jobert's part is over.", "voice": "v1794718746/levelblue/voiceovers/module1/chapter5/M01_CH05_END_07_Masked1.mp3", "duration": 2.273},
	{"speaker": "MASKED VOICE II", "text": "One less genius in the room.", "voice": "v1794718746/levelblue/voiceovers/module1/chapter5/M01_CH05_END_08_Masked2.mp3", "duration": 3.004},
	{"speaker": "MASKED VOICE III", "text": "Then let's see which of you lasts longer.", "voice": "v1794718747/levelblue/voiceovers/module1/chapter5/M01_CH05_END_09_Masked3.mp3", "duration": 4.676}
]
const ENDING_LAUGH: String = "v1793978786/VillainLaugh_group.wav"
## Caption page starts measured against the supplied recordings.
const VOICE_TIMINGS: Dictionary = {
	"M01_CH05_01_Eric.mp3": [0.0, 2.48],
	"M01_CH05_02_Jobert.mp3": [0.0],
	"M01_CH05_03_Mika.mp3": [0.0],
	"M01_CH05_04_Jobert.mp3": [0.0, 2.22, 4.68],
	"M01_CH05_05_John.mp3": [0.0, 2.3, 4.52],
	"M01_CH05_06_Eric.mp3": [0.0],
	"M01_CH05_07_SirRham.mp3": [0.0, 3.06],
	"M01_CH05_08_Dan.mp3": [0.0, 3.38],
	"M01_CH05_09_Jobert.mp3": [0.0],
	"M01_CH05_10_SirRham.mp3": [0.0],
	"M01_CH05_11_Jobert.mp3": [0.0, 2.76],
	"M01_CH05_12_John.mp3": [0.0, 3.48],
	"M01_CH05_13_Dan.mp3": [0.0, 2.78],
	"M01_CH05_14_SirRham.mp3": [0.0, 3.14],
	"M01_CH05_15_John.mp3": [0.0],
	"M01_CH05_16_Jobert.mp3": [0.0, 2.36],
	"M01_CH05_17_SirRham.mp3": [0.0],
	"M01_CH05_18_Jobert.mp3": [0.0, 1.92, 4.7],
	"M01_CH05_19_John.mp3": [0.0, 3.96],
	"M01_CH05_20_John.mp3": [0.0],
	"M01_CH05_21_Jobert.mp3": [0.0],
	"M01_CH05_22_SirRham.mp3": [0.0, 2.72],
	"M01_CH05_23_Mika.mp3": [0.0],
	"M01_CH05_24_Jobert.mp3": [0.0, 1.0, 2.6],
	"M01_CH05_25_John.mp3": [0.0],
	"M01_CH05_26_Jobert.mp3": [0.0, 3.06, 4.86],
	"M01_CH05_27_John.mp3": [0.0, 3.12],
	"M01_CH05_28_John.mp3": [0.0],
	"M01_CH05_29_Jobert.mp3": [0.0],
	"M01_CH05_30_SirRham.mp3": [0.0],
	"M01_CH05_37_John.mp3": [0.0, 3.1, 5.76],
	"M01_CH05_38_John.mp3": [0.0, 3.74, 6.36],
	"M01_CH05_39_John.mp3": [0.0, 4.94, 8.2],
	"M01_CH05_40_John.mp3": [0.0, 5.84, 7.34, 9.14],
	"M01_CH05_41_John.mp3": [0.0, 6.9, 9.56],
	"M01_CH05_42_John.mp3": [0.0, 2.64, 7.02],
	"M01_CH05_31_John.mp3": [0.0, 3.58, 5.74],
	"M01_CH05_32_Jobert.mp3": [0.0],
	"M01_CH05_34_Jobert.mp3": [0.0, 1.64, 3.08, 6.12, 8.2],
	"M01_CH05_35_Jobert.mp3": [0.0, 3.54],
	"M01_CH05_36_SirRham.mp3": [0.0, 2.44],
	"M01_CH05_43_SirRham.mp3": [0.0, 4.84],
	"M01_CH05_44_SirRham.mp3": [0.0, 2.98],
	"M01_CH05_45_John.mp3": [0.0, 1.82],
	"M01_CH05_END_01_Masked1.mp3": [0.0, 2.76],
	"M01_CH05_END_02_Masked2.mp3": [0.0, 1.88],
	"M01_CH05_END_03_Masked3.mp3": [0.0, 2.8],
	"M01_CH05_END_04_Masked1.mp3": [0.0, 2.68],
	"M01_CH05_END_05_Masked2.mp3": [0.0, 1.48],
	"M01_CH05_END_06_Masked3.mp3": [0.0, 3.24],
	"M01_CH05_END_07_Masked1.mp3": [0.0],
	"M01_CH05_END_08_Masked2.mp3": [0.0],
	"M01_CH05_END_09_Masked3.mp3": [0.0],
}

static func exhibit(id: String) -> Dictionary:
	for item: Dictionary in EXHIBITS:
		if item.id == id: return item
	return {}

static func frame(id: String) -> Dictionary:
	for item: Dictionary in COMIC:
		if item.id == id: return item
	return {}

static func fresh() -> Dictionary:
	return fresh_hearing(EXHIBITS)

static func fresh_hearing(exhibits: Array) -> Dictionary:
	var captures: Array[String] = []
	for item: Dictionary in exhibits: captures.append(str(item.id))
	return {"performance_version":1,"star_tracking":true,"star_blocked":[],"hotspot_order":[],"version":1,"phase":"prep","briefed":false,"theory_done":false,"theory_bonus":false,"suspect_guesses":[],"round":0,"solved":[],"credibility":20,"round_start":20,"round_errors":[0,0,0,0],"auto_hints":[],"restarts":0,"mistakes":0,"hint_used":false,"final_matched":false,"admission_step":0,"admitted":false,"comic_order":["","","","","",""],"comic_checked":false,"comic_errors":0,"animatic_step":0,"animatic_done":false,"aftermath_step":0,"aftermath_done":false,"ending_step":0,"lights_done":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"captures":captures,"perk_run":{}}

static func integer(raw: Dictionary, key: String, fallback: int, ceiling: int) -> int:
	var value: Variant = raw.get(key,fallback)
	return clampi(int(value),0,ceiling) if (value is int or value is float) and is_finite(float(value)) else fallback

static func clean(raw: Dictionary) -> Dictionary:
	return clean_hearing(raw, {"id":ID,"suspects":SUSPECTS,"correct":THEORY_CORRECT,"exhibits":EXHIBITS,"admission":ADMISSION,"aftermath":AFTERMATH,"comic":COMIC,"order":COMIC_ORDER,"ending_count":ENDING.size()})

static func clean_hearing(raw: Dictionary, rules: Dictionary) -> Dictionary:
	var state: Dictionary = fresh_hearing(rules.exhibits)
	for field: String in ["briefed","theory_done","theory_bonus","hint_used","final_matched","admitted","comic_checked","animatic_done","aftermath_done","lights_done"]: state[field] = raw.get(field,false) == true
	var guesses: Variant = raw.get("suspect_guesses",[])
	if guesses is Array:
		for value: Variant in guesses:
			if value in rules.suspects and value != rules.correct and not state.suspect_guesses.has(value): state.suspect_guesses.append(value)
	if state.suspect_guesses.size() == 3: state.theory_bonus = false
	state.theory_done = state.theory_done and state.briefed
	state.theory_bonus = state.theory_bonus and state.theory_done
	var solved: Variant = raw.get("solved",[])
	if solved is Array and state.theory_done:
		for index: int in 4:
			if solved.has(index) and state.solved.size() == index: state.solved.append(index)
	state.credibility = integer(raw,"credibility",35 if state.theory_bonus else 20,100)
	state.round_start = maxi(20,integer(raw,"round_start",35 if state.theory_bonus else 20,100))
	state.round = mini(3,state.solved.size())
	for field: String in ["mistakes","restarts","comic_errors"]: state[field] = integer(raw,field,0,9999)
	var errors: Variant = raw.get("round_errors",[])
	if errors is Array and errors.size() == 4:
		for index: int in 4: state.round_errors[index] = integer({"n":errors[index]},"n",0,9999)
	var recorded_errors: int = int(state.comic_errors)
	for count: int in state.round_errors: recorded_errors += count
	state.mistakes = maxi(int(state.mistakes),recorded_errors)
	var hints: Variant = raw.get("auto_hints",[])
	if hints is Array:
		for value: Variant in hints:
			if value is int and value >= 0 and value < 4 and not state.auto_hints.has(value): state.auto_hints.append(value)
	if not state.auto_hints.is_empty(): state.hint_used = true
	if not state.suspect_guesses.is_empty(): state.hint_used = true
	state.final_matched = state.final_matched and state.solved.size() == 4
	state.admission_step = integer(raw,"admission_step",0,rules.admission.size()-1)
	state.admitted = state.admitted and state.final_matched and state.admission_step == rules.admission.size()-1
	var order: Variant = raw.get("comic_order",[])
	if order is Array and order.size() == 6:
		for index: int in 6:
			if order[index] is String and _frame_exists(rules.comic, order[index]) and not state.comic_order.has(order[index]): state.comic_order[index] = order[index]
	state.comic_checked = state.comic_checked and state.admitted and state.comic_order == rules.order
	state.animatic_step = integer(raw,"animatic_step",0,5)
	state.animatic_done = state.animatic_done and state.comic_checked and state.animatic_step == 5
	state.aftermath_step = integer(raw,"aftermath_step",0,rules.aftermath.size()-1)
	state.aftermath_done = state.aftermath_done and state.animatic_done and state.aftermath_step == rules.aftermath.size()-1
	# Old completed saves predate the cutaway; preserve their earned completion.
	var ending_last: int = int(rules.get("ending_count",0))+1
	state.ending_step = integer(raw,"ending_step",ending_last if state.lights_done else 0,ending_last)
	state.lights_done = state.lights_done and state.aftermath_done
	if rules.has("ending_count"): state.lights_done = state.lights_done and state.ending_step == ending_last
	state.perk_run = Perks.clean_run(raw.get("perk_run",{}))
	if state.perk_run.get("chapter",rules.id) != rules.id: state.perk_run = {}
	var phase: String = str(raw.get("phase","prep"))
	if phase in ["prep","suspect","intro","debate","rebuttal","final","admission","comic","animatic","aftermath","lights","done"]: state.phase = phase
	if state.phase != "prep" and not state.briefed: state.phase = "prep"
	if state.phase not in ["prep","suspect"] and not state.theory_done: state.phase = "suspect"
	if state.phase in ["final","admission","comic","animatic","aftermath","lights","done"] and state.solved.size() < 4: state.phase = "debate"
	if state.phase == "rebuttal":
		if state.solved.is_empty(): state.phase = "debate"
		else: state.round = state.solved.size()-1
	if state.phase == "debate" and state.solved.size() == 4: state.phase = "final"
	if state.phase in ["admission","comic","animatic","aftermath","lights","done"] and not state.final_matched: state.phase = "final"
	if state.phase in ["comic","animatic","aftermath","lights","done"] and not state.admitted: state.phase = "admission"
	if state.phase in ["animatic","aftermath","lights","done"] and not state.comic_checked: state.phase = "comic"
	if state.phase in ["aftermath","lights","done"] and not state.animatic_done: state.phase = "animatic"
	if state.phase in ["lights","done"] and not state.aftermath_done: state.phase = "aftermath"
	if state.phase == "done" and not state.lights_done: state.phase = "lights"
	state.completed = raw.get("completed",false) == true and state.lights_done
	state.sealed = state.completed
	if state.completed:
		state.phase = "done"
		state.reward = 100 + (25 if state.mistakes == 0 and Perks.status(state.perk_run,state.hint_used) != "assisted" else 0)
	if str(rules.get("id", ID)) == ID:
		Rewards.track(state, raw, ID)
		if state.completed and state.get("performance_version", 0) == 1: state.reward = 100
	return state

static func _frame_exists(frames: Array, id: String) -> bool:
	for item: Dictionary in frames:
		if item.id == id: return true
	return false
