extends Control
## A touch-operated terminal. The dashboard owns the existing navigation signals.
signal switch_requested
signal battle_requested
signal create_room_requested
signal join_room_requested
signal find_opponent_requested

const FONT: Font = preload("res://assets/fonts/VT323-Regular.ttf")
const AMBER: Color = Color("#ffc642")
const INK: Color = Color("#130d04")
const EDGE: Color = Color("#a77523")
const SCREEN: Color = Color("#090804")

var _content: Control
var _status: VBoxContainer
var _switch: Button
var _queue: Button
var _create: Button
var _join: Button
var _find: Button
var _account: String
var _tick: float = 0.0
var _profile: Rect2
var _standing: Dictionary = {}
var _standing_loading: bool = false
var _standing_fresh: bool = false
var _standing_fetched_at: int = -10000
var _rain: Control
var _rain_material: ShaderMaterial
var _scan_line: ColorRect
var _phosphor_glass: ColorRect
var _refresh_band: TextureRect
var _columns: PackedStringArray = []
var _glass: Rect2
var _window: Rect2
var _unit: float = 1.0
## Set before adding this screen to the tree for the matchmaking handoff.
var match_confirmed: bool = false
## The online screen supplies the controls and owns their room/session signals.
var lobby_panel: ScrollContainer

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra_margin = 0
	add_child(safe)
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_content = Control.new()
	safe.add_child(_content)
	if lobby_panel != null:
		_content.add_child(lobby_panel)
		var form: Control = lobby_panel.get_child(0) as Control
		form.minimum_size_changed.connect(_layout, CONNECT_DEFERRED)
	elif not match_confirmed:
		_build_commands()
	else:
		accessibility_name = "Match found. Access granted."
	_setup_display()

func _build_commands() -> void:
	_status = VBoxContainer.new()
	_content.add_child(_status)
	_create = terminal_command("Create Room", create_room_requested.emit)
	_find = terminal_command("Find a Match", find_opponent_requested.emit, true)
	_join = terminal_command("Join a Room", join_room_requested.emit)
	_create.name = "CreateRoom"
	_find.name = "FindOpponent"
	_join.name = "JoinRoom"
	for command: Button in [_create, _find, _join]:
		_status.add_child(command)
	_switch = terminal_command("Switch mode", switch_requested.emit)
	_switch.name = "SwitchOS"
	_content.add_child(_switch)
	_queue = terminal_command("Practice vs bot", battle_requested.emit)
	_content.add_child(_queue)

func _setup_display() -> void:
	# Cache glyph geometry across frames. Only phosphor brightness and the scan line move.
	_rain = Control.new()
	_rain.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_rain)
	move_child(_rain, 0)
	_rain.draw.connect(_draw_streams)
	var shader: Shader = Shader.new()
	shader.code = """
		shader_type canvas_item;
		uniform float seconds;
		varying vec2 cell;
		void vertex() { cell = COLOR.rg * 255.0; }
		void fragment() {
			float column = round(cell.x);
			float row = round(cell.y);
			float speed = 0.8 + mod(column, 3.0) * 0.35;
			float trail = fract((row - column * 7.0 - seconds * speed) / 19.0);
			float light = smoothstep(0.0, 0.24, trail) * (1.0 - smoothstep(0.24, 0.7, trail));
			vec3 ink = mix(vec3(0.09,0.07,0.035),vec3(0.53,0.38,0.15),light);
			COLOR = vec4(ink,COLOR.a);
		}
	"""
	_rain_material = ShaderMaterial.new()
	_rain_material.shader = shader
	_rain.material = _rain_material
	_scan_line = ColorRect.new()
	_scan_line.mouse_filter = MOUSE_FILTER_IGNORE
	_scan_line.color = Color("#98712e")
	add_child(_scan_line)
	move_child(_scan_line, 1)
	if _status != null:
		_build_glass_effect()
	var glyphs: String = "0123456789ABCDEF<>+=:/"
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 1771
	for index: int in 80:
		var strip: String = ""
		for j: int in 32:
			strip += glyphs[random.randi_range(0, glyphs.length()-1)]
		_columns.append(strip)
	_content.resized.connect(_layout)
	visibility_changed.connect(_visibility_changed)
	AuthService.session_changed.connect(_account_changed)
	SettingsService.settings_changed.connect(_motion)
	refresh_identity()
	_motion()
	_layout.call_deferred()

func _build_glass_effect() -> void:
	_phosphor_glass = ColorRect.new()
	_phosphor_glass.color = Color.TRANSPARENT
	_phosphor_glass.clip_contents = true
	_phosphor_glass.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_phosphor_glass)

	var trail: Gradient = Gradient.new()
	trail.offsets = PackedFloat32Array([0.0, 0.68, 0.9, 1.0])
	trail.colors = PackedColorArray([Color("#ffcd7900"), Color("#ffcd7908"), Color("#ffcd7917"), Color("#ffcd7900")])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.width = 2
	texture.height = 64
	texture.fill_to = Vector2.DOWN
	texture.gradient = trail
	_refresh_band = TextureRect.new()
	_refresh_band.texture = texture
	_refresh_band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_refresh_band.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_refresh_band.mouse_filter = MOUSE_FILTER_IGNORE
	_phosphor_glass.add_child(_refresh_band)

func refresh_identity() -> void:
	_account = AuthService.display_name().strip_edges().to_upper()
	_standing = AuthService.pvp_standing()
	if is_visible_in_tree() and not match_confirmed and lobby_panel == null:
		_refresh_standing()
	queue_redraw()

func _account_changed(_signed_in: bool) -> void:
	_standing_fetched_at = -10000
	_standing_fresh = false
	refresh_identity()

func _visibility_changed() -> void:
	_motion()
	if is_visible_in_tree():
		_standing_fetched_at = -10000
		refresh_identity()

func _refresh_standing() -> void:
	if _standing_loading or Time.get_ticks_msec()-_standing_fetched_at < 10000: return
	if AuthService.auth_token().is_empty():
		_standing.clear()
		_standing_fresh = false
		return
	_standing_loading = true
	var owner: String = AuthService.auth_token()
	var fresh: bool = await AuthService.fetch_pvp_standing()
	_standing_loading = false
	if owner != AuthService.auth_token():
		refresh_identity()
		return
	_standing_fetched_at = Time.get_ticks_msec()
	_standing_fresh = fresh
	_standing = AuthService.pvp_standing()
	queue_redraw()

func _motion() -> void:
	if _phosphor_glass != null:
		_phosphor_glass.visible = not SettingsService.reduced_motion
	set_process(is_visible_in_tree() and not SettingsService.reduced_motion)
	queue_redraw()

func _process(delta: float) -> void:
	_tick += delta
	_update_motion()

func _update_motion() -> void:
	if _glass.size.y <= 0.0:
		return
	_rain_material.set_shader_parameter("seconds", _tick)
	var center: Vector2 = _window.position + Vector2(44*_unit, _window.size.y*0.53)
	_scan_line.position = center + Vector2(-27, sin(_tick*1.2)*30)*_unit
	_scan_line.size = Vector2(54,1)*_unit
	if _phosphor_glass != null and _phosphor_glass.visible:
		# Two slow waves occasionally coincide for a small dip in phosphor brightness.
		var dip: float = smoothstep(0.35, 1.0, sin(_tick * 3.7)) * (0.5 + 0.5 * sin(_tick * 1.3))
		_phosphor_glass.color = Color(0, 0, 0, 0.045 * dip)
		var phase: float = fmod(_tick, 5.5) / 5.5
		_refresh_band.position.y = lerpf(-_refresh_band.size.y, _phosphor_glass.size.y, phase)

static func _box(fill: Color, border: Color, width: int = 1, radius: int = 0) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.corner_detail = 2
	return box

static func terminal_command(caption: String, action: Callable, primary: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = caption.to_upper()

	button.add_theme_font_override("font", FONT)
	button.add_theme_color_override("font_color", Color("#ffe192") if primary else AMBER)
	button.add_theme_color_override("font_hover_color", Color("#fff1c9"))
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_stylebox_override("normal", _box(Color("#432c08") if primary else INK, AMBER if primary else EDGE, 2))
	button.add_theme_stylebox_override("hover", _box(Color("#593b0c"), AMBER, 2))
	button.add_theme_stylebox_override("pressed", _box(AMBER, AMBER))
	button.add_theme_stylebox_override("disabled", _box(INK, EDGE.darkened(0.4)))
	button.add_theme_color_override("font_disabled_color", EDGE.lightened(0.25))
	var focus: StyleBoxFlat = _box(Color.TRANSPARENT, Color("#ffdf8c"), 2)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(action)
	return button

func _layout_changed() -> void:
	if _phosphor_glass != null:
		var inner_glass: Rect2 = _glass.grow(-5.0 * _unit)
		_phosphor_glass.position = inner_glass.position
		_phosphor_glass.size = inner_glass.size
		_refresh_band.size = Vector2(inner_glass.size.x, inner_glass.size.y * 0.16)
	_rain.queue_redraw()
	_update_motion()
	queue_redraw()

func _layout() -> void:
	if not is_node_ready() or _content.size.y < 1:
		return
	var area: Vector2 = _content.size
	_unit = minf(area.x / 720.0, area.y / 360.0)
	var u: float = _unit
	var origin: Vector2 = _content.position
	var physical: float = maxf(.25, float(get_window().size.y) / get_viewport_rect().size.y)
	var tap: float = maxf(44.0 / physical, 42*u)
	_glass = Rect2(origin + Vector2(20,13)*u, area - Vector2(40,44)*u)
	if lobby_panel != null:
		var dialog_width: float = minf(520.0, _glass.size.x/u - 16.0)
		var form: Control = lobby_panel.get_child(0) as Control
		var body_height: float = clampf(form.get_combined_minimum_size().y, 112.0, _glass.size.y/u - 56.0)
		var dialog: Vector2 = Vector2(dialog_width, body_height + 48.0) * u
		_window = Rect2((_glass.get_center() - dialog*0.5).round(), dialog)
		lobby_panel.scale = Vector2.ONE*u
		lobby_panel.position = _window.position-origin + Vector2(83,24)*u
		lobby_panel.size = Vector2(dialog_width-96, body_height)
		_layout_changed()
		return
	var window_width: float = minf(394*u, _glass.size.x*0.75)
	if match_confirmed:
		var dialog_size: Vector2 = Vector2(window_width, 142*u)
		_window = Rect2((_glass.get_center() - dialog_size*0.5 - Vector2(0,24*u)).round(), dialog_size)
		_layout_changed()
		return
	var gap: float = roundf(5*u)
	var height: float = 3*tap + 2*gap + 52*u
	_window = Rect2((_glass.get_center() - Vector2(window_width,height)*0.5 - Vector2(0,7*u)).round(), Vector2(window_width,height))
	_window.position.x = _glass.end.x - window_width - 12*u
	_profile = Rect2(_glass.position.x+12*u, _window.position.y, _window.position.x-_glass.position.x-26*u, height)
	for button: Button in [_create, _find, _join, _switch, _queue]:
		button.add_theme_font_size_override("font_size", maxi(15, roundi(26*u)))
		button.custom_minimum_size = Vector2(0, tap)
	_status.add_theme_constant_override("separation", roundi(gap))
	_status.position = _window.position - origin + Vector2(88,30)*u
	_status.size = Vector2(window_width - 104*u, 3*tap + 2*gap)
	for button: Button in [_switch, _queue]:
		button.add_theme_font_size_override("font_size", roundi(19*u))
	_switch.size = Vector2(105*u,tap)
	_queue.size = Vector2(130*u,tap)
	_switch.position = _glass.position - origin + Vector2(8*u,_glass.size.y - tap - 6*u)
	_queue.position = _glass.end - origin - _queue.size - Vector2(8,6)*u
	_layout_changed()

func _draw() -> void:
	if _glass.size.y < 1:
		return
	var u: float = _unit
	# All art is drawn in reference-sized pixels, while touch targets use safe coordinates.
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE*u)
	var shell: Rect2 = Rect2(Vector2.ONE, size/u - Vector2.ONE*2)
	var glass: Rect2 = Rect2(_glass.position/u, _glass.size/u)
	var window: Rect2 = Rect2(_window.position/u, _window.size/u)
	draw_style_box(_box(Color("#a99e87"), Color("#d9cfb5"), 2, 10), shell)
	draw_style_box(_box(Color("#342e22"), Color("#625840"), 2, 8), glass.grow(4))
	draw_style_box(_box(SCREEN, Color("#201c13"), 2, 6), glass)
	if not match_confirmed and lobby_panel == null: _draw_profile()
	draw_style_box(_box(INK, EDGE, 1), window.grow(2))
	draw_rect(window, AMBER, false, 1)
	var bar: Rect2 = Rect2(window.position + Vector2(2,2), Vector2(window.size.x-4,17))
	draw_rect(bar, Color("#d7a13b"))
	draw_string(FONT, bar.position+Vector2(5,14), "PVP MATCH DIRECTORY", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, INK)
	for i: int in 7:
		draw_line(bar.end-Vector2(8+i*3,14), bar.end-Vector2(8+i*3,3), INK, 1)
	var scan: Vector2 = window.position+Vector2(44,window.size.y*0.53)
	_draw_reader(scan)
	if match_confirmed:
		draw_string(FONT, window.position + Vector2(89, 84), "MATCH FOUND", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, AMBER)
		_draw_access_granted(Rect2(window.position.x, window.end.y + 12, window.size.x, 34))
	var footer: Vector2 = Vector2(window.position.x+8,window.end.y-5)
	draw_string(FONT, footer, "USER // " + (_account if not _account.is_empty() else "LOCAL"), HORIZONTAL_ALIGNMENT_LEFT, window.size.x-20, 16, Color("#ca9b42"))
	# Subtle horizontal glass texture across the monitor, including the title strip.
	for y: int in range(ceili(glass.position.y+4), floori(glass.end.y-4), 3):
		draw_line(Vector2(glass.position.x+4,y), Vector2(glass.end.x-4,y), Color(0.02,0.015,0.0,0.15), 0.65)
	var base_y: float = lerpf(glass.end.y, shell.end.y, .57)
	draw_style_box(_box(Color("#817660"), Color("#534934"),1,2), Rect2(glass.position.x,base_y-4,56,9))
	for i: int in 12:
		var x: float = glass.end.x-108+i*5
		draw_line(Vector2(x,base_y-4),Vector2(x,base_y+5), Color("#534b3a"), 1.5)
	draw_rect(Rect2(glass.end.x-40,base_y-1,5,2),Color("#61e782"))
	draw_style_box(_box(Color("#bbaf96"), Color("#584f40")),Rect2(glass.end.x-27,base_y-5,18,11))
	draw_rect(Rect2(glass.end.x-21,base_y-2,7,3),Color("#786d58"))

func _draw_access_granted(rect: Rect2) -> void:
	draw_rect(rect, INK)
	draw_rect(rect, AMBER, false, 2)
	draw_rect(rect.grow(-3), EDGE, false, 1)
	for edge_x: float in [rect.position.x + 5, rect.end.x - 25]:
		# Slanted bands, clipped to a 20-pixel end cap at either edge.
		for offset: int in range(-24, 21, 6):
			var start: float = maxf(0, -offset)
			var end: float = minf(24, 20-offset)
			draw_line(Vector2(edge_x+offset+start, rect.end.y-5-start), Vector2(edge_x+offset+end, rect.end.y-5-end), AMBER, 2)
	draw_string(FONT, Vector2(rect.position.x, rect.get_center().y + 8), "ACCESS GRANTED", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 30, Color("#ffe192"))

func _draw_streams() -> void:
	if _glass.size.y <= 0.0:
		return
	var bounds: Rect2 = Rect2(_glass.position/_unit, _glass.size/_unit).grow(-5)
	var dialog: Rect2 = Rect2(_window.position/_unit, _window.size/_unit).grow(3)
	var panel: Rect2 = Rect2(_profile.position/_unit, _profile.size/_unit).grow(2)
	var directory: bool = lobby_panel == null and not match_confirmed
	var banner: Rect2 = Rect2(dialog.position.x, dialog.end.y+8, dialog.size.x, 38)
	_rain.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE*_unit)
	for col: int in mini(_columns.size(), floori(bounds.size.x/13)):
		var start: Vector2 = bounds.position + Vector2(col*13+3, (col*17)%11+10)
		var count: int = floori((bounds.end.y-start.y)/10)
		for row: int in count:
			var point: Vector2 = start + Vector2(0,row*10)
			var cell: Rect2 = Rect2(point-Vector2(0,12),Vector2(10,14))
			if dialog.intersects(cell) or (directory and panel.intersects(cell)) or (match_confirmed and banner.intersects(cell)):
				continue
			_rain.draw_char(FONT,point,_columns[col][row%32],14,Color8(col,row,0))

func _draw_reader(center: Vector2) -> void:
	var rect: Rect2 = Rect2(center-Vector2(29,33),Vector2(58,66))
	draw_rect(rect, Color("#231a08"))
	for sign_x: float in [-1.0,1.0]:
		for sign_y: float in [-1.0,1.0]:
			var corner: Vector2 = center+Vector2(29*sign_x,33*sign_y)
			draw_line(corner,corner-Vector2(8*sign_x,0),AMBER,1)
			draw_line(corner,corner-Vector2(0,8*sign_y),AMBER,1)
	# Draw broken, nested fingerprint ridges using the same square pixel grid as the type.
	for ring: int in 5:
		var radius: float = 19.0 - 3.5*ring
		var points: PackedVector2Array = []
		for i: int in 27:
			var angle: float = lerpf(2.9 + ring*.12, TAU + 1.0 - ring*.12, i/26.0)
			points.append((center + Vector2(cos(angle)*radius,sin(angle)*radius*1.25)).snapped(Vector2.ONE*2))
		draw_polyline(points, Color("#ffe096"), 1.7)


func _draw_profile() -> void:
	var rect: Rect2 = Rect2(_profile.position/_unit,_profile.size/_unit)
	draw_style_box(_box(INK, EDGE, 1), rect)
	draw_rect(Rect2(rect.position+Vector2(2,2), Vector2(rect.size.x-4,17)),Color("#d7a13b"))
	draw_string(FONT,rect.position+Vector2(7,16),"OPERATOR / RANKED",HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-14,18,INK)
	var x: float = rect.position.x+12
	var y: float = rect.position.y
	var width: float = rect.size.x-24
	draw_string(FONT,Vector2(x,y+42),_account.left(20),HORIZONTAL_ALIGNMENT_LEFT,width,21,Color("#ffe192"))
	if _standing.is_empty():
		draw_string(FONT,Vector2(x,y+80),"SYNCING..." if _standing_loading else "RANK UNAVAILABLE",HORIZONTAL_ALIGNMENT_LEFT,width,23,AMBER)
		draw_string(FONT,Vector2(x,y+108),"Connect to load your stats.",HORIZONTAL_ALIGNMENT_LEFT,width,17,EDGE.lightened(.3))
		return
	draw_string(FONT,Vector2(x,y+75),str(_standing.get("rank","")).to_upper(),HORIZONTAL_ALIGNMENT_LEFT,width,30,AMBER)
	draw_string(FONT,Vector2(x,y+98),"%d PVP POINTS" % int(_standing.get("points",0)),HORIZONTAL_ALIGNMENT_LEFT,width,21,Color("#ffe192"))
	draw_string(FONT,Vector2(x,y+126),"W %d   L %d   D %d" % [int(_standing.get("wins",0)),int(_standing.get("losses",0)),int(_standing.get("draws",0))],HORIZONTAL_ALIGNMENT_LEFT,width,21,AMBER)
	var next: Variant = _standing.get("next_threshold")
	var base: float = float(_standing.get("current_threshold",0))
	var ratio: float = 1.0 if next == null else clampf((float(_standing.get("points",0))-base)/maxf(1,float(next)-base),0,1)
	for cell: int in 24:
		draw_rect(Rect2(x+cell*width/24,y+139,width/24-2,8), AMBER if float(cell)/24 < ratio else Color("#493514"))
	var next_line: String = "MAX RANK" if next == null else "%d TO %s" % [int(_standing.get("points_to_next_rank",0)),str(_standing.get("next_rank","")).to_upper()]
	draw_string(FONT,Vector2(x,y+167),next_line,HORIZONTAL_ALIGNMENT_LEFT,width,18,AMBER)
	draw_string(FONT,Vector2(x,rect.end.y-8),"%d MATCHES / %s" % [int(_standing.get("rated_matches",0)),"SYNCED" if _standing_fresh else "CACHED"],HORIZONTAL_ALIGNMENT_LEFT,width,16,EDGE.lightened(.3))
