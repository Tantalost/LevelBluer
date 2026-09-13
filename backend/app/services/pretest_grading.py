"""Pure answer comparison shared by pre-test scoring and its tests."""
import re


def normalize_recall(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", value.lower()).strip()


def is_correct(question: dict, submitted: bool | int | str) -> bool:
    kind = question.get("type", "multiple_choice")
    if kind == "short_answer":
        # Older offline clients queued the original MC choice, not recall text.
        if type(submitted) is int and "legacy_answer" in question:
            return submitted == question["legacy_answer"]
        if not isinstance(submitted, str) or len(submitted) > 96:
            return False
        actual = normalize_recall(submitted)
        accepted = question.get("accepted_answers", [question["answer"]])
        return bool(actual) and any(actual == normalize_recall(item) for item in accepted)
    if kind == "true_false":
        return type(submitted) is bool and submitted == question["answer"]
    return type(submitted) is int and submitted == question["answer"]
