"""Per-module lesson pre-test banks. Answers stay server-side so BKT cannot be spoofed."""

from __future__ import annotations

import json

MODULE_IDS = ("mod_01", "mod_02", "mod_03", "mod_04", "mod_05")

MODULE_TOPICS = {
    "mod_01": "Phishing",
    "mod_02": "Smishing",
    "mod_03": "Vishing",
    "mod_04": "Pretexting",
    "mod_05": "Baiting",
}

MODULE_1_ID = "mod_01"

PHISHING = "Phishing"
SMISHING = "Smishing"
VISHING = "Vishing"
PRETEXTING = "Pretexting"
BAITING = "Baiting"


def _mc(
    qid: int,
    topic: str,
    text: str,
    options: list[str],
    answer: int,
    difficulty: str = "",
    skill: str = "",
) -> dict:
    row = {
        "id": qid,
        "topic": topic,
        "type": "multiple_choice",
        "text": text,
        "options": options,
        "answer": answer,
    }
    if difficulty:
        row["difficulty"] = difficulty
    if skill:
        row["skill"] = skill
    return row


MODULE_BANKS: dict[str, list[dict]] = {
    "mod_01": [
        _mc(
            1,
            PHISHING,
            'You receive an email saying:\n\n"Your school account will be deleted today. Verify now."\n\nWhich detail is the strongest warning sign?',
            [
                "The email mentions your school",
                "It contains your name",
                "It creates urgency to make you act quickly",
                "It was sent in the morning",
            ],
            2,
            "easy",
            "recognition",
        ),
        _mc(
            2,
            PHISHING,
            "What best describes phishing?",
            [
                "Pretending to be trustworthy through messages to steal information or cause an unsafe action",
                "Physically stealing someone's device",
                "Guessing passwords automatically",
                "Blocking access to a website",
            ],
            0,
            "easy",
            "recognition",
        ),
        _mc(
            3,
            PHISHING,
            "An email says it is from your university, but the sender is:\n\nregistrar.school@gmail.com\n\nWhat should concern you most?",
            [
                'It contains "registrar"',
                "It has no attachment",
                "It contains your name",
                "It uses Gmail rather than the school's expected official domain",
            ],
            3,
            "easy",
            "sender_verification",
        ),
        _mc(
            4,
            PHISHING,
            "A suspicious email asks you to log in immediately. What is safest?",
            [
                "Click the email link",
                "Open the official website yourself",
                "Reply asking whether it is legitimate",
                "Forward it to a friend first",
            ],
            1,
            "easy",
            "safe_response",
        ),
        _mc(
            5,
            PHISHING,
            "Which URL is most suspicious?",
            [
                "https://school.edu.ph.login-verification.net",
                "https://portal.school.edu.ph",
                "https://school.edu.ph/login",
                "https://library.school.edu.ph",
            ],
            0,
            "medium",
            "url_analysis",
        ),
        _mc(
            6,
            PHISHING,
            "An email shows:\n\nDisplay name: University Registrar\nActual address: studentverify247@gmail.com\n\nWhat should you trust when checking the sender?",
            [
                "Display name",
                "Profile photo",
                "Actual email address and domain",
                "Email signature",
            ],
            2,
            "medium",
            "sender_verification",
        ),
        _mc(
            7,
            PHISHING,
            'You hover over "Open Student Portal" and see:\n\nhttps://school-login.secure-account.xyz\n\nWhat should you do?',
            [
                "Open it because HTTPS is shown",
                "Avoid it and access the portal independently",
                "Open it in private browsing",
                "Ask a friend to test it",
            ],
            1,
            "medium",
            "link_analysis",
        ),
        _mc(
            8,
            PHISHING,
            "An unexpected email contains:\n\nClassSchedule.pdf.exe\n\nWhy is this dangerous?",
            [
                "PDF files are unsafe",
                "Long filenames cannot be trusted",
                "School files should always be ZIP files",
                ".exe indicates the file can execute a program",
            ],
            3,
            "medium",
            "attachment_awareness",
        ),
        _mc(
            9,
            PHISHING,
            "Your instructor's real name appears in an email asking you to open a project document. What would make it most suspicious?",
            [
                "It references your real project",
                "It uses correct grammar",
                "The email comes from an unfamiliar domain",
                "It contains the instructor's signature",
            ],
            2,
            "medium",
            "recognition",
        ),
        _mc(
            10,
            PHISHING,
            "What is the best way to verify an unexpected request from your instructor?",
            [
                "Contact the instructor using a previously known channel",
                "Reply to the suspicious email",
                "Click the link to inspect it",
                "Check whether the message uses the instructor's photo",
            ],
            0,
            "medium",
            "verification",
        ),
        _mc(
            11,
            PHISHING,
            "An email claiming to be IT support asks for your password.\n\nWhat should you do?",
            [
                "Send it if the address looks official",
                "Send only part of it",
                "Change it and send the new password",
                "Refuse and verify with IT independently",
            ],
            3,
            "medium",
            "credential_protection",
        ),
        _mc(
            12,
            PHISHING,
            "Consider:\n\nhttps://accounts.school.edu.ph.security-check.com\n\nWho controls the main registered domain?",
            [
                "school.edu.ph",
                "security-check.com",
                "accounts.school.edu.ph",
                "accounts",
            ],
            1,
            "hard",
            "url_analysis",
        ),
        _mc(
            13,
            PHISHING,
            "You clicked a phishing link and entered your password. What should you do next?",
            [
                "Delete the email",
                "Restart the browser",
                "Change the password using the legitimate site and report the incident",
                "Wait to see whether anything happens",
            ],
            2,
            "hard",
            "compromised_account",
        ),
        _mc(
            14,
            PHISHING,
            "Which provides the weakest evidence that an email is legitimate?",
            [
                "It uses the organization's logo and your real name",
                "You independently confirmed the request with the sender",
                "The domain matches the organization's official domain",
                "The request appears inside an official account portal",
            ],
            0,
            "hard",
            "evidence_evaluation",
        ),
        _mc(
            15,
            PHISHING,
            "An email looks legitimate but asks you to urgently download confidential documents from an unfamiliar domain.\n\nWhat should determine your decision?",
            [
                "How professional the email looks",
                "Whether the action and destination can be independently verified",
                "Whether it contains your correct name",
                "Whether the attachment is small",
            ],
            1,
            "hard",
            "transfer",
        ),
    ],
    "mod_02": [
        _mc(
            1,
            SMISHING,
            'You receive this text:\n\n"GCash Security: Your wallet has been locked. Tap the link below immediately to restore access."\n\nWhat makes this most likely a smishing attempt?',
            [
                "It mentions a mobile wallet",
                "It uses a message to pressure you into taking an action",
                "It was received on a phone",
                'It contains the word "Security"',
            ],
            1,
            "easy",
            "recognition",
        ),
        _mc(
            2,
            SMISHING,
            'A text claiming to be from your bank says:\n\n"We detected an unauthorized payment. Reply with the 6-digit OTP we just sent so we can cancel it."\n\nWhat should you do?',
            [
                "Send the OTP because you did not make the payment",
                "Send only the first three digits",
                "Ask the sender to prove they work for the bank",
                "Do not send the OTP and verify through the bank's official channel",
            ],
            3,
            "easy",
            "code_protection",
        ),
        _mc(
            3,
            SMISHING,
            "You receive an unexpected delivery text containing a link to pay a small redelivery fee.\n\nWhat is the safest first action?",
            [
                "Open the courier's official app or website yourself and check the tracking information",
                "Open the link because the fee is small",
                "Reply asking whether the message is real",
                "Forward the link to someone else to test it",
            ],
            0,
            "easy",
            "safe_response",
        ),
        _mc(
            4,
            SMISHING,
            "Which message is the strongest example of smishing?",
            [
                "Your school app displays your normal class schedule",
                "A courier app you already installed reports that your parcel was delivered",
                "An unexpected SMS threatens to suspend your account unless you open a link",
                "Your phone displays a low-battery warning",
            ],
            2,
            "easy",
            "recognition",
        ),
        _mc(
            5,
            SMISHING,
            'You receive:\n\n"Your student allowance is ready. Confirm at bit.ly/student-pay before 5 PM."\n\nWhy should the link increase your suspicion?',
            [
                "All bit.ly links are malware",
                "Short links cannot use encryption",
                "Schools cannot send links by SMS",
                "The shortened link hides the actual destination",
            ],
            3,
            "medium",
            "link_analysis",
        ),
        _mc(
            6,
            SMISHING,
            'A message begins:\n\n"GCash Alert"\n\nand uses the correct company name and logo.\n\nWhat should you conclude?',
            [
                "The message is legitimate because the brand is correct",
                "A familiar brand name alone does not prove the sender is legitimate",
                "The message is legitimate if it arrived in the morning",
                "Companies cannot be impersonated by text",
            ],
            1,
            "medium",
            "sender_evaluation",
        ),
        _mc(
            7,
            SMISHING,
            'You receive:\n\n"Your SIM will be disabled in 30 minutes. Verify at telecom-security-help.com."\n\nWhat is the safest action?',
            [
                "Open the link but do not enter a password",
                "Reply to the sender asking for more information",
                "Contact your carrier through its official app, website, or known number",
                "Ask a friend to open the link first",
            ],
            2,
            "medium",
            "safe_response",
        ),
        _mc(
            8,
            SMISHING,
            'Someone messages you from a new number:\n\n"Hi, this is Mom. My phone broke. Please send ₱4,000 now."\n\nWhat is the strongest way to verify the request?',
            [
                "Contact your mother through a previously trusted method or another trusted family member",
                "Ask the sender to tell you your birthday",
                "Send a smaller amount first",
                "Ask for a photo",
            ],
            0,
            "medium",
            "verification",
        ),
        _mc(
            9,
            SMISHING,
            'A text says:\n\n"Your ₱6,800 charge becomes permanent in 10 minutes. Tap now for a refund."\n\nWhat social-engineering technique is being used most clearly?',
            [
                "Encryption",
                "Password cracking",
                "Software installation",
                "Urgency and fear of losing money",
            ],
            3,
            "medium",
            "urgency_detection",
        ),
        _mc(
            10,
            SMISHING,
            "Which message should you be most likely to report as suspicious?",
            [
                '"Your monthly pass renews tomorrow. View details in the app you already use."',
                '"Your wallet is frozen. Send your OTP here within five minutes."',
                '"Your parcel was delivered successfully."',
                '"Your bookstore reservation is available for pickup at the counter."',
            ],
            1,
            "medium",
            "triage",
        ),
        _mc(
            11,
            SMISHING,
            'You receive:\n\n"MetroRide refund: metro-ride-help.tk/refund"\n\nThe real company\'s known website is:\n\n"metroride.ph"\n\nWhat is the strongest warning sign?',
            [
                'The text uses the word "refund"',
                "The message was sent by SMS",
                "The destination uses a different domain from the company's known domain",
                "The link contains a slash",
            ],
            2,
            "medium",
            "link_analysis",
        ),
        _mc(
            12,
            SMISHING,
            "A message knows your full name, phone number, and the store where you recently made a purchase.\n\nDoes this prove the text is legitimate?",
            [
                "Yes, because scammers cannot know recent purchases",
                "Yes, if your phone number is also correct",
                "Only if the message has no spelling errors",
                "No; personal information can be leaked, purchased, guessed, or obtained elsewhere",
            ],
            3,
            "hard",
            "evidence_evaluation",
        ),
        _mc(
            13,
            SMISHING,
            'Your school normally uses:\n\n"westfield.edu"\n\nWhich link is most suspicious?',
            [
                "https://portal.westfield.edu",
                "https://westfield.edu.verify-account.net",
                "https://library.westfield.edu",
                "https://westfield.edu",
            ],
            1,
            "hard",
            "domain_analysis",
        ),
        _mc(
            14,
            SMISHING,
            'A suspicious bank text contains a phone number and says:\n\n"Call this number immediately if this transaction wasn\'t yours."\n\nWhat is the strongest verification method?',
            [
                "Ignore the supplied number and use the number from the official banking app, card, or website",
                "Call the number in the text because it claims to be fraud support",
                "Reply to the text first",
                "Search the phone number inside the message",
            ],
            0,
            "hard",
            "verification",
        ),
        _mc(
            15,
            SMISHING,
            "Which feature is common across fake delivery texts, fake wallet warnings, prize texts, and account-suspension texts?",
            [
                "They always contain shortened URLs",
                "They always ask directly for money",
                "They use a message to create trust, fear, urgency, or temptation so the victim takes an unsafe action",
                "They always impersonate a bank",
            ],
            2,
            "hard",
            "transfer",
        ),
    ],
    "mod_03": [
        _mc(
            1,
            VISHING,
            "Which situation is the strongest example of vishing?",
            [
                "An unexpected caller claims to be your bank and asks you to read a one-time code",
                "A website displays a fake login page",
                "An email contains a suspicious attachment",
                "A stranger leaves a USB drive in a hallway",
            ],
            0,
            "easy",
            "recognition",
        ),
        _mc(
            2,
            VISHING,
            'A caller says:\n\n"This is your bank\'s fraud desk. A ₱12,000 transfer is pending. Read me the 6-digit code we just sent so I can cancel it."\n\nWhat should you do?',
            [
                "Read the code because the caller is trying to stop fraud",
                "Give only part of the code",
                "Do not give the code; hang up and contact the bank independently",
                "Ask the caller to repeat your account number first",
            ],
            2,
            "easy",
            "code_protection",
        ),
        _mc(
            3,
            VISHING,
            'Your phone displays "WESTFIELD REGISTRAR" when someone calls.\n\nWhat does this prove?',
            [
                "The caller definitely works for the school",
                "Very little; caller ID information can be spoofed or manipulated",
                "The phone company verified the caller",
                "The call is legitimate if the caller knows your name",
            ],
            1,
            "easy",
            "caller_id",
        ),
        _mc(
            4,
            VISHING,
            "What is the safest way to verify an unexpected bank call?",
            [
                "Ask the caller more security questions",
                "Call the number shown in your recent-call list",
                "Ask the caller to send you a text",
                "Hang up and dial the bank using a number from your card or official app",
            ],
            3,
            "easy",
            "verification",
        ),
        _mc(
            5,
            VISHING,
            "A caller claiming to be your bank knows the last four digits of a card you actually own.\n\nWhat should you conclude?",
            [
                "They have proven they work for the bank",
                "Knowing one true detail does not prove the caller's identity",
                "The call is safe unless they ask for your password",
                "Only bank employees can know partial card information",
            ],
            1,
            "medium",
            "evidence_evaluation",
        ),
        _mc(
            6,
            VISHING,
            'A caller says:\n\n"Do not hang up. If you disconnect, we cannot stop the transaction."\n\nWhat is the safest response?',
            [
                "Hang up and independently contact the real organization",
                "Stay on the line until the problem is fixed",
                "Give the caller basic information but no password",
                "Put the call on speaker and ask a friend",
            ],
            0,
            "medium",
            "pressure_resistance",
        ),
        _mc(
            7,
            VISHING,
            "Why might a scammer ask you to read a one-time code aloud?",
            [
                "To check whether your phone works",
                "To identify your mobile network",
                "To create a support ticket",
                "The code may allow them to approve a login, payment, or account change",
            ],
            3,
            "medium",
            "consequence_awareness",
        ),
        _mc(
            8,
            VISHING,
            'Campus IT calls and says:\n\n"Your account is logged in from another city. Stay on the line and read the code that just arrived."\n\nWhat should you do?',
            [
                "Read the code if they know your student number",
                "Ask for their employee ID, then continue",
                "Hang up and contact campus IT using the school's known contact information",
                "Wait for another code and give them that one instead",
            ],
            2,
            "medium",
            "safe_response",
        ),
        _mc(
            9,
            VISHING,
            "Which situation provides the strongest reason to trust a support call?",
            [
                "The caller knows your full name",
                "You initiated the call yourself using an independently verified official number",
                "The correct company name appears on caller ID",
                "The caller knows information about your account",
            ],
            1,
            "medium",
            "verification",
        ),
        _mc(
            10,
            VISHING,
            'A caller says:\n\n"Act now. Don\'t hang up and don\'t tell anyone in the room."\n\nWhy is this especially suspicious?',
            [
                "Legitimate companies never make phone calls",
                "Real employees cannot discuss account problems",
                "Calls lasting several minutes are usually scams",
                "Urgency and isolation reduce your chance to stop and independently verify the claim",
            ],
            3,
            "medium",
            "pressure_resistance",
        ),
        _mc(
            11,
            VISHING,
            "Which sequence most closely matches the vishing playbook taught in the lesson?",
            [
                "Borrow a trusted identity → mention a true detail → prevent callback → request a secret/code",
                "Send malware → encrypt files → demand payment → delete backups",
                "Leave a USB → wait for someone to connect it → install malware",
                "Create a fake website → advertise it → wait for search traffic",
            ],
            0,
            "medium",
            "playbook_recognition",
        ),
        _mc(
            12,
            VISHING,
            "A caller appears as your bank's real name, knows your name and partial card number, and describes a purchase you recently made. They then ask you to stay on the line and read a code.\n\nWhat is the strongest conclusion?",
            [
                "The accurate information proves the caller is legitimate",
                "It is safe because the caller only wants a temporary code",
                "The known details do not prove identity; the code request and refusal to let you verify independently are major warning signs",
                "The call is legitimate if the transaction amount is correct",
            ],
            2,
            "hard",
            "evidence_evaluation",
        ),
        _mc(
            13,
            VISHING,
            'A caller claiming to be from your bank says:\n\n"You can call us back, but only using the number currently shown on your screen."\n\nWhat should you do?',
            [
                "Call that number because it matches caller ID",
                "Ask the caller to call again later",
                "Save the displayed number before hanging up",
                "Ignore the supplied number and use an independently known official number",
            ],
            3,
            "hard",
            "verification",
        ),
        _mc(
            14,
            VISHING,
            "A caller claiming to be your registrar gives you a believable ticket number and correctly states your course. They insist your enrollment will be cancelled unless you verify immediately.\n\nWhat is the strongest next step?",
            [
                "Give limited information because they know your course",
                "End the call and verify the issue through the registrar's official contact channel",
                "Ask the caller to tell you another private fact",
                "Stay connected while opening the school portal",
            ],
            1,
            "hard",
            "verification",
        ),
        _mc(
            15,
            VISHING,
            "What feature best connects fake bank calls, fake school IT calls, and fake registrar calls?",
            [
                "They always use the same phone number",
                "They always ask directly for money",
                "They borrow trust and pressure the victim to say or approve something before independently checking",
                "They always use threatening language",
            ],
            2,
            "hard",
            "transfer",
        ),
    ],
    "mod_04": [
        _mc(
            1,
            PRETEXTING,
            "Which situation is the strongest example of pretexting?",
            [
                "A website automatically downloads malware",
                "Someone guesses your password repeatedly",
                "A text contains a shortened link",
                "A stranger invents a believable work role and story to convince you to unlock a restricted room",
            ],
            3,
            "easy",
            "recognition",
        ),
        _mc(
            2,
            PRETEXTING,
            'A visitor with a clipboard says:\n\n"I\'m from Facilities. We\'re doing a surprise key audit."\n\nWhat should you remember?',
            [
                "A clipboard proves they are working",
                "Their appearance and story do not prove their identity or authorization",
                "Surprise audits never happen",
                "Facilities workers never enter buildings",
            ],
            1,
            "easy",
            "role_verification",
        ),
        _mc(
            3,
            PRETEXTING,
            "A person claiming to be from Facilities asks you to unlock a staff closet and wait outside while they inspect it.\n\nWhat is the safest response?",
            [
                "Do not unlock it until their identity and authorization are verified",
                "Unlock it but remain nearby",
                "Ask whether the inspection will take long",
                "Let them enter if they know the building name",
            ],
            0,
            "easy",
            "access_control",
        ),
        _mc(
            4,
            PRETEXTING,
            "Someone says they are the dean's new assistant and asks you to approve a payment because the dean is currently in a meeting.\n\nWhat should you do?",
            [
                "Approve it because the dean is unavailable",
                "Approve a smaller amount first",
                "Wait and verify the request directly with the dean or authorized process",
                "Ask the assistant to promise the request is legitimate",
            ],
            2,
            "easy",
            "safe_response",
        ),
        _mc(
            5,
            PRETEXTING,
            'A visitor says:\n\n"I\'m with the accreditation team. Your professor already knows. She stepped out, so copy the class list from her laptop before she returns."\n\nWhat is the strongest warning sign?',
            [
                "Accreditation teams visit schools",
                "The story uses the professor's absence to justify accessing something you normally should not",
                "The visitor did not wear a uniform",
                "Class lists contain student names",
            ],
            1,
            "medium",
            "story_analysis",
        ),
        _mc(
            6,
            PRETEXTING,
            'A supposed administrator says:\n\n"Do not contact the dean. She\'s presenting right now and will be upset if this payment is delayed."\n\nWhy is this suspicious?',
            [
                "Administrators never handle payments",
                "Meetings cannot last long",
                "Payments cannot be made on phones",
                "The story discourages independent verification while creating pressure to comply",
            ],
            3,
            "medium",
            "authority_resistance",
        ),
        _mc(
            7,
            PRETEXTING,
            "A stranger claims to be helping your professor and asks you to copy a student list from the professor's unattended laptop.\n\nWhat should you do?",
            [
                "Refuse and wait for the professor or another authorized person to confirm the request",
                "Copy only student names",
                "Open the laptop but do not send anything",
                "Ask the stranger whether the data is confidential",
            ],
            0,
            "medium",
            "information_protection",
        ),
        _mc(
            8,
            PRETEXTING,
            "Which situation gives the strongest evidence that a person is authorized?",
            [
                "They know the building name",
                "They carry a clipboard and wear professional clothes",
                "Their identity and access request can be checked through an established school process",
                "They know the name of your professor",
            ],
            2,
            "medium",
            "verification",
        ),
        _mc(
            9,
            PRETEXTING,
            'A visitor says:\n\n"The inspection slot closes in ten minutes. If we miss it, your department will fail the audit."\n\nWhat role does this statement play in a pretexting attack?',
            [
                "It proves an official inspection exists",
                "It verifies the visitor's authority",
                "It protects the department from delays",
                "It creates urgency so you are less likely to stop and verify",
            ],
            3,
            "medium",
            "urgency_detection",
        ),
        _mc(
            10,
            PRETEXTING,
            "Which request is more suspicious?",
            [
                "A verified employee asks you to walk with them to a shared room",
                "A visitor asks you to unlock a restricted room and leave them alone inside",
                "A coworker waits while you use your own badge",
                "A staff member asks where the copy room is",
            ],
            1,
            "medium",
            "access_control",
        ),
        _mc(
            11,
            PRETEXTING,
            "Which sequence most closely matches the pretexting pattern taught in the lesson?",
            [
                "Borrow a trusted role → make the trusted person unavailable → request an unusual favor → add time pressure",
                "Send malware → encrypt files → demand payment → erase backups",
                "Call repeatedly → guess a password → lock the account",
                "Offer a prize → ask the victim to install software",
            ],
            0,
            "medium",
            "playbook_recognition",
        ),
        _mc(
            12,
            PRETEXTING,
            "A visitor knows your dean's name, carries a professional badge, and says the dean already approved a vendor payment. The dean is conveniently unavailable, and the visitor wants you to approve it on their phone immediately.\n\nWhat is the strongest conclusion?",
            [
                "Knowing the dean's name proves the story is probably legitimate",
                "The badge is enough if it looks professional",
                "The combination of borrowed authority, an unavailable decision-maker, unusual payment request, and urgency strongly suggests pretexting",
                "The payment is safe if the amount is small",
            ],
            2,
            "hard",
            "multi_cue_analysis",
        ),
        _mc(
            13,
            PRETEXTING,
            "Someone claiming to be from an accrediting team gives you their name, department, and a believable explanation for accessing a staff laptop.\n\nWhat is the strongest next step?",
            [
                "Let them use the laptop while you watch",
                "Verify the visit through a trusted school contact before allowing access",
                "Ask them one more question about the school",
                "Let them proceed if their story is detailed",
            ],
            1,
            "hard",
            "independent_verification",
        ),
        _mc(
            14,
            PRETEXTING,
            'A visitor claims they need access to a locked drawer while the adviser is away. They say:\n\n"The adviser already knows. Please don\'t message them yet because we\'re on a deadline."\n\nWhat should you do?',
            [
                "Open the drawer but stay nearby",
                "Give them only the documents they request",
                "Ask them to return the documents afterward",
                "Refuse to open it until the adviser or another authorized person independently confirms the request",
            ],
            3,
            "hard",
            "boundary_control",
        ),
        _mc(
            15,
            PRETEXTING,
            "What feature best connects fake Facilities audits, fake accreditation visits, and fake executive-assistant requests?",
            [
                "They always involve physical keys",
                "They always request money",
                "They create a believable role and situation designed to make you bypass normal verification or access rules",
                "They always require the real employee to leave the building",
            ],
            2,
            "hard",
            "transfer",
        ),
    ],
    "mod_05": [
        _mc(
            1,
            BAITING,
            "Which situation is the strongest example of baiting?",
            [
                "A caller pretends to be your bank",
                "A message threatens to close your account",
                'A USB labeled "Final Exam Answers" is left where students are likely to find it',
                "Someone repeatedly guesses your password",
            ],
            2,
            "easy",
            "recognition",
        ),
        _mc(
            2,
            BAITING,
            'You find a USB labeled "Grades 2026" in the computer lab.\n\nWhat should you do?',
            [
                "Do not plug it in; turn it over to the appropriate staff",
                "Plug it into a school computer instead of your own",
                "Open it only long enough to find the owner",
                "Take it home and scan it first",
            ],
            0,
            "easy",
            "unknown_media",
        ),
        _mc(
            3,
            BAITING,
            'A booth outside campus gives students free flash drives and says:\n\n"Plug it in now to claim the files we included."\n\nWhat is the main security concern?',
            [
                "Free flash drives usually have little storage",
                "School computers may not recognize the drive",
                "Students might lose the drive",
                "The free item could be bait containing malicious files or software",
            ],
            3,
            "easy",
            "gift_bait",
        ),
        _mc(
            4,
            BAITING,
            "A website offers a free cracked version of expensive school software.\n\nWhy is downloading it risky?",
            [
                "Free software cannot run on modern computers",
                "The installer may contain malware hidden behind the attractive free offer",
                "Cracked programs are always slower",
                "Schools automatically delete every free program",
            ],
            1,
            "easy",
            "suspicious_download",
        ),
        _mc(
            5,
            BAITING,
            'A hallway poster says:\n\n"FREE CAMPUS WI-FI — Scan this QR code to connect."\n\nWhat is the safest response?',
            [
                "Scan it because the poster is inside the school",
                "Ask a friend to scan it first",
                "Use the school's known Wi-Fi instructions or official portal instead of the unknown QR code",
                "Scan it only if your phone has antivirus software",
            ],
            2,
            "medium",
            "qr_safety",
        ),
        _mc(
            6,
            BAITING,
            "You receive a file named:\n\nFreeMovie.mp4.exe\n\nWhat is the strongest warning sign?",
            [
                "The filename is too long",
                "The final .exe means it is an executable program, not simply a video",
                "Movies cannot be downloaded",
                ".mp4 files are always malicious",
            ],
            1,
            "medium",
            "file_extension",
        ),
        _mc(
            7,
            BAITING,
            'A pop-up says:\n\n"Congratulations! You won a new phone. Download PrizeClaim.exe now."\n\nWhat is the safest conclusion?',
            [
                "The prize may be bait designed to make you run an unsafe file",
                "The prize is legitimate if the page uses school colors",
                "The offer is safe if no password is requested",
                "Winning a phone online is always impossible",
            ],
            0,
            "medium",
            "temptation",
        ),
        _mc(
            8,
            BAITING,
            'A classmate finds a USB labeled "Answer Key" and says:\n\n"We can test it on an old laptop first."\n\nWhat is the best response?',
            [
                "Use the old laptop because nothing important is stored there",
                "Scan the USB first, then open it",
                "Copy only the PDF files",
                "Do not plug unknown media into any device just to discover what is inside",
            ],
            3,
            "medium",
            "safe_handling",
        ),
        _mc(
            9,
            BAITING,
            "Which situation is most suspicious?",
            [
                "Your school provides software through its official student portal",
                "A teacher posts a file in the official learning system",
                'An unknown site promises a "free premium license" if you download and run its installer',
                "A verified store offers a normal student discount",
            ],
            2,
            "medium",
            "source_verification",
        ),
        _mc(
            10,
            BAITING,
            "You urgently need to charge your phone and see an unfamiliar public USB charging station.\n\nWhat is the safer choice when possible?",
            [
                "Connect because charging cables cannot transfer data",
                "Use your own charger/power source or another trusted charging method",
                "Connect only for five minutes",
                "Unlock the phone while charging so you can monitor it",
            ],
            1,
            "medium",
            "charging_safety",
        ),
        _mc(
            11,
            BAITING,
            "Why might an attacker leave several attractive USB drives around a school?",
            [
                "To increase the chance that curiosity or temptation causes someone to plug one into a device",
                "To give students free storage",
                "To test whether USB ports work",
                "To identify students who lose property",
            ],
            0,
            "medium",
            "attacker_goal",
        ),
        _mc(
            12,
            BAITING,
            'A USB labeled "Scholarship Applicants — Confidential" is found outside the registrar\'s office. It looks new and has the school logo printed on it.\n\nWhat is the strongest conclusion?',
            [
                "The school logo proves it belongs to the registrar",
                "It is safer because it was found near an office",
                "You may open it if you disconnect from Wi-Fi first",
                "The label, location, and logo may all be part of the bait; do not plug it in and report it appropriately",
            ],
            3,
            "hard",
            "multi_cue_analysis",
        ),
        _mc(
            13,
            BAITING,
            'A post says:\n\n"Download the leaked answer key before it gets deleted."\n\nThe file comes from an unknown file-sharing account.\n\nWhy is this dangerous?',
            [
                "Answer keys are always fake",
                "Curiosity and scarcity are being used to persuade you to download an untrusted file",
                "File-sharing services cannot contain school files",
                "Deleted files cannot contain malware",
            ],
            1,
            "hard",
            "scarcity_bait",
        ),
        _mc(
            14,
            BAITING,
            "Which situation gives the strongest reason to trust a software download?",
            [
                'The website says "100% virus free"',
                "Thousands of people supposedly downloaded it",
                "The software is obtained from the school's official portal or the vendor's independently verified official source",
                "The installer filename matches the product name",
            ],
            2,
            "hard",
            "trusted_download",
        ),
        _mc(
            15,
            BAITING,
            'What feature best connects a found "Grades" USB, a free cracked application, an unknown prize QR code, and a "you won a phone" download?',
            [
                "They all require USB ports",
                "They all steal passwords immediately",
                "They all depend on school computers",
                "They use something attractive, useful, or interesting to persuade the victim to perform a risky action",
            ],
            3,
            "hard",
            "transfer",
        ),
    ],
}


def questions_for_module(module_id: str) -> list[dict] | None:
    return MODULE_BANKS.get(str(module_id or "").strip())


def topic_for_module(module_id: str) -> str | None:
    return MODULE_TOPICS.get(str(module_id or "").strip())


def parse_module_pretests(raw) -> dict[str, bool]:
    data = raw
    if isinstance(raw, str) and raw.strip():
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            return {}
    completed: dict[str, bool] = {}
    if isinstance(data, dict):
        for key, value in data.items():
            module_id = str(key)
            if module_id in MODULE_IDS and bool(value):
                completed[module_id] = True
        return completed
    if isinstance(data, list):
        for item in data:
            module_id = str(item)
            if module_id in MODULE_IDS:
                completed[module_id] = True
    return completed


def completed_module_ids(raw) -> list[str]:
    completed = parse_module_pretests(raw)
    return [module_id for module_id in MODULE_IDS if completed.get(module_id)]


def public_question(row: dict) -> dict:
    payload = {
        "id": row["id"],
        "topic": row["topic"],
        "type": row["type"],
        "text": row["text"],
    }
    if "options" in row:
        payload["options"] = row["options"]
    return payload
