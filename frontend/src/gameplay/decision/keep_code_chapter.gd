extends RefCounted
## Module 2 hearing content; shared mechanics remain in the original hearing.
const Hearing: GDScript = preload("res://src/gameplay/decision/confrontation_chapter.gd")
const ID: String = "mod_02_ch_05"
const NUMBER: int = 5
const TITLE: String = "Keep the Code"
const HEARING: bool = true
const THEORY_CORRECT: String = "Code requester"
const SUSPECTS: Array[String] = ["Dan's public post","Code requester","Wallet alert","Weak signal"]
const NAME_HINTS: Array[String] = ["Which request turns a delivery problem into account access?","Read what the genuine code authorizes.","Who asks you to send the secret back to them?"]
const PRESENTATION: Dictionary = {
 "protagonist":"Amani", "module_index":1, "cast":["Amani","Sir Rham","John","Dan"],
 "backdrop":"story_bg_event_room_day", "counter_art":"", "resolution_art":"story_bg_event_room_day", "aftermath_art":"story_bg_event_room_day",
 "theory_title":"WHERE IS THE TRAP?", "theory_caption":"FOUR LEADS. ONE UNSAFE REQUEST.", "theory_prompt":"CHOOSE THE REQUEST TO CHALLENGE", "theory_instruction":"Identify the unsafe request. The sender's real identity is still unknown.", "theory_action":"CHALLENGE ", "theory_empty":"SELECT A LEAD",
 "final_title":"FINAL CONTRADICTION / CANCEL OR AUTHORIZE?", "final_typing":"Replaying the saved request...",
 "final_text":"Send the code to [color=#FFB648]cancel[/color] the new-device request. Do not open your wallet app while we fix this.",
 "final_exhibits":["authorization","support"], "final_match":"MATCH THE PURPOSE / NOT THE PROMISE", "final_frozen":"REQUEST FROZEN / Compare its promise with the verified records.",
 "comic_success":"Six moments. One sequence supported by independently checked records.", "comic_hint":"Delivery fee, device code, copied identity, recovery pressure, independent support, then the hearing. A public post does not identify the operator.",
 "recap":"A paid delivery became an account-code request. A copied identity and recovery warning added pressure. Amani rejected the device request and used independently opened support. The operator remains unidentified.",
 "cutaway_step":3, "lights":2, "lights_caption":"Audience only / Jobert remains disconnected. The text operator's connection closes. Two remain.",
 "practice_module":"mod_02", "practice_label":"PRACTICE SMISHING", "availability":"Module 3 intro and Chapter 1 are available after the first Phone Tricks lesson."
}
const BRIEFING: String = "NEXT MORNING / THE CLUBROOM\n\nDan arrives with the real parcel: ‘Your tape has completed its character development.’\nAmani: ‘Mine cost eighteen pesos less than expected.’\n\nInside the wallet support case Amani opened herself, LB-204 now says: ‘The rejected new-device request did not authorize access. We recorded your messages. Review signed-in devices and report anything unfamiliar.’\n\nSir Rham: ‘We will replay the sender's claims. Challenge each with the records. Nobody here is being identified as the operator.’\n\nThe voices in this hearing test possible explanations. Load evidence, then tap an orange claim. HOLD pauses the discussion."
const EXHIBITS: Array[Dictionary] = [
 {"id":"order","title":"Paid order + destination","source":"CH1 / Independent order record","detail":"The original order is paid and out for delivery. It requests no extra fee. The SMS points to parcel-redelivery.example/pay without a matching order reference. Eighteen pesos does not authenticate its recipient.","art":"story_bg_event_room_day","mark":"18"},
 {"id":"authorization","title":"Authorize, not cancel","source":"CH2 / Genuine alert + saved SMS","detail":"The wallet alert says the code authorizes a new device. Amani did not request it. The separate sender asks her to reply with that code to cancel the attempt. A genuine code does not verify its requester.","art":"story_bg_event_room_day","mark":"#"},
 {"id":"post","title":"Public post + copied name","source":"CH3 / Established club records","detail":"The photo and delivery day were on the public event post. The payment request came from a separate contact using Amani's identity. Her established club conversation remained accessible. Public knowledge does not identify Dan or anyone else as the sender.","art":"story_bg_club_corridor_afternoon","mark":"@"},
 {"id":"route","title":"Independent support route","source":"CH4 / Saved support case","detail":"The recovery SMS supplied its own contact and demanded a wallet code to fix cellular service. Amani used her existing wallet and carrier apps instead. Carrier help did not establish why the signal dropped.","art":"story_bg_event_room_day","mark":"↗"},
 {"id":"support","title":"Case LB-204 response","source":"NEW / Read before the hearing","detail":"In the independently opened wallet case: the rejected new-device request did not authorize access. Messages were recorded. Review signed-in devices and report unfamiliar activity. This confirms the outcome of this attempt, not every account's safety.","art":"story_bg_event_room_day","mark":"✓"},
 {"id":"signal","title":"Missing cellular signal","source":"CH3 / Observation, cause unknown","detail":"Amani noticed a signal drop. School Wi-Fi still worked. The cause was not established; this alone does not prove a SIM swap or identify an attacker.","art":"story_bg_club_corridor_afternoon","mark":"?"},
 {"id":"joke","title":"Dan's delivery joke","source":"CH1 / Context, not identification","detail":"Dan joked about the event materials. His public reminder and joking tone do not establish who controlled the suspicious contact.","art":"story_bg_event_room_day","mark":"?"}
]
const ROUNDS: Array[Dictionary] = [
 {"title":"Only eighteen pesos.","speaker":"Dan","weak":"too small to matter","claim":"Let me try the sender's argument: eighteen pesos is too small to matter. Why not pay and move on?","correct":"order","options":["signal","order","joke","post"],"hint":"Compare the fee with the order opened independently.","smug":"That record doesn't tell us whether this payment was required.","result":"Amani: The order was already paid. This new destination had no matching order reference.\nDan: So the small amount was the distraction, not verification.\nSir Rham: Exactly. Check the request, not just its price.","flash":"CH1 / The original order requested no redelivery payment.","art":"story_bg_event_room_day","voices":[{"who":"Amani","text":"The real parcel arrived this morning."},{"who":"John","text":"And the extra fee still had no explanation."},{"who":"Sir Rham","text":"Dan, test the sender's claim. Amani, show the contradiction."}]},
 {"title":"The code was genuine.","speaker":"John","weak":"the requester was genuine","claim":"The wallet really sent the code. Does that mean the requester was genuine too?","correct":"authorization","options":["order","signal","authorization","joke"],"hint":"The alert describes authorization. The sender describes cancellation.","smug":"We need the record that explains what sharing this code would do.","result":"Amani: The code authorized a new device. It did not cancel one.\nJohn: The alert was real. The instructions from the other sender were the trap.\nSir Rham: Separate the service that issued the code from the person requesting it.","flash":"CH2 / Amani kept the code private and rejected the unfamiliar request inside her wallet app.","art":"story_bg_event_room_day","voices":[{"who":"Dan","text":"The alert looked more convincing than the delivery text."},{"who":"Amani","text":"It was a genuine alert for something I had not requested."},{"who":"Sir Rham","text":"Authentic information can still be used in a false story."}]},
 {"title":"They knew the delivery.","speaker":"Dan","weak":"only a friend could know","claim":"They had the photo and delivery day. Those are things only a friend could know, right?","correct":"post","options":["joke","route","post","signal"],"hint":"Check where those details were visible before the messages arrived.","smug":"That doesn't establish who could see the photo and date.","result":"Amani: Both were on the public post. My name and photo were copied onto a different contact.\nDan: Including the reminder I posted. That makes it available, not evidence against me.\nSir Rham: Correct. Familiar details do not authenticate a sender.","flash":"CH3 / Amani warned the club through the established conversation.","art":"story_bg_club_corridor_afternoon","voices":[{"who":"John","text":"The new contact looked like Amani."},{"who":"Amani","text":"My original conversation was still there."},{"who":"Sir Rham","text":"Explain the copied details without guessing an identity."}]},
 {"title":"Call their recovery number.","speaker":"John","weak":"their number could verify it","claim":"The warning supplied a recovery contact. Calling their number could verify it and fix the signal, couldn't it?","correct":"route","options":["signal","joke","order","route"],"hint":"An independent verifier is not selected by the suspicious message.","smug":"That observation doesn't make the supplied contact independent.","result":"Amani: Their contact would just verify their own story. I opened my wallet and carrier support separately.\nJohn: And a wallet code was not evidence of a cellular repair.\nSir Rham: We still don't know why the signal dropped. Keep the confirmed facts separate.","flash":"CH4 / Amani preserved the messages in case LB-204 without sharing a code.","art":"story_bg_event_room_day","voices":[{"who":"Amani","text":"The story changed from a parcel to account recovery."},{"who":"Dan","text":"And suddenly everything had to happen right now."},{"who":"Sir Rham","text":"Pressure is a reason to pause and verify independently."}]}
]
const ADMISSION: Array[String] = ["Amani: The message said cancel. The code said authorize. The verified case confirms that rejecting the request did not grant access.","Sir Rham: That resolves this attempt. It does not identify the operator or certify every account as safe.","John: Rebuild the sequence. Show where each new request tried to borrow trust from the last one."]
const COMIC: Array[Dictionary] = [
 {"id":"delivery","title":"01 / The small fee","art":"story_bg_event_room_day","narration":"Amani: A delivery text asked for a small extra fee. I opened the original order and found it already paid."},
 {"id":"code","title":"02 / An unrequested code","art":"story_bg_event_room_day","narration":"Amani: A genuine wallet code arrived for a new device. The other sender called it cancellation. I rejected the request without sharing the code."},
 {"id":"identity","title":"03 / A copied identity","art":"story_bg_club_corridor_afternoon","narration":"Amani: Someone copied my photo and public delivery details. I warned the club through our established conversation. Familiar information did not identify the sender."},
 {"id":"recovery","title":"04 / Recovery pressure","art":"story_bg_event_room_day","narration":"Amani: The next warning demanded the wallet code to fix cellular service. Its own contact could not independently verify that story."},
 {"id":"support","title":"05 / The independent check","art":"story_bg_event_room_day","narration":"Amani: I used my existing wallet and carrier apps. The wallet case confirmed the rejected request did not authorize access. The signal issue remained unexplained."},
 {"id":"hearing","title":"06 / Keep the code","art":"story_bg_event_room_day","narration":"Amani: We challenged the claims using the records. The message knew something about me. That did not mean it was speaking for me."},
 {"id":"dan","title":"Dan must be the sender","art":"story_bg_club_corridor_afternoon","narration":"Unsupported. Posting public details does not identify the operator."},
 {"id":"safe","title":"Every account is safe","art":"story_bg_event_room_day","narration":"Unsupported. The response confirms the outcome of one rejected request."}
]
const COMIC_ORDER: Array[String] = ["delivery","code","identity","recovery","support","hearing"]
const AFTERMATH: Array[String] = ["John: You checked without handing the check back to the person who sent it.","Amani: Great. Now let's investigate who ordered twenty name tags for a nineteen-person activity.","Sir Rham: Preserve the messages, report the suspicious contact, and review unfamiliar signed-in devices.","AUDIENCE ONLY: Elsewhere, the text operator speaks into the masked meeting: ‘No code. They've reported the contact.’", "The Collector: Then stop texting. One connection closes. Jobert's connection stays dark. Two remain."]
static func exhibit(id: String) -> Dictionary:
	for item: Dictionary in EXHIBITS:
		if item.id == id: return item
	return {}
static func frame(id: String) -> Dictionary:
	for item: Dictionary in COMIC:
		if item.id == id: return item
	return {}
static func fresh() -> Dictionary:
	return Hearing.fresh_hearing(EXHIBITS)
static func clean(raw: Dictionary) -> Dictionary:
	var state: Dictionary = Hearing.clean_hearing(raw, {"id":ID,"suspects":SUSPECTS,"correct":THEORY_CORRECT,"exhibits":EXHIBITS,"admission":ADMISSION,"aftermath":AFTERMATH,"comic":COMIC,"order":COMIC_ORDER})

	# Retain the earlier compact review without pretending it was a debate run.
	var legacy_source: Variant = raw.get("legacy_review",raw if raw.has("read") else {})
	if legacy_source is Dictionary and not legacy_source.is_empty():
		var legacy: Dictionary = {"read":[],"flags":[],"domains":[],"captures":[],"sorted":[],"sealed":false,"completed":false}
		var preceding: bool = true
		for field: String in ["read","flags","domains","captures"]:
			var values: Variant = legacy_source.get(field,[])
			preceding = preceding and values is Array and values.has("case")
			if preceding: legacy[field] = ["case"]
		var order: Array[String] = ["delivery","code","identity","recovery"]
		var saved: Variant = legacy_source.get("sorted",[])
		if preceding and saved is Array:
			for id: String in order:
				if saved.size() <= legacy.sorted.size() or saved[legacy.sorted.size()] != id: break
				legacy.sorted.append(id)
		legacy.sealed = legacy_source.get("sealed",false) == true and legacy.sorted == order
		legacy.completed = legacy_source.get("completed",false) == true and legacy.sealed
		legacy.reward = Hearing.integer(legacy_source,"reward",100,125) if legacy.completed else 0
		state["legacy_review"] = legacy
		if legacy.completed and not state.completed:
			state.completed = true
			state.sealed = true
			state.phase = "done"
			state.reward = legacy.reward
	return state
