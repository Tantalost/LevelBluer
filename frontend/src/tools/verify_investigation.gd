extends SceneTree
## Regression suite for the optional "inspect evidence, reach a conclusion"
## investigation moment (DecisionScenarios.investigation_* +
## decision_investigation_panel.gd). Covers schema parsing and the reusable
## panel's own presentation-only behavior in isolation — full live-scene
## coexistence with dialogue/timer/call/story_event on the Module 3 Stage 1
## demo is covered by verify_stage_one_live.gd's Incident 3 checks, since
## that needs a real running match.
##
## Run headless:  godot --headless --script res://src/tools/verify_investigation.gd

const InvestigationPanel = preload("res://src/gameplay/decision/decision_investigation_panel.gd")
const Workspace = preload("res://src/gameplay/decision/decision_workspace.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("  ok  " + message)


func _run() -> void:
	_test_absent_investigation_preserves_old_behavior()
	_test_investigation_schema_parsing()
	_test_malformed_investigation_is_safely_ignored()
	_test_stable_item_ids_survive_parsing()
	_test_resolved_story_event_reuses_story_event_lines()
	_test_isolated_from_gameplay_state()
	await _test_panel_single_selection_only()
	await _test_panel_invalid_shows_analysis_and_permits_retry()
	await _test_panel_valid_requires_explicit_continue_to_resolve()
	await _test_panel_reconfigure_resets_state()
	await _test_workspace_gates_decision_ready_until_resolved()
	await _test_workspace_call_and_emotions_coexist_with_investigation()

	print("INVESTIGATION_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)


func _test_absent_investigation_preserves_old_behavior() -> void:
	print("== Absent/disabled 'investigation' data all mean the existing flow, unchanged ==")
	check(not DecisionScenarios.has_investigation({}), "A threat with no 'investigation' key at all has none")
	check(not DecisionScenarios.has_investigation({"investigation": {"enabled": false, "items": [{"id": "x", "label": "y", "valid": true}]}}),
		"enabled=false has no investigation even with well-formed items present")
	for threat in DecisionScenarios.get_threats("mod_01", 1):
		check(not DecisionScenarios.has_investigation(threat), "[Regression] Existing Module 1 Stage 1 threats have no investigation")
	for threat in DecisionScenarios.get_threats("mod_02", 1):
		check(not DecisionScenarios.has_investigation(threat), "[Regression] Existing Module 2 Stage 1 threats have no investigation")


func _test_investigation_schema_parsing() -> void:
	print("== Investigation schema: title/prompt/items parse safely ==")
	var threat: Dictionary = {"investigation": {
		"enabled": true,
		"title": "verify the caller",
		"prompt": "Which evidence independently proves who is calling?",
		"items": [
			{"id": "caller_id", "label": "Caller ID matches the bank", "valid": false, "analysis": "Caller ID can be spoofed."},
			{"id": "none", "label": "None of these independently verify the caller", "valid": true, "analysis": "Verification must leave the caller-controlled channel."},
		],
	}}
	check(DecisionScenarios.has_investigation(threat), "enabled=true with well-formed items is an investigation")
	check(DecisionScenarios.investigation_title(threat) == "VERIFY THE CALLER", "Title is read and normalized to upper case")
	check(DecisionScenarios.investigation_prompt(threat) == "Which evidence independently proves who is calling?", "Prompt is read exactly")
	var items: Array[Dictionary] = DecisionScenarios.investigation_items(threat)
	check(items.size() == 2, "Both well-formed items parse")
	check(items[0].get("id") == "caller_id" and not items[0].get("valid") and items[0].get("analysis") == "Caller ID can be spoofed.",
		"An invalid item's id/valid/analysis are read exactly")
	check(items[1].get("id") == "none" and items[1].get("valid"), "A valid item's id/valid are read exactly")
	check(DecisionScenarios.investigation_title({}) == "INVESTIGATION", "A threat with no authored title falls back to a generic one, never blank")


func _test_malformed_investigation_is_safely_ignored() -> void:
	print("== Malformed investigation data is safely ignored, never a crash ==")
	check(DecisionScenarios.investigation_items({"investigation": "not a dictionary"}).is_empty(), "A plain string 'investigation' is safely ignored")
	check(DecisionScenarios.investigation_items({"investigation": {"items": "not an array"}}).is_empty(), "A non-array 'items' is safely ignored")
	check(DecisionScenarios.investigation_items({"investigation": {"items": ["garbage", 5, {"label": "no id"}, {"id": "no_label"}]}}).is_empty(),
		"Items missing an id or a label are dropped, never shown half-broken")
	check(not DecisionScenarios.has_investigation({"investigation": {"enabled": true, "items": []}}),
		"enabled=true with zero well-formed items is treated as no investigation at all, never a panel with nothing to select")
	check(not DecisionScenarios.has_investigation({"investigation": {"enabled": true, "items": [{"label": "no id"}]}}),
		"enabled=true where every item is malformed is treated as no investigation at all")


func _test_stable_item_ids_survive_parsing() -> void:
	print("== Item ids are stable, authored strings — future Case Board readiness ==")
	var threat: Dictionary = {"investigation": {"enabled": true, "items": [
		{"id": "mod03_s1_i3_caller_id", "label": "x", "valid": false},
		{"id": "mod03_s1_i3_none", "label": "y", "valid": true},
	]}}
	var ids: Array = []
	for item in DecisionScenarios.investigation_items(threat):
		ids.append(item.get("id"))
	check(ids == ["mod03_s1_i3_caller_id", "mod03_s1_i3_none"], "Ids are read verbatim, in authored order")


func _test_resolved_story_event_reuses_story_event_lines() -> void:
	print("== resolved_story_event reuses the exact same story_event parser as a choice's/timer's/call's own story_event ==")
	var threat: Dictionary = {"investigation": {"resolved_story_event": [
		{"type": "dialogue", "speaker": "Daniel", "text": "So everything they're showing me can be real...", "emotion": "worried"},
		{"type": "dialogue", "speaker": "Security Assistant", "text": "...and the person using it can still be fake."},
	]}}
	var lines: Array[Dictionary] = DecisionScenarios.investigation_resolved_story_event_lines(threat)
	check(lines.size() == 2, "Two authored dialogue events produce 2 lines")
	check(str(lines[0].get("speaker", "")) == "Daniel" and str(lines[0].get("emotion", "")) == "worried", "The first line carries its authored speaker/emotion through")
	check(DecisionScenarios.investigation_resolved_story_event_lines({}).is_empty(), "A threat with no investigation/resolved_story_event produces no lines")
	check(DecisionScenarios.investigation_resolved_story_event_lines({"investigation": {}}).is_empty(), "An investigation with no resolved_story_event key produces no lines")


func _test_isolated_from_gameplay_state() -> void:
	print("== Investigation schema/panel code never touches BKT, TD, save, decision outcomes, or progression directly ==")
	var forbidden: PackedStringArray = [
		"PlayerManager", "update_mastery", "mark_stage_cleared", "SaveService", "StageManager", "TaskManager",
		"pending_outcome", "bkt_correct", "begin_defend", "GAME_OVER", "GamePhase",
	]
	var scenarios_text: String = FileAccess.get_file_as_string("res://src/gameplay/decision/decision_scenarios.gd")
	check(not scenarios_text.is_empty(), "decision_scenarios.gd is readable for the isolation check")
	for symbol in forbidden:
		check(not scenarios_text.contains(symbol), "decision_scenarios.gd's investigation code does not reference %s" % symbol)
	var panel_text: String = FileAccess.get_file_as_string("res://src/gameplay/decision/decision_investigation_panel.gd")
	check(not panel_text.is_empty(), "decision_investigation_panel.gd is readable for the isolation check")
	for symbol in forbidden:
		check(not panel_text.contains(symbol), "decision_investigation_panel.gd does not reference %s — structurally cannot grade BKT, trigger TD/Game Over, or pick an outcome" % symbol)


func _mount_panel() -> Control:
	var panel: Control = InvestigationPanel.new()
	root.add_child(panel)
	await process_frame
	return panel


func _test_panel_single_selection_only() -> void:
	print("== Only one item is selectable at a time (ButtonGroup mutual exclusion) ==")
	var panel: Control = await _mount_panel()
	panel.configure({"title": "T", "prompt": "P", "items": [
		{"id": "a", "label": "A", "valid": false, "analysis": "no"},
		{"id": "b", "label": "B", "valid": false, "analysis": "no"},
		{"id": "c", "label": "C", "valid": true, "analysis": "yes"},
	]})
	check(panel._item_buttons.size() == 3, "All three items render as selectable buttons")
	panel._item_buttons[0].button_pressed = true
	panel._select(0)
	check(panel._item_buttons[0].text.begins_with("[X]"), "Selecting an item marks it selected in TEXT, not color alone")
	panel._item_buttons[1].button_pressed = true
	panel._select(1)
	check(panel._item_buttons[1].text.begins_with("[X]") and panel._item_buttons[0].text.begins_with("[ ]"),
		"Selecting a second item deselects the first — only one item is ever selected at once")
	panel.queue_free()
	await process_frame


func _test_panel_invalid_shows_analysis_and_permits_retry() -> void:
	print("== Invalid evidence shows EVIDENCE INSUFFICIENT + analysis, and permits another selection ==")
	var panel: Control = await _mount_panel()
	panel.configure({"title": "T", "prompt": "P", "items": [
		{"id": "a", "label": "A", "valid": false, "analysis": "Caller ID can be spoofed."},
		{"id": "b", "label": "B", "valid": true, "analysis": "Confirmed reasoning."},
	]})
	panel._select(0)
	panel._analyze()
	check(panel._result_label.text.begins_with("EVIDENCE INSUFFICIENT") and panel._result_label.text.contains("Caller ID can be spoofed."),
		"Invalid selection shows EVIDENCE INSUFFICIENT with the authored analysis text, never 'Wrong'/'Incorrect'")
	check(not panel.is_resolved(), "An invalid analysis does not resolve the investigation")
	check(panel._items_column.visible and not panel._analyze_button.disabled, "Items remain selectable and ANALYZE remains available — no lock-out, no separate 'try again' step")
	panel._select(1)
	panel._analyze()
	check(panel._result_label.text.begins_with("ANALYSIS CONFIRMED"), "A subsequent valid selection still resolves normally after a prior invalid attempt")
	panel.queue_free()
	await process_frame


func _test_panel_valid_requires_explicit_continue_to_resolve() -> void:
	print("== Valid evidence shows ANALYSIS CONFIRMED and only resolves once CONTINUE is explicitly pressed ==")
	var panel: Control = await _mount_panel()
	panel.configure({"title": "T", "prompt": "P", "items": [
		{"id": "a", "label": "A", "valid": true, "analysis": "Verification must leave the caller-controlled channel."},
	]})
	panel._select(0)
	panel._analyze()
	check(panel._result_label.text.begins_with("ANALYSIS CONFIRMED") and panel._result_label.text.contains("Verification must leave the caller-controlled channel."),
		"Valid selection shows ANALYSIS CONFIRMED with the authored analysis text, never 'Correct'")
	check(not panel.is_resolved() == false and panel._confirmed, "The panel is internally confirmed immediately")
	var resolved_calls: Array = []
	panel.investigation_resolved.connect(func() -> void: resolved_calls.append(true))
	check(resolved_calls.is_empty(), "investigation_resolved has not fired yet — CONTINUE has not been pressed")
	panel._confirm_continue()
	check(resolved_calls.size() == 1, "Pressing CONTINUE fires investigation_resolved exactly once")
	panel._confirm_continue()
	check(resolved_calls.size() == 1, "Pressing CONTINUE again cannot fire it a second time")
	panel.queue_free()
	await process_frame


func _drain_dialogue(workspace: Control) -> void:
	for i in 6:
		if workspace._typing:
			workspace._continue()
		workspace._continue()


func _test_workspace_gates_decision_ready_until_resolved() -> void:
	print("== decision_workspace.gd: decision_ready (and with it the decision timer) is withheld until an authored investigation resolves ==")
	var workspace: Control = Workspace.new()
	root.add_child(workspace)
	await process_frame
	var ready_calls: Array = []
	workspace.decision_ready.connect(func() -> void: ready_calls.append(true))
	var threat: Dictionary = {"title": "T", "situation": "S", "evidence": [], "choices": [
		{"label": "Safe", "outcome": "SAFE"}, {"label": "Risky", "outcome": "RISKY"},
	]}
	var story_lines: Array[Dictionary] = [{"speaker": "A", "text": "Hello.", "emotion": "", "when": {}}]
	workspace.show_threat(threat, story_lines, 1, 1, "HEADER")
	workspace.set_investigation({"title": "T", "prompt": "P", "items": [
		{"id": "a", "label": "A", "valid": false, "analysis": "no"},
		{"id": "b", "label": "B", "valid": true, "analysis": "yes"},
	]})
	_drain_dialogue(workspace)
	check(ready_calls.is_empty(), "decision_ready has not fired yet — the investigation is still pending, not the choices")
	check(workspace._investigation_panel.visible, "The investigation panel is visible once dialogue is read")
	check(not workspace._choices_scroll.visible, "Choices remain hidden while investigating")
	workspace.set_decision_timer_visible(true)
	check(not workspace._timer_row.visible, "[Timer] The decision timer row does not show while investigating, even if a caller marked this threat as timed")
	workspace._investigation_panel._select(0)
	workspace._investigation_panel._analyze()
	check(ready_calls.is_empty(), "An invalid analysis still does not unlock the decision")
	workspace._investigation_panel._select(1)
	workspace._investigation_panel._analyze()
	workspace._investigation_panel._confirm_continue()
	check(ready_calls.size() == 1, "decision_ready fires exactly once, only after the investigation resolves")
	check(workspace._choices_scroll.visible, "Choices become actionable immediately once the investigation resolves")
	workspace.set_decision_timer_visible(true)
	check(workspace._timer_row.visible, "[Timer] Only now, with choices actionable, does the decision timer row show — a real caller starts the countdown normally from here")
	workspace.queue_free()
	await process_frame


func _test_workspace_call_and_emotions_coexist_with_investigation() -> void:
	print("== decision_workspace.gd: the call panel/duration and character portraits coexist with an active investigation ==")
	var workspace: Control = Workspace.new()
	root.add_child(workspace)
	await process_frame
	var threat: Dictionary = {"title": "T", "situation": "S", "evidence": [], "choices": [{"label": "Safe", "outcome": "SAFE"}]}
	var story_lines: Array[Dictionary] = [{"speaker": "Daniel", "text": "Hello there.", "emotion": "worried", "when": {}}]
	workspace.show_threat(threat, story_lines, 1, 1, "HEADER")
	workspace.set_call({"caller": "Bank", "number": "1", "status": "CONNECTED"})
	workspace.set_investigation({"title": "T", "prompt": "P", "items": [{"id": "a", "label": "A", "valid": true, "analysis": "x"}]})
	check(workspace._call_panel.visible, "[Call] The call panel remains visible while the threat's own dialogue is read")
	check(workspace._speaker_label.text == "DANIEL", "[Emotion] The speaker/portrait system still engages normally with an investigation pending later")
	_drain_dialogue(workspace)
	check(workspace._investigation_panel.visible, "Investigation panel shows once dialogue is read")
	check(workspace._call_panel.visible, "[Call] The call panel remains visible alongside the investigation panel")
	workspace.update_call_duration(12.0)
	check(workspace._call_panel._duration_label.text == "00:12", "[Call] Call duration keeps updating independently while investigating")
	workspace._investigation_panel._select(0)
	workspace._investigation_panel._analyze()
	check(workspace._investigation_panel.is_resolved(), "Investigation resolves normally with a call active")
	workspace._investigation_panel._confirm_continue()
	check(workspace._choices_scroll.visible, "Choices unlock normally afterward")
	check(workspace._call_panel.visible, "[Call] The call panel is still visible once choices are actionable")
	workspace.queue_free()
	await process_frame


func _test_panel_reconfigure_resets_state() -> void:
	print("== configure() resets everything for a NEW investigation — a retried incident replays it safely ==")
	var panel: Control = await _mount_panel()
	panel.configure({"title": "T", "prompt": "P", "items": [{"id": "a", "label": "A", "valid": true, "analysis": "x"}]})
	panel._select(0)
	panel._analyze()
	check(panel.is_resolved(), "First investigation resolves normally")
	panel.configure({"title": "T2", "prompt": "P2", "items": [{"id": "b", "label": "B", "valid": false, "analysis": "y"}, {"id": "c", "label": "C", "valid": true, "analysis": "z"}]})
	check(not panel.is_resolved(), "Reconfiguring (e.g. a retried incident) starts fully unresolved again — no memory of the previous attempt")
	check(panel._analyze_button.disabled, "Reconfiguring clears the previous selection — ANALYZE is disabled until a new pick is made")
	panel.queue_free()
	await process_frame
