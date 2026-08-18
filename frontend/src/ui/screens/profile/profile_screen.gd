extends BaseScreen
## Student dossier. Pulled from the logged-in `students` row via /api/auth/me.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const MASTERY_ORDER := ["Phishing", "Smishing", "Vishing", "Pretexting", "Baiting"]

@onready var _back_button: Button = %BackButton
@onready var _header_title: Label = %HeaderTitle
@onready var _os_cursor: Label = %OsCursor
@onready var _os_led: ColorRect = %OsLed
@onready var _os_bar: PanelContainer = %OsBar
@onready var _callsign: Label = %CallsignLabel
@onready var _rank: Label = %RankLabel
@onready var _section_hero: Label = %SectionHero
@onready var _hero_card: PanelContainer = %HeroCard
@onready var _identity_card: PanelContainer = %IdentityCard
@onready var _progress_card: PanelContainer = %ProgressCard
@onready var _systems_card: PanelContainer = %SystemsCard
@onready var _mastery_card: PanelContainer = %MasteryCard
@onready var _identity_bar: PanelContainer = %IdentityTitleBar
@onready var _progress_bar: PanelContainer = %ProgressTitleBar
@onready var _systems_bar: PanelContainer = %SystemsTitleBar
@onready var _mastery_bar: PanelContainer = %MasteryTitleBar
@onready var _mastery_list: VBoxContainer = %MasteryList
@onready var _full_name: Label = %FullNameValue
@onready var _email: Label = %EmailValue
@onready var _section: Label = %SectionValue
@onready var _status: Label = %StatusValue
@onready var _level: Label = %LevelValue
@onready var _exp: Label = %ExpValue
@onready var _sessions: Label = %SessionsValue
@onready var _stage: Label = %StageValue
@onready var _pre: Label = %PreValue
@onready var _post: Label = %PostValue
@onready var _threat: Label = %ThreatValue
@onready var _materials: Label = %MaterialsValue
@onready var _tower: Label = %TowerLevel
@onready var _glade: Label = %GladeLevel
@onready var _forge: Label = %ForgeLevel
@onready var _exp_fill: ColorRect = %ExpBarFill

var _pixel_font: Font
var _blink_t: float = 0.0


func _ready() -> void:
	_load_font()
	_style_chrome()
	_back_button.pressed.connect(func() -> void: Router.request_back())


func _process(delta: float) -> void:
	_blink_t += delta
	var on := fmod(_blink_t, 1.05) < 0.58
	_os_cursor.visible = on
	_os_led.color = Palette.GREEN if on else Color(Palette.GREEN, 0.28)


func on_enter(_args: Dictionary) -> void:
	set_process(true)
	_apply_copy()
	_bind_profile()
	_refresh_from_server()


func on_resume() -> void:
	_bind_profile()
	_refresh_from_server()


func on_exit() -> void:
	set_process(false)


func _refresh_from_server() -> void:
	await AuthService.refresh_profile()
	if not is_inside_tree():
		return
	_bind_profile()


func _apply_copy() -> void:
	_header_title.text = tr("PROFILE_TITLE")
	%IdentityFile.text = tr("PROFILE_IDENTITY")
	%ProgressFile.text = tr("PROFILE_PROGRESS")
	%SystemsFile.text = tr("PROFILE_SYSTEMS")
	%MasteryFile.text = tr("PROFILE_MASTERY")
	%FullNameLabel.text = tr("PROFILE_FULL_NAME")
	%EmailLabel.text = tr("PROFILE_EMAIL")
	%SectionLabel.text = tr("PROFILE_SECTION")
	%StatusLabel.text = tr("PROFILE_STATUS")
	%LevelLabel.text = tr("PROFILE_LEVEL")
	%ExpLabel.text = tr("PROFILE_EXP")
	%SessionsLabel.text = tr("PROFILE_SESSIONS")
	%StageLabel.text = tr("PROFILE_STAGE")
	%PreLabel.text = tr("PROFILE_PRE")
	%PostLabel.text = tr("PROFILE_POST")
	%ThreatLabel.text = tr("PROFILE_THREAT")
	%MaterialsLabel.text = tr("PROFILE_MATERIALS")
	%TowerCaption.text = tr("PROFILE_TOWER")
	%GladeCaption.text = tr("PROFILE_GLADE")
	%ForgeCaption.text = tr("PROFILE_FORGE")


func _bind_profile() -> void:
	_callsign.text = AuthService.display_name()
	_rank.text = AuthService.rank_title()
	var section := AuthService.section()
	_section_hero.text = section if not section.is_empty() else "—"
	_full_name.text = AuthService.full_name()
	_email.text = AuthService.email() if not AuthService.email().is_empty() else "—"
	_section.text = section if not section.is_empty() else "—"
	_status.text = AuthService.status_label()
	_level.text = tr("PROFILE_LV") % AuthService.tower_level()
	_exp.text = "%d / %d" % [AuthService.points(), AuthService.next_rank_points()]
	_sessions.text = str(AuthService.sessions())
	_stage.text = str(AuthService.current_stage())
	_pre.text = "%d%%" % AuthService.pre_score()
	_post.text = "%d%%" % AuthService.post_score()
	_threat.text = str(maxi(AuthService.threat_points(), 0))
	_materials.text = str(maxi(AuthService.materials(), 0))
	_tower.text = tr("PROFILE_LV") % AuthService.tower_level()
	_glade.text = tr("PROFILE_LV") % AuthService.glade_level()
	_forge.text = tr("PROFILE_LV") % AuthService.forge_level()
	var span := maxi(AuthService.exp_rank_span(), 1)
	_exp_fill.anchor_right = clampf(float(AuthService.exp_into_rank()) / float(span), 0.04, 1.0)
	_exp_fill.offset_right = 0.0
	_rebuild_mastery()


func _rebuild_mastery() -> void:
	for child in _mastery_list.get_children():
		child.queue_free()
	var mastery := AuthService.mastery()
	for topic in MASTERY_ORDER:
		var p_learn := clampf(float(mastery.get(topic, 0.0)), 0.0, 1.0)
		_mastery_list.add_child(_make_mastery_row(str(topic), p_learn))


func _make_mastery_row(topic: String, p_learn: float) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var header := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = topic.to_upper()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_label(name_label, Palette.TEXT_SECONDARY, 9)
	var value := Label.new()
	value.text = "%.0f%%" % (p_learn * 100.0)
	_apply_label(value, Palette.CYAN if p_learn >= 0.4 else Palette.GOLD, 9)
	header.add_child(name_label)
	header.add_child(value)
	var track := PanelContainer.new()
	track.custom_minimum_size = Vector2(0, 10)
	var track_box := _pixel_box(Palette.BG_DEEP, Palette.CYAN_DIM, 0, 2)
	track.add_theme_stylebox_override("panel", track_box)
	var fill := ColorRect.new()
	fill.color = Palette.CYAN if p_learn >= 0.4 else Palette.GOLD
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = maxf(p_learn, 0.04)
	fill.offset_right = 0.0
	track.add_child(fill)
	row.add_child(header)
	row.add_child(track)
	return row


func _style_chrome() -> void:
	_style_window(_os_bar, Palette.CYAN)
	_style_window(_hero_card, Palette.CYAN)
	_style_window(_identity_card, Palette.CYAN)
	_style_window(_progress_card, Palette.GOLD)
	_style_window(_systems_card, Palette.CYAN)
	_style_window(_mastery_card, Palette.GOLD)
	_style_title_bar(_identity_bar, Palette.CYAN_DIM)
	_style_title_bar(_progress_bar, Palette.ORANGE)
	_style_title_bar(_systems_bar, Palette.CYAN_DIM)
	_style_title_bar(_mastery_bar, Palette.ORANGE)
	_style_close_button()
	var avatar := %AvatarBox as PanelContainer
	avatar.add_theme_stylebox_override("panel", _pixel_box(Palette.FOREST_NIGHT, Palette.CYAN, 0, 2))
	%ExpBar.add_theme_stylebox_override("panel", _pixel_box(Palette.BG_DEEP, Palette.CYAN_DIM, 0, 2))
	%ExpBarFill.color = Palette.CYAN
	_apply_label(_header_title, Palette.TEXT_PRIMARY, 12)
	_apply_label(_os_cursor, Palette.GREEN, 12)
	_apply_label(_callsign, Palette.TEXT_PRIMARY, 16)
	_apply_label(_rank, Palette.GREEN, 10)
	_apply_label(_section_hero, Palette.TEXT_SECONDARY, 9)
	_apply_label(_full_name, Palette.TEXT_PRIMARY, 10)
	_apply_label(_email, Palette.TEXT_PRIMARY, 10)
	_apply_label(_section, Palette.TEXT_PRIMARY, 10)
	_apply_label(_status, Palette.TEXT_PRIMARY, 10)
	_apply_label(_level, Palette.CYAN, 12)
	_apply_label(_exp, Palette.TEXT_PRIMARY, 10)
	_apply_label(_sessions, Palette.TEXT_PRIMARY, 10)
	_apply_label(_stage, Palette.TEXT_PRIMARY, 10)
	_apply_label(_pre, Palette.TEXT_PRIMARY, 10)
	_apply_label(_post, Palette.TEXT_PRIMARY, 10)
	_apply_label(_threat, Palette.GOLD, 12)
	_apply_label(_materials, Palette.CYAN, 12)
	_apply_label(_tower, Palette.TEXT_PRIMARY, 12)
	_apply_label(_glade, Palette.TEXT_PRIMARY, 12)
	_apply_label(_forge, Palette.TEXT_PRIMARY, 12)
	for caption in [%FullNameLabel, %EmailLabel, %SectionLabel, %StatusLabel, %LevelLabel, %ExpLabel, %SessionsLabel, %StageLabel, %PreLabel, %PostLabel, %ThreatLabel, %MaterialsLabel, %TowerCaption, %GladeCaption, %ForgeCaption, %IdentityFile, %ProgressFile, %SystemsFile, %MasteryFile]:
		_apply_label(caption, Palette.TEXT_SECONDARY, 9)
	_style_stat_value(_full_name)
	_style_stat_value(_email)
	_style_stat_value(_section)
	_style_stat_value(_status)
	_apply_label(_email, Palette.TEXT_PRIMARY, 9)


func _style_stat_value(label: Label) -> void:
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_label(label, Palette.TEXT_PRIMARY, 10)


func _style_close_button() -> void:
	var box := _pixel_box(Palette.RED_DEEP, Palette.RED, 0, 2)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	_back_button.add_theme_stylebox_override("normal", box)
	_back_button.add_theme_stylebox_override("hover", _pixel_box(Palette.RED, Palette.TEXT_PRIMARY, 0, 2))
	_back_button.add_theme_stylebox_override("pressed", box)
	_back_button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_back_button.text = "X"
	if _pixel_font != null:
		_back_button.add_theme_font_override("font", _pixel_font)
	_back_button.add_theme_font_size_override("font_size", 12)


func _style_window(card: PanelContainer, accent: Color) -> void:
	var box := _pixel_box(Color(Palette.BG_HEADER, 0.94), accent, 0, 2)
	box.content_margin_left = 0.0
	box.content_margin_right = 0.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	box.shadow_color = Color(Palette.BG_DEEP, 0.7)
	box.shadow_size = 1
	box.shadow_offset = Vector2(4, 4)
	card.add_theme_stylebox_override("panel", box)


func _style_title_bar(bar: PanelContainer, fill: Color) -> void:
	var style := _pixel_box(fill, fill, 0, 0)
	style.content_margin_left = 10.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	bar.add_theme_stylebox_override("panel", style)


func _pixel_box(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(radius)
	return box


func _apply_label(label: Label, color: Color, font_size: int) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if _pixel_font != null:
		label.add_theme_font_override("font", _pixel_font)


func _load_font() -> void:
	if not ResourceLoader.exists(FONT_PATH):
		return
	var file: FontFile = load(FONT_PATH) as FontFile
	if file != null:
		_pixel_font = file
