extends SceneTree
## Local fake HTTP endpoint and in-memory auth only. Never posts to the real dashboard.
var failures: int = 0
var form_script: GDScript
var auth: Node
var server: TCPServer = TCPServer.new()
var port: int = 0
var requests: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	await process_frame
	await process_frame

func _run() -> void:
	form_script = load("res://src/ui/screens/settings/student_feedback.gd") as GDScript
	if form_script == null or not form_script.can_instantiate():
		quit(1)
		return
	auth = root.get_node("AuthService")
	var saved: Array = [auth._signed_in, auth._participant_code, auth._token, auth._full_name]
	var original_url: Variant = ProjectSettings.get_setting("levelblue/feedback_api_base_url")
	auth._signed_in = true
	auth._participant_code = "feedback-test-student"
	auth._token = "local-test-only"
	auth._full_name = "Test Student"
	for candidate: int in range(18761, 18781):
		if server.listen(candidate, "127.0.0.1") == OK:
			port = candidate
			break
	check(port != 0, "Local test endpoint starts")
	if port == 0:
		quit(1)
		return
	ProjectSettings.set_setting("levelblue/feedback_api_base_url", "http://127.0.0.1:%d" % port)
	var context: Dictionary = {"module_id": "mod_02", "stage": 7, "won": false}
	var form: CanvasLayer = form_script.open(root, context)
	await settle()
	check(form_script.open(root, context) == form, "Repeated entry cannot stack modals")
	form._advance()
	check(form._step == 0 and form._scores == [0, 0, 0, 0, 0], "No default ratings; all five are required")
	for index: int in 5:
		form._rate(index, index + 1)
	form._advance()
	check(form._step == 1 and form._context_text() == "Smishing / Stage 7 / Not cleared", "Results context is disclosed")
	form._kind = 1
	form._advance()
	check(not form._busy, "Bug requires an actual student comment")
	form._comment = "x".repeat(4501)
	form._advance()
	check(not form._busy, "Oversize comments are blocked")
	form._comment = "The button did not respond."
	form._save_draft()
	await _submit(form, 503, {"error": "Not configured"})
	check(not form._sent and form._comment == "The button did not respond.", "503 preserves draft without claiming success")
	form._dismiss()
	await settle()
	form = form_script.open(root, context)
	check(form._scores == [1, 2, 3, 4, 5] and form._kind == 1 and not form._comment.is_empty(), "Closing and reopening restores this account's session draft")
	form._advance()
	for code: int in [400, 401, 403, 429, 500]:
		await _submit(form, code, {"error": "Test rejection"})
		check(not form._sent and not form._next.disabled and not form._comment.is_empty(), "Recoverable HTTP failure %d" % code)
	await _submit(form, 201, {})
	check(not form._sent, "Malformed success cannot clear a draft")
	form._set_busy(true)
	form._completed(HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray())
	check(form._status.text.contains("duplicate") and not form._busy, "Ambiguous timeout explains manual retry risk")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		for step: int in 2:
			form._step = step
			form._render()
			await settle()
			print("[FEEDBACK LAYOUT] viewport=%s panel=%s minimum=%s next=%s" % [root.get_visible_rect(), form._panel.get_global_rect(), form._panel.get_combined_minimum_size(), form._next.get_global_rect()])
			check(root.get_visible_rect().encloses(form._panel.get_global_rect()), "Form fits landscape %s step %d" % [dimensions, step])
			check(form._scroll.get_h_scroll_bar().max_value <= form._scroll.size.x + 1, "No horizontal scrolling")
			check(root.get_visible_rect().encloses(form._next.get_global_rect()), "Footer remains reachable")
			check(form._next.size.y * root.get_final_transform().get_scale().y >= 48, "48px touch target")
			if "--render" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/feedback_%dx%d_step%d.png" % [dimensions.x, dimensions.y, step])
	# Emulate the space occupied by a landscape mobile keyboard; no native keyboard opens.
	form.set_process(false)
	form._keyboard_height = 180
	form._layout()
	await settle()
	check(form._next.get_global_rect().end.y * root.get_final_transform().get_scale().y <= root.size.y - 180, "Send stays above virtual keyboard")
	form._keyboard_height = 0
	form._layout()
	form.set_process(true)
	form._kind = 1
	await _submit(form, 201, {"_id": "local-ack", "respondentRole": "student"})
	check(form._sent and form._next.visible == false, "Confirmed submission shows thanks and cannot resend")
	form._dismiss()
	await settle()
	form = form_script.open(root, context)
	check(form._scores == [0, 0, 0, 0, 0] and form._comment.is_empty(), "Success clears only the sent draft")
	form._rate(0, 2)
	auth._participant_code = "different-student"
	form._session_changed(true)
	await settle()
	form = form_script.open(root, context)
	check(form._scores == [0, 0, 0, 0, 0], "Account switch cannot expose another student's draft")
	form.free()
	auth._signed_in = false
	form = form_script.open(root)
	check(form._next.disabled, "Signed-out students cannot send")
	form.free()
	check(not form_script._safe_endpoint("http://example.com") and not form_script._safe_endpoint("https://user:secret@example.com") and form_script._safe_endpoint("https://school.example.com"), "Remote server requires HTTPS and cannot embed credentials")
	await _test_entry_points()
	server.stop()
	auth._signed_in = saved[0]
	auth._participant_code = saved[1]
	auth._token = saved[2]
	auth._full_name = saved[3]
	ProjectSettings.set_setting("levelblue/feedback_api_base_url", original_url)
	print("[STUDENT FEEDBACK] failures=%d local_requests=%d" % [failures, requests])
	quit(1 if failures else 0)

func _submit(form: CanvasLayer, code: int, body: Dictionary) -> void:
	form._advance()
	check(form._busy, "Submission starts")
	form._advance()
	form._dismiss()
	check(not form.is_queued_for_deletion() and form._busy, "Double-send and close are blocked while sending")
	var peer: StreamPeerTCP
	for frame: int in 300:
		if server.is_connection_available():
			peer = server.take_connection()
			break
		await create_timer(0.01).timeout
	check(peer != null, "Request reaches local server")
	if peer == null:
		return
	var request: String = ""
	for frame: int in 300:
		peer.poll()
		if peer.get_available_bytes() > 0:
			request += peer.get_utf8_string(peer.get_available_bytes())
		if request.contains("\r\n\r\n") and request.ends_with("}"):
			break
		await create_timer(0.01).timeout
	requests += 1
	check(request.begins_with("POST /api/usability-feedback ") and request.contains("Authorization: Bearer local-test-only"), "Uses existing web endpoint with bearer authentication")
	var payload: Variant = JSON.parse_string(request.get_slice("\r\n\r\n", 1))
	check(payload is Dictionary and payload.get("q1") == 1 and payload.get("q5") == 5 and payload.get("module") == "Smishing" and payload.get("feedbackType") == "bug", "Web survey payload matches selected ratings and type")
	check(payload is Dictionary and not payload.has("studentId") and not payload.has("rating") and not payload.has("mastery"), "Server owns identity and composite score; no mastery is sent")
	var response: String = JSON.stringify(body)
	peer.put_data(("HTTP/1.1 %d Test\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [code, response.to_utf8_buffer().size(), response]).to_utf8_buffer())
	for frame: int in 300:
		if not form._busy:
			break
		await create_timer(0.01).timeout
	check(not form._busy, "Request completes")
	peer.disconnect_from_host()

func _test_entry_points() -> void:
	var settings: Control = load("res://src/ui/screens/settings/settings_screen.tscn").instantiate()
	root.add_child(settings)
	settings.on_enter({})
	var scroll: ScrollContainer = settings.get_node("SafeAreaContainer/ScreenLayout/ScrollContainer") as ScrollContainer
	await settle()
	scroll.ensure_control_visible(settings._feedback_button)
	await settle()
	check(scroll.get_global_rect().encloses(settings._feedback_button.get_global_rect()), "Settings feedback is reachable by scrolling")
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/feedback_settings_entry.png")
	settings._feedback_button.pressed.emit()
	check(settings.has_node("StudentFeedback"), "Settings opens shared form")
	root.get_node("Router").request_back()
	await settle()
	check(not settings.has_node("StudentFeedback"), "System back closes modal, not the underlying screen")
	settings.free()
	var overlay: CanvasLayer = load("res://src/ui/screens/victory/base_defeat_overlay.gd").new()
	root.add_child(overlay)
	for won: bool in [false, true]:
		overlay.configure({"module_id": "mod_01", "stage": 3, "won": won})
		overlay.finish_reveal()
		await settle()
		check(overlay._feedback_button.visible, "Both results expose feedback after reveal")
		check(not overlay._feedback_button.get_global_rect().intersects(overlay._stage.get_global_rect()), "Feedback shortcut does not overlap stage heading")
		if "--render" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/feedback_result_%s.png" % str(won))
		overlay._feedback_button.pressed.emit()
		check(overlay.get_node("StudentFeedback").context.won == won, "Results capture the correct outcome")
		overlay.get_node("StudentFeedback").free()
	overlay.free()
	var legacy: Control = load("res://src/ui/screens/victory/victory_screen.tscn").instantiate()
	root.add_child(legacy)
	legacy.on_enter({"module_id": "mod_02", "stage": 4, "won": true})
	await settle()
	check(root.get_visible_rect().encloses(legacy._feedback_button.get_global_rect()), "Legacy result shortcut remains reachable")
	legacy._feedback_button.pressed.emit()
	check(legacy.has_node("StudentFeedback"), "Legacy result opens shared form")
	check(legacy._feedback_context.stage == 4, "Legacy results capture stage context")
	legacy.free()
