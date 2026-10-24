extends RefCounted
## Authored fictional hearing. Evidence challenges claims; admission resolves identity.
const ID: String = "mod_01_ch_05"
const NUMBER: int = 5
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
	{"title":"It's Eric.","weak":"the only one who knew","claim":"Eric brought the surveys. He's the only one who knew John needed coffee money. Obvious.","correct":"coffee","options":["domain","coffee","borrow","short"],"hint":"Was the coffee comment private, or visible in the club chat?","smug":"That's a suspicious message, John. Not an answer to my point.","result":"John: Only Eric? I posted it to the group. Twenty members had access.\nEric: You made a group message sound like a secret.\nSir Rham: That accusation is unsupported. Access is not authorship.","flash":"CH1 / Jobert: ‘Careful with random surveys. Ask me if you're unsure.’","art":"story_bg_clubroom","voices":[{"who":"Eric","text":"I shared the survey. That doesn't mean I wrote every email."},{"who":"Jobert","text":"Let's stop making this complicated."},{"who":"Mika","text":"Then explain what actually proves it."}]},
	{"title":"It's Dan.","weak":"knowing the format proves it","claim":"Dan bragged about our email format. Knowing the format proves it was his prank.","correct":"headers","options":["typo1","short","headers","whisper"],"hint":"The headers show impersonation. Do they name Dan as the sender?","smug":"You brought another warning sign. I asked who sent it.","result":"John: A copied format doesn't identify Dan. The From and Reply-To aren't Sir Rham's, but neither identifies Dan.\nDan: My joke was stupid. Your conclusion is worse.\nSir Rham: We will distinguish a joke from evidence. That accusation is unsupported.","flash":"CH2 / Jobert: ‘Now compare the part after the @.’","art":"story_chapter2_cover","voices":[{"who":"Dan","text":"I joked about the inbox. I never said I sent that email."},{"who":"Jobert","text":"You knew exactly how to make it look official."},{"who":"Sir Rham","text":"Knowledge is not the same as an action."}]},
	{"title":"I saved you.","weak":"before Submit, nothing was captured","claim":"I called before you hit Submit. Before Submit, nothing was captured. I saved you.","correct":"call","options":["addresses","timeline","call","borrow"],"hint":"Review the new IT finding and call log. Was Submit required for input capture?","smug":"You're accusing the person who answered your messages?","result":"John: IT found input capture before Submit. The first input and your call share a timestamp.\nJohn: How did you know I was on the page at that second?\nJobert: I just... had a feeling.\nSir Rham: The timing needs an explanation. It is not proof of an operator by itself.","flash":"CH3 / Jobert: ‘Don't enter anything else. Send me a screenshot.’","art":"story_bg_john_desk_night","voices":[{"who":"John","text":"You called just as I started typing."},{"who":"Jobert","text":"Because you messaged me. Remember who helped you."},{"who":"Sir Rham","text":"Helping once does not settle what happened elsewhere."}]},
	{"title":"I was offline.","weak":"offline proves I was asleep","claim":"I was asleep when the prize arrived. My status was offline. Offline proves I was asleep.","correct":"timeline","options":["urgency","whisper","addresses","timeline"],"hint":"Compare both last-seen times. Can either status establish sleep or authorship?","smug":"You can't turn every ordinary detail into an accusation.","result":"John: Ten seconds after your last seen. Fifteen after Eric's.\nJohn: Neither status proves who sent it—and neither proves you were asleep.\nJobert: You keep twisting everything.\nSir Rham: Your status is not the alibi you claimed.","flash":"CH4 / John: ‘Offline. You picked a really bad time to disappear.’","art":"opening_john_reaching_phone_v1","voices":[{"who":"Mika","text":"Eric's status was close to the email too."},{"who":"Jobert","text":"Exactly. Check my status. I wasn't even there."},{"who":"John","text":"A status isn't the whole timeline."}]}
]
const COMIC: Array[Dictionary] = [
	{"id":"survey","title":"01 / An offer, then trust","art":"story_bg_clubroom","narration":"John: A survey offer reached me through Eric. My coffee comment was in the group chat. Jobert told me to ask him whenever I was unsure."},
	{"id":"advisor","title":"02 / A familiar name","art":"story_chapter2_cover","narration":"John: Someone copied Sir Rham's identity. Jobert helped me spot the lookalike domain. Dan's joke made him look suspicious, but it wasn't evidence that he sent it."},
	{"id":"call","title":"03 / The perfect interruption","art":"story_bg_john_desk_night","narration":"John: The fake wallet page captured input before Submit. Jobert's call came at the recorded first-input second. I mistook the timing for safety."},
	{"id":"prize","title":"04 / That same morning","art":"opening_john_claim_prize_v1","narration":"John: I woke in my room to a prize promise that repeated my coffee comment. Jobert was offline. I tapped. The records linked the messages, but did not name the sender."},
	{"id":"challenge","title":"05 / Claims fall apart","art":"story_bg_john_bed_night","narration":"John: We challenged the accusations against Eric and Dan, the claim about Submit, and the offline alibi. Then ‘recieve’ appeared again. It was a clue to question, not a verdict."},
	{"id":"admission","title":"06 / His own words","art":"opening_collector_meeting_v2","narration":"John: I asked for an explanation. This time, Jobert couldn't hide behind helping me. His admission—not a spelling mistake—identified him."},
	{"id":"dan_prank","title":"Dan sent a harmless prank","art":"story_chapter2_cover","narration":"Unsupported. Knowing the format does not establish authorship."},
	{"id":"eric_alone","title":"Only Eric knew about coffee","art":"story_bg_clubroom","narration":"Contradicted by the group-chat exhibit."}
]
const COMIC_ORDER: Array[String] = ["survey","advisor","call","prize","challenge","admission"]
const ADMISSION: Array[String] = ["John: You wrote ‘recieve.’ So did both emails. That alone doesn't prove anything. Explain the messages—and the call.","Jobert: I only wanted you to keep coming back to me.","John: Did you send them?","Jobert: Yes. The survey messages. The fake advisor. The payout link. The prize.","Jobert: When the page showed input, I called. If I stopped you once, you'd trust me the next time.","Sir Rham: That's enough, Jobert. We will preserve that admission with the records."]
const AFTERMATH: Array[String] = ["Sir Rham: Eric and Dan, the accusations against you were not supported. Mika's conversation was not proof either.","Sir Rham: Jobert, you are removed from the club. The accounts used in this case will be reported, and you will face a disciplinary hearing.","John: My phone buzzes. For the first time, I don't rush to open it.","John: Relief. Then a familiar screen.","Four lights. Four figures. One connection closes."]

static func exhibit(id: String) -> Dictionary:
	for item: Dictionary in EXHIBITS:
		if item.id == id: return item
	return {}

static func frame(id: String) -> Dictionary:
	for item: Dictionary in COMIC:
		if item.id == id: return item
	return {}

static func fresh() -> Dictionary:
	var captures: Array[String] = []
	for item: Dictionary in EXHIBITS: captures.append(str(item.id))
	return {"version":1,"phase":"prep","briefed":false,"theory_done":false,"theory_bonus":false,"suspect_guesses":[],"round":0,"solved":[],"credibility":20,"round_start":20,"round_errors":[0,0,0,0],"auto_hints":[],"restarts":0,"mistakes":0,"hint_used":false,"final_matched":false,"admission_step":0,"admitted":false,"comic_order":["","","","","",""],"comic_checked":false,"comic_errors":0,"animatic_step":0,"animatic_done":false,"aftermath_step":0,"aftermath_done":false,"lights_done":false,"sealed":false,"completed":false,"next_chapter_unlocked":false,"reward":0,"captures":captures,"perk_run":{}}

static func integer(raw: Dictionary, key: String, fallback: int, ceiling: int) -> int:
	var value: Variant = raw.get(key,fallback)
	return clampi(int(value),0,ceiling) if (value is int or value is float) and is_finite(float(value)) else fallback

static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = fresh()
	for field: String in ["briefed","theory_done","theory_bonus","hint_used","final_matched","admitted","comic_checked","animatic_done","aftermath_done","lights_done"]: state[field] = raw.get(field,false) == true
	var guesses: Variant = raw.get("suspect_guesses",[])
	if guesses is Array:
		for value: Variant in guesses:
			if value in SUSPECTS and value != "Jobert" and not state.suspect_guesses.has(value): state.suspect_guesses.append(value)
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
	state.admission_step = integer(raw,"admission_step",0,ADMISSION.size()-1)
	state.admitted = state.admitted and state.final_matched and state.admission_step == ADMISSION.size()-1
	var order: Variant = raw.get("comic_order",[])
	if order is Array and order.size() == 6:
		for index: int in 6:
			if order[index] is String and not frame(order[index]).is_empty() and not state.comic_order.has(order[index]): state.comic_order[index] = order[index]
	state.comic_checked = state.comic_checked and state.admitted and state.comic_order == COMIC_ORDER
	state.animatic_step = integer(raw,"animatic_step",0,5)
	state.animatic_done = state.animatic_done and state.comic_checked and state.animatic_step == 5
	state.aftermath_step = integer(raw,"aftermath_step",0,AFTERMATH.size()-1)
	state.aftermath_done = state.aftermath_done and state.animatic_done and state.aftermath_step == AFTERMATH.size()-1
	state.lights_done = state.lights_done and state.aftermath_done
	state.perk_run = Perks.clean_run(raw.get("perk_run",{}))
	if state.perk_run.get("chapter",ID) != ID: state.perk_run = {}
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
	return state
