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
            "What is smishing?",
            [
                "Phone-call fraud",
                "Social engineering using SMS or messaging apps",
                "Malware that attacks SIM cards",
                "Email spoofing",
            ],
            1,
            "easy",
            "recognition",
        ),
        _mc(
            2,
            SMISHING,
            'You receive:\n\n"You won ₱50,000! Claim now."\n\nYou never entered a contest.\n\nWhat is most likely happening?',
            [
                "Account verification",
                "Software update",
                "Bank notification",
                "Smishing bait",
            ],
            3,
            "easy",
            "recognition",
        ),
        _mc(
            3,
            SMISHING,
            "A text asks you to send your OTP. What should you do?",
            [
                "Never provide the OTP and verify independently",
                "Send it",
                "Send only half",
                "Ask why they need it first",
            ],
            0,
            "easy",
            "safe_response",
        ),
        _mc(
            4,
            SMISHING,
            "A delivery message includes an unexpected link. Safest response?",
            [
                "Open the link",
                "Reply with your address",
                "Use the courier's official site/app independently",
                "Ask someone else to open it",
            ],
            2,
            "easy",
            "safe_response",
        ),
        _mc(
            5,
            SMISHING,
            "Why can shortened URLs be risky?",
            [
                "They always contain malware",
                "They cannot use HTTPS",
                "They only work on phones",
                "They hide the actual destination",
            ],
            3,
            "medium",
            "url_analysis",
        ),
        _mc(
            6,
            SMISHING,
            "A bank SMS appears in the same conversation thread as legitimate bank notifications.\n\nDoes that guarantee authenticity?",
            [
                "Yes",
                "No, sender information may be spoofed",
                "Only on Android",
                "Yes, if a bank logo appears",
            ],
            1,
            "medium",
            "sender_verification",
        ),
        _mc(
            7,
            SMISHING,
            'A message says:\n\n"Your SIM expires tonight. Verify immediately."\n\nBest action?',
            [
                "Open the provided link",
                "Reply with your PIN",
                "Contact your carrier using an official channel",
                "Forward it to friends",
            ],
            2,
            "medium",
            "safe_response",
        ),
        _mc(
            8,
            SMISHING,
            "Your friend's real Messenger account sends an unusual login link.\n\nWhat may have happened?",
            [
                "Their account could be compromised",
                "The link must be safe",
                "Messenger verified the link",
                "Friends cannot send malicious links",
            ],
            0,
            "medium",
            "recognition",
        ),
        _mc(
            9,
            SMISHING,
            'Someone messages:\n\n"Mom, new number. I lost my phone. Send ₱5,000."\n\nBest verification?',
            [
                "Ask for your birthday",
                "Send ₱500 first",
                "Ask for a selfie",
                "Contact your mother through an existing trusted channel",
            ],
            3,
            "medium",
            "verification",
        ),
        _mc(
            10,
            SMISHING,
            "Which request is most suspicious?",
            [
                "Open the official app to review your transaction.",
                "Reply with your OTP to cancel this transaction.",
                "Your monthly statement is available.",
                "Visit a branch if you need assistance.",
            ],
            1,
            "medium",
            "recognition",
        ),
        _mc(
            11,
            SMISHING,
            'A QR code arrives by SMS for "account verification."\n\nWhat should you do?',
            [
                "Scan it with another phone",
                "Scan it while using mobile data",
                "Verify through the official service instead",
                "Scan it but don't type anything",
            ],
            2,
            "medium",
            "safe_response",
        ),
        _mc(
            12,
            SMISHING,
            "A message correctly identifies your name and recent online purchase.\n\nDoes that prove legitimacy?",
            [
                "Yes",
                "Only if the amount is correct",
                "Yes, because scammers do not know purchase information",
                "No; personal information can be leaked or obtained elsewhere",
            ],
            3,
            "hard",
            "evidence_evaluation",
        ),
        _mc(
            13,
            SMISHING,
            "A sender claims to be your bank and provides a link using HTTPS.\n\nWhat does HTTPS prove?",
            [
                "The sender is your bank",
                "The connection to that website is encrypted, not that the site is legitimate",
                "The site has been approved by the bank",
                "Your OTP is safe to enter",
            ],
            1,
            "hard",
            "url_analysis",
        ),
        _mc(
            14,
            SMISHING,
            "Which is the strongest verification?",
            [
                "Opening your bank's official app independently",
                "Replying to the suspicious message",
                "Calling the number contained in the message",
                "Checking whether the sender knows your name",
            ],
            0,
            "hard",
            "verification",
        ),
        _mc(
            15,
            SMISHING,
            "What feature connects most smishing attacks?",
            [
                "They always contain spelling errors",
                "They always request money",
                "They attempt to trigger an unsafe action through a message",
                "They always use shortened links",
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
            "Vishing primarily uses:",
            [
                "Voice calls",
                "Email",
                "USB drives",
                "Websites only",
            ],
            0,
            "easy",
            "recognition",
        ),
        _mc(
            2,
            VISHING,
            "A bank caller asks for your OTP.\n\nWhat should you do?",
            [
                "Provide it",
                "Give only half",
                "Refuse and verify independently",
                "Text it instead",
            ],
            2,
            "easy",
            "credential_protection",
        ),
        _mc(
            3,
            VISHING,
            "Can caller ID alone prove who is calling?",
            [
                "Yes",
                "No",
                "Only for banks",
                "Only for local calls",
            ],
            1,
            "easy",
            "sender_verification",
        ),
        _mc(
            4,
            VISHING,
            "A caller demands payment using gift cards to avoid arrest.\n\nWhat is most likely?",
            [
                "A normal government procedure",
                "A bank verification process",
                "Technical support",
                "Vishing/social engineering",
            ],
            3,
            "easy",
            "recognition",
        ),
        _mc(
            5,
            VISHING,
            'A caller says:\n\n"Do not hang up or your account will be permanently closed."\n\nWhat tactic is being used?',
            [
                "Encryption",
                "Malware",
                "Urgency and pressure",
                "Password cracking",
            ],
            2,
            "medium",
            "recognition",
        ),
        _mc(
            6,
            VISHING,
            "Someone claiming to be IT support asks for remote access to your computer.\n\nSafest response?",
            [
                "Refuse and independently contact IT",
                "Allow access",
                "Give temporary access",
                "Share your password instead",
            ],
            0,
            "medium",
            "safe_response",
        ),
        _mc(
            7,
            VISHING,
            "A caller knows your full name.\n\nWhat does this prove?",
            [
                "They are legitimate",
                "They work for your bank",
                "They have passed authentication",
                "Very little; names can be publicly available or leaked",
            ],
            3,
            "medium",
            "evidence_evaluation",
        ),
        _mc(
            8,
            VISHING,
            "A caller claiming to be your bank asks for your CVV.\n\nBest response?",
            [
                "Provide it if they know your name",
                "Refuse and contact the bank independently",
                "Provide only one digit",
                "Ask them to call again",
            ],
            1,
            "medium",
            "credential_protection",
        ),
        _mc(
            9,
            VISHING,
            "You receive a suspicious call from a displayed bank number.\n\nHow should you verify it?",
            [
                "Call the official number from your card or bank app",
                "Redial the displayed number",
                "Ask the caller to send an SMS",
                "Stay on the line",
            ],
            0,
            "medium",
            "verification",
        ),
        _mc(
            10,
            VISHING,
            "A caller creates panic and repeatedly prevents you from hanging up.\n\nWhy?",
            [
                "To keep your phone connected technically",
                "To improve call quality",
                "To reduce the time you have to think and verify",
                "To protect your account",
            ],
            2,
            "medium",
            "recognition",
        ),
        _mc(
            11,
            VISHING,
            "Someone claiming to be the registrar asks for your portal password.\n\nBest response?",
            [
                "Give the password",
                "Text the password later",
                "Give an old password",
                "Verify with the registrar through an official channel",
            ],
            3,
            "medium",
            "credential_protection",
        ),
        _mc(
            12,
            VISHING,
            "A caller sounds exactly like a family member asking for emergency money.\n\nWhat should you do?",
            [
                "Trust the voice",
                "Verify using another established contact method",
                "Send a smaller amount",
                "Ask them to repeat your name",
            ],
            1,
            "hard",
            "verification",
        ),
        _mc(
            13,
            VISHING,
            "A caller knows your name, school and date of birth.\n\nWhat is the correct conclusion?",
            [
                "Identity is confirmed",
                "The call is probably legitimate",
                "Information knowledge alone does not prove identity",
                "It is safe to provide an OTP",
            ],
            2,
            "hard",
            "evidence_evaluation",
        ),
        _mc(
            14,
            VISHING,
            'Why is "stay on the line and don\'t tell anyone" especially suspicious?',
            [
                "Isolation prevents independent verification",
                "Legitimate organizations cannot use phones",
                "Calls longer than five minutes are fraudulent",
                "Banks never give instructions",
            ],
            0,
            "hard",
            "recognition",
        ),
        _mc(
            15,
            VISHING,
            "What principle best protects against vishing?",
            [
                "Trust calls from known numbers",
                "Never rely solely on information provided by the caller to verify the caller",
                "Answer security questions quickly",
                "Only trust callers who know personal information",
            ],
            1,
            "hard",
            "transfer",
        ),
    ],
    "mod_04": [
        _mc(
            1,
            PRETEXTING,
            "What is pretexting?",
            [
                "Guessing passwords",
                "Sending malware automatically",
                "Encrypting files",
                "Creating a believable fake identity or story to obtain information/access",
            ],
            3,
            "easy",
            "recognition",
        ),
        _mc(
            2,
            PRETEXTING,
            "Someone wearing an IT uniform asks for your password.\n\nWhat should you do?",
            [
                "Give it because of the uniform",
                "Verify their identity and authorization independently",
                "Give part of it",
                "Ask another student to give theirs first",
            ],
            1,
            "easy",
            "credential_protection",
        ),
        _mc(
            3,
            PRETEXTING,
            "A stranger claims to be a student's parent and asks for private records.\n\nSafest action?",
            [
                "Follow official authorization procedures",
                "Provide them",
                "Give only basic information",
                "Ask whether they know the student's birthday",
            ],
            0,
            "easy",
            "safe_response",
        ),
        _mc(
            4,
            PRETEXTING,
            "Why do attackers often impersonate authority figures?",
            [
                "Authority bypasses passwords technically",
                "Executives have stronger computers",
                "Authority can make victims more likely to comply",
                "Emails from managers cannot be blocked",
            ],
            2,
            "easy",
            "recognition",
        ),
        _mc(
            5,
            PRETEXTING,
            'Someone claims:\n\n"I\'m the Dean\'s assistant. Send the student list immediately."\n\nWhat should you do?',
            [
                "Send it immediately",
                "Independently verify the request",
                "Send only names",
                "Ask whether it is urgent",
            ],
            1,
            "medium",
            "verification",
        ),
        _mc(
            6,
            PRETEXTING,
            "A person knows your supervisor's name and office number.\n\nDoes this establish authorization?",
            [
                "Yes",
                "Only during office hours",
                "Only if they know your name too",
                "No",
            ],
            3,
            "medium",
            "evidence_evaluation",
        ),
        _mc(
            7,
            PRETEXTING,
            "A delivery worker asks to enter a restricted room.\n\nWhat matters most?",
            [
                "Whether they are authorized to enter",
                "Whether they have a package",
                "Whether they look professional",
                "Whether they know someone's name",
            ],
            0,
            "medium",
            "verification",
        ),
        _mc(
            8,
            PRETEXTING,
            "What should you verify first when someone requests sensitive information?",
            [
                "Their clothing",
                "Their age",
                "Their authority and legitimate need for the information",
                "Their job title alone",
            ],
            2,
            "medium",
            "verification",
        ),
        _mc(
            9,
            PRETEXTING,
            'A "researcher" asks for your account password to complete a survey.\n\nBest response?',
            [
                "Provide an old password",
                "Create a temporary password",
                "Give only the username and password hint",
                "Refuse",
            ],
            3,
            "medium",
            "credential_protection",
        ),
        _mc(
            10,
            PRETEXTING,
            "Which is a common characteristic of pretexting?",
            [
                "A computer virus",
                "A believable story explaining why information or access is needed",
                "A damaged hard drive",
                "Automatic password guessing",
            ],
            1,
            "medium",
            "recognition",
        ),
        _mc(
            11,
            PRETEXTING,
            "An employee says their badge stopped working and asks you to let them inside.\n\nBest response?",
            [
                "Follow official access procedures",
                "Let them in",
                "Ask for their employee name only",
                "Enter with them",
            ],
            0,
            "medium",
            "safe_response",
        ),
        _mc(
            12,
            PRETEXTING,
            "An attacker has researched your organization and knows several real employee names.\n\nWhy does this strengthen pretexting?",
            [
                "Employee names bypass security systems",
                "It proves the attacker works there",
                "Accurate details make a fabricated story more believable",
                "It disables access control",
            ],
            2,
            "hard",
            "recognition",
        ),
        _mc(
            13,
            PRETEXTING,
            "A senior manager tells you to bypass normal security because the request is urgent.\n\nWhat should you do?",
            [
                "Follow the request because they outrank you",
                "Follow the required security process or seek formal authorization",
                "Bypass it temporarily",
                "Do it and report it later",
            ],
            1,
            "hard",
            "safe_response",
        ),
        _mc(
            14,
            PRETEXTING,
            "Which question is most important when evaluating a request?",
            [
                '"Does the person sound confident?"',
                '"Do they know my name?"',
                '"Are they being polite?"',
                '"Is this person independently verified and authorized to request this?"',
            ],
            3,
            "hard",
            "verification",
        ),
        _mc(
            15,
            PRETEXTING,
            "What is the fundamental weakness exploited by pretexting?",
            [
                "People's willingness to trust believable identities and stories",
                "Software bugs",
                "Weak Wi-Fi",
                "Old computers",
            ],
            0,
            "hard",
            "transfer",
        ),
    ],
    "mod_05": [
        _mc(
            1,
            BAITING,
            "What makes baiting different from many other attacks?",
            [
                "It always uses email",
                "It offers something attractive to encourage unsafe behavior",
                "It requires a password",
                "It requires physical access",
            ],
            1,
            "easy",
            "recognition",
        ),
        _mc(
            2,
            BAITING,
            'You find a USB labeled "Final Exam Answers."\n\nSafest action?',
            [
                "Turn it in without connecting it",
                "Open it",
                "Test it at home",
                "Format it first",
            ],
            0,
            "easy",
            "safe_response",
        ),
        _mc(
            3,
            BAITING,
            "A site offers expensive software completely free from an unknown source.\n\nWhat is the main risk?",
            [
                "It will download slowly",
                "It cannot work without internet",
                "Free software cannot run on Windows",
                "The download could contain malware",
            ],
            3,
            "easy",
            "attachment_awareness",
        ),
        _mc(
            4,
            BAITING,
            'A pop-up says:\n\n"Congratulations! You won a new phone!"\n\nWhat technique may be involved?',
            [
                "Encryption",
                "Firewalling",
                "Baiting",
                "Authentication",
            ],
            2,
            "easy",
            "recognition",
        ),
        _mc(
            5,
            BAITING,
            'Why might an attacker label a USB "Salary Information"?',
            [
                "To exploit curiosity",
                "To encrypt the USB",
                "To increase storage",
                "To make antivirus ignore it",
            ],
            0,
            "medium",
            "recognition",
        ),
        _mc(
            6,
            BAITING,
            "A file is named:\n\nFreeMovie.mp4.exe\n\nWhat is its actual executable extension?",
            [
                ".mp4",
                ".movie",
                ".free",
                ".exe",
            ],
            3,
            "medium",
            "attachment_awareness",
        ),
        _mc(
            7,
            BAITING,
            "Why can pirated software be dangerous?",
            [
                "Paid software cannot contain malware",
                "Modified installers can hide malicious code",
                "Antivirus automatically disables pirated programs",
                "Pirated programs cannot connect to the internet",
            ],
            1,
            "medium",
            "attachment_awareness",
        ),
        _mc(
            8,
            BAITING,
            "A QR code on a poster promises free Wi-Fi.\n\nSafest response?",
            [
                "Scan immediately",
                "Let a friend scan it",
                "Verify the Wi-Fi details with an official source",
                "Scan while disconnected from Wi-Fi",
            ],
            2,
            "medium",
            "safe_response",
        ),
        _mc(
            9,
            BAITING,
            "A stranger gives students free USB drives.\n\nWhat is the key security concern?",
            [
                "They may contain malicious files or programs",
                "USB drives cannot store documents",
                "Free electronics are illegal",
                "The USB may be too small",
            ],
            0,
            "medium",
            "attachment_awareness",
        ),
        _mc(
            10,
            BAITING,
            "Which is the best example of baiting?",
            [
                '"Give me your OTP or your account will close."',
                "A fake bank phone call",
                "An attacker pretending to be IT",
                'A USB labeled "Confidential Exams" deliberately left in a hallway',
            ],
            3,
            "medium",
            "recognition",
        ),
        _mc(
            11,
            BAITING,
            'Someone sends you a "free premium game" installer.\n\nBefore running it, what is most important?',
            [
                "Whether the graphics look good",
                "Whether it came from a trusted and authorized source",
                "Whether your friend likes the game",
                "Whether the file size is small",
            ],
            1,
            "medium",
            "verification",
        ),
        _mc(
            12,
            BAITING,
            "What do malicious USBs, free downloads, prize links and enticing QR codes have in common?",
            [
                "They all require passwords",
                "They all attack phones",
                "They exploit curiosity or desire to trigger unsafe actions",
                "They all contain ransomware",
            ],
            2,
            "hard",
            "transfer",
        ),
        _mc(
            13,
            BAITING,
            "A trusted friend gives you cracked software that works correctly on their computer.\n\nWhat should you conclude?",
            [
                "It must be safe",
                "It is safe if antivirus finds nothing",
                "Your friend's computer proves its authenticity",
                "Successful execution does not prove the software is free from malicious code",
            ],
            3,
            "hard",
            "evidence_evaluation",
        ),
        _mc(
            14,
            BAITING,
            "Why is plugging a suspicious USB into an unused computer still unsafe?",
            [
                "Malicious code may still execute or spread",
                "USB attacks only work once",
                "Unused computers cannot read USB devices",
                "Formatting happens automatically",
            ],
            0,
            "hard",
            "attachment_awareness",
        ),
        _mc(
            15,
            BAITING,
            "Which best describes the defensive principle against baiting?",
            [
                "Avoid every free item",
                "Do not let curiosity or rewards bypass normal trust and verification procedures",
                "Only use USBs at school",
                "Download files only at night",
            ],
            1,
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
