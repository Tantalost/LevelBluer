extends Control
## Touch-operated computer. The room owns evidence gates, time and capture.
signal command(action: String, target: String)
signal leave_requested
signal retry_requested
signal practice_started(role: String)
signal replay_requested

## Set by the local screen before adding the workspace to the tree.
var practice_mode: bool = false
var _practice_role: String = "attacker"
var _launch: Button
var _role_choice: Button
var _replay: Button
var _surface: Control

const Terminal: GDScript = preload("res://src/ui/components/terminal_workspace.gd")
const GREEN: Color = Color("#32ef69")
const EDGE: Color = Color("#227a3d")
const RED: Color = Color("#ff4958")
const BLACK: Color = Color("#040b06")
enum App { HOME, TERMINAL, FILES, NETMAP }

var _desk: Control
var _art: Control
var _texture: Control
var _head: Label
var _clock: Label
var _progress: Label
var _home: Panel
var _home_title: Label
var _mission: Label
var _shortcuts: Array[Button] = []
var _rail: Array[Button] = []
var _shell: Panel
var _shell_scroll: ScrollContainer
var _shell_text: Label
var _shell_action: Button
var _map: Panel
var _files: Panel
var _net_lines: Control
var _file_scroll: ScrollContainer
var _file_text: Label
var _action: Button
var _leave: Button
var _map_note: Label
var _files_caption: Label
var _captions: Array[Label] = []
var _close_buttons: Array[Button] = []
var _grips: Array[Label] = []
var _nodes: Array[Button] = []
var _ids: Array[String] = []
var _data: Dictionary = {}
var _mode: String = ""
var _selected: String = ""
var _app: App = App.HOME
var _pending: bool = false
var _note: String = ""
var _history: Array[String] = []
var _outcome: Control
var _result_tween: Tween

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	add_child(safe)
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var surface: Control = Control.new()
	_surface = surface
	safe.add_child(surface)
	_desk = Control.new()
	surface.add_child(_desk)
	_desk.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art = Control.new()
	_art.mouse_filter = MOUSE_FILTER_IGNORE
	_desk.add_child(_art)
	_art.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_art.draw.connect(_draw_computer)
	_head = _label(_desk, GREEN, 20)
	_clock = _label(_desk, GREEN, 20)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress = _label(_desk, GREEN, 18)
	for index: int in 4:
		var button: Button = _button(_desk)
		_desktop_icon(button, 3 if index == 0 else index-1)
		button.pressed.connect(_open_app.bind(index as App))
		_rail.append(button)
	_home = _window("PERSONAL TERMINAL / HOME")
	_home_title = _label(_home, GREEN, 28)
	_mission = _label(_home, GREEN, 21)
	_mission.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for index: int in 3:
		var shortcut: Button = _button(_home)
		shortcut.add_theme_stylebox_override("hover", Terminal.box(Color("#10371e"), GREEN, 1))
		shortcut.add_theme_stylebox_override("pressed", Terminal.box(EDGE, GREEN, 1))
		shortcut.pressed.connect(_open_app.bind((index+1) as App))
		shortcut.accessibility_name = ["Terminal", "Files", "Netmap"][index]
		var icon: Control = Control.new()
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		shortcut.add_child(icon)
		icon.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		icon.draw.connect(_draw_icon.bind(icon, index))
		_shortcuts.append(shortcut)
	_shell = _window("TERMINAL / SESSION.LOG")
	_shell_scroll = ScrollContainer.new()
	_shell_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shell.add_child(_shell_scroll)
	_style_scroll(_shell_scroll)
	_shell_text = _label(_shell_scroll, GREEN, 22)
	_shell_text.size_flags_horizontal = SIZE_EXPAND_FILL
	_shell_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shell_action = _button(_shell)
	_shell_action.text = "OPEN CURRENT FILE"
	_shell_action.pressed.connect(_open_app.bind(App.FILES))
	_map = _window("NETMAP / EVENT SUBNET")
	_net_lines = Control.new()
	_net_lines.mouse_filter = MOUSE_FILTER_IGNORE
	_map.add_child(_net_lines)
	_net_lines.draw.connect(_draw_links)
	for index: int in 4:
		var node: Button = _button(_map)
		node.pressed.connect(_select_node.bind(index))
		_nodes.append(node)
	_map_note = _label(_map, GREEN, 18)
	_files = _window("FILES / INVITATION")
	_files_caption = _captions.back()
	_file_scroll = ScrollContainer.new()
	_file_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_files.add_child(_file_scroll)
	_style_scroll(_file_scroll)
	_file_text = _label(_file_scroll, GREEN, 23)
	_file_text.size_flags_horizontal = SIZE_EXPAND_FILL
	_file_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outcome = Control.new()
	_outcome.mouse_filter = MOUSE_FILTER_IGNORE
	_files.add_child(_outcome)
	_outcome.draw.connect(_draw_outcome)
	_outcome.hide()
	_action = _button(_files)
	_action.pressed.connect(_act)
	if practice_mode:
		_launch = _button(_home)
		_launch.text = "START PRACTICE"
		_launch.pressed.connect(func() -> void: practice_started.emit(_practice_role))
		_role_choice = _button(_home)
		_role_choice.pressed.connect(_swap_practice_role)
		_replay = _button(_files)
		_replay.text = "PLAY AGAIN"
		_replay.pressed.connect(replay_requested.emit)
	_leave = _button(_desk)
	_desktop_icon(_leave, 4)
	_leave.pressed.connect(leave_requested.emit)
	_texture = Control.new()
	_texture.mouse_filter = MOUSE_FILTER_IGNORE
	_desk.add_child(_texture)
	_texture.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_texture.draw.connect(Terminal.draw_scanlines.bind(_texture))
	surface.resized.connect(_layout.bind(surface))
	_layout.call_deferred(surface)
	_show_apps()

func _label(parent: Control, ink: Color, font_size: int) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_override("font", Terminal.FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ink)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _window(caption: String) -> Panel:
	var pane: Panel = Panel.new()
	pane.add_theme_stylebox_override("panel", Terminal.box(BLACK, EDGE, 2))
	_desk.add_child(pane)
	var title: Label = _label(pane, GREEN, 19)
	title.text = caption
	title.clip_text = true
	title.add_theme_stylebox_override("normal", Terminal.box(Color("#145b29"), EDGE, 1))
	_captions.append(title)
	var grip: Label = _label(pane, GREEN, 18)
	grip.text = "||||||"
	_grips.append(grip)
	var close: Button = _button(pane)
	close.add_theme_stylebox_override("normal", Terminal.box(Color.TRANSPARENT, Color.TRANSPARENT, 0))
	close.add_theme_stylebox_override("hover", Terminal.box(Color("#10371e"), GREEN, 1))
	close.add_theme_stylebox_override("pressed", Terminal.box(EDGE, GREEN, 1))
	var glyph: Label = _label(close, GREEN, 21)
	glyph.text = "×"
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.position = Vector2(0,0)
	glyph.size = Vector2(46,27)
	close.accessibility_name = "Close window and return Home"
	close.pressed.connect(_open_app.bind(App.HOME))
	_close_buttons.append(close)
	return pane

func _style_scroll(scroll: ScrollContainer) -> void:
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x = 12
	bar.add_theme_stylebox_override("scroll", Terminal.box(Color("#07160c"), EDGE, 1))
	for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var thumb: StyleBoxFlat = Terminal.box(EDGE if state == "grabber" else GREEN, GREEN, 1)
		thumb.content_margin_top = 12
		thumb.content_margin_bottom = 12
		bar.add_theme_stylebox_override(state, thumb)

func _button(parent: Control) -> Button:
	var button: Button = Button.new()
	button.add_theme_font_override("font", Terminal.FONT)
	button.add_theme_font_size_override("font_size", 21)
	for style: String in ["normal", "disabled", "pressed", "hover", "focus"]:
		var fill: Color = BLACK if style in ["normal", "disabled", "focus"] else GREEN
		var box: StyleBoxFlat = Terminal.box(fill, EDGE if style in ["normal", "disabled"] else GREEN, 1)
		box.draw_center = style != "focus"
		button.add_theme_stylebox_override(style, box)
	button.add_theme_color_override("font_color", GREEN)
	button.add_theme_color_override("font_hover_color", BLACK)
	button.add_theme_color_override("font_pressed_color", BLACK)
	button.add_theme_color_override("font_disabled_color", Color("#40784d"))
	button.clip_text = true
	parent.add_child(button)
	return button

func _desktop_icon(button: Button, kind: int) -> void:
	button.accessibility_name = ["Terminal", "Files", "Netmap", "Home", "Exit match"][kind]
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var icon: Control = Control.new()
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	button.add_child(icon)
	icon.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	icon.draw.connect(_draw_icon.bind(icon, kind, true))
	for event: Signal in [button.mouse_entered, button.mouse_exited, button.button_down, button.button_up]:
		event.connect(icon.queue_redraw)

func _place(control: Control, x: float, y: float, w: float, h: float) -> void:
	if control is Button:
		w = maxf(w, ceilf(44.0/_desk.scale.x))
		h = maxf(h, ceilf(44.0/_desk.scale.y))
	control.position = Vector2(x,y).round()
	control.size = Vector2(w,h).round()

func _layout(surface: Control) -> void:
	if not is_node_ready() or surface.size.y < 1: return
	var factor: float = minf(surface.size.x/720.0, surface.size.y/360.0)
	_desk.scale = Vector2.ONE*factor
	_desk.size = surface.size/factor
	var w: float = _desk.size.x
	var h: float = _desk.size.y
	var pw: float = w-130
	var ph: float = h-112
	_place(_head, 28, 18, w-170, 24)
	_place(_clock, w-132, 18, 104, 24)
	for index: int in 4:
		_place(_rail[index], 24, 51+index*54, 78, 46)
		(_rail[index].get_child(0) as Control).queue_redraw()
	var panes: Array[Panel] = [_home, _shell, _map, _files]
	for index: int in panes.size():
		_place(panes[index], 108, 49, pw, ph)
		_place(_captions[index], 3, 3, pw-6, 27)
		_place(_grips[index], pw-101, 3, 49, 27)
		_place(_close_buttons[index], pw-48, 2, 46, 44)
	_place(_home_title, 17, 47, pw-34, 32)
	_place(_mission, 17, 82, pw-34, 62)
	var sw: float = (pw-50)/3
	for index: int in 3:
		_place(_shortcuts[index], 15+index*(sw+10), ph-92, sw, 78)
		(_shortcuts[index].get_child(0) as Control).queue_redraw()
	_place(_shell_scroll, 17, 48, pw-34, ph-112)
	_place(_shell_action, 15, ph-59, pw-30, 46)
	_place(_net_lines, 0, 0, pw, ph)
	var bw: float = minf(160, pw*.3)
	_place(_nodes[0], 16, 54, bw, 46)
	_place(_nodes[1], (pw-bw)/2, 55, bw, 46)
	_place(_nodes[2], (pw-bw)/2, ph-89, bw, 46)
	_place(_nodes[3], pw-bw-16, (ph-46)/2, bw, 46)
	_place(_map_note, 16, ph-32, pw-32, 26)
	_place(_file_scroll, 16, 49, pw-32, ph-111)
	_place(_action, 15, ph-59, pw-30, 46)
	if practice_mode:
		_place(_role_choice, 15, ph-69, (pw-40)/2, 46)
		_place(_launch, 25+(pw-40)/2, ph-69, (pw-40)/2, 46)
		_place(_replay, 15, ph-59, (pw-40)/2, 46)
		if _mode == "done": _place(_action, 25+(pw-40)/2, ph-59, (pw-40)/2, 46)
	_place(_progress, 110, h-58, w-137, 25)
	_place(_leave, 24, h-87, 78, 46)
	(_leave.get_child(0) as Control).queue_redraw()
	if _mode == "done":
		var rw: float = w-68
		var rh: float = h-112
		_place(_files,34,49,rw,rh)
		_place(_files_caption,3,3,rw-6,27)
		_grips[3].hide()
		_close_buttons[3].hide()
		_place(_outcome,12,39,rw-24,rh-104)
		_place(_file_scroll,145,110,rw-161,rh-176)
		_file_text.add_theme_font_size_override("font_size",21)
		_place(_action,15,rh-59,rw-30,46)
		if practice_mode:
			_place(_replay,15,rh-59,(rw-40)/2,46)
			_place(_action,25+(rw-40)/2,rh-59,(rw-40)/2,46)
		_place(_progress,40,h-58,w-80,25)
		_outcome.queue_redraw()
	else:
		_grips[3].show()
		_close_buttons[3].show()
		_file_text.add_theme_font_size_override("font_size",23)
	_art.queue_redraw()
	_net_lines.queue_redraw()
	_texture.queue_redraw()

func _draw_computer() -> void:
	var w: float = _desk.size.x
	var h: float = _desk.size.y
	Terminal.draw_monitor(_art)
	_art.draw_rect(Rect2(25,18,w-50,24), Color("#10371e"))
	_art.draw_rect(Rect2(105,46,w-124,h-106), EDGE, false, 1)
	for x: int in range(28, int(w)-26, 13):
		for y: int in range(47, int(h)-35, 13):
			_art.draw_rect(Rect2(x,y,1,1), Color("#0c2515"))

func _draw_icon(layer: Control, kind: int, compact: bool = false) -> void:
	# Integer-grid icons stay sharp at native size, without image imports or atlas filtering.
	var rows: PackedStringArray
	match kind:
		0: rows = PackedStringArray(["1111111111111111","1000000000000001","1010000000000001","1001000000000001","1000100000000001","1001000000000001","1010001111000001","1000000000000001","1111111111111111","0000000110000000","0000000110000000","0000111111110000"])
		1: rows = PackedStringArray(["0111110000000000","1100011000000000","1000001111111110","1000000000000011","1111111111111111","1000000000000001","1000000000000001","1000000000000001","1000000000000001","1000000000000001","1000000000000001","1111111111111111"])
		3: rows = PackedStringArray(["0000000110000000","0000001111000000","0000011001100000","0000110000110000","0001100000011000","0011000000001100","0111111111111110","0001000000001000","0001001111001000","0001001001001000","0001001001001000","0001111111111000"])
		4: rows = PackedStringArray(["0000000110000000","0000000110000000","0001100110011000","0011000110001100","0110000110000110","0100000110000010","0100000000000010","0100000000000010","0110000000000110","0011000000001100","0001100000011000","0000111111110000"])
		_: rows = PackedStringArray(["0000011111100000","0000010000100000","0000010000100000","0000011111100000","0000000110000000","0000000110000000","0001111111111000","0001000110001000","0111101111011110","0100101001010010","0100101001010010","0111101111011110"])
	var button: Button = layer.get_parent() as Button
	var ink: Color = EDGE if button.disabled else GREEN
	var origin: Vector2 = Vector2(floorf(layer.size.x/2)-16, 3 if compact else 12)
	if compact:
		var selected: bool = _rail.find(button) == int(_app)
		if selected or button.is_hovered() or button.is_pressed():
			layer.draw_rect(Rect2(4,layer.size.y-20,layer.size.x-8,18), Color("#145b29"))
	for y: int in rows.size():
		for x: int in rows[y].length():
			if rows[y][x] == "1":
				layer.draw_rect(Rect2(origin+Vector2(x*2,y*2), Vector2(2,2)), ink if y > 1 or button.disabled else Color("#aeffc0"))
	layer.draw_string(Terminal.FONT, Vector2(0,layer.size.y-(5 if compact else 12)), ["TERMINAL", "FILES", "NETMAP", "HOME", "EXIT"][kind], HORIZONTAL_ALIGNMENT_CENTER, layer.size.x, 18 if compact else 22, ink)

func _draw_links() -> void:
	for edge: Vector2i in [Vector2i(0,1), Vector2i(0,2), Vector2i(1,3), Vector2i(2,3)]:
		var start: Vector2 = _nodes[edge.x].get_rect().get_center()
		var end: Vector2 = _nodes[edge.y].get_rect().get_center()
		_net_lines.draw_dashed_line(start, end, EDGE, 2, 5)
		var mid: Vector2 = start.lerp(end,.5)
		_net_lines.draw_rect(Rect2(mid-Vector2.ONE*2,Vector2.ONE*4), GREEN)

func _open_app(app: App) -> void:
	if _mode not in ["active", "briefing"]: return
	_app = app
	_show_apps()

func _show_apps() -> void:
	_home.visible = _app == App.HOME
	_shell.visible = _app == App.TERMINAL
	_files.visible = _app == App.FILES
	_map.visible = _app == App.NETMAP
	_outcome.visible = _mode == "done"
	_leave.visible = _mode != "done"
	for index: int in _rail.size():
		_rail[index].visible = _mode != "done"
		_rail[index].disabled = _mode not in ["active", "briefing"]
		(_rail[index].get_child(0) as Control).queue_redraw()
	for close: Button in _close_buttons: close.disabled = _mode not in ["active", "briefing"]
	if practice_mode:
		_launch.visible = _mode == "ready"
		_role_choice.visible = _mode == "ready"
		_replay.visible = _mode == "done"
		for shortcut: Button in _shortcuts: shortcut.visible = _mode != "ready"

func prepare_practice() -> void:
	_history.clear()
	_data.clear()
	present({"role":_practice_role,"step":0,"rival_step":0,"inspected":false,"revision":0,"ends_at":0,"node":"INVITATION","inspect_label":"Inspect file","summary":"","detail":"","targets":{},"feedback":""},"ready")
	_clock.text = "02:00"

func _swap_practice_role() -> void:
	if _mode != "ready": return
	_practice_role = "defender" if _practice_role == "attacker" else "attacker"
	_data.role = _practice_role
	_refresh()

func present(data: Dictionary, mode: String, notice: String = "") -> void:
	var newly_finished: bool = mode == "done" and _mode != "done"
	var first: bool = _data.is_empty()
	var changed: bool = first or int(_data.step) != int(data.step)
	var inspected_now: bool = bool(data.inspected) and not bool(_data.get("inspected",false))
	if changed and not first and int(data.step) > int(_data.step):
		_history.append("> ROUTE ACCEPTED / STAGE %d" % int(data.step))
		if _mode == "active": AudioManager.play_sfx("ui_success")
	if inspected_now: _history.append("> READ " + str(data.node) + " / OK")
	while _history.size() > 2: _history.pop_front()
	if mode == "ready":
		_app = App.HOME
	elif mode not in ["active", "briefing"]:
		_app = App.FILES
	elif first or (_mode == "briefing" and mode == "active"):
		_app = App.HOME
	elif changed or inspected_now:
		_app = App.FILES
	if changed or mode != _mode or inspected_now:
		_selected = ""
		_file_scroll.scroll_vertical = 0
	_pending = false
	_data = data.duplicate(true)
	_mode = mode
	_note = notice
	_refresh()
	_layout(_surface)
	if newly_finished:
		if _result_tween != null: _result_tween.kill()
		_files.modulate.a = 1.0
		if not SettingsService.reduced_motion:
			_files.modulate.a = 0.0
			_result_tween = create_tween()
			_result_tween.tween_property(_files,"modulate:a",1.0,.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if notice.begins_with("VICTORY"): AudioManager.play_sfx("ui_success")

func show_clock(ms: int) -> void:
	if _mode == "done":
		_clock.text = "FINISHED"
		return
	var seconds: int = maxi(0, ceili(ms/1000.0))
	_clock.text = "%02d:%02d" % [seconds/60, seconds%60]

func show_rating(line: String, detail: String) -> void:
	_progress.text = line
	if _mode == "done": _file_text.text = _note.get_slice("\n",1) + "\n" + detail

func _refresh() -> void:
	var step: int = int(_data.step)
	var role: String = str(_data.role).to_upper()
	_head.text = "SYS://EVENT-PACK  /  " + role
	_progress.text = "LINK: ONLINE   /   YOU %d/3   RIVAL %d/3" % [step, int(_data.rival_step)]
	if practice_mode:
		_progress.text = "LOCAL PRACTICE / YOU %d/3   BOT %d/3" % [step,int(_data.rival_step)]
		_role_choice.text = "ROLE: " + _practice_role.to_upper()
	_home_title.text = "WELCOME, " + role
	_mission.text = "Trace the invitation. Retrieve EVENT.FLAG before your rival." if role == "ATTACKER" else "Verify the invitation. Secure EVENT.FLAG before your rival."
	_mission.text += "\nOpen Files to begin."
	if _mode == "briefing": _mission.text = "Connection established. Waiting for the synchronized start…"
	if practice_mode and _mode == "briefing": _mission.text = "Local opponent ready. The race starts when the countdown ends."
	if _mode == "ready":
		_home_title.text = "CAPTURE THE FLAG / PRACTICE"
		_mission.text = "Choose your role. First capture wins.\nThe bot takes 8–14 seconds per action."
		_progress.text = "OFFLINE PRACTICE / NO RATING CHANGE"
	_shell_text.text = "> CONNECT EVENT-PACK\nSESSION AUTHENTICATED / " + role + "\n" + "\n".join(_history) + "\n> CURRENT: " + str(_data.node) + "\n> _"
	if practice_mode: _shell_text.text = _shell_text.text.replace("SESSION AUTHENTICATED", "LOCAL PRACTICE")
	var targets: Dictionary = _data.targets
	_ids.assign(targets.keys())
	_nodes[0].text = str(_data.node)
	for index: int in 2:
		_nodes[index+1].text = str(targets[_ids[index]]).get_slice(" / ",0).to_upper() if index < _ids.size() and step < 2 else "LOCKED"
		_nodes[index+1].disabled = _mode != "active" or step >= 2 or index >= _ids.size()
	_nodes[3].text = "EVENT.FLAG"
	_nodes[3].disabled = _mode != "active" or step != 2 or not bool(_data.inspected)
	_nodes[0].disabled = _mode != "active"
	_map_note.text = "Select a destination to inspect its route." if bool(_data.inspected) else "Open the current file to reveal its routes."
	_files_caption.text = "FILES / " + str(_data.node)
	_file_text.add_theme_color_override("font_color", GREEN)
	_file_text.text = str(_data.summary)
	_action.disabled = _pending or _mode != "active"
	_action.text = str(_data.inspect_label).to_upper()
	var warning: bool = not str(_data.feedback).is_empty() or _mode in ["lost", "offline"] or (_mode == "done" and _note.begins_with("DEFEAT"))
	_files.add_theme_stylebox_override("panel", Terminal.box(BLACK, RED if warning else EDGE, 2))
	_files_caption.add_theme_stylebox_override("normal", Terminal.box(Color("#37100e") if warning else Color("#145b29"), RED if warning else EDGE, 1))
	_files_caption.add_theme_color_override("font_color", RED if warning else GREEN)
	if _mode == "ready":
		_action.disabled = true
	elif _mode not in ["active", "briefing"]:
		_file_text.text = _note
		_files_caption.text = "EVENT LOG / FINAL" if _mode == "done" else "WARNING / CONNECTION"
		_file_text.add_theme_color_override("font_color", RED if warning else GREEN)
		_action.text = "RETURN TO DIRECTORY" if _mode == "done" else ("RECONNECT" if _mode == "lost" else "RECONNECTING…")
		_action.disabled = _mode not in ["done", "lost"]
		_progress.text = "LINK: OFFLINE / WAITING FOR SERVER" if _mode != "done" else _progress.text
	elif _mode == "briefing":
		_file_text.text = "Session starts when the countdown ends."
	elif bool(_data.inspected):
		_file_text.text = str(_data.detail)
		_action.text = "OPEN NETMAP"
		if not _selected.is_empty():
			_action.text = str(targets[_selected]).to_upper() if step == 2 else "ROUTE TO " + _selected.to_upper()
			_file_text.text += "\n\nSelected: " + str(targets[_selected])
		if not str(_data.feedback).is_empty():
			_files_caption.text = "WARNING / ROUTE DENIED"
			_file_text.text = str(_data.feedback) + "\n\n" + _file_text.text
			_file_text.add_theme_color_override("font_color", RED)
	if _mode == "done":
		_head.text = "SYS://MATCH-REPORT  /  " + ("LOCAL" if practice_mode else "ONLINE")
		_files_caption.text = "SESSION COMPLETE / " + _note.get_slice("\n",0)
	_show_apps()

func _draw_outcome() -> void:
	var title: String = _note.get_slice("\n",0)
	var ink: Color = GREEN if title == "VICTORY" else (RED if title == "DEFEAT" else Color("#FFC642"))
	var rect: Rect2 = Rect2(0,0,_outcome.size.x,56)
	_outcome.draw_rect(rect,ink.darkened(.88))
	_outcome.draw_rect(rect,ink,false,2)
	_outcome.draw_rect(rect.grow(-4),ink.darkened(.45),false,1)
	for x: float in [8.0,rect.size.x-34]:
		for row: int in 18:
			for col: int in 12:
				if (row+col)%6 < 3: _outcome.draw_rect(Rect2(x+col*2,9+row*2,2,2),ink)
	_outcome.draw_string(Terminal.FONT,Vector2(42,42),title,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x-84,48,ink)
	# Pixel flag and a clear state caption; outcome never depends on color alone.
	_outcome.draw_rect(Rect2(30,76,4,48),ink)
	_outcome.draw_rect(Rect2(34,76,45,27),ink,false,3)
	for row: int in 3:
		for col: int in 5:
			if (row+col)%2 == 0: _outcome.draw_rect(Rect2(38+col*8,80+row*7,7,6),ink)
	if title == "DEFEAT": _outcome.draw_line(Vector2(22,125),Vector2(88,72),ink,4)
	_outcome.draw_string(Terminal.FONT,Vector2(1,146),"EVENT.FLAG",HORIZONTAL_ALIGNMENT_CENTER,116,20,ink)

func _select_node(index: int) -> void:
	if _pending or _mode != "active" or _nodes[index].disabled: return
	_selected = "" if index == 0 else ("flag" if index == 3 else _ids[index-1])
	_app = App.FILES
	_file_scroll.scroll_vertical = 0
	_refresh()

func _act() -> void:
	if _mode == "lost":
		retry_requested.emit()
		return
	if _mode == "done":
		leave_requested.emit()
		return
	if _mode != "active" or _pending: return
	if bool(_data.inspected) and _selected.is_empty():
		_open_app(App.NETMAP)
		return
	_pending = true
	_action.disabled = true
	command.emit("route" if bool(_data.inspected) else "inspect", _selected)
