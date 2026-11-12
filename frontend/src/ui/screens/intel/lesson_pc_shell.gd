extends "res://src/ui/components/terminal_workspace.gd"
## Lesson-specific shortcuts, evidence indicators and report wording.
var case_app: String = ""
var case_title: String = ""
var case_kind: IntelPixelIcon.Kind = IntelPixelIcon.Kind.ENVELOPE
var unread: bool = true

func _ready() -> void:
	session_title = "SYS://SCHOOL-01   /   LOCAL SESSION"
	checklist_title = "CASE BUFFER"
	checklist = PackedStringArray(["DETAILS", "VERIFIED", "REPORTED"])
	if case_app.is_empty():
		add_app("Inbox", "Mail", IntelPixelIcon.Kind.ENVELOPE)
		add_app("Browser", "Browser", IntelPixelIcon.Kind.TERMINAL)
		add_app("Directory", "Directory", IntelPixelIcon.Kind.BADGE)
		add_app("File Sandbox", "Files", IntelPixelIcon.Kind.FOLDER)
		add_app("Evidence", "Evidence", IntelPixelIcon.Kind.CODEX)
		add_app("Quarantine", "Quarantine", IntelPixelIcon.Kind.LOCK)
	else:
		add_app(case_app, case_app, case_kind)
	super._ready()
	refresh_badges()
	log_action("mount /school/local\nOK   %02d application%s online" % [shortcuts.size(), "s" if shortcuts.size() > 1 else ""])
	log_action("Case: " + case_title + "\nOpen " + ("Mail" if case_app.is_empty() else case_app) + " to inspect the request.")
	set_case_state(false, false, false)

func refresh_badges() -> void:
	set_app_badge("Inbox" if case_app.is_empty() else case_app, "Unread request", unread)

func set_case_state(inspected: bool, verified: bool, reported: bool) -> void:
	set_indicators([inspected, verified, reported])
	var message: String = "1 UNREAD" if unread else "REQUEST OPENED"
	set_home_status("LOCAL   /   %02d APPS     •     %s" % [shortcuts.size(), "CASE CLOSED" if reported else message])

func result(message: String, warning: bool) -> void:
	show_result("WARNING  /  ACTION BLOCKED" if warning else "CASE CLOSED  /  REPORT SAVED", message, warning)
