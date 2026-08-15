"""Baseline pre-test bank. Answers stay server-side so BKT cannot be spoofed."""

PRETEST_QUESTIONS: list[dict] = [
    {
        "id": 1,
        "topic": "Phishing",
        "type": "multiple_choice",
        "text": "Which of the following is the STRONGEST password?",
        "options": ["password123", "MyBirthday1990", "Tr!8#kL@mp99", "abc123"],
        "answer": 2,
    },
    {
        "id": 2,
        "topic": "Phishing",
        "type": "true_false",
        "text": "Using the same password across multiple sites is a best practice.",
        "answer": False,
    },
    {
        "id": 3,
        "topic": "Smishing",
        "type": "multiple_choice",
        "text": "What is smishing?",
        "options": [
            "Phishing that uses SMS or messaging apps",
            "A type of antivirus software",
            "A secure way to share one-time codes",
            "Voice calls from your real bank",
        ],
        "answer": 0,
    },
    {
        "id": 4,
        "topic": "Smishing",
        "type": "true_false",
        "text": "A legitimate bank will ask you to reply to a text with your OTP to verify your account.",
        "answer": False,
    },
    {
        "id": 5,
        "topic": "Vishing",
        "type": "multiple_choice",
        "text": "Vishing is social engineering that primarily happens through:",
        "options": ["Email attachments", "Phone or voice calls", "USB drives", "QR codes only"],
        "answer": 1,
    },
    {
        "id": 6,
        "topic": "Vishing",
        "type": "true_false",
        "text": "Caller ID is enough proof that the person on the phone is who they claim to be.",
        "answer": False,
    },
    {
        "id": 7,
        "topic": "Pretexting",
        "type": "true_false",
        "text": "Social engineering relies heavily on human interaction.",
        "answer": True,
    },
    {
        "id": 8,
        "topic": "Pretexting",
        "type": "multiple_choice",
        "text": "What is pretexting?",
        "options": [
            "Encrypting files before sending them",
            "Inventing a fake scenario to trick someone into giving information",
            "Scanning a network for open ports",
            "Resetting a password through official IT",
        ],
        "answer": 1,
    },
    {
        "id": 9,
        "topic": "Baiting",
        "type": "true_false",
        "text": "Malware can be hidden in seemingly harmless file downloads.",
        "answer": True,
    },
    {
        "id": 10,
        "topic": "Baiting",
        "type": "multiple_choice",
        "text": "You find a USB labeled 'Grades' in a school hallway. What is safest?",
        "options": [
            "Plug it in to see who it belongs to",
            "Open it on a school computer only",
            "Do not plug it in and turn it in to staff",
            "Take it home and scan it later",
        ],
        "answer": 2,
    },
]


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
