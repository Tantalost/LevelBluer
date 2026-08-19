class_name LessonCatalog
extends RefCounted
## One activity per lesson. L1 guided, L2 trust, L3–L6 mixed formats.

const CHECKLIST := [
	"Who is contacting you?",
	"What are they asking you to do?",
	"How urgent or emotional does it feel?",
]


static func modules() -> Array[Dictionary]:
	return [
		{
			"id": "mod_01",
			"title": "Email Tricks",
			"desc": "Spot fake mail that wants a click or a secret",
			"accent": "cyan",
			"domain": "phishing",
		},
		{
			"id": "mod_02",
			"title": "Text Tricks",
			"desc": "Spot fake texts that want a tap or a code",
			"accent": "green",
			"domain": "smishing",
		},
		{
			"id": "mod_03",
			"title": "Phone Tricks",
			"desc": "Spot fake calls that want a code or a yes",
			"accent": "magenta",
			"domain": "vishing",
		},
		{
			"id": "mod_04",
			"title": "Fake Stories",
			"desc": "Spot people who borrow a trusted role",
			"accent": "cyan",
			"domain": "pretexting",
		},
		{
			"id": "mod_05",
			"title": "Tempting Offers",
			"desc": "Spot gifts and finds that hide a trap",
			"accent": "muted",
			"domain": "baiting",
		},
	]


static func module_ids() -> Array[String]:
	var ids: Array[String] = []
	var list: Array[Dictionary] = modules()
	for i in list.size():
		ids.append(str(list[i].get("id", "")))
	return ids


static func module_by_id(module_id: String) -> Dictionary:
	var list: Array[Dictionary] = modules()
	for i in list.size():
		if str(list[i].get("id", "")) == module_id:
			return list[i]
	return {}


static func lessons_for(module_id: String) -> Array[Dictionary]:
	match module_id:
		"mod_01":
			return [_phishing_l1(), _phishing_l2(), _phishing_l3(), _phishing_l4(), _phishing_l5(), _phishing_l6()]
		"mod_02":
			return [_smishing_l1(), _smishing_l2(), _smishing_l3(), _smishing_l4(), _smishing_l5(), _smishing_l6()]
		"mod_03":
			return [_vishing_l1(), _vishing_l2(), _vishing_l3(), _vishing_l4(), _vishing_l5(), _vishing_l6()]
		"mod_04":
			return [_pretexting_l1(), _pretexting_l2(), _pretexting_l3(), _pretexting_l4(), _pretexting_l5(), _pretexting_l6()]
		"mod_05":
			return [_baiting_l1(), _baiting_l2(), _baiting_l3(), _baiting_l4(), _baiting_l5(), _baiting_l6()]
		_:
			return []


static func lesson_count(module_id: String) -> int:
	return lessons_for(module_id).size()


static func checklist_label(item: int) -> String:
	var index := item - 1
	if index < 0 or index >= CHECKLIST.size():
		return ""
	return str(CHECKLIST[index])


static func _scene(channel: String, content: String) -> Dictionary:
	return {"channel": channel, "content": content}


static func _note(item: int, text: String) -> Dictionary:
	return {"checklist_item": item, "plain_language_note": text}


static func _practice(
	channel: String,
	content: String,
	is_attack: bool,
	correct_feedback: String,
	incorrect_feedback: String,
	explanation: String,
	items: Array
) -> Dictionary:
	return {
		"scenario": _scene(channel, content),
		"is_attack": is_attack,
		"correct_feedback": correct_feedback,
		"incorrect_feedback": incorrect_feedback,
		"explanation": explanation,
		"checklist_items_referenced": items,
		"guesses_do_not_count": true,
	}


static func _lesson(
	domain: String,
	title: String,
	beat1_scene: Dictionary,
	observations: Array,
	term: String,
	definition: String,
	practice: Array,
	summary: String
) -> Dictionary:
	return {
		"domain": domain,
		"title": title,
		"activity": "guided",
		"skip_intro": false,
		"beat1_guided_example": {
			"scenario": beat1_scene,
			"observations": observations,
		},
		"beat2_name_it": {
			"term": term,
			"reveal": "This kind of trick has a name: %s." % term,
			"definition": definition,
			"callback_line": "It just means what you already spotted above.",
		},
		"beat3_practice": practice,
		"beat4_summary": summary,
	}


static func _pack(
	domain: String,
	title: String,
	activity: String,
	summary: String,
	extra: Dictionary
) -> Dictionary:
	var row := {
		"domain": domain,
		"title": title,
		"activity": activity,
		"beat4_summary": summary,
	}
	for key in extra.keys():
		row[key] = extra[key]
	return row


static func _trust(
	domain: String,
	title: String,
	channel: String,
	content: String,
	is_attack: bool,
	hint: String,
	correct_feedback: String,
	incorrect_feedback: String,
	explanation: String,
	summary: String
) -> Dictionary:
	return _pack(domain, title, "trust", summary, {
		"scenario": _scene(channel, content),
		"is_attack": is_attack,
		"hint": hint,
		"correct_feedback": correct_feedback,
		"incorrect_feedback": incorrect_feedback,
		"explanation": explanation,
	})


static func _spot(
	domain: String,
	title: String,
	channel: String,
	real_text: String,
	fake_text: String,
	options: Array,
	tell_index: int,
	explanation: String,
	summary: String
) -> Dictionary:
	return _pack(domain, title, "spot", summary, {
		"real": _scene(channel, real_text),
		"fake": _scene(channel, fake_text),
		"options": options,
		"tell_index": tell_index,
		"explanation": explanation,
	})


static func _tap(
	domain: String,
	title: String,
	channel: String,
	brief: String,
	question: String,
	prompt: String,
	segments: Array,
	summary: String
) -> Dictionary:
	return _pack(domain, title, "tap", summary, {
		"scenario": _scene(channel, ""),
		"brief": brief,
		"question": question,
		"prompt": prompt,
		"segments": segments,
	})


static func _seg(text: String, is_tell: bool, trap: bool, why: String) -> Dictionary:
	return {"text": text, "is_tell": is_tell, "trap": trap, "why": why}


static func _branch(domain: String, title: String, channel: String, nodes: Dictionary, summary: String) -> Dictionary:
	return _pack(domain, title, "branch", summary, {
		"scenario": _scene(channel, ""),
		"nodes": nodes,
	})


static func _triage(domain: String, title: String, seconds: int, items: Array, summary: String) -> Dictionary:
	return _pack(domain, title, "triage", summary, {
		"seconds": seconds,
		"items": items,
	})


static func _triage_item(preview: String, content: String, correct: String, why: String) -> Dictionary:
	return {"preview": preview, "content": content, "correct": correct, "why": why}


static func _consequence(
	domain: String,
	title: String,
	channel: String,
	lure: String,
	aftermath: String,
	click_debrief: String,
	ignore_debrief: String,
	summary: String
) -> Dictionary:
	return _pack(domain, title, "consequence", summary, {
		"scenario": _scene(channel, lure),
		"aftermath": aftermath,
		"click_debrief": click_debrief,
		"ignore_debrief": ignore_debrief,
	})


static func _reverse(domain: String, title: String, goal: String, phrases: Array, summary: String) -> Dictionary:
	return _pack(domain, title, "reverse", summary, {
		"goal": goal,
		"phrases": phrases,
	})


static func _phrase(text: String, good: bool) -> Dictionary:
	return {"text": text, "good": good}


static func _timeline(
	domain: String,
	title: String,
	events: Array,
	suspicion_index: int,
	explanation: String,
	summary: String
) -> Dictionary:
	return _pack(domain, title, "timeline", summary, {
		"events": events,
		"suspicion_index": suspicion_index,
		"explanation": explanation,
	})


static func _phishing_l1() -> Dictionary:
	return _lesson(
		"phishing",
		"The fake school email",
		_scene(
			"email",
			"From: Harbor Civic IT <help@harb0r-civic.net>\nSubject: Campus login expires in 12 minutes\n\nYour campus password stops working at 9:15. Open this page now and type it again so you are not locked out of class: harb0r-civic.net/login-fix"
		),
		[
			_note(1, "The address tries to look like the school, but one letter in the name is actually a zero."),
			_note(2, "They want you to open their page and type your campus password."),
			_note(3, "They give you twelve minutes and talk about being locked out of class."),
		],
		"phishing",
		"A fake email that pretends to be a place you already trust, hoping you will click and hand over a secret.",
		[
			_practice(
				"email",
				"From: Payroll Desk <pay@harborcivic-hr.co>\n\nYour student stipend is on hold. Download stipend-release.pdf.exe, sign in, and confirm today so payment is not delayed.",
				true,
				"That's right. You caught the fake sender and the rush.",
				"Close — look at who wrote it, what they want opened, and how fast they want you to move.",
				"The address is not the school's. They want a file opened and a sign-in, and 'today' is there to hurry you.",
				[1, 2, 3]
			),
			_practice(
				"email",
				"From: Harbor Civic Registrar <registrar@harborcivic.edu>\n\nAdd-drop ends Friday. Review your courses in the campus portal you already use. We will never ask for your password by email.",
				false,
				"That's right. This is ordinary campus mail.",
				"Good guess to be careful. This uses the real school address, does not ask for a password, and points you to a portal you already know.",
				"A real office can send reminders. The sender matches the school, the ask is just to check a page you already use, and there is no panic countdown.",
				[]
			),
		],
		"You can now recognize phishing."
	)


static func _smishing_l1() -> Dictionary:
	return _lesson(
		"smishing",
		"The fake charge text",
		_scene(
			"sms",
			"MetroRide: Your card was charged ₱4,900 for a trip you did not take. Tap metro-ride-help.tk/refund in the next 10 minutes or the charge stays."
		),
		[
			_note(1, "The text uses a name you know, but the link goes to a different, odd website."),
			_note(2, "They want you to tap and 'fix' a charge you did not make."),
			_note(3, "They give you ten minutes or you lose money."),
		],
		"smishing",
		"A fake text that pretends to be a company you know, hoping you will tap a link and give something away.",
		[
			_practice(
				"sms",
				"GCash Alert: We paused your wallet. Reply YES and send the 6-digit code that just arrived to keep your money.",
				true,
				"That's right. A real wallet app will not ask you to send that code by text.",
				"Close — ask who is texting, what they want sent back, and why it has to be now.",
				"The sender wants a yes and a one-time code. That code is meant for you, not for a stranger in a text.",
				[1, 2]
			),
			_practice(
				"sms",
				"MetroRide: Your monthly pass renews on the 1st. Open the MetroRide app you already have to see the receipt. We will never ask for a code by text.",
				false,
				"That's right. This is a normal reminder.",
				"Good guess. This names the real app, does not ask for a code, and does not push a strange link.",
				"The company points you to the app you already installed and makes no rush demand.",
				[]
			),
		],
		"You can now recognize smishing."
	)


static func _vishing_l1() -> Dictionary:
	return _lesson(
		"vishing",
		"The fake bank call",
		_scene(
			"call",
			"A calm caller says they are Northline Credit Union fraud desk. They read the last four digits of a card you do have. They say a ₱12,000 transfer is pending, and you must read the 6-digit code that just appeared on your phone so they can cancel it."
		),
		[
			_note(1, "Anyone can say they are the bank. A real desk will not need you to prove it by reading a code aloud."),
			_note(2, "They want the number that just popped up on your phone."),
			_note(3, "They talk about a big transfer happening right now so you will not pause."),
		],
		"vishing",
		"A fake phone call that pretends to be a trusted office, hoping you will say a secret out loud.",
		[
			_practice(
				"call",
				"Someone claiming to be campus IT says your school account is being used in another city. To freeze it, they need the code from the text the school just sent you, and they ask you not to hang up.",
				true,
				"That's right. Hang up. Real IT will not ask you to read that code.",
				"Close — think about who called, what they want spoken, and why they tell you not to hang up.",
				"The caller wants the code meant for you, and they keep you on the line so you cannot check.",
				[1, 2, 3]
			),
			_practice(
				"call",
				"You called the number printed on the back of your Northline card. The agent verifies two questions you chose, then says they will mail a new card. They never ask for a code from a text.",
				false,
				"That's right. You started this call, and they did not ask for a code.",
				"Good guess to stay cautious. You placed the call to the printed number, and they did not ask you to read a code.",
				"When you dial the number on the card, and they do not ask for a one-time code, that is ordinary help.",
				[]
			),
		],
		"You can now recognize vishing."
	)


static func _pretexting_l1() -> Dictionary:
	return _lesson(
		"pretexting",
		"The clipboard story",
		_scene(
			"in-person",
			"A person with a clipboard says they are from Facilities doing a surprise key audit. They know the building name. They ask you to unlock the staff closet and wait outside so they can 'count the keys' without you watching."
		),
		[
			_note(1, "A clipboard and a building name do not prove they work here."),
			_note(2, "They want a door opened and they want you not to watch."),
			_note(3, "Calling it a surprise audit makes you feel you should obey right now."),
		],
		"pretexting",
		"Making up a believable story and role so you will help, unlock, or share something you normally would not.",
		[
			_practice(
				"in-person",
				"A visitor says they are your dean's new assistant. The dean is in a meeting and needs you to approve a payment on a phone they are holding, before the vendor walks out.",
				true,
				"That's right. A new face plus a payment on their phone is a story built to skip checks.",
				"Close — who are they really, what do they want approved, and why can't it wait for the dean?",
				"They borrowed a trusted title, asked for a payment, and used a meeting as a reason to hurry.",
				[1, 2, 3]
			),
			_practice(
				"in-person",
				"A staffer with a school ID you can check at the desk asks you to walk them to the copy room you both already use. They wait while you swipe your own badge. No payment, no secret, no 'don't tell anyone.'",
				false,
				"That's right. You can check the ID, and nothing secret is being asked.",
				"Good guess. You can verify the badge, you keep control of the door, and nobody asks for money or a secret.",
				"A real coworker can ask for a walk to a shared room. The badge can be checked, and the ask is small and visible.",
				[]
			),
		],
		"You can now recognize pretexting."
	)


static func _baiting_l1() -> Dictionary:
	return _lesson(
		"baiting",
		"The mystery USB",
		_scene(
			"usb-drive",
			"A USB stick labeled DEAN'S LIST 2026 sits by the library printer. A sticky note says 'plug in to see if you made it.' Nobody is around to claim it."
		),
		[
			_note(1, "You do not know who left this, even if the label uses a school name."),
			_note(2, "The note wants you to plug it into a computer."),
			_note(3, "Curiosity about making a list is meant to win over caution."),
		],
		"baiting",
		"Leaving a tempting gift or find so you will plug it in, open it, or take it — and give the stranger a way in.",
		[
			_practice(
				"in-person",
				"A table in the quad offers free earphones if you sign in with your campus email and password on their tablet 'to confirm you are a student.'",
				true,
				"That's right. A free gift that needs your campus password is the bait.",
				"Close — who set up the table, what login are they collecting, and how appealing is the free gift?",
				"Unknown people want your school password in exchange for a prize. That trade is the trap.",
				[1, 2, 3]
			),
			_practice(
				"in-person",
				"The library desk, with staff you know, hands you a loaner USB from the labeled drawer after you show your ID. They tell you to return it to the desk, not to keep it.",
				false,
				"That's right. This is a normal loan from people you can name.",
				"Good guess. You can see the staff, they checked your ID, and the stick is a known loan, not a mystery prize.",
				"A real desk can lend a drive. You know who handed it over, and they are not trading it for a password.",
				[]
			),
		],
		"You can now recognize baiting."
	)

static func _phishing_l2() -> Dictionary:
	return _trust(
		"phishing",
		"The name on the left can lie",
		"email",
		"From: IT Helpdesk <it.help@gmail.com>\nSubject: Re: Your ticket #4412\n\nWe continued your ticket. Reply with your campus password so we can reopen the printer queue before lab starts.",
		true,
		"Look at the address after the name, not the name itself.",
		"That's right. A public mailbox plus a password ask is a trap.",
		"You can still walk this back. The name is typed. The address is gmail. Nobody at school needs your password by reply.",
		"Safety net: never send a password by email. Open the real portal yourself if a ticket matters.",
		"You can now judge a full message: trust it, or not."
	)


static func _phishing_l3() -> Dictionary:
	return _spot(
		"phishing",
		"Almost the real website",
		"email",
		"From: Campus Network <network@westfield.edu>\nSubject: Wifi maintenance tonight\n\nWifi will pause 11pm–1am. No login needed. Use saved campus wifi after.",
		"From: Campus Wifi <wifi@westfie1d.edu>\nSubject: Wifi will drop at noon\n\nRe-enter your password at westfie1d.edu/wifi-fix so you can stay online for class.",
		["The subject mentions wifi", "The school name uses a 1 instead of L", "Both mails talk about campus", "The fake one is a bit shorter"],
		1,
		"The giveaway is the lookalike name: westfie1d, and they want a password on their page.",
		"You can now tap the one detail that makes a page or mail a spoof."
	)


static func _phishing_l4() -> Dictionary:
	return _tap(
		"phishing",
		"Files that are not files",
		"email",
		"A fake email often hides a program inside a 'document' and uses a fine or a hold to make you hurry. You will see one mail cut into four lines.",
		"Which lines are the trick (fake sender, fake file, or rush)? Which line is only a fine amount?",
		"Tap the dangerous lines. Leave the ordinary one unselected.",
		[
			_seg("From: Klaris Library <fines@klaris-lib.net>", true, false, "Not the school library address."),
			_seg("Subject: Overdue fine ₱350", false, true, "A fine amount can be real. The trap is what they want opened."),
			_seg("Open FINE_NOTICE.PDF.exe and log in today", true, false, "A program hiding as a PDF, plus a same-day hold."),
			_seg("Avoid a hold on your account", true, false, "The rush is there to skip thinking."),
		],
		"You can now mark the tells, and leave the decoy alone."
	)


static func _phishing_l5() -> Dictionary:
	return _triage(
		"phishing",
		"Inbox under the clock",
		40,
		[
			_triage_item("Mia / shared notes", "From: Mia Santos <mia.santos.group@outlook.com>\nOpen this folder and sign in with your campus account before 10.", "report", "Familiar name, public mailbox, campus login."),
			_triage_item("Mia / class drive", "From: Mia Santos <mia.santos@westfield.edu>\nNotes are in our class group on the school drive. No extra login.", "safe", "School address, drive you already share."),
			_triage_item("Health / portal", "From: Campus Health <clinic@westfield.edu>\nCertificate ready in the patient portal you already book with. We will not ask for a password here.", "safe", "Real office, known portal."),
			_triage_item("Health / 30 min hold", "From: Campus Health <clinic.westfield.care@proton.me>\nUpload ID and password in 30 minutes or a hold hits enrollment.", "report", "Wrong mailbox, password harvest, timer."),
			_triage_item("Promo blast", "From: Campus Events <events@westfield.edu>\nClub fair Friday on the quad. Poster is on the school site. No links to sign in.", "ignore", "FYI you can skip. Not a trap, not urgent work."),
		],
		"You can now sort a mixed inbox: safe, report, or ignore."
	)


static func _phishing_l6() -> Dictionary:
	return _consequence(
		"phishing",
		"What a click costs",
		"email",
		"From: Campus Wifi <wifi@westfie1d.edu>\n\nYour wifi drops at noon. Re-enter your password here: westfie1d.edu/wifi-fix",
		"ACCOUNT FLAG\n\nwestfie1d.edu/wifi-fix accepted your campus password.\nA copy was sent to a mailbox you do not control.\nSession opened on a lab PC you are not sitting at.\n\nThis is a drill. The password was not really taken.",
		"That click would have handed a lookalike site your password. Next time, type the school address yourself.",
		"You left it. Typing the real school address yourself is the move. The 1 in westfie1d was the tell.",
		"You can now picture the aftermath before you tap."
	)


static func _smishing_l2() -> Dictionary:
	return _trust(
		"smishing",
		"A text is still a stranger",
		"sms",
		"Navo Bookstore: Your reserved book is about to be given away. Tap bit.ly/navo-hold and type your student number plus password to keep it.",
		true,
		"A shop name at the start of a text can be typed by anyone. Where does the link go?",
		"That's right. A short hidden link plus a password is not how a bookstore works.",
		"You can still stop. A real hold is picked up at the counter. A bit.ly link hides the real site.",
		"Safety net: do not type a password from a text. Open the shop's real app or walk in.",
		"You can now judge a full text: trust it, or not."
	)


static func _smishing_l3() -> Dictionary:
	return _tap(
		"smishing",
		"Codes are not for strangers",
		"sms",
		"A text can use a real app name and still be a trap. The danger is what they want you to send back, not the brand at the top.",
		"Which lines ask for a code or scare you about money? Which line is only a brand name?",
		"Tap the dangerous lines. Leave the ordinary one unselected.",
		[
			_seg("GCash Alert", false, true, "Apps can send alerts. The danger is what they ask you to send back."),
			_seg("We paused your wallet", true, false, "Fear of lost money."),
			_seg("Reply YES and send the 6-digit code that just arrived", true, false, "That code is for you, not a stranger."),
			_seg("to keep your money", true, false, "The prize is keeping what you already have."),
		],
		"You can now highlight the ask for a code, and ignore the decoy brand name."
	)


static func _smishing_l4() -> Dictionary:
	return _triage(
		"smishing",
		"Texts under the clock",
		40,
		[
			_triage_item("MetroRide refund", "MetroRide: charged ₱4,900. Tap metro-ride-help.tk/refund in 10 minutes.", "report", "Odd site, fake charge, timer."),
			_triage_item("MetroRide pass", "MetroRide: pass renews on the 1st. Open the MetroRide app you already have. We never ask for a code by text.", "safe", "Points to the real app."),
			_triage_item("Lalamove pay", "Lalamove: Pay ₱82 at lalamove-pay.xyz or your next ride is blocked in 5 minutes.", "report", "Strange page plus a block threat."),
			_triage_item("Navo pickup", "Navo Bookstore: pickup 1–4pm at the counter. Show your ID. We never ask for a password by text.", "safe", "In-person pickup, no link."),
			_triage_item("Promo load", "Win ₱500 load. Reply YES to unknown-shortcode. No school name.", "ignore", "Junk. Do not report as school mail; do not tap."),
		],
		"You can now sort texts the way you sort a noisy lock screen."
	)


static func _smishing_l5() -> Dictionary:
	return _reverse(
		"smishing",
		"Build the trick",
		"Goal: make a student tap a link and type a password in under a minute.",
		[
			_phrase("Use a brand they already know", true),
			_phrase("Hide the real site behind a short link", true),
			_phrase("Say the book / ride / wallet will be lost soon", true),
			_phrase("Ask them to visit the shop in person with ID", false),
			_phrase("Tell them you will never ask for a password", false),
			_phrase("Demand student number plus password on the page", true),
		],
		"You can now see the playbook from the inside: brand, hidden link, rush, secret."
	)


static func _smishing_l6() -> Dictionary:
	return _timeline(
		"smishing",
		"How the text trap runs",
		[
			"A short text uses a brand name you know.",
			"A timer says the charge or hold lands in minutes.",
			"The link is a short or odd address, not the real app.",
			"The page asks for a password or a one-time code.",
		],
		1,
		"Suspicion should kick in at the timer. Real companies let you open the app you already have.",
		"You can now name the step where you should have stopped."
	)


static func _vishing_l2() -> Dictionary:
	return _trust(
		"vishing",
		"Caller ID can be copied",
		"call",
		"Your phone shows WESTFIELD REGISTRAR. A woman says your enrollment will be voided in fifteen minutes unless you read the code from the school text so she can verify you are the student.",
		true,
		"The name on the screen can be faked. What does she want you to say out loud?",
		"That's right. A code from a text is not proof for a stranger on a live call.",
		"You can still hang up. Call the number on the school site. The screen name does not prove who spoke.",
		"Safety net: hang up, then dial the printed number. Never read a code to someone who called you.",
		"You can now judge a full call: trust it, or not."
	)


static func _vishing_l3() -> Dictionary:
	return _branch(
		"vishing",
		"Stay or shut it down",
		"call",
		{
			"start": {
				"line": "Campus IT. Your account is signed in from another city. Stay on the line. Read me the code that just arrived.",
				"choices": [
					{"text": "What's your ticket number? I'll stay on.", "next": "push"},
					{"text": "I'll hang up and call the number on the school site.", "next": "end_win"},
				],
			},
			"push": {
				"line": "If you hang up we cannot freeze it. The code, now. Do not tell anyone in the room.",
				"choices": [
					{"text": "Read the code so they can freeze it.", "next": "end_lose"},
					{"text": "Hang up anyway. Call the real desk.", "next": "end_win"},
				],
			},
			"end_win": {
				"line": "The line goes dead. The real IT page lists a desk you can ring yourself.",
				"end": true,
				"won": true,
				"debrief": "Hanging up and calling the printed number shuts this down. Staying on the line is what they need.",
			},
			"end_lose": {
				"line": "They repeat the code back. A new session opens on a machine that is not yours.",
				"end": true,
				"won": false,
				"debrief": "The code was meant for you. Saying it on a call they started hands them the account. This is a drill.",
			},
		},
		"You can now pick the reply that ends a fake call."
	)


static func _vishing_l4() -> Dictionary:
	return _consequence(
		"vishing",
		"If you stay on the line",
		"call",
		"A calm voice: Northline fraud desk. ₱12,000 is pending. Read the 6-digit code on your phone so we can cancel it. Do not hang up.",
		"VOICE NOTE FILED\n\nThe code you spoke was used to approve a transfer.\nA new payee was added to the account.\nNorthline's real desk has no ticket for this call.\n\nThis is a drill. No money moved.",
		"Reading the code would have finished their job. Next time, hang up and dial the number on the card.",
		"You cut the line. The real desk is the number on the card, not the voice that called you.",
		"You can now see what 'just stay on the line' is for."
	)


static func _vishing_l5() -> Dictionary:
	return _timeline(
		"vishing",
		"The call, in order",
		[
			"A name you trust lights up on caller ID.",
			"They already know one small fact (last four digits, a class).",
			"They ask you not to hang up.",
			"They want a code or a yes spoken now.",
		],
		2,
		"The 'do not hang up' line is where suspicion should lock in. Knowing one fact does not make them the bank.",
		"You can now mark the beat where a real desk would let you call back."
	)


static func _vishing_l6() -> Dictionary:
	return _reverse(
		"vishing",
		"Build the call",
		"Goal: get a student to say a one-time code before they check.",
		[
			_phrase("Spoof a name they already trust on the screen", true),
			_phrase("Read back one true detail you found elsewhere", true),
			_phrase("Tell them not to hang up", true),
			_phrase("Ask them to call the number on their card", false),
			_phrase("Demand the code from the text that just arrived", true),
			_phrase("Mail a new card and never ask for a code", false),
		],
		"You can now hear the playbook: borrowed name, one true fact, stay on, say the code."
	)


static func _pretexting_l2() -> Dictionary:
	return _trust(
		"pretexting",
		"The story is the tool",
		"in-person",
		"A person in a plain shirt says they are with the accrediting team. Your professor already knows. They ask you to copy the class list from the teacher's laptop while she is in the restroom, so the visit stays on schedule.",
		true,
		"Who is missing, and what unusual favor happens while they are gone?",
		"That's right. A story plus an empty room is the tool.",
		"You can still wait. The teacher can confirm a visit. A laptop you should not open is the tell.",
		"Safety net: do not copy lists or open a staff laptop because a stranger said the visit is running late.",
		"You can now judge a full story: trust it, or not."
	)


static func _pretexting_l3() -> Dictionary:
	return _branch(
		"pretexting",
		"The dean's assistant",
		"in-person",
		{
			"start": {
				"line": "I'm the dean's new assistant. She's in a meeting. Approve this vendor payment on my phone before they walk out.",
				"choices": [
					{"text": "Sure — she said to keep things moving.", "next": "push"},
					{"text": "I'll wait and ask the dean myself.", "next": "end_win"},
				],
			},
			"push": {
				"line": "If this misses the window she will be upset. Just tap approve. Don't message her, she's presenting.",
				"choices": [
					{"text": "Tap approve so the vendor can leave.", "next": "end_lose"},
					{"text": "Still wait. Payments wait for the dean.", "next": "end_win"},
				],
			},
			"end_win": {
				"line": "They pocket the phone and leave. The dean has no new assistant on the books.",
				"end": true,
				"won": true,
				"debrief": "Waiting for the person they named shuts the story down. Secrecy plus a payment on their phone is the tell.",
			},
			"end_lose": {
				"line": "The payment goes through on a wallet you do not control. The dean never asked.",
				"end": true,
				"won": false,
				"debrief": "You approved their story, not the dean's bill. This is a drill.",
			},
		},
		"You can now pick the reply that waits for the real person."
	)


static func _pretexting_l4() -> Dictionary:
	return _timeline(
		"pretexting",
		"The visit that wasn't",
		[
			"A stranger names a trusted office or teacher.",
			"That trusted person is 'busy' or out of the room.",
			"The ask is one unusual favor (list, drawer, payment).",
			"A clock or schedule is used so you skip checking.",
		],
		1,
		"When the trusted person is conveniently gone, that is the kick-in. Stories need an empty room.",
		"You can now point at the step where you should have waited."
	)


static func _pretexting_l5() -> Dictionary:
	return _spot(
		"pretexting",
		"Badge vs clipboard",
		"in-person",
		"Staffer with a school ID you can check at the desk asks you to walk them to the copy room. They wait while you swipe your own badge. No payment. No 'don't tell anyone.'",
		"Visitor with a clipboard knows the building name. Surprise key audit. Unlock the staff closet and wait outside so they can count keys without you watching.",
		["They know the building name", "They want you outside while a door stays open", "A clipboard looks official", "Both people are standing in the hall"],
		1,
		"The tell is the closed-door ask: unlock, then don't watch. A name and a clipboard are cheap.",
		"You can now tap the one ask that a real coworker would not need."
	)


static func _pretexting_l6() -> Dictionary:
	return _reverse(
		"pretexting",
		"Write the story",
		"Goal: get a student to open a locked drawer while the adviser is gone.",
		[
			_phrase("Borrow a role (yearbook, accreditation, facilities)", true),
			_phrase("Say the trusted adult already knows or just left", true),
			_phrase("Tie it to a slot, visit, or printer window that is about to close", true),
			_phrase("Walk with them in the open and keep the ask small", false),
			_phrase("Let them check an ID at the desk", false),
			_phrase("Ask them not to message the adviser yet", true),
		],
		"You can now see why the story exists: to skip the person who could say no."
	)


static func _baiting_l2() -> Dictionary:
	return _trust(
		"baiting",
		"Free stuff has a price",
		"in-person",
		"A booth titled FREE HEADSET FOR SURVEY asks you to install their listener app with your campus login so they can verify you are enrolled before they hand over the box.",
		true,
		"What do you have to give before the gift moves?",
		"That's right. The headset is the hook. The login is the cost.",
		"You can still walk. A real raffle from Student Affairs uses paper, not a campus password.",
		"Safety net: no prize is worth a campus login on someone else's phone.",
		"You can now judge a full offer: trust it, or not."
	)


static func _baiting_l3() -> Dictionary:
	return _spot(
		"baiting",
		"Loan vs lure",
		"usb-drive",
		"Library desk you know. Staff checks your ID, hands a loaner USB from a labeled drawer, tells you to return it to the desk.",
		"USB labeled DEAN'S LIST 2026 by the printer. Sticky note: plug in to see if you made it. Nobody to claim it.",
		["Both are USB sticks", "The found stick has no owner and wants a plug-in", "The label uses a school phrase", "Curiosity is normal"],
		1,
		"The tell is no owner plus 'plug in to see.' A desk loan has a person, an ID check, and a return rule.",
		"You can now tap what makes a find different from a loan."
	)


static func _baiting_l4() -> Dictionary:
	return _tap(
		"baiting",
		"The prize table",
		"in-person",
		"A prize table can look friendly. The tell is what you have to type before you get the gift — not where the table sits.",
		"Which lines trade a gift for a campus login? Which line is only a location?",
		"Tap the dangerous lines. Leave the ordinary one unselected.",
		[
			_seg("A table in the quad", false, true, "Place is ordinary. The trade is the trap."),
			_seg("Free earphones if you sign in", true, false, "Gift first."),
			_seg("Campus email and password on their tablet", true, false, "That login is the real take."),
			_seg("To confirm you are a student", true, false, "A school ID at a known desk would be enough. Their tablet is not."),
		],
		"You can now mark the login, and leave the decoy place-name."
	)


static func _baiting_l5() -> Dictionary:
	return _triage(
		"baiting",
		"Offers under the clock",
		40,
		[
			_triage_item("Dean's list USB", "Unclaimed stick by the printer. Note: plug in to see if you made it.", "report", "Give it to the desk. Do not plug it in."),
			_triage_item("Library loaner", "Known staff, ID check, labeled drawer, return to desk.", "safe", "A real loan."),
			_triage_item("Headset survey", "Unknown booth. Install app with campus login for a free box.", "report", "Prize for a password."),
			_triage_item("Paper raffle", "Student Affairs table. Printed stub, drop in a box. No QR.", "safe", "Known office, no login."),
			_triage_item("QR laptop win", "Flyer on a bench. Scan and sign in with school email. No office name.", "ignore", "Don't scan. Treat as junk, or hand to security if you want it gone."),
		],
		"You can now sort gifts, finds, and tables in a hurry."
	)


static func _baiting_l6() -> Dictionary:
	return _consequence(
		"baiting",
		"If you plug it in",
		"usb-drive",
		"A stick labeled SALARY-CORRECTION sits in the faculty hall. Note: plug in to see if your name is on the adjustment list.",
		"DEVICE REPORT\n\nThe stick ran a small program when it mounted.\nA copy of your last login token left the machine.\nShared folders you can open were listed.\n\nThis is a drill. Nothing was really taken.",
		"Curiosity about pay is the bait. Next time the stick goes to security, not a USB port.",
		"You left it. Handing a mystery stick to a desk is the whole win.",
		"You can now picture what 'just check the list' was for."
	)
