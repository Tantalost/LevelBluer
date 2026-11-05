extends RefCounted
## Editorial field notes plus live combat rules. No duplicate damage tables.
const Survey: GDScript = preload("res://src/gameplay/decision/survey_chapter.gd")
const Advisor: GDScript = preload("res://src/gameplay/decision/advisor_chapter.gd")
const Payout: GDScript = preload("res://src/gameplay/decision/payout_chapter.gd")
const Prize: GDScript = preload("res://src/gameplay/decision/prize_chapter.gd")
const Hearing: GDScript = preload("res://src/gameplay/decision/confrontation_chapter.gd")
const Delivery: GDScript = preload("res://src/gameplay/decision/delivery_chapter.gd")
const WalletCode: GDScript = preload("res://src/gameplay/decision/wallet_code_chapter.gd")
const FamiliarName: GDScript = preload("res://src/gameplay/decision/familiar_name_chapter.gd")
const RecoveryPressure: GDScript = preload("res://src/gameplay/decision/recovery_pressure_chapter.gd")
const KeepCode: GDScript = preload("res://src/gameplay/decision/keep_code_chapter.gd")
const HelpfulCaller: GDScript = preload("res://src/gameplay/decision/helpful_caller_chapter.gd")
const KnownDetails: GDScript = preload("res://src/gameplay/decision/known_details_chapter.gd")
const DontHangUp: GDScript = preload("res://src/gameplay/decision/dont_hang_up_chapter.gd")
const SafeCallback: GDScript = preload("res://src/gameplay/decision/safe_callback_chapter.gd")
const VoiceControl: GDScript = preload("res://src/gameplay/decision/voice_control_chapter.gd")
const HereToHelp: GDScript = preload("res://src/gameplay/decision/here_to_help_chapter.gd")
const ConsistentStory: GDScript = preload("res://src/gameplay/decision/consistent_story_chapter.gd")
const ExceptionChapter: GDScript = preload("res://src/gameplay/decision/exception_chapter.gd")
const RealOffice: GDScript = preload("res://src/gameplay/decision/real_office_chapter.gd")
const Gift: GDScript = preload("res://src/gameplay/decision/gift_for_club_chapter.gd")
const PreviewHelper: GDScript = preload("res://src/gameplay/decision/just_open_it_chapter.gd")
const EveryoneHasIt: GDScript = preload("res://src/gameplay/decision/everyone_has_it_chapter.gd")
const FourConnections: GDScript = preload("res://src/gameplay/decision/four_connections_chapter.gd")
const CONNECTION_OBSERVATIONS: Array[Dictionary] = [
 {"id":"m5_report_source","title":"An independently reached support case","people":["mika","rham"],"field":"flags","value":"connections","status":"Known","source":"Module 5 / Existing school directory and support case","text":"Sir Rham opens the delivery review through the established School Office and support case. The suspicious sender did not supply this route."},
 {"id":"m5_delivery_pair","title":"Two corroborated deliveries","people":["mika","rham"],"field":"domains","value":"connections","status":"Known","source":"Module 5 / Service export and preserved messages","text":"The service export supplies DL-041 for the coordinator's contact-list request and DL-052 for the event-pack offer. Their excerpts match the preserved originals. The independent review corroborates a connection between these two deliveries."},
 {"id":"m5_attribution_limit","title":"The directing account is still withheld","people":["mika","rham"],"field":"captures","value":"connections","status":"Known","source":"Module 5 / Saved case note","text":"Mika keeps the report and both originals together while preserving the earlier case outcomes separately. The directing-account field is withheld pending verification. This report alone does not identify who directed the wider campaign. Her hearing question is: Who directed the switch?"}
]
const ENDORSEMENT_OBSERVATIONS: Array[Dictionary] = [
 {"id":"m5_crop","title":"The missing banner context","people":["mika","amani"],"field":"flags","value":"endorsement","status":"Known","source":"Module 5 / Supplied crop and existing club chat","text":"Event Recovery Desk supplies Amani's words as praise for its event pack. The original club thread places Mika's banner photo and question above the reply. The crop removes this context."},
 {"id":"m5_original_praise","title":"What Amani actually tried","people":["mika","amani"],"field":"domains","value":"endorsement","status":"Known","source":"Module 5 / Amani's club reply","text":"Amani says she followed the hand-painted banner's arrow from the gate. She did not try the download. Her praise does not endorse the package or implicate her in sending the offer."},
 {"id":"m5_safe_warning","title":"Warning without the package","people":["mika","liza"],"field":"captures","value":"endorsement","status":"Known","source":"Module 5 / Preserved records and club warning","text":"Mika keeps the crop and original with their sources, explains the installation request and points classmates to the pinned club folder. The package remains closed and is not forwarded."}
]
const PREVIEW_OBSERVATIONS: Array[Dictionary] = [
 {"id":"m5_helper_source","title":"Design desk reply","people":["mika"],"field":"flags","value":"helper","status":"Known","source":"Module 5 / Pinned contact and offer thread","text":"The Student Design Desk says its signs are in the club folder and denies sending a helper. The separate Event Recovery Desk conversation asks Mika to install one."},
 {"id":"m5_helper_type","title":"A poster preview on an app package","people":["mika","john"],"field":"domains","value":"helper","status":"Known","source":"Module 5 / Attachment details","text":"The thumbnail depicts an event poster. EventPreview.apk is an Android app package. The sender asks Mika to allow installation from this source."},
 {"id":"m5_helper_saved","title":"Package kept closed","people":["mika"],"field":"captures","value":"helper","status":"Known","source":"Module 5 / Preserved records","text":"Mika saved the message, file details and independent desk reply. She kept installation disabled and the package closed."}
]
const GIFT_OBSERVATIONS: Array[Dictionary] = [
 {"id":"m5_offer","title":"A pack the club needs","people":["mika","john"],"field":"flags","value":"gift","status":"Known","source":"Module 5 / Event pack offer","text":"The incoming message offers finished signs and table numbers. Event Recovery Desk is its displayed name. The supplier role is a claim."},
 {"id":"m5_sources","title":"The club's own materials plan","people":["mika"],"field":"domains","value":"gift","status":"Known","source":"Module 5 / Pinned club plan","text":"The existing chat assigns event artwork to the Student Design Desk through the club folder. The offer arrived in a separate conversation."},
 {"id":"m5_contact","title":"Checked through the pinned contact","people":["mika"],"field":"captures","value":"gift","status":"Known","source":"Module 5 / Design desk inquiry","text":"Mika preserved the offer and contacted the design desk independently. The pack stays unopened while she awaits a reply."}
]
const MaskHolds: GDScript = preload("res://src/gameplay/decision/mask_holds_chapter.gd")
const MASK_HOLDS_OBSERVATIONS: Array[Dictionary] = [
 {"id":"m4_hearing_schedule","title":"A matching time is not an appointment","people":["rham","john","liza"],"field":"solved","value":0,"status":"Known","source":"Module 4 / Hearing / Schedule comparison","text":"The school's corrected schedule described an internal meeting, not the supplied external appointment. The ordinary time correction does not implicate its author."},
 {"id":"m4_hearing_sources","title":"Count independent sources","people":["rham","liza","mika"],"field":"solved","value":1,"status":"Known","source":"Module 4 / Hearing / Document sources","text":"The matching profile, email and invitation repeated one unverified source. Agreement between supplied records did not independently confirm authority."},
 {"id":"m4_hearing_exception","title":"Urgency did not establish permission","people":["rham","mika"],"field":"solved","value":2,"status":"Known","source":"Module 4 / Hearing / Request and approval notice","text":"The emergency claim did not establish the documented approval required by this fictional school's notice. The student roster stayed restricted; no partial list was sent."},
 {"id":"m4_hearing_denial","title":"An independent answer","people":["rham","john","liza"],"field":"solved","value":3,"status":"Known","source":"Module 4 / Hearing / Established School Office","text":"The office reached through the existing school directory explicitly denied the assignment and requested authorization. This goes beyond the schedule discrepancy but does not identify the operator."},
 {"id":"m4_hearing_outcome","title":"False authority, no disclosure","people":["rham","john","liza","mika"],"field":"final_matched","status":"Known","source":"Module 4 / Hearing / Final comparison and acknowledgement","text":"Already approved was the requester's claim. No assignment and no approval came from the independently contacted office. The school acknowledged the report, restricted the fraudulent contact and shared guidance. No roster was disclosed; the investigation remains open."}
]
const OFFICE_OBSERVATIONS: Array[Dictionary] = [
 {"id":"m4_office_route","title":"An independently chosen office","people":["rham"],"field":"flags","value":"office","status":"Known","source":"Module 4 / Chapter 4 / Existing school directory","text":"Sir Rham follows his existing school directory to the established School Office entry and its response. The coordinator did not supply this route. He asks about both the external assignment and authorization for student contacts."},
 {"id":"m4_office_denial","title":"No assignment, no approval","people":["rham"],"field":"domains","value":"office","status":"Known","source":"Module 4 / Chapter 4 / Independent office response","text":"The office explicitly denies assigning an external coordinator to this club case and approving this request for student contacts. The internal event meeting was separate. This contradicts the claims in this case; it does not identify the operator or guarantee every school system is safe."},
 {"id":"m4_case_record","title":"Messages preserved, roster excluded","people":["rham"],"field":"captures","value":"office","status":"Known","source":"Module 4 / Chapter 4 / Saved case record","text":"The supplied appointment and private request are kept beside the independent office response, with their sources intact. No student roster or unsupported culprit accusation is included. No student contacts were disclosed."}
]
const EXCEPTION_OBSERVATIONS: Array[Dictionary] = [
 {"id":"m4_roster_request","title":"Data and channel need permission","people":["rham"],"field":"flags","value":"exception","status":"Known","source":"Module 4 / Chapter 3 / Request and school notice","text":"The sender asks for student names, sections and contact numbers through a private conversation. The fictional school's displayed notice requires independently confirmed approval identifying recipient, purpose, fields and channel. No such approval for this request is in the record."},
 {"id":"m4_exception_claim","title":"A claimed emergency exception","people":["rham"],"field":"domains","value":"exception","status":"Unverified","source":"Module 4 / Chapter 3 / Emergency claim","text":"Emergency clearance is already approved is the unverified sender's statement. Independently confirmed, documented approval is missing. The School Office has not yet answered; this finding is not an office denial or an identification of the sender."},
 {"id":"m4_restricted_list","title":"The list stays restricted","people":["rham"],"field":"captures","value":"exception","status":"Known","source":"Module 4 / Chapter 3 / Independent route","text":"Sir Rham chooses the established School Office entry in his existing directory to ask about both the appointment and permission. No list, partial list or student contact is disclosed. The office response remains pending."}
]
const CONSISTENT_STORY_OBSERVATIONS: Array[Dictionary] = [
 {"id":"m4_shared_source","title":"Three records, one supplier","people":["rham","john"],"field":"flags","value":"sources","status":"Unverified","source":"Module 4 / Chapter 2 / Source comparison","text":"The profile, email copy and invitation all came from the same unverified sender. Matching claims and school branding do not independently confirm the coordinator's role."},
 {"id":"m4_expanded_request","title":"More than an acknowledgement","people":["rham"],"field":"domains","value":"sources","status":"Known","source":"Module 4 / Chapter 2 / Actual request","text":"The sender requests student names, sections and contact numbers for protective follow-up. A helpful purpose and matching documents do not establish authority to receive this list. No list is sent."},
 {"id":"m4_notice_limits","title":"A correction with limited meaning","people":["rham","john"],"field":"captures","value":"sources","status":"Known","source":"Module 4 / Chapter 2 / Independent school notice","text":"The independently opened school notice corrects an internal event meeting from 10:30 to 11:00. It neither appoints the external coordinator nor authorizes disclosure. The correction does not implicate its staff author."}
]
const APPOINTMENT_OBSERVATIONS: Array[Dictionary] = [
 {"id":"m4_claims","title":"Branding is observable, authority is not confirmed","people":["rham","john"],"field":"flags","value":"appointment","status":"Unverified","source":"Module 4 / Chapter 1 / Identity review","text":"The message displays school branding and claims an incident-response role and approval. These claims have not been independently confirmed."},
 {"id":"m4_schedule","title":"The appointment is not confirmed by the schedule","people":["rham"],"field":"domains","value":"appointment","status":"Known","source":"Module 4 / Chapter 1 / Independent schedule","text":"The supplied appointment proposes an external consultation. The existing school schedule lists an internal event meeting at the same time. This discrepancy needs clarification; it does not alone prove fraud."},
 {"id":"m4_route","title":"Choose the verifier independently","people":["rham"],"field":"captures","value":"appointment","status":"Known","source":"Module 4 / Chapter 1 / Existing school directory","text":"Sir Rham selects the established School Office contact through his existing directory. No office response has been received and no student list has been shared."}
]
const VOICE_CONTROL_OBSERVATIONS: Array[Dictionary] = [
 {"id":"m3_hearing_identity","title":"A label is not verification","people":["liza","eric","rham"],"field":"solved","value":0,"status":"Known","source":"Module 3 / Hearing / Identity comparison","text":"The independently contacted wallet service contradicts the claimed security role. A displayed label and a professional voice do not authenticate the caller. Eric's expense call is not attribution evidence."},
 {"id":"m3_hearing_public","title":"Public knowledge grants no access","people":["liza","john"],"field":"solved","value":1,"status":"Known","source":"Module 3 / Hearing / Public information","text":"Liza's role and event date were already public. They could be copied; this does not identify the operator or establish where the details were actually obtained."},
 {"id":"m3_hearing_purpose","title":"Read the code's purpose","people":["liza","eric"],"field":"solved","value":2,"status":"Known","source":"Module 3 / Hearing / Alert comparison","text":"The wallet alert describes a password reset, not payment cancellation. Received call statements remain separate from review examples when the original call was declined or ended early."},
 {"id":"m3_hearing_route","title":"Choose an independent verifier","people":["liza","john","rham"],"field":"solved","value":3,"status":"Known","source":"Module 3 / Hearing / Contact source","text":"A supervisor number supplied by the suspicious conversation cannot independently verify it. Liza opens Support in her existing wallet app."},
 {"id":"m3_hearing_outcome","title":"This reset was not completed","people":["liza","rham"],"field":"final_matched","status":"Known","source":"Module 3 / Hearing / Verified incident acknowledgement","text":"The independent service case confirms this reset was not completed. Liza ended the call without sharing her code. This outcome does not identify the caller or guarantee that every account is safe; unfamiliar activity still needs review."}
]
const CALLBACK_OBSERVATIONS: Array[Dictionary] = [
 {"id":"m3_callback_source","title":"A contact chosen independently","people":["liza","john"],"field":"flags","value":"callback","status":"Known","source":"Module 3 / Chapter 4 / Contact source","text":"The supposed supervisor supplies a callback contact in the same suspicious conversation. Liza instead opens her existing wallet app, then Support and Contact us. A second name from the same source is not independent verification."},
 {"id":"m3_service_reply","title":"The service contradicts the claim","people":["liza"],"field":"domains","value":"callback","status":"Known","source":"Module 3 / Chapter 4 / Independent support response","text":"Independently reached wallet Support says it did not request the call or ask Liza to share a reset code. This password reset was not completed. Support recommends reviewing account activity; it does not guarantee every account is safe or identify the caller."},
 {"id":"m3_incident","title":"An incident record with sources","people":["liza"],"field":"captures","value":"callback","status":"Known","source":"Module 3 / Chapter 4 / Simulated incident record","text":"Liza includes the supervisor message and support response, and attaches the wallet alert and actual saved Chapter 3 call notes. A declined call has no transcript; missing statements remain review guidance. No code is attached. The supervisor name and callback contact remain unverified."}
]
const HANG_UP_OBSERVATIONS: Array[Dictionary] = [
 {"id":"m3_reset","title":"The code resets a password","people":["liza"],"field":"flags","value":"call","status":"Known","source":"Module 3 / Chapter 3 / Wallet alert","text":"The wallet alert describes a password reset Liza did not request. Its code is not a payment-cancellation code. A genuine alert does not verify a separate caller."},
 {"id":"m3_conflict","title":"Different instructions","people":["liza"],"field":"domains","value":"call","status":"Known","source":"Module 3 / Chapter 3 / Call comparison","text":"Liza compares the received request to read a code to stop a payment against the alert stating reset password. These are different actions. The caller discourages hanging up and independent verification."},
 {"id":"m3_refusal","title":"The call ends, the code stays private","people":["liza"],"field":"captures","value":"call","status":"Known","source":"Module 3 / Chapter 3 / Saved record","text":"Liza ends or declines the call without sharing a code. Only received statements and the wallet alert are retained as evidence. Any missed statements remain review guidance. She still needs to verify the reset outcome through the wallet service."}
]
const KNOWN_DETAILS_OBSERVATIONS: Array[Dictionary] = [
 {"id":"m3_public_details","title":"Three details were already public","people":["liza","john"],"field":"flags","value":"public","status":"Known","source":"Module 3 / Chapter 2 / Source comparison","text":"Liza matches her name, event expense role and 6 November event date from a new voicemail to a public club announcement published before the call. These details could be copied; this does not prove the caller actually used this post."},
 {"id":"m3_permission","title":"Knowledge is not authorization","people":["liza"],"field":"domains","value":"public","status":"Unverified","source":"Module 3 / Chapter 2 / Permission claim","text":"The caller claims that knowing event details verifies a security role and justifies account access. Public knowledge establishes neither identity nor permission. Liza does not authorize access."},
 {"id":"m3_comparison","title":"Sources preserved, identity unknown","people":["liza","john"],"field":"captures","value":"public","status":"Known","source":"Module 3 / Chapter 2 / Saved comparison","text":"Liza preserves the new voicemail beside the independently opened club post. This supports a possible public source, not a culprit identity. The author of a public post is not implicated merely because the same details appear in a call."}
]
const CALLER_OBSERVATIONS: Array[Dictionary] = [
 {"id":"m3_claim","title":"Claim versus observation","people":["liza","john"],"field":"flags","value":"call","status":"Known","source":"Module 3 / Chapter 1 / Call review","text":"Liza distinguishes the displayed Account Security label from independently confirmed identity. Receiving a call is observable; its displayed name does not authenticate the caller."},
 {"id":"m3_identity","title":"Identity remains unverified","people":["liza"],"field":"domains","value":"call","status":"Unverified","source":"Module 3 / Chapter 1 / Identity check","text":"The service has not independently confirmed this caller. A professional voice or a reference supplied by the caller would still need checking."},
 {"id":"m3_route","title":"An independent verification route","people":["liza"],"field":"captures","value":"call","status":"Known","source":"Module 3 / Chapter 1 / Verification route","text":"Liza chooses Support in the wallet app she already uses. Choosing this independent route does not yet confirm the caller's identity. No account code was shared."}
]
const CHAPTERS: Array[GDScript] = [Survey, Advisor, Payout, Prize, Hearing, Delivery, WalletCode, FamiliarName, RecoveryPressure, KeepCode, HelpfulCaller, KnownDetails, DontHangUp, SafeCallback, VoiceControl, HereToHelp, ConsistentStory, ExceptionChapter, RealOffice, MaskHolds, Gift, PreviewHelper, EveryoneHasIt, FourConnections]
const KEEP_CODE_OBSERVATIONS: Array[Dictionary] = [
 {"id":"m2_final_fee","title":"A small fee does not verify a recipient","people":["amani"],"field":"solved","value":0,"status":"Known","source":"Module 2 / Chapter 5 / Fee rebuttal","text":"The paid order and unexplained payment destination contradict the harmless-fee claim. The amount does not establish whether the request is legitimate."},
 {"id":"m2_final_code","title":"A real code does not verify its requester","people":["amani","john"],"field":"solved","value":1,"status":"Known","source":"Module 2 / Chapter 5 / Code rebuttal","text":"The code authorized a new device; the sender falsely described cancellation. Support confirms this rejected request did not authorize access, not that every account is safe."},
 {"id":"m2_final_public","title":"Familiar information can be copied","people":["amani","dan"],"field":"solved","value":2,"status":"Known","source":"Module 2 / Chapter 5 / Identity rebuttal","text":"The public post explains how the photo and delivery date could be copied. It does not identify the operator or implicate Dan. Amani verified through established channels and kept the code private."},
 {"id":"m2_final_route","title":"Verify outside the supplied route","people":["amani","john","rham"],"field":"solved","value":3,"status":"Known","source":"Module 2 / Chapter 5 / Recovery rebuttal","text":"A sender-provided contact cannot independently verify that sender. Amani used existing service apps. The wallet response confirms one rejected request; the signal issue remains unexplained."}
]
const RECOVERY_OBSERVATIONS: Array[Dictionary] = [
 {"id":"m2_recovery_sequence","title":"A changing pretext","people":["amani","john"],"field":"flags","value":"recovery","status":"Known","source":"Module 2 / Chapter 4 / Message sequence","text":"The parcel payment request precedes a genuine wallet code, a copied-name payment message and then a mobile recovery warning. The warning asks for the wallet authorization code to fix a different service. This does not identify its sender."},
 {"id":"m2_recovery_route","title":"The warning supplies its own verifier","people":["amani","rham"],"field":"domains","value":"recovery","status":"Known","source":"Module 2 / Chapter 4 / Independent route","text":"The SMS tells Amani to use its supplied recovery number. She instead chooses support through her existing wallet and carrier apps. A sender-selected contact cannot independently verify the sender's own story."},
 {"id":"m2_recovery_case","title":"Messages attached to the support case","people":["amani"],"field":"captures","value":"recovery","status":"Known","source":"Module 2 / Chapter 4 / Support responses","text":"Wallet support says to keep the device code private and retain case LB-204 in the app. Carrier help treats the signal issue separately; no technical cause has been established. Amani attaches the messages to the simulated wallet case without sharing a code."}
]
const FAMILIAR_OBSERVATIONS: Array[Dictionary] = [
 {"id":"m2_public","title":"Copied public details","people":["amani","dan"],"field":"flags","value":"identity","status":"Known","source":"Module 2 / Chapter 3 / Public post","text":"Amani matches the photo and delivery-day detail to the public event post. Dan posted the reminder; knowing this public information does not identify the impersonator."},
 {"id":"m2_contact","title":"A different contact","people":["amani","john"],"field":"domains","value":"identity","status":"Known","source":"Module 2 / Chapter 3 / Established conversation","text":"The payment request comes from a separate contact. Amani's established conversation remains accessible over school Wi-Fi. A copied name and photo do not authenticate the new sender."},
 {"id":"m2_warning","title":"A warning through the club chat","people":["amani","john"],"field":"captures","value":"identity","status":"Known","source":"Module 2 / Chapter 3 / Club warning","text":"Amani denies the payment request in the established club chat. Her cellular signal loss is observed, but its cause remains unknown; it does not prove a SIM swap or device compromise. The sender remains unidentified."}
]
const WALLET_OBSERVATIONS: Array[Dictionary] = [
	{"id":"m2_code_purpose", "title":"A code authorizes a new device", "people":["amani","john"], "field":"flags", "value":"wallet", "status":"Known", "source":"Module 2 / Chapter 2 / Wallet alert", "text":"Amani identifies the genuine alert's stated purpose: authorize a new device. She did not request it. A genuine code does not authenticate the separate sender asking for it."},
	{"id":"m2_cancellation", "title":"An opposite instruction", "people":["amani","john"], "field":"domains", "value":"wallet", "status":"Known", "source":"Module 2 / Chapter 2 / Message comparison", "text":"The unknown delivery sender asks Amani to reply with the code to cancel an attempt. That conflicts with the wallet alert, which says the code authorizes access. The sender also discourages independent verification."},
	{"id":"m2_rejection", "title":"Rejected through the wallet", "people":["amani"], "field":"captures", "value":"wallet", "status":"Known", "source":"Module 2 / Chapter 2 / Independent wallet app", "text":"Amani opens her installed wallet independently, rejects the unfamiliar device request and reports it there. She keeps the code private and preserves both messages. The operator behind the request remains unidentified."}
]
const DELIVERY_OBSERVATIONS: Array[Dictionary] = [
	{"id":"m2_delivery", "title":"An unexpected redelivery fee", "people":["amani"], "field":"read", "value":"parcel", "status":"Known", "source":"Module 2 / Chapter 1 / SMS", "text":"Amani receives an SMS requesting an extra payment. The message supplies no matching order reference. Reading it does not verify its sender."},
	{"id":"m2_destination", "title":"A hidden payment destination", "people":["amani"], "field":"domains", "value":"parcel", "status":"Known", "source":"Module 2 / Chapter 1 / Expanded link", "text":"The saved short link leads to parcel-redelivery.example/pay. A short address alone does not prove fraud; compare the actual request with independently obtained information."},
	{"id":"m2_order", "title":"The order is already paid", "people":["amani","john"], "field":"captures", "value":"parcel", "status":"Known", "source":"Module 2 / Chapter 1 / Independent order", "text":"The order opened through its own app is paid and out for delivery. It requests no redelivery fee. Amani preserves the conflicting message without paying."}
]
const CHARACTER_IDS: Array[String] = ["john", "eric", "jobert"]
const CHARACTERS: Dictionary = {
	"liza": {"name":"Liza", "role":"Student / Club event volunteer", "background":"A student helping with the school club event.", "relationship":"You follow Liza as she checks an unexpected account-security call."},
	"amani": {"name":"Amani", "role":"Student / Event organizer", "background":"A club member preparing materials for the school event.", "relationship":"You follow Amani as she checks an unexpected delivery message."},
	"john": {"name":"John", "role":"Student / Protagonist", "background":"A student whose perspective you follow through the investigation.", "relationship":"You follow John's experiences and investigation."},
	"eric": {"name":"Eric", "role":"Club member", "background":"A member of John's school club.", "relationship":"John's fellow club member."},
	"jobert": {"name":"Jobert", "role":"Club member", "background":"A member of John's school club.", "relationship":"John's fellow club member."},
	"dan": {"name":"Dan", "role":"Club member", "background":"A member of John's school club.", "relationship":"John's fellow club member."},
	"mika": {"name":"Mika", "role":"Club member", "background":"A member of John's school club.", "relationship":"John's fellow club member."},
	"rham": {"name":"Sir Rham", "role":"Club advisor", "background":"The advisor whose identity appears on the club's legitimate emails.", "relationship":"The students' club advisor."}
}
# after_beat means the player has advanced past the entire authored story beat.
# A saved beat points to the CURRENT dialogue, not proof that it has been read.
const OBSERVATIONS: Array[Dictionary] = [
	{"id":"income", "title":"Looking for extra income", "people":["john"], "after_beat":4, "status":"Known", "source":"Chapter 1 / Club chat", "text":"John tells the group he misses coffee and needs a side gig. This is what John shared with the club."},
	{"id":"offer", "title":"The survey opportunity", "people":["john","eric"], "after_beat":4, "status":"Known", "source":"Chapter 1 / Club chat", "text":"Eric introduces a survey job. John asks him to send it over. The conversation establishes the offer, not whether the job is legitimate."},
	{"id":"warning", "title":"Jobert's warning", "people":["john","jobert"], "after_beat":4, "status":"Known", "source":"Chapter 1 / Club chat", "text":"Jobert warns John to be careful with random surveys and offers help if he is unsure. Giving advice does not establish a person's trustworthiness."},
	{"id":"client_claim", "title":"Eric's connection to the client", "people":["john","eric"], "after_beat":5, "status":"Unverified", "source":"Chapter 1 / Eric in the clubroom", "text":"Eric says the work is easy and that he knows the client personally. These are Eric's claims; Chapter 1 does not independently verify them."},
	{"id":"client_identity", "title":"Who is the client?", "people":["john","eric"], "after_beat":7, "status":"Unknown", "source":"Chapter 1 / John's question and Eric's reply", "text":"John asks for the client's name. Eric says he will send the contact and that they use email. He does not give a name in this exchange. The client's identity remains unknown."},
	{"id":"verification", "title":"An offer to check", "people":["john","jobert"], "after_beat":9, "status":"Known", "source":"Chapter 1 / Jobert in the clubroom", "text":"Jobert offers to help John check who is behind the survey. This records his recommendation to verify; it does not mean the survey has been verified."},
	{"id":"pay", "title":"Payment amount withheld", "people":["john"], "read_id":"survey", "status":"Known", "source":"Chapter 1 / Your first survey job", "text":"The message promises rewards but says the payment amount will be given after the work is finished. The promise of payment is unverified."},
	{"id":"pressure", "title":"Pressure to reply", "people":["john"], "read_id":"urgent", "status":"Known", "source":"Chapter 1 / Keep your survey slot", "text":"The message asks for a contact number, sets a ten-minute deadline, and tells John not to ask the school. These requests are visible in the message; the sender's authority is not verified."},
	{"id":"personal_data", "title":"Personal information requested", "people":["john"], "read_id":"profile", "status":"Known", "source":"Chapter 1 / Complete your reward profile", "text":"The message asks for a full birth date and home address and spells receive as 'recieve'. A typo alone does not prove who wrote it or whether they intended harm."}
]

const CHAPTER_OBSERVATIONS: Dictionary = {
	2:[
		{"id":"c2_request", "title":"A familiar name asks for details", "people":["john","rham"], "after_beat":2, "status":"Unverified", "source":"Chapter 2 / New advisor email", "text":"An email using Sir Rham's name asks for personal details within 24 hours and threatens removal from the club. A display name and a deadline do not verify the sender."},
		{"id":"c2_help", "title":"Check the sender first", "people":["john","jobert"], "after_beat":3, "status":"Known", "source":"Chapter 2 / Private conversation", "text":"John asks Jobert before replying. Jobert tells him to inspect the address beneath the sender's name. This records helpful advice, not proof of who sent the email."},
		{"id":"c2_domain", "title":"A digit in the school domain", "people":["john","jobert","rham"], "after_beat":11, "status":"Known", "source":"Chapter 2 / Email comparison", "text":"The new address uses schoo1.example, with digit 1, instead of school.example, with lowercase L. Jobert helps John notice the difference. The lookalike reveals impersonation, not the author's identity."},
		{"id":"c2_dan", "title":"Dan's inbox joke", "people":["john","dan","eric","jobert"], "after_beat":20, "status":"Unverified", "source":"Chapter 2 / Club chat", "text":"Dan jokes about hacking Sir Rham's inbox and says he knows the club's subject format. Knowing a format and joking about an inbox do not establish that he accessed it or sent the message."},
		{"id":"c2_reply", "title":"Replies go to another address", "people":["john","rham"], "field":"headers", "value":"Reply-To", "status":"Known", "source":"Chapter 2 / Header investigation", "text":"From is sir.rham@schoo1.example, while Reply-To is club.records@member-support.example. A reply would go somewhere else. Neither address identifies the person operating it."},
		{"id":"c2_wording", "title":"Generic wording and signature", "people":["john","rham"], "field":"flags", "value":"signature", "status":"Known", "source":"Chapter 2 / Signature comparison", "text":"The new message signs off as Club Administration rather than Sir Rham, Club Advisor. Compare the signature alongside the address and the request; a familiar subject format is not verification."}
	],
	3:[
		{"id":"c3_borrow", "title":"Eric asks to borrow money", "people":["john","eric"], "after_beat":3, "status":"Known", "source":"Chapter 3 / Eric's private chat", "text":"Eric asks to borrow some of the survey payout and promises to repay John. The request does not establish that Eric sent the payout email."},
		{"id":"c3_whisper", "title":"A conversation at the doorway", "people":["john","eric","mika"], "after_beat":7, "status":"Unknown", "source":"Chapter 3 / Outside the clubroom", "text":"John hears Mika ask 'Did you ask him?' and Eric answer 'Yeah. Not yet.' John only hears part of their conversation. Its connection to the emails is unresolved."},
		{"id":"c3_call", "title":"An interruption while typing", "people":["john","jobert"], "after_beat":23, "status":"Known", "source":"Chapter 3 / Jobert's call", "text":"Jobert calls while John is on the fake wallet page and tells him to stop entering information and send a screenshot. John says he started typing a username but did not submit. At this point, John has not verified whether the page captured any input."},
		{"id":"c3_destination", "title":"Link text and destination differ", "people":["john"], "field":"revealed", "value":"payout", "status":"Known", "source":"Chapter 3 / Link inspection", "text":"The displayed wallet link differs from its real destination. The destination is http://pocket-wallet-verify.example/login. Check where a link leads before trusting its label."},
		{"id":"c3_short", "title":"The short link conceals a destination", "people":["john"], "field":"expanded", "value":"payout", "status":"Known", "source":"Chapter 3 / Link expander", "text":"Expanding short.example/payout reveals the same fake wallet destination. A shortened address hides where it leads; shortening alone does not establish who created a link."},
		{"id":"c3_page", "title":"The login page's warning signs", "people":["john"], "field":"reviewed", "status":"Known", "source":"Chapter 3 / Reviewed page inspection", "text":"The page uses an odd domain and HTTP. The missing secure-connection indicator supports the HTTP finding; blurry branding and LOGN IN are supporting clues. Even HTTPS would not prove a page genuine."}
	],
	4:[
		{"id":"c4_morning", "title":"Back in John's room", "people":["john"], "after_beat":2, "status":"Known", "source":"Chapter 4 / The morning from the intro", "text":"John wakes in his room to a prize email. Its promised reward is a claim, not a verified payout. This is the same morning shown in the module introduction."},
		{"id":"c4_silence", "title":"No reply from Jobert", "people":["john","jobert"], "after_beat":5, "status":"Known", "source":"Chapter 4 / Private messages", "text":"John asks whether the prize is legitimate. Jobert appears offline and does not reply. A presence status alone does not show what someone is doing."},
		{"id":"c4_coffee", "title":"The coffee comment was in the group", "people":["john","eric","jobert","dan","mika"], "field":"connections", "value":"coffee|group", "status":"Known", "source":"Chapter 4 / Coffee and group-message connection", "text":"The prize email repeats John's coffee comment from the club chat. The comment was available to the group; it was not a secret known only to Eric. This does not identify who copied it."},
		{"id":"c4_gap", "title":"Ten seconds after last seen", "people":["john","jobert","eric"], "field":"timeline_checked", "value":"prize", "status":"Known", "source":"Chapter 4 / Verified timeline order", "text":"The prize email arrived at 08:14:00, ten seconds after Jobert's last seen and fifteen after Eric's. Arrival time and presence status do not establish the sender or when either person was asleep."},
		{"id":"c4_typo", "title":"The spelling appears again", "people":["john"], "field":"connections", "value":"earlier|typo", "status":"Known", "source":"Chapter 4 / Repeated-wording connection", "text":"The survey and prize emails both spell receive as 'recieve'. The repeated wording supports comparing the messages. A common typo is not a unique fingerprint."},
		{"id":"c4_claim", "title":"John taps the prize button", "people":["john"], "field":"claimed", "status":"Known", "source":"Chapter 4 / Return to that morning", "text":"The reconstruction ends. Still in his room, John taps Claim Prize and the screen glitches. The next chapter continues the confrontation."}
	],
	5:[
		{"id":"c5_briefing", "title":"New records for the hearing", "people":["john","rham","jobert"], "field":"briefed", "status":"Known", "source":"Chapter 5 / Sir Rham's briefing", "text":"The roster lists 20 members with access to the coffee message, not proof they all read it. IT's recovered page record shows input transmission at 18:41:12; John's incoming Jobert call has the same timestamp. These records establish timing and page behavior, not the operator's identity."},
		{"id":"c5_eric", "title":"The accusation against Eric is unsupported", "people":["john","eric","jobert","rham"], "field":"solved", "value":0, "status":"Known", "source":"Chapter 5 / First rebuttal", "text":"The group-chat exhibit contradicts the claim that only Eric knew about the coffee comment. Access to a message does not identify who authored the scam."},
		{"id":"c5_dan", "title":"Knowing a format does not prove authorship", "people":["john","dan","jobert","rham"], "field":"solved", "value":1, "status":"Known", "source":"Chapter 5 / Second rebuttal", "text":"The advisor headers show impersonation but do not identify Dan. His joke and knowledge of the club format do not support Jobert's accusation."},
		{"id":"c5_input", "title":"Submit was not required for capture", "people":["john","jobert","rham"], "field":"solved", "value":2, "status":"Known", "source":"Chapter 5 / Third rebuttal", "text":"The recovered record contradicts Jobert's claim that nothing was captured before Submit. John asks how Jobert knew when to call. Timing raises a question; it does not identify the page operator by itself."},
		{"id":"c5_status", "title":"Offline is not an alibi", "people":["john","jobert","eric","rham"], "field":"solved", "value":3, "status":"Known", "source":"Chapter 5 / Fourth rebuttal", "text":"Neither Jobert's nor Eric's last-seen status proves sleep or authorship. The timeline challenges Jobert's claimed alibi without establishing a culprit on its own."},
		{"id":"c5_typo", "title":"A repeated word in the hearing chat", "people":["john","jobert"], "field":"final_matched", "status":"Known", "source":"Chapter 5 / Final comparison", "text":"Jobert types 'recieve' in the hearing chat. John matches it to the two emails. The spelling is a reason to ask for an explanation, not a verdict."},
		{"id":"c5_admission", "title":"Jobert's admission", "people":["john","jobert","rham"], "field":"admitted", "status":"Known", "source":"Chapter 5 / Recorded admission", "text":"Jobert admits sending the survey, advisor, payout, and prize messages. He says he called when the page showed input so John would trust him. His admission resolves authorship in this story; the typo and online status alone did not."},
		{"id":"c5_outcome", "title":"The hearing's outcome", "people":["john","eric","dan","mika","jobert","rham"], "field":"aftermath_done", "status":"Known", "source":"Chapter 5 / Sir Rham's decision", "text":"Sir Rham says the accusations against Eric and Dan were unsupported and Mika's conversation was not proof. Jobert is removed from the club; the accounts will be reported and he faces a disciplinary hearing."}
	]
}

static func chapter_definition(number: int) -> GDScript:
	return CHAPTERS[clampi(number - 1, 0, CHAPTERS.size() - 1)]

static func chapter_records(snapshot: Dictionary) -> Array[Dictionary]:
	if int(snapshot.get("_chapter", 1)) == 24: return CONNECTION_OBSERVATIONS.duplicate(true)
	if int(snapshot.get("_chapter", 1)) == 23: return ENDORSEMENT_OBSERVATIONS.duplicate(true)
	if int(snapshot.get("_chapter", 1)) == 22: return PREVIEW_OBSERVATIONS.duplicate(true)
	if int(snapshot.get("_chapter", 1)) == 21: return GIFT_OBSERVATIONS.duplicate(true)
	if int(snapshot.get("_chapter", 1)) == 20: return MASK_HOLDS_OBSERVATIONS.duplicate(true)
	if int(snapshot.get("_chapter", 1)) == 19: return OFFICE_OBSERVATIONS.duplicate(true)
	if int(snapshot.get("_chapter", 1)) == 18: return EXCEPTION_OBSERVATIONS.duplicate(true)
	if int(snapshot.get("_chapter", 1)) == 17: return CONSISTENT_STORY_OBSERVATIONS.duplicate(true)
	if int(snapshot.get("_chapter", 1)) == 16: return APPOINTMENT_OBSERVATIONS.duplicate(true)
	if int(snapshot.get("_chapter", 1)) == 15: return VOICE_CONTROL_OBSERVATIONS.duplicate(true)
	if int(snapshot.get("_chapter", 1)) == 14: return CALLBACK_OBSERVATIONS.duplicate(true)
	if int(snapshot.get("_chapter", 1)) == 13:
		var records: Array[Dictionary] = HANG_UP_OBSERVATIONS.duplicate(true)
		if int(snapshot.get("call_received", 0)) == 0:
			records[1].source = "Module 3 / Chapter 3 / Review guidance"
			records[1].text = "Liza declined this call; no caller statements were received. In a labeled review example, she contrasts stop payment with the actual alert purpose, reset password. The example is learning guidance, not evidence of words heard in this call."
		return records
	if int(snapshot.get("_chapter", 1)) == 12: return KNOWN_DETAILS_OBSERVATIONS.duplicate(true)
	if int(snapshot.get("_chapter", 1)) == 11: return CALLER_OBSERVATIONS.duplicate(true)
	if int(snapshot.get("_chapter", 1)) == 6: return DELIVERY_OBSERVATIONS.duplicate(true)
	if int(snapshot.get("_chapter", 1)) == 7: return WALLET_OBSERVATIONS.duplicate(true)
	if int(snapshot.get("_chapter", 1)) == 8: return FAMILIAR_OBSERVATIONS.duplicate(true)
	if int(snapshot.get("_chapter", 1)) == 9: return RECOVERY_OBSERVATIONS.duplicate(true)
	if int(snapshot.get("_chapter", 1)) == 10: return KEEP_CODE_OBSERVATIONS.duplicate(true)
	var result: Array[Dictionary] = []
	result.assign(CHAPTER_OBSERVATIONS.get(int(snapshot.get("_chapter", 1)), OBSERVATIONS))
	return result

static func character_ids(snapshot: Dictionary) -> Array[String]:
	if int(snapshot.get("_chapter", 1)) == 24:
		return ["mika","rham"] if seen_beat(snapshot,1) else ["mika"]
	if int(snapshot.get("_chapter", 1)) == 23:
		var people: Array[String] = ["mika"]
		if seen_beat(snapshot,3): people.append("amani")
		if seen_beat(snapshot,6): people.append("liza")
		return people
	if int(snapshot.get("_chapter", 1)) == 22:
		return ["mika","john"] if seen_beat(snapshot,2) else ["mika"]
	if int(snapshot.get("_chapter", 1)) == 21:
		return ["mika","john"] if seen_beat(snapshot,1) else ["mika"]
	if int(snapshot.get("_chapter", 1)) == 20:
		return ["rham","john","liza","mika"] if snapshot.get("briefed",false) else ["rham"]
	if int(snapshot.get("_chapter", 1)) in [18,19]: return ["rham"]
	if int(snapshot.get("_chapter", 1)) in [16,17]:
		return ["rham","john"] if seen_beat(snapshot,1) else ["rham"]
	if int(snapshot.get("_chapter", 1)) == 15:
		return ["liza","rham","john","eric"] if snapshot.get("briefed",false) else ["liza"]
	if int(snapshot.get("_chapter", 1)) == 14:
		var people: Array[String] = ["liza"]
		if seen_beat(snapshot, 2): people.append("john")
		return people
	if int(snapshot.get("_chapter", 1)) == 13: return ["liza"]
	if int(snapshot.get("_chapter", 1)) == 12:
		var people: Array[String] = ["liza"]
		if seen_beat(snapshot, 3): people.append("john")
		return people
	if int(snapshot.get("_chapter", 1)) == 11:
		var people: Array[String] = ["liza"]
		if seen_beat(snapshot, 0): people.append("eric")
		if seen_beat(snapshot, 4): people.append("john")
		return people
	if int(snapshot.get("_chapter", 1)) == 10:
		var people: Array[String] = ["amani","dan"]
		if seen_beat(snapshot, 3): people.append("rham")
		if seen_beat(snapshot, 4): people.append("john")
		return people
	if int(snapshot.get("_chapter", 1)) == 9:
		var people: Array[String] = ["amani"]
		if seen_beat(snapshot, 2): people.append("john")
		if seen_beat(snapshot, 4): people.append("rham")
		return people
	if int(snapshot.get("_chapter", 1)) == 8:
		var people: Array[String] = ["amani","john"]
		if seen_beat(snapshot, 6): people.append("dan")
		return people
	if int(snapshot.get("_chapter", 1)) == 7:
		var people: Array[String] = ["amani"]
		if seen_beat(snapshot, 2): people.append("john")
		return people
	if int(snapshot.get("_chapter", 1)) == 6:
		var people: Array[String] = ["amani"]
		if seen_beat(snapshot, 1): people.append("dan")
		if seen_beat(snapshot, 5): people.append("john")
		return people
	var ids: Array[String] = CHARACTER_IDS.duplicate()
	var number: int = int(snapshot.get("_chapter", 1))
	if number >= 2: ids.append("rham")
	if number > 2 or (number == 2 and seen_beat(snapshot, 20)): ids.append("dan")
	if number > 3 or (number == 3 and seen_beat(snapshot, 7)): ids.append("mika")
	return ids

static func story_snapshot(raw: Dictionary, chapter: int = 1) -> Dictionary:
	# Read-only projection of existing saves. No migration or new unlock flags.
	var snapshot: Dictionary = chapter_definition(chapter).clean(raw)
	snapshot["_chapter"] = clampi(chapter, 1, CHAPTERS.size())
	return snapshot

static func seen_beat(snapshot: Dictionary, index: int) -> bool:
	return snapshot.get("completed", false) == true or str(snapshot.get("phase", "day")) != "day" or int(snapshot.get("beat", 0)) > index

static func observations(snapshot: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var number: int = int(snapshot.get("_chapter", 1))
	for authored: Dictionary in chapter_records(snapshot):
		var discovered: bool = false
		if authored.has("field"):
			var saved: Variant = snapshot.get(str(authored.field))
			discovered = (saved is Array and saved.has(authored.value)) if authored.has("value") else saved == true
		elif authored.has("read_id"):
			discovered = (snapshot.get("read", []) as Array).has(authored.read_id)
		else:
			discovered = seen_beat(snapshot, int(authored.after_beat))
		if not discovered and number == 10 and snapshot.has("legacy_review"):
			var legacy_field: String = {0:"flags",1:"domains",2:"captures"}.get(authored.get("value",-1),"")
			discovered = not legacy_field.is_empty() and (snapshot.legacy_review.get(legacy_field,[]) as Array).has("case")
		if not discovered:
			result.append({"id":authored.id, "title":"Undiscovered observation", "status":"Unknown", "source":chapter_label(number), "text":"Continue %s to discover this record." % chapter_label(number), "people":[], "discovered":false})
			continue
		var item: Dictionary = authored.duplicate(true)
		item.discovered = true
		if authored.has("read_id"):
			var message_id: String = str(authored.read_id)
			if (snapshot.get("flags", []) as Array).has(message_id): item.text += "\n\nInvestigation: you marked the concerning request."
			if (snapshot.get("domains", []) as Array).has(message_id):
				item.text += "\n\nRecorded sender domain: " + str(Survey.message(message_id).address).get_slice("@", 1) + ". A mailbox domain alone does not identify the author."
			if (snapshot.get("captures", []) as Array).has(message_id): item.text += "\n\nMessage capture saved in your Chapter 1 exhibit."
		result.append(item)
	return result

static func discovery_progress(snapshot: Dictionary, person: String = "") -> Dictionary:
	var total: int = 0
	var found: int = 0
	var records: Array[Dictionary] = observations(snapshot)
	var authored: Array[Dictionary] = chapter_records(snapshot)
	for index: int in authored.size():
		if not person.is_empty() and person not in authored[index].people: continue
		total += 1
		if records[index].discovered: found += 1
	return {"found":found, "total":total}

static func character(id: String, snapshot: Dictionary) -> Dictionary:
	if not CHARACTERS.has(id): return {}
	var data: Dictionary = (CHARACTERS[id] as Dictionary).duplicate(true)
	data.id = id
	data.behavior = "More observations unlock as you meet this character in Chapter 1."
	if int(snapshot.get("_chapter", 1)) > 1:
		data.behavior = "This file records only what you have discovered in the selected chapter."
		data.interactions = []
		for observation: Dictionary in observations(snapshot):
			if observation.discovered and id in observation.people: data.interactions.append(observation)
		return data
	match id:
		"john":
			if seen_beat(snapshot, 4):
				data.background += " He is seeking extra income and agrees to look at a survey opportunity."
				data.behavior = "He asks the club about a side gig and is willing to examine Eric's offer."
			if seen_beat(snapshot, 6): data.behavior += " He asks Eric for the client's name."
		"eric":
			if seen_beat(snapshot, 3): data.behavior = "He greets John and offers to save him a seat at the club meeting."
			if seen_beat(snapshot, 4): data.relationship += " He introduces John to the survey opportunity."
			if seen_beat(snapshot, 5): data.background += " He claims to know the client personally; this remains unverified."
		"jobert":
			if seen_beat(snapshot, 4):
				data.behavior = "He voices caution about random surveys and tells John to ask if unsure."
				data.relationship += " He gives John a warning about the survey."
			if seen_beat(snapshot, 9): data.background += " He recommends checking who is behind the survey and offers to help."
	data.interactions = []
	for observation: Dictionary in observations(snapshot):
		if observation.discovered and id in observation.people: data.interactions.append(observation)
	return data

const NOTES := {
	"base": ["Precision defender", "Direct fire rewards careful placement against durable targets. Pair it with crowd control to keep enemies in range.", "Network defense", "Basic Node is a fictional defender inspired by network protection. A real firewall controls traffic using security rules; it does not shoot malware or guarantee protection against every attack.", "NIST / Firewall", "https://csrc.nist.gov/glossary/term/firewall"],
	"scanner": ["Rapid-fire defender", "A fast-firing specialist with a damage advantage against swarm threats. Heavy targets resist its damage.", "Vulnerability scanning", "Security scanning helps identify systems and potential weaknesses. Finding a problem is different from fixing it. The Scanner's rapid-fire attack is a game mechanic, not how real scanning removes threats.", "NIST / Vulnerability scanning", "https://csrc.nist.gov/glossary/term/vulnerability_scanning"],
	"sandbox": ["Control specialist", "Deals no direct damage. Its field buys firing time for nearby defenders, with the strongest slowdown against stealth threats.", "Sandboxing", "A sandbox runs software in a controlled environment with limited permissions and access to resources. The tower's slowing field represents containment; real software is not physically slowed like an enemy on a path.", "NIST / Sandbox", "https://csrc.nist.gov/glossary/term/Sandbox"],
	"basic": ["Stealth intruder", "A steady-moving intruder. Direct damage has no special type modifier against it, but Sandbox applies its strongest slow.", "Unauthorized access", "This enemy represents an intruder, not everyone who uses the word hacker. Protect accounts with unique passwords and multifactor authentication, and report suspicious messages instead of following their instructions.", "CISA / Staying safe online", "https://www.cisa.gov/sites/default/files/2024-09/Secure-Our-World-4-Easy-Ways-Stay-Safe-Online-Tip-Sheet.pdf"],
	"fast": ["Swarm runner", "Low health and high speed make this threat dangerous in groups. Scanner has a damage advantage; Basic Node is less effective.", "Phishing", "Phishing messages impersonate a trusted source to obtain information or make you open harmful links or files. Pause when a message pressures you to act. Report it using a trusted channel instead of engaging with the sender.", "CISA / Recognize and report phishing", "https://www.cisa.gov/sites/default/files/2024-09/Secure-Our-World-4-Easy-Ways-Stay-Safe-Online-Tip-Sheet.pdf"],
	"heavy": ["Heavy intruder", "A slow, durable threat. Focus Basic Node fire on it; Scanner's damage is reduced against this profile.", "Ransomware", "Ransomware can deny access to systems or data, and attackers may also steal information for extortion. Backups and incident planning help organizations recover. Report a suspected incident to your IT team promptly.", "CISA / StopRansomware guide", "https://www.cisa.gov/resources-tools/resources/stopransomware-guide"],
	"boss": ["Heavy / boss variant", "The heavy profile with a much larger health pool. It shares the same matchups as the regular heavy intruder.", "Ransomware incidents", "The boss is a game variant, not a separate real-world malware category. Ransomware incidents can disrupt whole organizations. Recovery requires coordinated response; a single tool is not a complete defense.", "CISA / StopRansomware guide", "https://www.cisa.gov/resources-tools/resources/stopransomware-guide"]
}

static func ids(tab: StringName) -> Array[String]:
	var available := ContentDB.get_all_tower_ids() if tab == &"units" else ContentDB.get_all_enemy_ids()
	var preferred := ["base", "scanner", "sandbox"] if tab == &"units" else ["basic", "fast", "heavy", "boss"]
	var ordered: Array[String] = []
	for id in preferred:
		if id in available:
			ordered.append(id)
	for id in available:
		if id not in ordered:
			ordered.append(id)
	return ordered

static func display_name(tab: StringName, id: String) -> String:
	if tab == &"units":
		return str(ContentDB.get_tower(id).get("name", id.capitalize()))
	return str({"basic": "Hacker", "fast": "Phisherman", "heavy": "Ransomware", "boss": "Ransomware Prime"}.get(id, id.capitalize()))

static func profile(id: String) -> String:
	return EnemyBase.profile_for_character(EnemyBase.character_for_wave(id))

static func entry(tab: StringName, id: String) -> Dictionary:
	var notes: Array = NOTES.get(id, ["Field entry", "Inspect the authored stats and matchup rules below.", "Field notes pending", "No real-world notes have been authored for this entry yet.", "", ""])
	var stats: Dictionary = ContentDB.get_tower(id) if tab == &"units" else ContentDB.get_enemy(id)
	return {"name": display_name(tab, id), "type": str(stats.get("role", "DEFENDER")) if tab == &"units" else profile(id).to_upper(), "subtitle": notes[0], "tactics": notes[1], "real_title": notes[2], "real_body": notes[3], "source": notes[4], "url": notes[5], "stats": stats}

static func matchup(tower_id: String, enemy_id: String) -> Dictionary:
	# No tree membership, assets, initialization or gameplay side effects.
	var probe := EnemyBase.new()
	probe.threat_profile = profile(enemy_id)
	var result: Dictionary
	if tower_id == "sandbox":
		var factor := probe.sandbox_slow_factor()
		result = {"value": factor, "kind": "slow", "tier": str(EnemyBase.matchup_tier(factor, 0.4, 0.8)), "effect": "%d%% slow" % roundi((1.0 - factor) * 100.0)}
	else:
		var multiplier := probe.damage_multiplier_vs(tower_id)
		result = {"value": multiplier, "kind": "damage", "tier": str(EnemyBase.matchup_tier(multiplier, 1.5, 0.5)), "effect": "%.1fx damage" % multiplier}
	probe.free()
	return result

static func matchups(tab: StringName, id: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if tab == &"units":
		var seen: Array[String] = []
		for enemy_id in ids(&"enemies"):
			var type := profile(enemy_id)
			if type in seen:
				continue
			seen.append(type)
			var row := matchup(id, enemy_id)
			row["name"] = type.capitalize()
			row["id"] = enemy_id
			rows.append(row)
	else:
		for tower_id in ids(&"units"):
			var row := matchup(tower_id, id)
			row["name"] = display_name(&"units", tower_id)
			row["id"] = tower_id
			rows.append(row)
	return rows

static func chapter_label(number: int) -> String:
	var chapter: GDScript = chapter_definition(number)
	return "Module %d / Chapter %d" % [int(chapter.ID.get_slice("_", 1)), chapter.NUMBER]
