extends RefCounted
## Module 3 content for the shared hearing; call provenance stays with original saves.
const Hearing: GDScript = preload("res://src/gameplay/decision/confrontation_chapter.gd")
const PriorCall: GDScript = preload("res://src/gameplay/decision/dont_hang_up_chapter.gd")
const ID: String = "mod_03_ch_05"
const NUMBER: int = 5
const TITLE: String = "The Voice Loses Control"
const HEARING: bool = true
const THEORY_CORRECT: String = "Share reset code"
const SUSPECTS: Array[String] = ["Eric's call", "Share reset code", "Public post", "Hang up"]
const NAME_HINTS: Array[String] = ["Which action gives a stranger something private?", "Read the purpose printed on the wallet alert.", "A password-reset code is not a payment-cancellation tool."]
const PRESENTATION: Dictionary = {
 "protagonist":"Liza", "module_index":2, "cast":["Liza","Sir Rham","John","Eric"],
 "backdrop":"story_bg_mod3_quiet_study_room_v1", "counter_art":"module3_liza_counter_signal_v1", "effect_style":"voice_signal", "resolution_art":"story_bg_mod3_quiet_study_room_v1", "aftermath_art":"story_bg_mod3_quiet_study_room_v1",
 "theory_title":"WHERE IS THE TRAP?", "theory_caption":"FOUR LEADS. ONE UNSAFE REQUEST.", "theory_prompt":"CHOOSE THE UNSAFE REQUEST", "theory_instruction":"Follow the records. The caller's identity is unknown.", "theory_action":"CHALLENGE ", "theory_empty":"SELECT A LEAD",
 "final_title":"FINAL CONTRADICTION / PROTECTION OR PRESSURE?", "final_typing":"Reviewing the claim and its source...",
 "final_text":"REVIEW EXAMPLE / Sharing a reset code is necessary to [color=#FFB648]keep protection active[/color].",
 "final_exhibits":["call","support"], "final_match":"MATCH THE CLAIM / CHECK THE OUTCOME", "final_frozen":"COMPARE WITH THE INDEPENDENT SERVICE RESPONSE",
 "comic_success":"Six moments. Received evidence stays separate from review examples.", "comic_hint":"Helpful call, public details, reset alert, refusal, independent support, then the evidence review. Eric's call does not identify the operator.",
 "recap":"A caller used a security label and familiar details to claim authority. The wallet alert described a password reset. Liza kept the code private and independently contacted Support. The attempted reset was not completed; the operator remains unidentified.",
 "cutaway_step":3, "lights":3, "lights_caption":"Audience only / Jobert and the text operator remain disconnected. The voice operator leaves. One connection remains.",
 "practice_module":"mod_03", "practice_label":"PRACTICE VISHING", "availability":"After completing Module 4's first lesson, open its school-coordinator story in Deploy."
}
const BRIEFING: String = "LATER THAT AFTERNOON / THE QUIET STUDY ROOM\n\nLiza joins the club's video review. Sir Rham chairs; John and Eric join her.\nEric: ‘For the record, my expense call was about receipt totals.’\nLiza: ‘The only thing those totals took over was my afternoon.’\n\nSir Rham: ‘The acknowledgement in the wallet Support case Liza opened independently confirms: we recorded the incident; this password reset was not completed. We did not request that call or ask you to share the reset code. Review unfamiliar account activity.’\n\nThis is a newly reviewed service record, not a new message from the caller. It confirms this attempt's outcome, not every account's safety.\n\nWe will test possible explanations. The students voicing claims are not being accused. Load evidence, then tap an orange claim. HOLD pauses the discussion."
const EXHIBITS: Array[Dictionary] = [
 {"id":"identity","title":"Label versus verified identity","source":"CH1 + CH4 / Independent comparison","detail":"Account Security was a displayed caller label, not verified identity. The wallet Support route Liza opened herself says it did not request the call or ask for her reset code. A professional voice cannot replace that check.","art":"story_bg_mod3_covered_walkway_v1","mark":"?"},
 {"id":"post","title":"Public role and event date","source":"CH2 / Public club announcement","detail":"Liza's name, expense role and event date were visible on the public post before the voicemail. They were available to copy. This does not prove where the caller obtained them, or identify the author of the post as the caller.","art":"story_bg_mod3_library_research_v1","mark":"@"},
 {"id":"purpose","title":"Reset password, not payment","source":"CH3 / Wallet alert + review","detail":"The genuine wallet alert states password reset and says never to share the code. A claim about stopping a payment describes a different action. The hearing distinguishes received call statements from labeled review examples.","art":"story_bg_mod3_rain_courtyard_v1","mark":"#"},
 {"id":"route","title":"Two names, one source","source":"CH4 / Contact provenance","detail":"The supposed supervisor supplied a number inside the same suspicious conversation. Liza instead opened her existing wallet app and found Support / Contact us there. The supplied number cannot independently authenticate its own source.","art":"story_bg_mod3_quiet_study_room_v1","mark":"↗"},
 {"id":"call","title":"Received call notes","source":"CH3 / Original saved history","detail":"Only statements actually received belong in the transcript. Liza ended or declined the call without sharing a code. Missing statements remain review examples, never saved quotes.","art":"story_bg_mod3_rain_courtyard_v1","mark":"☎"},
 {"id":"support","title":"Verified incident acknowledgement","source":"NEW / Independent service case","detail":"The wallet service acknowledges the incident Liza reported through its independently opened Support route. It did not request that call or ask for the code. This password reset was not completed. Review unfamiliar account activity. Ending the call did not authorize that reset; this does not certify every account as safe.","art":"story_bg_mod3_quiet_study_room_v1","mark":"✓"},
 {"id":"expense","title":"Eric's call","source":"CH1 / Context, not attribution","detail":"Eric called earlier about club expenses. Being another caller that day does not connect him to the security impersonation. Neither timing nor a familiar voice establishes who controlled the suspicious contact.","art":"story_bg_mod3_briefing_classroom_v1","mark":"?"}
]
const ROUNDS: Array[Dictionary] = [
 {"title":"They sounded professional.","speaker":"Eric","weak":"verify the caller","claim":"Testing the explanation: a security label and a professional voice verify the caller. Right?","correct":"identity","options":["expense","identity","post","purpose"],"hint":"Compare the displayed label with the independently contacted service.","smug":"That record doesn't verify who was speaking for the wallet service.","result":"Liza: A name on my screen was a claim. Support, reached through my own app, says it did not request the call.\nEric: Professional delivery. Unverified identity.\nSir Rham: Exactly. Confidence is not a credential.","flash":"CH1 / The displayed Account Security label was never independent verification.","art":"story_bg_mod3_covered_walkway_v1","voices":[{"who":"Eric","text":"I can sound very official when asking for a receipt."},{"who":"Liza","text":"Your missing receipt is still not a security department."},{"who":"Sir Rham","text":"Test the label against a source the caller did not choose."}]},
 {"title":"They knew her role.","speaker":"John","weak":"only someone authorized","claim":"They knew Liza's role and the event date. Surely only someone authorized could know those?","correct":"post","options":["route","expense","post","call"],"hint":"Where were the name, role and event date already visible?","smug":"That doesn't establish whether those details were private.","result":"Liza: They were on our public club post. Knowing them doesn't grant access to my wallet.\nJohn: A possible source, not proof of who copied it.\nSir Rham: And not evidence against the person who published the announcement.","flash":"CH2 / The public announcement preceded the voicemail.","art":"story_bg_mod3_library_research_v1","voices":[{"who":"Liza","text":"My name, expense role, and event date."},{"who":"Eric","text":"That sounds specific."},{"who":"Sir Rham","text":"Specific and private are different questions."}]},
 {"title":"The code stops a payment.","speaker":"Eric","weak":"needed to stop a payment","claim":"Let's test the review claim: the password-reset code was needed to stop a payment.","correct":"purpose","options":["expense","route","purpose","post"],"hint":"Read the action named by the wallet alert. Compare it with the payment claim.","smug":"We need the record describing what the code actually authorizes.","result":"Liza: The alert says reset password. It does not say cancel payment. I kept the code private.\nEric: A real alert can still be paired with a false explanation.\nSir Rham: Use only received statements as call evidence. Review examples teach the comparison without rewriting the transcript.","flash":"CH3 / The actual wallet alert names a password reset, not payment cancellation.","art":"story_bg_mod3_rain_courtyard_v1","voices":[{"who":"John","text":"First, read the alert's own wording."},{"who":"Liza","text":"Password reset. I didn't request it."},{"who":"Sir Rham","text":"Now test the payment explanation against that purpose."}]},
 {"title":"A supervisor can verify it.","speaker":"John","weak":"an independent check","claim":"The message gives a supervisor's number. A second person means an independent check, doesn't it?","correct":"route","options":["expense","post","identity","route"],"hint":"Who selected that contact? Compare it with the route through the existing wallet app.","smug":"That does not make a contact supplied by the message independent.","result":"Liza: Two names from the same source are still one source. I opened Support in my wallet app.\nJohn: The message didn't get to choose its own verifier.\nSir Rham: Keep the message, the independent response, and the received call notes together.","flash":"CH4 / Liza independently opened her existing wallet app, then Support and Contact us.","art":"story_bg_mod3_quiet_study_room_v1","voices":[{"who":"Eric","text":"The caller had a supervisor remarkably quickly."},{"who":"Liza","text":"An echo with a promotion."},{"who":"Sir Rham","text":"A new title does not create a new source."}]}
]
const ADMISSION: Array[String] = ["Liza: I ended the call without sharing the code. The independently contacted service confirms this reset was not completed.","Sir Rham: That supports refusing the request. It does not identify the caller or guarantee every account is safe.","John: Rebuild the sequence. Keep what happened separate from what someone wanted us to believe."]
const COMIC: Array[Dictionary] = [
 {"id":"helpful","title":"01 / A helpful voice","art":"story_bg_mod3_covered_walkway_v1","narration":"Liza: A new call displayed Account Security. A displayed label was not proof of who was calling."},
 {"id":"public","title":"02 / Familiar details","art":"story_bg_mod3_library_research_v1","narration":"Liza: A voicemail cited my role and the event date. Those details were already public; knowledge was not authorization."},
 {"id":"alert","title":"03 / Read the actual purpose","art":"story_bg_mod3_rain_courtyard_v1","narration":"Liza: My wallet showed a password-reset alert I had not requested. A payment explanation could not change the code's stated purpose."},
 {"id":"refusal","title":"04 / Hang up","art":"story_bg_mod3_rain_courtyard_v1","narration":"Liza: The call ended without my code being shared. Only received statements stayed in the call notes."},
 {"id":"support","title":"05 / Choose the verifier","art":"story_bg_mod3_quiet_study_room_v1","narration":"Liza: I used Support inside my existing wallet app. The service confirmed this reset was not completed and recommended reviewing unfamiliar activity."},
 {"id":"review","title":"06 / The voice loses control","art":"story_bg_mod3_quiet_study_room_v1","narration":"Liza: We compared the records without guessing a culprit. A convincing voice did not get to decide whom I trusted."},
 {"id":"eric","title":"Eric was another caller","art":"story_bg_mod3_briefing_classroom_v1","narration":"Unsupported. An expense call does not connect Eric to the impersonation."},
 {"id":"all_safe","title":"Every account is safe","art":"story_bg_mod3_quiet_study_room_v1","narration":"Unsupported. The service confirmed the outcome of this reset, not every account's safety."}
]
const COMIC_ORDER: Array[String] = ["helpful","public","alert","refusal","support","review"]
const AFTERMATH: Array[String] = ["Eric: My next expense call will begin with a receipt photo.\nLiza: A bold new verification method: actually having the receipt.","John: You didn't have to win an argument with the caller. You could leave it.","Sir Rham: Preserve the contact and report the incident. Review unfamiliar activity through the service. We do not have a verified identity for the operator.","AUDIENCE ONLY: Elsewhere, the voice operator speaks into the masked meeting: ‘She hung up. Used the service's own contact.’", "The voice operator disconnects. Jobert and the text operator remain dark. One connection remains.\nThe Collector: ‘Then give them someone they expect to trust.’"]

static func exhibit(id: String) -> Dictionary:
	for item: Dictionary in EXHIBITS:
		if item.id == id: return item
	return {}

static func frame(id: String) -> Dictionary:
	for item: Dictionary in COMIC:
		if item.id == id: return item
	return {}

static func hearing_context(original_progress: Dictionary) -> Dictionary:
	var prior: Dictionary = PriorCall.clean(original_progress.get(PriorCall.ID, {}))
	var received: int = int(prior.get("call_received", 0))
	var notes: PackedStringArray = ["CHAPTER 3 / ORIGINAL CALL NOTES"]
	if received == 0:
		notes.append("Call declined. No caller statements received. No transcript is attached.")
	else:
		for index: int in received: notes.append("Caller: " + PriorCall.CALL_LINES[index])
		if received < PriorCall.CALL_LINES.size(): notes.append("Call ended before the next statement.")
	notes.append("Call ended. No code was shared. Review examples are not call evidence.")
	var call: Dictionary = exhibit("call").duplicate(true)
	call.detail = "\n\n".join(notes)
	var purpose: Dictionary = exhibit("purpose").duplicate(true)
	purpose.detail = "Wallet alert: reset password. Never share the code.\n\n" + ("Received call statement: " + PriorCall.CALL_LINES[0] if received > 0 else "REVIEW EXAMPLE, NOT RECEIVED CALL EVIDENCE: a requester says the code will stop a payment. Liza declined this call, so this example is not a transcript.")
	var final_text: String = "SAVED CALL STATEMENT / Don't hang up - we'll [color=#FFB648]lose the protection session[/color]." if received > 0 else "REVIEW EXAMPLE / Don't hang up - we'll [color=#FFB648]lose the protection session[/color].\nLiza declined this call. These words were not received; test the example against the verified outcome."
	return {"briefing":BRIEFING + "\n\n" + str(call.detail), "final_text":final_text, "exhibits":{"call":call,"purpose":purpose}}

static func fresh() -> Dictionary:
	return Hearing.fresh_hearing(EXHIBITS)

static func clean(raw: Dictionary) -> Dictionary:
	return Hearing.clean_hearing(raw, {"id":ID,"suspects":SUSPECTS,"correct":THEORY_CORRECT,"exhibits":EXHIBITS,"admission":ADMISSION,"aftermath":AFTERMATH,"comic":COMIC,"order":COMIC_ORDER})
