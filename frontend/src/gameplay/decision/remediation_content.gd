extends RefCounted
## Authored transfer practice, separate from persistence/policy. Indices are zero-based
## existing lessons, not invented lessons. Shared question IDs survive stage changes.
const PLANS: Dictionary = {
	"mod_01": {
		3: [["identity", 1], ["sessions", 5], ["warning", 4]],
		4: [["payment", 1], ["permission", 1], ["destination", 2]],
		5: [["mfa", 5], ["sessions", 5], ["destination", 2]],
		6: [["attachment", 3], ["consent", 5], ["destination", 2]],
		7: [["payment", 1], ["attachment", 3], ["payment", 4]],
		8: [["warning", 4], ["isolation", 5], ["forwarding", 5]],
		9: [["sessions", 5], ["forwarding", 5], ["isolation", 5]],
	},
	"mod_02": {
		1: [["destination", 1], ["verified", 3], ["codes", 2]],
		2: [["records", 3], ["payment", 3], ["codes", 2]],
		3: [["identity", 1], ["permission", 4], ["payment", 4]],
		4: [["codes", 2], ["codes", 2], ["sessions", 5]],
		5: [["recovery", 5], ["privacy", 2], ["warning", 5]],
		6: [["simswap", 5], ["authmethods", 2], ["remote", 5]],
		7: [["corroboration", 3], ["corroboration", 3], ["privacy", 4]],
		8: [["identity", 1], ["scope", 4], ["scope", 5]],
		9: [["identity", 1], ["destination", 1], ["verified", 3]],
	},
}

# Concept, lesson for each authored exam question. No keyword guessing at runtime.
const EMAIL_EXAM: Dictionary = {
	"tv": ["verified", "destination", "attachment", "verified", "identity", "verified", "payment", "verified", "destination", "destination"],
	"st": ["destination", "attachment", "codes", "codes", "destination", "destination", "destination", "identity", "destination", "identity"],
	"sa": ["identity", "identity", "identity", "identity", "identity", "destination", "identity", "verified", "identity", "verified"],
	"us": ["destination", "destination", "destination", "destination", "destination", "destination", "destination", "destination", "destination", "destination"],
	"tt": ["attachment", "destination", "codes", "payment", "destination", "destination", "destination", "privacy", "privacy", "payment"],
	"it": ["codes", "verified", "destination", "payment", "verified", "destination", "verified", "destination", "privacy", "payment"],
	"cc": ["destination", "attachment", "codes", "payment", "destination", "destination", "destination", "privacy", "privacy", "payment"],
	"tf": ["codes", "identity", "attachment", "payment", "destination", "destination", "payment", "warning", "identity", "verified"],
}
const EMAIL_LESSONS: Dictionary = {"identity": 1, "destination": 2, "attachment": 3, "verified": 4, "codes": 1, "payment": 4, "privacy": 5, "warning": 4}
const COLLEGE_EXAM: Array = [["destination", 1], ["payment", 3], ["records", 3], ["records", 3], ["verified", 3], ["identity", 1], ["permission", 4], ["scope", 4], ["scope", 4], ["permission", 4], ["destination", 1], ["scope", 5], ["verified", 3], ["verified", 3], ["warning", 5]]

# title, rationale, transferable rule; each question has a fresh context, 3 options,
# correct index, and corrective feedback. No stage or ordinary-quiz answers copied.
const CONCEPTS: Dictionary = {
	"identity": ["Check who is really asking", "Familiar names, true details and even genuine accounts do not authorize an unusual request.", "Contact the person through a route saved before the message. Do not replace that route using instructions from the message itself.", [
		["Your teammate's real account sends a new sign-in link. Beside you, they say they never sent it. Your next move?", ["Open it because the address matches", "Keep it unopened and report the possible account misuse together", "Ask another teammate to test the login"], 1, "A genuine account can be misused. The owner's independent denial matters more than the familiar address."],
		["A new number knows your public debate-team nickname. It asks you to replace your captain's saved number. What verifies the change?", ["The nickname", "The new number repeating the request", "Reaching your captain through the established contact or in person"], 2, "Public details are not identity proof. Do not let the unverified message choose its own verifier."],
		["A caller quotes your real support ticket. Which check is independent?", ["End the call and use the support contact saved in your handbook", "Call back from the incoming call history", "Ask that caller for another ticket detail"], 0, "Caller ID and ticket details can be copied. Use a contact obtained independently of the call."],
	]],
	"destination": ["Choose your own verification route", "A second screen, a QR code or a padlock can still lead to the sender's chosen site.", "Inspect the destination without opening it. Check the claim through a saved portal or independently known contact, not the message's link, QR or chat.", [
		["A rehearsal QR opens a preview of rehearsal-pass.example. Your saved timetable is at portal.campus.example. What next?", ["Scan again to make it trustworthy", "Sign in if the QR has a school logo", "Keep the page closed and verify the change through your saved timetable and adviser"], 2, "QR codes carry destinations, not proof of authority. A schedule change needs an independent check."],
		["An SMS links to a page whose chat says 'We confirm this SMS'. Has a second source verified it?", ["No: the message selected both the page and its chat", "Yes: chat and SMS are different apps", "Yes: if the page has a padlock"], 0, "Different interfaces are not independent sources when the same sender supplies them."],
		["A login page uses campus.example.signin-check.example. The saved portal is campus.example. What should guide you?", ["The school name appearing anywhere in the address", "The actual destination; use your saved portal instead", "The page's familiar colors"], 1, "The school name can appear inside an unrelated address. A padlock does not establish school ownership."],
	]],
	"verified": ["Resume only what the evidence supports", "Safe decisions require checking the scope of real evidence, not trusting everything or rejecting everything.", "Use independently retrieved, current records. Resume the verified ordinary task; do not extend one service's recovery result to unrelated accounts.", [
		["Your saved class portal confirms a room change. The text asks for no secrets and agrees. What is reasonable?", ["Abandon class because the information also arrived by text", "Use the room listed in your independently opened portal", "Reply with your password to confirm attendance"], 1, "Independent confirmation supports the ordinary task without disclosing credentials."],
		["The campus portal says an unauthorized contact change was rejected. Your cousin's carrier case is still open. What is established?", ["Every family account is safe", "The rejected contact should now be added", "That campus change was rejected; the carrier case still needs its own checks"], 2, "A result applies to the case and service it actually covers."],
		["IT confirms your existing workspace permissions are safe. An earlier suspicious text offered a 'release access' link. How do you resume?", ["Use the saved workspace with existing permissions", "Use the earlier link now that IT finished", "Make the workspace public so the issue cannot recur"], 0, "Recovery does not retroactively validate an untrusted link or authorize broader sharing."],
	]],
	"sessions": ["A reset is not the whole recovery", "Unknown sessions can remain active after a password change, depending on the service.", "With verified support, end unauthorized sessions, use a unique password and review recovery settings. Keep protection enabled; check activity rather than assuming the reset fixed everything.", [
		["An unknown browser downloads a file two minutes after your reset. What next?", ["Assume the reset already stopped it", "Leave it connected to watch", "Use verified IT support to revoke access and review the account"], 2, "The later activity is evidence that access persisted. Do not leave it active to investigate yourself."],
		["Two sessions performed actions you did not make. One is named 'Library PC'. Staff have saved the logs. Which response fits?", ["Ask staff to end all sessions on the affected account and check recovery settings", "Keep the friendly-named session", "Delete the project to remove the sessions"], 0, "Device labels do not establish ownership. Signing out sessions is not deleting your files."],
		["Support has secured your password, but an unknown recovery address remains. Are you finished?", ["Yes, the password is all that matters", "No, review and remove unauthorized recovery access with verified support", "Disable verification so recovery is quicker"], 1, "Recovery contacts and active sessions are separate access paths. Keep verification enabled."],
	]],
	"warning": ["Warn without spreading the trap", "Fixing your account or deleting one copy does not remove risky messages already sent to others.", "Preserve relevant evidence privately for verified support. Warn affected recipients through an established channel without forwarding live links, files, or private records.", [
		["A fake software update reached three club chats. IT published a verified warning. What do you share?", ["The original executable as an example", "The verified notice and reporting route, without the attachment", "Only a joke about the person who clicked"], 1, "A useful warning gives a safe action without redistributing the payload or blaming someone."],
		["Your account is recovered, but it sent an unsafe invite yesterday. What still needs attention?", ["Nothing: recovery repaired everyone's copies", "Delete all records before anyone sees them", "Privately report the details and warn the confirmed recipients"], 2, "Earlier messages remain a risk after account recovery. Preserve evidence and reach those affected."],
		["You want to warn classmates about a reported attack. Which message helps?", ["Describe the request, what is confirmed, and the saved support route without private screenshots", "Post the full case file so everyone can investigate", "Forward the active link and ask who recognizes it"], 0, "Share actionable, limited facts. Keep identities, codes and case records in the verified private report."],
	]],
	"payment": ["Pressure is not payment approval", "Correct order details, a real deadline or a small amount do not validate changed payment instructions.", "Hold the payment and verify the payee and purpose through independently saved records and the authorized person. A test payment or a reply in the same thread is not verification.", [
		["Your costume supplier's usual email thread changes the payee to a personal wallet. What verifies the change?", ["A small test transfer", "A confirmation reply in the same thread", "Your adviser calling the supplier number on the original receipt"], 2, "A compromised thread can confirm its own false instructions. Use the previously recorded independent contact."],
		["A parcel text requests a tiny fee on a new page. The saved order and courier account show no fee. What next?", ["Leave the delivery unchanged and check through the known courier route", "Use a low-limit card because the amount is small", "Supply the wallet code to check the fee"], 0, "A small payment can still expose credentials. Verify the actual charge through trusted records."],
		["A message says your adviser is in a meeting and needs money secretly. A classmate agrees it sounds real. Is that approval?", ["Yes, two students agree", "No; wait for the adviser's independent confirmation through the established route", "Yes, if you send only half"], 1, "Peer agreement and accurate schedules do not authorize payment. Urgency does not replace approval."],
	]],
	"permission": ["Share the task, not the whole folder", "Read-only and temporary access can still expose private data. A genuine service does not authorize every requester.", "Verify the exact person, purpose and required role before changing access. Share only the necessary material through the established workspace; keep sensitive files restricted.", [
		["A supposed tutor asks for your interview folder. It includes private recordings; the real task needs only an outline. What do you share?", ["A public viewer link to everything", "Only the outline through the independently confirmed class workspace", "A short private recording to test their identity"], 1, "Viewer access still reveals data. Verify the task and share the minimum necessary material."],
		["An unknown account wants temporary editor access on the genuine school drive. What should happen first?", ["Grant it for five minutes", "Grant viewer access while checking", "Verify the account and authorization through the saved adviser contact"], 2, "Real infrastructure does not authenticate the requester. Temporary access can still leak or alter files."],
		["Your verified adviser needs to read the final poster, not the contact sheet. Which permission fits?", ["Restricted viewer access to that poster only", "Public edit access to the parent folder", "Editor access to every group file"], 0, "Match access to the verified task and keep unrelated data private."],
	]],
	"mfa": ["Do not approve someone else's sign-in", "A genuine verification prompt can represent an attacker trying to sign in.", "Deny unexpected approval requests. Review activity through your saved account route with verified support; do not approve or merely mute repeated prompts.", [
		["Your authenticator asks you to approve a sign-in you did not start. What is the safe response?", ["Approve once to stop the prompts", "Approve because the app is genuine", "Deny it and check activity through saved support"], 2, "The prompt may be genuine while the sign-in is unauthorized."],
		["You deny an unexpected login, then receive several more requests. What next?", ["Report and review the attempts through the known support route", "Mute notifications and consider it solved", "Accept the last request to end the sequence"], 0, "Denying one request does not investigate the repeated attempts. Do not authorize them to stop the noise."],
		["A support message offers to stop the prompts if you approve a 'test login'. You never contacted support. What do you do?", ["Approve the test but not later requests", "Keep denying and contact IT through the saved directory", "Disable verification entirely"], 1, "An unrequested test login is still an access request. Verify support independently and keep protection on."],
	]],
	"attachment": ["Inspect without running", "A convincing filename or familiar sender does not make a file safe.", "Check the full extension and requested action without running the attachment. Use the independently saved source and verify unexpected files; never send them to a friend to test.", [
		["A pickup slip is named Ticket.pdf.exe. The order number is correct. What is it?", ["A PDF because PDF appears first", "An executable, despite the document-looking name", "Safe because the order matches"], 1, "The final extension identifies an executable. Order details do not make it safe to run."],
		["An unexpected Chart.pdf.html asks for your password. The saved class drive has a chart that opens without that form. What next?", ["Enter the password to convert the file", "Forward the HTML to a teammate", "Use the saved chart and verify the unexpected file with the teacher"], 2, "A web file masquerading as a document can collect credentials. Verify without opening or sharing the trap."],
		["You cannot tell whether a competition attachment is genuine. A friend offers to open it first. Your response?", ["Keep it unopened and use the established reporting route", "Let the friend test it", "Run it offline and assume nothing can happen"], 0, "Testing an unverified file on another device transfers the risk; offline execution is not a safety guarantee."],
	]],
	"consent": ["A real login can grant too much", "A genuine identity provider can ask you to grant an unapproved app excessive permissions.", "Check the app's publisher, approval and need for each permission with verified staff. Cancel until verified; grant only the access needed for the approved task.", [
		["A real school login asks you to let a poster app read all email and drive files. What next?", ["Approve because the login provider is real", "Approve profile access before checking the app", "Cancel and verify the app and permissions with IT"], 2, "The login service can be genuine while the receiving app is unapproved or overprivileged."],
		["The app is absent from the saved approved-tools list. What does that establish?", ["Approval is unconfirmed; check with staff before connecting", "It is definitely malware", "It is safe if the icon looks familiar"], 0, "Missing approval is a reason to verify, not proof of malware or permission to proceed."],
		["Staff approve a tool solely to edit one selected poster. Which consent fits?", ["All email and files, in case it helps", "Only the approved access needed for that poster", "Permanent access to the whole class drive"], 1, "Authorization should match the task; approval of a tool does not justify every requested permission."],
	]],
	"forwarding": ["Close the quiet access paths", "An email rule or shared connection can keep exposing information after one sender is blocked.", "Stop using affected shares and report session, forwarding and download records privately. Let authorized staff preserve evidence and disable all confirmed unauthorized paths.", [
		["An unknown inbox rule copies club mail outside school and marks it read. What next?", ["Send private details to see whether the rule works", "Report it privately and ask IT to preserve the record and disable the rule", "Leave it running as evidence"], 1, "Staff can preserve configuration and logs without allowing continued disclosure."],
		["Your own rule is removed. IT reports a second unauthorized rule in the group inbox. Can normal sharing resume?", ["Yes, your inbox is fixed", "Yes, after blocking the original sender", "Not yet; report both inboxes and have staff review the remaining path"], 2, "Recovery must cover the confirmed related paths, not only the first visible problem."],
		["The saved workspace shows bulk downloads, an outside forwarding rule and an active unknown session. What response fits?", ["Stop affected sharing and give these records privately to verified IT", "Block one email address and assume all access ended", "Post the downloaded files publicly as proof"], 0, "Blocking a sender does not revoke sessions or forwarding. Report the separate access paths without widening exposure."],
	]],
	"isolation": ["Protect the work without keeping the breach", "Finishing an upload is not worth leaving a confirmed malicious connection active.", "Stop using affected access. Follow verified staff instructions to isolate the device or account while preserving evidence; continue only from a checked, approved backup.", [
		["Staff confirm an active compromise and have the logs. One slide is unsaved; a checked device has yesterday's copy. What next?", ["Finish uploading before disconnecting", "Close the browser but keep using the laptop", "Stop using it, ask staff to isolate it, and recreate the slide on the checked device"], 2, "Do not extend confirmed exposure to save a small amount of work. Use the verified backup."],
		["Your group's affected account still has unauthorized access. The adviser offers an approved offline presentation. What is safest?", ["Pause affected sharing and use the approved offline copy", "Keep the compromised share open until the presentation ends", "Copy everything to a USB from the affected machine"], 0, "A safe continuity plan does not require leaving compromised access active or transferring unchecked files."],
		["You closed the browser on a device with confirmed malicious network activity. Is that enough to resume?", ["Yes, no visible window means no connection", "No; follow verified staff isolation and recovery instructions", "Yes, if the deadline is close"], 1, "Closing one interface is not evidence the underlying compromise has ended."],
	]],
	"records": ["Match the whole record", "A matching suffix, an old receipt or a genuine deadline can refer to a different event.", "Match the full reference, service, date and requested action in independently opened records. State what those records establish and what remains unverified.", [
		["Two orders end in 7420. A text says your microphone is delayed. Which record answers that claim?", ["Whichever suffix matches first", "The full microphone order reference and current courier record", "Last month's payment receipt for another order"], 1, "A partial match can point to the wrong item. Check the full reference and current status."],
		["A message quotes the right order number but asks for a new fee. Does the number authorize the fee?", ["Yes, only the courier knows it", "Yes, if the amount is small", "No; check that order's current charges through the saved account"], 2, "Accurate background information does not independently support a new payment demand."],
		["An old support receipt says an upload succeeded. You need to know whether today's slides arrived. What do you check?", ["Today's submission timestamp and receipt in the saved workspace", "The old success notice", "An SMS saying uploads usually work"], 0, "Use a record for the exact event and date, not a different successful action."],
	]],
	"codes": ["Codes authorize actions", "Calling a login code a cancellation or delivery code does not change what it can authorize.", "Keep login and recovery codes private. Inspect the actual pending action in the saved service and use independently verified support. A request is not proof that access completed.", [
		["A text says 'Send your reset code with CANCEL to stop the reset'. What next?", ["Send it because cancellation sounds safe", "Send a student-card photo instead", "Keep it private and report the pending reset through saved support"], 2, "The code may authorize the reset. The sender's label does not change its function."],
		["The portal shows an unexpected pending verification but no new session. What can you conclude?", ["An attempt needs review; this record does not show a completed sign-in", "The attacker definitely entered the account", "Nothing needs checking until a sign-in succeeds"], 0, "Distinguish an attempted action from completed access while still reporting the attempt."],
		["A courier text knows your delivery time and asks for your account login code. Which response protects you?", ["Send the code because the time matches", "Use the saved collection procedure and report the login-code request", "Ask the sender to name the attendant, then send it"], 1, "Knowing delivery details does not authorize account access. Do not substitute other sensitive information either."],
	]],
	"recovery": ["Recover through the route you chose", "A real case number can be used to sell a fake recovery shortcut.", "Use your saved help desk or established case. Verify current status there, keep recovery contacts unchanged until authorized, and retain your own account secrets.", [
		["While you are locked out, a text quotes your real ticket and offers paid express recovery with a new contact address. What next?", ["Pay so the real case moves faster", "Reach the saved help desk with your ticket; do not change the contact from the text", "Trust it after it repeats the case number"], 1, "A copied reference does not verify the service, fee or contact change."],
		["You have an old successful-login receipt but are locked out now. What does the receipt prove?", ["Your account is currently fine", "The new SMS agent is genuine", "Only the older event; current status needs an independent check"], 2, "Historical records do not establish the present state of the account."],
		["Verified support offers an in-person identity appointment without collecting backup codes. What should you do?", ["Use that established process and keep recovery secrets private", "Send backup codes to the unsolicited express agent", "Let a classmate replace your recovery contact"], 0, "Owner-led recovery through verified support does not require handing control to an unsolicited helper."],
	]],
	"privacy": ["Report with less personal data", "A security title or urgent form does not authorize collecting everyone's identity records.", "Verify the reporting route and disclose only the information that process actually needs. Keep codes and private evidence out of class chats and unverified forms.", [
		["An unsolicited support chat asks for your ID, family details and backup code. The saved desk offers an appointment needing only your student card. Which route fits?", ["Send a cropped card to the unsolicited chat", "Post the bundle for classmates to check", "Attend the verified appointment and keep the backup code private"], 2, "Reducing an unverified request does not make its recipient trustworthy. Use the verified minimum-data process."],
		["A 'security team' text asks you to collect classmates' phone numbers in a new sheet. What next?", ["Check the saved campus reporting procedure before collecting anything", "Upload numbers but not ID photos", "Trust the sheet because it has a security heading"], 0, "Phone numbers are personal data too. Verify authority, purpose and channel first."],
		["Your class needs a warning about a reported scam. What belongs in the class feed?", ["All original screenshots, with names blurred", "A short factual warning and safe reporting steps, without private records", "The full recovery case and student IDs"], 1, "Screenshots can retain identifying details even after partial redaction. Keep evidence with authorized recipients."],
	]],
	"simswap": ["Verify what happened to the line", "Lost signal alone does not prove a SIM replacement, and a cancellation link can be another trap.", "Use saved carrier support over an available independent connection. Confirm the event, report an unauthorized replacement and follow the carrier's alternative owner-verification process.", [
		["You lose signal and find an SMS offering a replacement profile to cancel a SIM change. Where do you check?", ["Install the supplied profile", "Use saved carrier support through Wi-Fi or another trusted route", "Request more SMS codes until one arrives"], 1, "Verify with the carrier independently; do not install the untrusted profile or depend on the affected line."],
		["The carrier's independently opened case confirms a replacement you did not request. What next?", ["Assume last month's maintenance explains it", "Wait without contacting anyone", "Report it in that case and follow verified suspension and owner-check steps"], 2, "A confirmed unauthorized replacement requires the carrier's recovery process, not an unrelated outage explanation."],
		["Your friend's signal works; their carrier finds no replacement despite a threatening SMS. What should they do?", ["Report the message and follow their carrier's advice without assuming a SIM swap", "Copy your replacement-recovery steps regardless", "Give you carrier passwords to investigate"], 0, "Similar messages can have different outcomes. Recovery should follow that person's verified evidence."],
	]],
	"authmethods": ["Recover each service on its own evidence", "Restoring a phone line does not automatically secure every account that uses it.", "Avoid repeated SMS-code requests while the line is affected. Keep working authenticator protection, use saved alternative recovery and review each service's sessions separately.", [
		["Your line is affected, but the campus authenticator still works. Another service waits for an SMS code. What should you do?", ["Switch both services to SMS", "Make a friend's phone your recovery number", "Keep authenticator protection and use the other service's saved alternative recovery"], 2, "Different services have different controls. Do not weaken a working method to match the affected one."],
		["A service reports an unfinished SMS verification. Is that proof the account was entered?", ["No; review that service's actual sessions and activity", "Yes, every requested code means access", "No review is needed if it is unfinished"], 0, "An attempt and completed access are different; check the service instead of assuming either outcome."],
		["The carrier restores your line. Which check remains?", ["None: the carrier secured all your accounts", "Test service and review affected accounts through their own known routes", "Turn off authenticators now that SMS works"], 1, "Line recovery and account recovery are separate responsibilities."],
	]],
	"remote": ["Support does not get unrestricted control", "Knowing a carrier case number does not authorize remote access to your screen or financial apps.", "Reject unsolicited remote-control requests. Finish recovery through established support, verify service works and review affected accounts separately.", [
		["An email quotes your carrier case and asks you to install remote control and open your banking app. What next?", ["Allow view-only sharing", "Reject it and check through the established carrier case", "Install it because the case matches"], 1, "Case details are not permission for screen access. View-only sharing can still expose secrets."],
		["Your signal bars return during recovery. Is that enough to close everything?", ["Yes, bars prove all accounts are safe", "Yes, delete the case records", "Follow the carrier's service tests and check SMS-dependent accounts separately"], 2, "An indicator is not a completed recovery check, and carrier work does not secure unrelated accounts."],
		["A caller says view-only access is harmless if you keep the bank app closed. What is the safer response?", ["Decline and use the support channel you independently established", "Share the screen because they cannot click", "Read them notification codes instead"], 0, "Notifications and other private information can be exposed even without control."],
	]],
	"corroboration": ["Count incidents, not forwards", "Repeated screenshots and similar wording are not independent proof of additional compromises.", "Trace reports to their original sources, distinguish message-only reports from confirmed access or line changes, and document uncertainty without exposing private details.", [
		["Three forwarded screenshots all show one student's carrier case. You also have your own separate confirmed case. How many confirmed cases are supported?", ["Four, one per screenshot plus yours", "Only one because the messages look alike", "Two; the forwards are copies of the same source"], 2, "Duplicate reports do not create independent incidents."],
		["Another student received a similar threat, but their carrier confirms no replacement. How do you record it?", ["As a message-only report, separate from confirmed replacements", "As another confirmed replacement", "Exclude it completely because signal works"], 0, "The report is relevant but its confirmed outcome differs. State both facts."],
		["Two original reports are verified; the rest are rumors. What is a useful warning?", ["Announce that every student was hacked", "Describe the confirmed scope, uncertainty and independent checks", "Wait for every student before recording any case"], 1, "Act on supported evidence without expanding it into an unsupported class-wide claim."],
	]],
	"scope": ["A trusted person still needs the right role", "Family consent, good intentions or a real case number do not authorize changes to someone else's workspace.", "Check the exact account, requested action and authorized owner or reviewer. Keep unrequested changes on hold; help people reach verified support without transferring credentials or roles.", [
		["Your brother is your personal account's recovery contact. A text asks him to approve your college team's access change. What next?", ["Let him approve because his recovery role is genuine", "Use campus IT and the designated workspace reviewer; his personal role does not transfer", "Give him your campus session to make the roles match"], 1, "Authority belongs to a specific account and task, not every related service."],
		["An official portal contains a pending contact-change request that nobody authorized. The family wants reassurance. What should happen?", ["Approve because the request number exists", "Approve once the family agrees with the wording", "Leave the change on hold for its authorized reviewers and reassure the family separately"], 2, "A real pending request is not proof of permission. Welfare checks and account-control changes are different actions."],
		["A genuine friend asks for help and forwards an unverified recovery instruction. How can you help now?", ["Find the established owner-led support process together without taking their session", "Take their password to finish faster", "Follow the forwarded instruction because the friend is genuine"], 0, "A genuine helper can relay an unsafe instruction. Support the owner without taking control."],
	]],
}

static func topics() -> Dictionary:
	var result: Dictionary = {}
	for module_id: String in PLANS:
		for stage: int in PLANS[module_id]:
			for pair: Array in PLANS[module_id][stage]:
				_add_topic(result, module_id, stage, str(pair[0]), int(pair[1]))
	for group: String in EMAIL_EXAM:
		for concept: String in EMAIL_EXAM[group]:
			_add_topic(result, "mod_01", 10, concept, int(EMAIL_LESSONS[concept]))
	for pair: Array in COLLEGE_EXAM:
		_add_topic(result, "mod_02", 10, str(pair[0]), int(pair[1]))
	return result

static func _add_topic(result: Dictionary, module_id: String, stage: int, concept: String, lesson: int) -> void:
	var source: Array = CONCEPTS[concept]
	result[key(module_id, stage, concept, lesson)] = {"module": module_id, "stage": stage, "concept": concept, "lesson": lesson, "title": source[0], "why": source[1], "rule": source[2], "example": "Before trying a new situation, identify the source you can independently check, the exact action requested, and the permission or evidence still missing. This is a stage-specific extension of the lesson above."}

static func key(module_id: String, stage: int, concept: String, lesson: int) -> String:
	return "%s_s%d_%s_l%d" % [module_id, stage, concept, lesson]

static func mappings() -> Dictionary:
	var result: Dictionary = {}
	for module_id: String in PLANS:
		for stage: int in PLANS[module_id]:
			var entries: Array = PLANS[module_id][stage]
			for index: int in entries.size():
				var pair: Array = entries[index]
				result["%s_stage%02d_incident%02d" % [module_id.replace("_", ""), stage, index + 1]] = key(module_id, stage, str(pair[0]), int(pair[1]))
	for group: String in EMAIL_EXAM:
		var entries: Array = EMAIL_EXAM[group]
		for index: int in entries.size():
			var concept: String = str(entries[index])
			result["mod01_%s_%02d" % [group, index + 1]] = key("mod_01", 10, concept, int(EMAIL_LESSONS[concept]))
	for index: int in COLLEGE_EXAM.size():
		var pair: Array = COLLEGE_EXAM[index]
		result["mod02_final_%02d" % [index + 1]] = key("mod_02", 10, str(pair[0]), int(pair[1]))
	return result

static func questions(topic: Dictionary) -> Array[Dictionary]:
	var concept: String = str(topic.get("concept", ""))
	var result: Array[Dictionary] = []
	if not CONCEPTS.has(concept):
		return result
	var rows: Array = CONCEPTS[concept][3]
	for index: int in rows.size():
		var row: Array = rows[index]
		# Shared across modules too: the same exact practice is not new evidence.
		result.append({"id": "transfer_%s_%d_v1" % [concept, index], "question": row[0], "options": row[1], "correct": row[2], "feedback": row[3]})
	return result
