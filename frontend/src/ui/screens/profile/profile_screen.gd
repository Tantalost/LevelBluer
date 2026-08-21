extends BaseScreen
## Student dossier. Pulled from the logged-in `students` row via /api/auth/me.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const MASTERY_ORDER := [
	{"topic": "Phishing", "kind": IntelPixelIcon.Kind.ENVELOPE},
	{"topic": "Smishing", "kind": IntelPixelIcon.Kind.CHAT},
	{"topic": "Vishing", "kind": IntelPixelIcon.Kind.PHONE},
]

@onready var _back_button: Button = %BackButton
@onready var _header_title: Label = %HeaderTitle
@onready var _os_cursor: Label = %OsCursor
@onready var _os_led: ColorRect = %OsLed
@onready var _os_bar: PanelContainer = %OsBar
@onready var _callsign: Label = %CallsignLabel
@onready var _rank: Label = %RankLabel
@onready var _section_hero: Label = %SectionHero
@onready var _email_hero: Label = %EmailHero
@onready var _status_badge: PanelContainer = %StatusBadge
@onready var _status_badge_label: Label = %StatusBadgeLabel
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
@onready var _status: Label = %StatusValue
@onready var _exp_caption: Label = %ExpCaption
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
	%StatusLabel.text = tr("PROFILE_STATUS")
	%SessionsLabel.text = tr("PROFILE_SESSIONS")
	%StageLabel.text = tr("PROFILE_STAGE_SHORT")
	%PreLabel.text = tr("PROFILE_PRE")
	%PostLabel.text = tr("PROFILE_POST")
	%ThreatLabel.text = tr("PROFILE_THREAT_SHORT")
	%MaterialsLabel.text = tr("PROFILE_MATERIALS")
	%TowerCaption.text = tr("PROFILE_TOWER")
	%GladeCaption.text = tr("PROFILE_GLADE")
	%ForgeCaption.text = tr("PROFILE_FORGE")
	%LegendLow.text = tr("PROFILE_LEGEND_LOW")
	%LegendMid.text = tr("PROFILE_LEGEND_MID")
	%LegendHigh.text = tr("PROFILE_LEGEND_HIGH")


func _bind_profile() -> void:
	_callsign.text = AuthService.display_name()
	_rank.text = AuthService.rank_title()
	var section := AuthService.section()
	var email := AuthService.email()
	_section_hero.text = "%s: %s" % [tr("PROFILE_SECTION").to_upper(), section if not section.is_empty() else "—"]
	_email_hero.text = "%s: %s" % [tr("PROFILE_EMAIL").to_upper(), email if not email.is_empty() else "—"]
	_full_name.text = AuthService.full_name()
	var status := AuthService.status_label()
	_status.text = status if not status.is_empty() else "—"
	_status_badge_label.text = status.to_upper() if not status.is_empty() else "—"
	_style_status_badge(_is_on_track(status))
	_apply_label(_status, _band_color(_status_unit(status)), 10)
	_exp_caption.text = tr("PROFILE_TOWER_XP") % AuthService.tower_level()
	_exp.text = "%d / %d" % [AuthService.exp_into_rank(), AuthService.exp_rank_span()]
	_sessions.text = str(AuthService.sessions())
	_stage.text = str(AuthService.current_stage())
	var pre := AuthService.pre_score()
	var post := AuthService.post_score()
	_pre.text = "%d%%" % pre
	_post.text = "%d%%" % post
	_apply_label(_pre, _band_color(float(pre) / 100.0), 12)
	_apply_label(_post, _band_color(float(post) / 100.0), 12)
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
	for entry in MASTERY_ORDER:
		var topic := str(entry["topic"])
		var p_learn := _as_unit(float(mastery.get(topic, 0.0)))
		var kind: IntelPixelIcon.Kind = entry["kind"]
		_mastery_list.add_child(_make_mastery_row(topic, p_learn, kind))


func _make_mastery_row(topic: String, p_learn: float, kind: IntelPixelIcon.Kind) -> Control:
	var accent := _band_color(p_learn)
	var cell := PanelContainer.new()
	cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.add_theme_stylebox_override("panel", _pixel_box(Palette.BG_PANEL_ALT, Palette.CYAN_DIM, 0, 2))
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := IntelPixelIcon.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.kind = kind
	icon.ink_override = accent
	var name_label := Label.new()
	name_label.text = topic.to_upper()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_label(name_label, Palette.TEXT_SECONDARY, 9)
	var value := Label.new()
	value.text = "%.0f%%" % (p_learn * 100.0)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_label(value, accent, 10)
	header.add_child(icon)
	header.add_child(name_label)
	header.add_child(value)
	var track := PanelContainer.new()
	track.custom_minimum_size = Vector2(0, 12)
	track.add_theme_stylebox_override("panel", _pixel_box(Palette.BG_DEEP, Palette.CYAN_DIM, 0, 2))
	var fill := ColorRect.new()
	fill.color = accent
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = maxf(p_learn, 0.04)
	fill.offset_right = 0.0
	track.add_child(fill)
	row.add_child(header)
	row.add_child(track)
	pad.add_child(row)
	cell.add_child(pad)
	return cell


func _style_chrome() -> void:
	_style_window(_os_bar, Palette.CYAN)
	_style_window(_hero_card, Palette.CYAN)
	_style_window(_identity_card, Palette.CYAN)
	_style_window(_progress_card, Palette.CYAN)
	_style_window(_systems_card, Palette.CYAN)
	_style_window(_mastery_card, Palette.CYAN)
	_style_title_bar(_identity_bar, Palette.ORANGE)
	_style_title_bar(_progress_bar, Palette.ORANGE)
	_style_title_bar(_systems_bar, Palette.ORANGE)
	_style_title_bar(_mastery_bar, Palette.ORANGE)
	_style_close_button()
	_style_status_badge(true)
	var avatar := %AvatarBox as PanelContainer
	avatar.add_theme_stylebox_override("panel", _pixel_box(Palette.FOREST_NIGHT, Palette.CYAN, 0, 2))
	%ExpBar.add_theme_stylebox_override("panel", _pixel_box(Palette.BG_DEEP, Palette.CYAN_DIM, 0, 2))
	%ExpBarFill.color = Palette.CYAN
	%LegendRed.color = Palette.RED
	%LegendOrange.color = Palette.ORANGE
	%LegendGreen.color = Palette.GREEN
	for cell in [%SessionsCell, %StageCell, %PreCell, %PostCell, %ThreatCell, %MaterialsCell, %TowerCell, %GladeCell, %ForgeCell]:
		_style_stat_cell(cell)
	_center_stat_stack(%SessionsLabel, _sessions)
	_center_stat_stack(%StageLabel, _stage)
	_center_stat_stack(%PreLabel, _pre)
	_center_stat_stack(%PostLabel, _post)
	_center_stat_stack(%ThreatLabel, _threat)
	_center_stat_stack(%MaterialsLabel, _materials)
	_apply_label(_header_title, Palette.TEXT_PRIMARY, 12)
	_apply_label(_os_cursor, Palette.GREEN, 12)
	_apply_label(_callsign, Palette.TEXT_PRIMARY, 16)
	_apply_label(_rank, Palette.GREEN, 10)
	_apply_label(_section_hero, Palette.TEXT_SECONDARY, 9)
	_apply_label(_email_hero, Palette.TEXT_SECONDARY, 9)
	_apply_label(_status_badge_label, Palette.GREEN, 10)
	_apply_label(_full_name, Palette.TEXT_PRIMARY, 10)
	_apply_label(_status, Palette.GREEN, 10)
	_apply_label(_exp_caption, Palette.TEXT_SECONDARY, 9)
	_apply_label(_exp, Palette.TEXT_PRIMARY, 10)
	_apply_label(_sessions, Palette.TEXT_PRIMARY, 12)
	_apply_label(_stage, Palette.TEXT_PRIMARY, 12)
	_apply_label(_pre, Palette.TEXT_PRIMARY, 12)
	_apply_label(_post, Palette.TEXT_PRIMARY, 12)
	_apply_label(_threat, Palette.TEXT_PRIMARY, 12)
	_apply_label(_materials, Palette.TEXT_PRIMARY, 12)
	_apply_label(_tower, Palette.TEXT_PRIMARY, 12)
	_apply_label(_glade, Palette.TEXT_PRIMARY, 12)
	_apply_label(_forge, Palette.TEXT_PRIMARY, 12)
	for caption in [%FullNameLabel, %StatusLabel, %SessionsLabel, %StageLabel, %PreLabel, %PostLabel, %ThreatLabel, %MaterialsLabel, %TowerCaption, %GladeCaption, %ForgeCaption, %IdentityFile, %ProgressFile, %SystemsFile, %MasteryFile, %LegendLow, %LegendMid, %LegendHigh]:
		_apply_label(caption, Palette.TEXT_SECONDARY, 9)
	_style_stat_value(_full_name)
	_full_name.size_flags_horizontal = Control.SIZE_FILL
	_apply_label(%IdentityFile, Palette.TEXT_PRIMARY, 9)
	_apply_label(%ProgressFile, Palette.TEXT_PRIMARY, 9)
	_apply_label(%SystemsFile, Palette.TEXT_PRIMARY, 9)
	_apply_label(%MasteryFile, Palette.TEXT_PRIMARY, 9)


func _style_stat_cell(cell: PanelContainer) -> void:
	cell.add_theme_stylebox_override("panel", _pixel_box(Palette.BG_PANEL_ALT, Palette.CYAN_DIM, 0, 2))


func _center_stat_stack(caption: Label, value: Label) -> void:
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := caption.get_parent() as VBoxContainer
	if col == null:
		return
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _style_stat_value(label: Label) -> void:
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_label(label, Palette.TEXT_PRIMARY, 10)


func _style_status_badge(on_track: bool) -> void:
	var accent := Palette.GREEN if on_track else Palette.ORANGE
	var box := _pixel_box(Color(Palette.BG_HEADER, 0.94), accent, 0, 2)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	_status_badge.add_theme_stylebox_override("panel", box)
	_apply_label(_status_badge_label, accent, 10)


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
	card.add_theme_stylebox_override("panel", box)


func _style_title_bar(bar: PanelContainer, fill: Color) -> void:
	bar.custom_minimum_size = Vector2(0, 28)
	var style := _pixel_box(fill, fill, 0, 0)
	style.content_margin_left = 12.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
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


func _band_color(unit: float) -> Color:
	if unit >= 0.75:
		return Palette.GREEN
	if unit >= 0.50:
		return Palette.ORANGE
	return Palette.RED


func _as_unit(value: float) -> float:
	if value > 1.0:
		return clampf(value / 100.0, 0.0, 1.0)
	return clampf(value, 0.0, 1.0)


func _is_on_track(status: String) -> bool:
	return status.strip_edges().to_lower().contains("track")


func _status_unit(status: String) -> float:
	return 1.0 if _is_on_track(status) else 0.6
