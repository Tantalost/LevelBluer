"""Pure answer comparison shared by pre-test scoring and its tests."""


def is_correct(question: dict, submitted: bool | int | str) -> bool:
    kind = question.get("type", "multiple_choice")
    if kind == "true_false":
        return type(submitted) is bool and submitted == question["answer"]
    return type(submitted) is int and submitted == question["answer"]
