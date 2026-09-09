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


def _mc(qid: int, topic: str, text: str, options: list[str], answer: int) -> dict:
    return {
        "id": qid,
        "topic": topic,
        "type": "multiple_choice",
        "text": text,
        "options": options,
        "answer": answer,
    }


def _tf(qid: int, topic: str, text: str, answer: bool) -> dict:
    return {
        "id": qid,
        "topic": topic,
        "type": "true_false",
        "text": text,
        "answer": answer,
    }


PHISHING = "Phishing"
SMISHING = "Smishing"
VISHING = "Vishing"
PRETEXTING = "Pretexting"
BAITING = "Baiting"

MODULE_BANKS: dict[str, list[dict]] = {
    "mod_01": [
        _mc(
            1,
            PHISHING,
            "Which of the following is the STRONGEST password?",
            ["password123", "MyBirthday1990", "Tr!8#kL@mp99", "abc123"],
            2,
        ),
        _tf(
            2,
            PHISHING,
            "Using the same password across multiple sites is a best practice.",
            False,
        ),
        _mc(
            3,
            PHISHING,
            "What is phishing?",
            [
                "A virus that only infects USB drives",
                "A fake message, usually email, that tries to steal a click or a secret",
                "Official mail from your school's real domain",
                "A tool that encrypts your inbox",
            ],
            1,
        ),
        _tf(
            4,
            PHISHING,
            "A legitimate bank will email you asking for your full password.",
            False,
        ),
        _mc(
            5,
            PHISHING,
            "You get an unexpected email saying you won a prize. What is safest?",
            [
                "Click the button before the offer expires",
                "Reply with your student ID to claim it",
                "Ignore it or check through a website you typed yourself",
                "Forward it to classmates so they can win too",
            ],
            2,
        ),
        _tf(
            6,
            PHISHING,
            "Hovering over a link in an email can reveal the real destination URL.",
            True,
        ),
        _mc(
            7,
            PHISHING,
            "Which address is most likely a lookalike phishing domain?",
            [
                "support@school.edu.ph",
                "noreply@paypa1.com",
                "registrar@your-school.edu.ph",
                "help@gov.ph",
            ],
            1,
        ),
        _tf(
            8,
            PHISHING,
            "A padlock in the browser means the email sender is definitely who they claim to be.",
            False,
        ),
        _mc(
            9,
            PHISHING,
            "An email attachment named invoice.exe is most dangerous because:",
            [
                "EXE files are always documents",
                "It may run a program that installs malware",
                "Schools never send invoices",
                "Only ZIP files can carry malware",
            ],
            1,
        ),
        _tf(
            10,
            PHISHING,
            "The display name on an email can be faked even when the real address is different.",
            True,
        ),
        _mc(
            11,
            PHISHING,
            "You get a password-reset email you did not request. What should you do first?",
            [
                "Click the reset link to be safe",
                "Reply with the code so they know it is you",
                "Do not click; open the site yourself or ignore it",
                "Send them your current password to cancel it",
            ],
            2,
        ),
        _tf(
            12,
            PHISHING,
            "You should click a link immediately if the email says your account will close in 10 minutes.",
            False,
        ),
        _mc(
            13,
            PHISHING,
            "The best way to check if an email is real is to:",
            [
                "Trust the logo and greeting that uses your name",
                "Check the actual sender domain and known official channel",
                "See how urgent the subject line is",
                "Count how many classmates already clicked",
            ],
            1,
        ),
        _tf(
            14,
            PHISHING,
            "Forwarding a suspicious email to friends is a safe way to warn them.",
            False,
        ),
        _mc(
            15,
            PHISHING,
            "An email from “IT Support” asks you to reply with your portal password. You should:",
            [
                "Reply so they can fix your account",
                "Send the password in a new email you typed",
                "Not send the password and report the message",
                "Change the password to 123456 first, then send it",
            ],
            2,
        ),
    ],
    "mod_02": [
        _mc(
            1,
            SMISHING,
            "What is smishing?",
            [
                "Phishing that uses SMS or messaging apps",
                "A type of antivirus software",
                "A secure way to share one-time codes",
                "Voice calls from your real bank",
            ],
            0,
        ),
        _tf(
            2,
            SMISHING,
            "A legitimate bank will ask you to reply to a text with your OTP to verify your account.",
            False,
        ),
        _tf(
            3,
            SMISHING,
            "A delivery text from an unknown number with a tracking link is always safe to tap.",
            False,
        ),
        _mc(
            4,
            SMISHING,
            "A text says your SIM will be deactivated unless you tap a link. What is safest?",
            [
                "Tap immediately so you keep your number",
                "Reply STOP and include your PIN",
                "Do not tap; check with your carrier using a number you already trust",
                "Forward the text to a group chat for advice",
            ],
            2,
        ),
        _tf(
            5,
            SMISHING,
            "Your real bank will text a link and ask you to type your OTP on that page.",
            False,
        ),
        _mc(
            6,
            SMISHING,
            "You get “You won ₱50,000 — claim here.” The message is most likely:",
            [
                "A government rebate",
                "A smishing bait to steal a tap or a code",
                "Proof you entered a raffle",
                "Safe if it uses your nickname",
            ],
            1,
        ),
        _tf(
            7,
            SMISHING,
            "Shortened links in unexpected texts can hide a fake website.",
            True,
        ),
        _mc(
            8,
            SMISHING,
            "A text asks you to update payroll details via a link. You should:",
            [
                "Tap the link before it expires",
                "Reply with your bank account so they can help",
                "Ignore the link and confirm through an official app or person",
                "Call the number that sent the text and follow their steps",
            ],
            2,
        ),
        _tf(
            9,
            SMISHING,
            "If a text shows your phone number, that proves it came from your bank.",
            False,
        ),
        _mc(
            10,
            SMISHING,
            "A “missed package” text tells you to scan a QR code. Safest action?",
            [
                "Scan it so the parcel is not returned",
                "Ask a friend to scan it first",
                "Do not scan; track the parcel on the courier’s official site or app",
                "Scan it only on school Wi-Fi",
            ],
            2,
        ),
        _tf(
            11,
            SMISHING,
            "You should install an app from a random text link to keep your account active.",
            False,
        ),
        _mc(
            12,
            SMISHING,
            "How should you verify a text that claims to be from your bank?",
            [
                "Reply YES to confirm you are the owner",
                "Use the bank’s official app or a number printed on your card",
                "Tap the link and look for a padlock",
                "Ask the sender to text a selfie of their ID",
            ],
            1,
        ),
        _tf(
            13,
            SMISHING,
            "Smishing only happens on SMS, never on chat apps.",
            False,
        ),
        _mc(
            14,
            SMISHING,
            "A message from an unknown number says “Hi Mom, send load.” This is suspicious because:",
            [
                "Parents never buy load",
                "The sender may be pretending to be family to get money or a code",
                "Load can only be sent in person",
                "Unknown numbers cannot send texts",
            ],
            1,
        ),
        _tf(
            15,
            SMISHING,
            "You should share an OTP from a text with anyone who asks for it in chat.",
            False,
        ),
    ],
    "mod_03": [
        _mc(
            1,
            VISHING,
            "Vishing is social engineering that primarily happens through:",
            ["Email attachments", "Phone or voice calls", "USB drives", "QR codes only"],
            1,
        ),
        _tf(
            2,
            VISHING,
            "Caller ID is enough proof that the person on the phone is who they claim to be.",
            False,
        ),
        _tf(
            3,
            VISHING,
            "A government agency will demand gift-card payment over the phone to stop an arrest.",
            False,
        ),
        _mc(
            4,
            VISHING,
            "A “tech support” caller wants remote access to your computer. You should:",
            [
                "Allow it so they can remove a virus",
                "Give them your password so they can log in",
                "Refuse and hang up; real IT will not cold-call for remote control",
                "Read your OTP so they can verify you",
            ],
            2,
        ),
        _tf(
            5,
            VISHING,
            "If a call feels wrong, you can hang up and call back using a number from a trusted source.",
            True,
        ),
        _mc(
            6,
            VISHING,
            "A caller who says they are from your bank asks for the CVV on the back of your card. This is:",
            [
                "Normal identity confirmation",
                "A vishing tell — banks do not need you to read that over the phone",
                "Required if they already know your name",
                "Safe if they also know your school",
            ],
            1,
        ),
        _tf(
            7,
            VISHING,
            "Office sounds in the background prove the caller works at a real company.",
            False,
        ),
        _mc(
            8,
            VISHING,
            "The caller says this is a secret investigation and you must not tell anyone. That is a sign of:",
            [
                "Standard bank policy",
                "Pressure used in vishing",
                "Proof the call is official",
                "A courtesy for VIP customers",
            ],
            1,
        ),
        _tf(
            9,
            VISHING,
            "You should read a one-time code out loud if the caller asks for it.",
            False,
        ),
        _mc(
            10,
            VISHING,
            "Someone claiming to be the school registrar calls and asks for your portal password. You should:",
            [
                "Give it so your enrollment is not delayed",
                "Ask them to wait while you find it",
                "Not give it; verify through the school’s known office or site",
                "Text the password so it is not said aloud",
            ],
            2,
        ),
        _tf(
            11,
            VISHING,
            "You must stay on the line or your account will close in five minutes.",
            False,
        ),
        _mc(
            12,
            VISHING,
            "An unknown caller already knows your name. That means:",
            [
                "They must be from your bank",
                "Names can be guessed or leaked; it still does not prove identity",
                "You should answer every question they ask",
                "Caller ID plus a name is enough",
            ],
            1,
        ),
        _tf(
            13,
            VISHING,
            "A rushed, emotional voice on a call can be a tactic to stop you from thinking.",
            True,
        ),
        _mc(
            14,
            VISHING,
            "Best way to confirm a bank call about your card:",
            [
                "Call back the number on your screen",
                "Hang up and use the number printed on the card or official app",
                "Ask them to email a form and click it",
                "Give a small amount of data to test them",
            ],
            1,
        ),
        _tf(
            15,
            VISHING,
            "Vishing only happens on landline phones, never on mobile.",
            False,
        ),
    ],
    "mod_04": [
        _tf(
            1,
            PRETEXTING,
            "Social engineering relies heavily on human interaction.",
            True,
        ),
        _mc(
            2,
            PRETEXTING,
            "What is pretexting?",
            [
                "Encrypting files before sending them",
                "Inventing a fake scenario to trick someone into giving information",
                "Scanning a network for open ports",
                "Resetting a password through official IT",
            ],
            1,
        ),
        _mc(
            3,
            PRETEXTING,
            "A person in a staff vest says they are from IT and need your password. You should:",
            [
                "Give it because of the vest",
                "Write it down for them",
                "Not share it; verify through a channel you already trust",
                "Tell a classmate to give theirs first",
            ],
            2,
        ),
        _tf(
            4,
            PRETEXTING,
            "Holding the door for someone without a badge is always the polite and safe choice.",
            False,
        ),
        _mc(
            5,
            PRETEXTING,
            "Someone claiming to be a parent asks you for a classmate’s LRN and portal password. You should:",
            [
                "Share it so the parent can help",
                "Refuse and direct them to official school staff",
                "Share only the LRN",
                "Ask the classmate in a group chat later",
            ],
            1,
        ),
        _tf(
            6,
            PRETEXTING,
            "A printed ID card is always proof that the person is who they claim to be.",
            False,
        ),
        _mc(
            7,
            PRETEXTING,
            "A message says “I’m the principal’s assistant — send the class list now.” This is risky because:",
            [
                "Principals never have assistants",
                "It borrows a trusted role and rushes you for data",
                "Class lists are public anyway",
                "Assistants only use paper forms",
            ],
            1,
        ),
        _tf(
            8,
            PRETEXTING,
            "Urgency plus a borrowed role is a common pretexting tell.",
            True,
        ),
        _mc(
            9,
            PRETEXTING,
            "A visitor asks you to let them into a locked computer lab because they “left a USB.” Safest action?",
            [
                "Open the door; they sound honest",
                "Direct them to staff who control access",
                "Go in with them and watch",
                "Ask them to prove it by showing the USB",
            ],
            1,
        ),
        _tf(
            10,
            PRETEXTING,
            "You should verify unexpected requests through a known channel, not through the person who asked.",
            True,
        ),
        _mc(
            11,
            PRETEXTING,
            "A “research survey” in person asks for your email password. You should:",
            [
                "Fill it out; research is important",
                "Give a fake password",
                "Refuse; real surveys do not need your password",
                "Give the password only if they show a clipboard",
            ],
            2,
        ),
        _tf(
            12,
            PRETEXTING,
            "Pretexting only happens online, never in person.",
            False,
        ),
        _mc(
            13,
            PRETEXTING,
            "A “delivery rider” asks you to enter an OTP from your phone so they can confirm the drop. You should:",
            [
                "Enter it so you get the package",
                "Read the OTP aloud",
                "Not share OTPs; confirm with the store or a known contact",
                "Enter it only if they wait outside",
            ],
            2,
        ),
        _tf(
            14,
            PRETEXTING,
            "It is okay to share a classmate’s private info if someone says they lost their phone.",
            False,
        ),
        _mc(
            15,
            PRETEXTING,
            "Best response when a stranger in a trusted role asks for credentials:",
            [
                "Comply so you are not rude",
                "Pause, refuse the secret, and check with a known official source",
                "Give a hint instead of the full password",
                "Ask them to message you later with the same story",
            ],
            1,
        ),
    ],
    "mod_05": [
        _tf(
            1,
            BAITING,
            "Malware can be hidden in seemingly harmless file downloads.",
            True,
        ),
        _mc(
            2,
            BAITING,
            "You find a USB labeled 'Grades' in a school hallway. What is safest?",
            [
                "Plug it in to see who it belongs to",
                "Open it on a school computer only",
                "Do not plug it in and turn it in to staff",
                "Take it home and scan it later",
            ],
            2,
        ),
        _mc(
            3,
            BAITING,
            "A booth offers free USB sticks to students. The hidden risk is:",
            [
                "USBs never work on school PCs",
                "The drive may be bait that installs malware when plugged in",
                "Free gifts are illegal",
                "USB sticks can only store photos",
            ],
            1,
        ),
        _tf(
            4,
            BAITING,
            "A contest that is too good to be true can be bait to make you click or plug something in.",
            True,
        ),
        _mc(
            5,
            BAITING,
            "A site offers “free cracked” school software. Downloading it is risky because:",
            [
                "Cracked files are always smaller",
                "The installer may hide malware as the “free” bait",
                "Schools block all downloads",
                "Only paid software can have viruses",
            ],
            1,
        ),
        _tf(
            6,
            BAITING,
            "Public USB charging kiosks can be used to deliver malware to your phone.",
            True,
        ),
        _mc(
            7,
            BAITING,
            "A hallway poster says “Scan for free Wi-Fi / prize.” Safest move?",
            [
                "Scan it; posters are official",
                "Scan it only with a school tablet",
                "Do not scan unknown QR codes; use a known network login",
                "Ask a friend to scan it for you",
            ],
            2,
        ),
        _tf(
            8,
            BAITING,
            "A found USB labeled “Salary” is safer than one labeled “Grades.”",
            False,
        ),
        _mc(
            9,
            BAITING,
            "A pop-up says you won a phone and must download a file now. This is:",
            [
                "A standard warranty offer",
                "Baiting that uses a tempting prize",
                "Proof your device is already secure",
                "Safe if the pop-up uses your school colors",
            ],
            1,
        ),
        _tf(
            10,
            BAITING,
            "You should open an “answer key” file from an unknown classmate’s USB.",
            False,
        ),
        _mc(
            11,
            BAITING,
            "A stranger gives you a gift flash drive “for school.” You should:",
            [
                "Thank them and plug it in at home",
                "Plug it in once to see the files",
                "Not plug it in; unexpected media can be bait",
                "Format it, then use it",
            ],
            2,
        ),
        _tf(
            12,
            BAITING,
            "Baiting only uses USB drives, never fake downloads or prize offers.",
            False,
        ),
        _mc(
            13,
            BAITING,
            "A file named FreeMovie.mp4.exe is dangerous because:",
            [
                "Movie files cannot open on PCs",
                "The .exe ending means it can run a program, not just play a video",
                "Only .mp4 files carry malware",
                "Long file names are blocked",
            ],
            1,
        ),
        _tf(
            14,
            BAITING,
            "Testing a found drive on your personal computer is a safe way to check it.",
            False,
        ),
        _mc(
            15,
            BAITING,
            "What should you do with found USBs, discs, or mystery cables?",
            [
                "Keep them as free storage",
                "Plug in once, then throw away",
                "Leave them or turn them in to staff without plugging them in",
                "Sell them if they look new",
            ],
            2,
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
