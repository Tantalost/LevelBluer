extends Control
## Expression atlases for the school cast; other speakers keep the pixel fallback.
const Emotion = preload("res://src/gameplay/decision/dialogue_emotion.gd")
static var _expression_frames: Dictionary = {}

static func college_expression(who: String, mood: String, head_only: bool = false) -> Texture2D:
	var row: int = ["Alex", "Mia", "Leah"].find(who)
	if row < 0:
		return null
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var assets: Node = tree.root.get_node_or_null("AssetManager") if tree != null else null
	# AssetManager owns disk loading and downloads (bundled res:// fallback
	# first-run, Cloudinary afterward). Never retain a null cache result
	# here: an open workspace can refresh after startup sync completes.
	var atlas: Texture2D = assets.get_texture("story_college_cast") if assets != null else null
	if atlas == null:
		return null
	var column: int = 1 if mood in ["worried", "shocked", "scared", "sad", "crying", "angry", "frustrated"] else (2 if mood in ["relieved", "determined"] else 0)
	var key: String = "college/%s/%d/%s" % [who, column, str(head_only)]
	if not _expression_frames.has(key):
		var frame: AtlasTexture = AtlasTexture.new()
		frame.atlas = atlas
		var top: float = [0.0, 434.0, 839.0][row]
		var height: float = [434.0, 405.0, 415.0][row]
		frame.region = Rect2(100 + column * 400, top, 256, height)
		if head_only:
			frame.region = Rect2(124 + column * 400, top, 208, 170)
		frame.filter_clip = true
		_expression_frames[key] = frame
	var cached_frame: AtlasTexture = _expression_frames[key] as AtlasTexture
	cached_frame.atlas = atlas
	return cached_frame
const BODY_CANVAS: Vector2 = Vector2(408, 1024)
const SCHOOL_EXPRESSIONS: PackedStringArray = ["neutral", "worried", "shocked", "frustrated", "sad", "determined", "relieved", "scared"]
## Source crops and attachment rectangles belong to the asset, not the scene.
## All cast members share the same rendering and expression lifecycle.
const SCHOOL_ATLASES: Dictionary = {
	"Alex": {"asset_id": "story_dialogue_alex", "body": Rect2(0, 160, 408, 824), "head": Rect2(70, 0, 236, 270), "origin": Vector2(416, 160), "cell": Vector2(280, 320), "row_step": 400},
	"Mia": {"asset_id": "story_dialogue_mia", "body": Rect2(0, 150, 384, 840), "head": Rect2(60, 0, 276, 315), "origin": Vector2(395, 160), "cell": Vector2(280, 320), "row_step": 400},
	"Ms. Reyes": {"asset_id": "story_dialogue_ms_reyes", "body": Rect2(0, 140, 392, 852), "head": Rect2(72, 0, 248, 310), "origin": Vector2(400, 150), "cell": Vector2(280, 350), "row_step": 380},
}

static func _school_frame(who: String, key: String, region: Rect2) -> Texture2D:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var assets: Node = tree.root.get_node_or_null("AssetManager") if tree != null else null
	if assets == null:
		return null
	var spec: Dictionary = SCHOOL_ATLASES[who]
	# AssetManager owns disk loading and downloads. Never retain a null cache
	# result here: an open workspace can refresh after startup sync completes.
	var atlas: Texture2D = assets.get_texture(str(spec["asset_id"]))
	if atlas == null:
		return null
	key = who + "/" + key
	if not _expression_frames.has(key):
		var frame: AtlasTexture = AtlasTexture.new()
		frame.atlas = atlas
		frame.region = region
		frame.filter_clip = true
		_expression_frames[key] = frame
	var cached_frame: AtlasTexture = _expression_frames[key] as AtlasTexture
	cached_frame.atlas = atlas
	return cached_frame

static func school_body(who: String) -> Texture2D:
	if not SCHOOL_ATLASES.has(who):
		return null
	var spec: Dictionary = SCHOOL_ATLASES[who]
	return _school_frame(who, "body", spec["body"] as Rect2)

static func school_expression(who: String, mood: String) -> Texture2D:
	if not SCHOOL_ATLASES.has(who):
		return null
	var spec: Dictionary = SCHOOL_ATLASES[who]
	var expression: String = Emotion.normalize(mood)
	if expression == "angry":
		expression = "frustrated"
	elif expression == "crying":
		expression = "sad"
	var index: int = maxi(0, SCHOOL_EXPRESSIONS.find(expression))
	var cell: Vector2 = spec["cell"] as Vector2
	var origin: Vector2 = spec["origin"] as Vector2
	origin += Vector2((index % 4) * cell.x, 0 if index < 4 else int(spec["row_step"]))
	return _school_frame(who, "expression/" + expression, Rect2(origin, cell))

var portrait_texture: Texture2D
var body_texture: Texture2D
var retain_expression: bool = false
var _light: float = 0.48:
	set(value):
		_light = value
		queue_redraw()
var _light_tween: Tween
var frameless: bool = false
var speaker := "Mia"
var speaking := false
var talking := false
var clock := 0.0
## The active speaker's current emotion (see DialogueEmotion). Presentation
## is purely a function of (emotion, _emotion_clock), recomputed every frame
## in _emotion_transform() — never an accumulated offset/tween — so a new
## configure() call always starts the next emotion from a clean state with
## zero carryover from whatever animation was previously playing.
var emotion: String = Emotion.NEUTRAL
var _emotion_clock := 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	clock += delta
	_emotion_clock += delta
	if speaking and (talking or emotion != Emotion.NEUTRAL):
		queue_redraw()

func configure(who: String, active: bool, animated: bool, p_emotion: String = Emotion.NEUTRAL) -> void:
	var changed_character: bool = speaker != who
	var changed_focus: bool = speaking != active
	speaker = who
	speaking = active
	talking = animated
	# School listeners keep their last authored reaction; legacy callers retain
	# the neutral inactive behavior. Only active speakers run emotion motion.
	var next_emotion: String = Emotion.normalize(p_emotion) if active or retain_expression else Emotion.NEUTRAL
	if next_emotion != emotion:
		emotion = next_emotion
		_emotion_clock = 0.0
	if changed_character or changed_focus:
		if _light_tween != null and _light_tween.is_valid():
			_light_tween.kill()
		var target_light: float = 1.0 if active else 0.48
		if retain_expression and not changed_character and is_inside_tree() and not _reduced_motion():
			_light_tween = create_tween()
			_light_tween.tween_property(self, "_light", target_light, 0.18)
		else:
			_light = target_light
	queue_redraw()

func _exit_tree() -> void:
	if _light_tween != null and _light_tween.is_valid():
		_light_tween.kill()

func _draw_full_body() -> void:
	var factor: float = minf((size.x - 12.0) / BODY_CANVAS.x, (size.y - 12.0) / BODY_CANVAS.y)
	var origin: Vector2 = Vector2((size.x - BODY_CANVAS.x * factor) * 0.5, size.y - BODY_CANVAS.y * factor)
	var spec: Dictionary = SCHOOL_ATLASES.get(speaker, SCHOOL_ATLASES["Alex"])
	var head: Rect2 = spec["head"] as Rect2
	if speaking and not _reduced_motion():
		origin += _emotion_transform().get("offset", Vector2.ZERO) as Vector2
	var tint: Color = Color(_light, _light, _light, 1.0)
	draw_texture_rect(body_texture, Rect2(origin + Vector2(0, 200) * factor, Vector2(408, 824) * factor), false, tint)
	draw_texture_rect(portrait_texture, Rect2(origin + head.position * factor, head.size * factor), false, tint)

## Pure function of (emotion, time-since-emotion-began): offset/rotation/scale
## to apply around the drawing's own pivot, plus whether to suppress the
## idle talking-mouth animation and whether to draw a crying tear detail.
## Never touches this Control's own position/scale/rotation (which would
## fight a parent Container's layout) — only the local draw transform inside
## _draw(), so nothing here can conflict with, or leak past, one line's
## presentation into the next.
func _emotion_transform() -> Dictionary:
	var t: float = _emotion_clock
	match emotion:
		"angry":
			if t < 0.22:
				var decay: float = 1.0 - (t / 0.22)
				return {"offset": Vector2(sin(t * 90.0) * 4.0 * decay, 0.0)}
			return {}
		"frustrated":
			return {"offset": Vector2(sin(t * 6.0) * 1.6, 0.0)}
		"shocked":
			if t < 0.15:
				var k: float = t / 0.15
				return {"scale": 1.0 + sin(k * PI) * 0.18}
			return {}
		"scared":
			return {"offset": Vector2(sin(t * 20.0) * 0.8, cos(t * 17.0) * 0.6)}
		"crying":
			return {"offset": Vector2(0.0, sin(t * 5.0) * 0.8), "crying": true, "slow_talk": true}
		"worried":
			return {"offset": Vector2(0.0, sin(t * 2.2) * 1.2)}
		"sad":
			return {"offset": Vector2(0.0, 1.5), "slow_talk": true}
		"determined":
			var k2: float = minf(1.0, t / 0.18)
			return {"scale": 1.0 + (1.0 - k2) * 0.08}
		"relieved":
			var k3: float = minf(1.0, t / 0.5)
			return {"offset": Vector2(0.0, (1.0 - k3) * -1.5)}
		_:
			return {}

func _draw() -> void:
	if size.x <= 12.0 or size.y <= 12.0:
		return
	var ink := Color("85d9c3") if speaking else Color("46606b")
	var frame := Rect2(Vector2.ZERO, size)
	if not frameless:
		draw_style_box(_frame(ink), frame)
	if body_texture != null and portrait_texture != null:
		_draw_full_body()
		return
	if portrait_texture != null:
		var fitted := portrait_texture.get_size()
		fitted *= minf((size.x - 12) / fitted.x, (size.y - 12) / fitted.y)
		var art_offset: Vector2 = Vector2((size.x - fitted.x) / 2, size.y - fitted.y)
		# Texture portraits retain the existing reduced-motion preference and
		# restrained emotion motion without ever moving a Container child.
		if speaking and not _reduced_motion():
			art_offset += _emotion_transform().get("offset", Vector2.ZERO)
		draw_texture_rect(portrait_texture, Rect2(art_offset, fitted), false, Color(_light, _light, _light, 1.0))
		return
	var scale_factor := minf((size.x - 12) / 48.0, (size.y - 8) / 48.0)
	var offset := Vector2((size.x - 48 * scale_factor) / 2, size.y - 48 * scale_factor - 4)
	# Emotion presentation only ever adjusts this local draw transform (never
	# this Control's own position/scale/rotation), so it can never fight a
	# parent Container's layout and never leaks into the frame's own border.
	var fx := _emotion_transform() if speaking else {}
	# reduced_motion suppresses jolt/tremble/pop motion (offset/scale) but
	# keeps every non-motion signal — tears (fx.crying below) and the slowed
	# talking cadence — so the emotion still reads clearly without motion.
	var motion_reduced := _reduced_motion()
	var fx_offset: Vector2 = Vector2.ZERO if motion_reduced else fx.get("offset", Vector2.ZERO)
	var fx_scale: float = 1.0 if motion_reduced else fx.get("scale", 1.0)
	draw_set_transform(offset + fx_offset, 0, Vector2.ONE * scale_factor * fx_scale)
	var skin := Color("d5ab87")
	var coat := Color("37677a")
	var hair := Color("293a47")
	if speaker.begins_with("Ramon"):
		skin = Color("b88b69")
		coat = Color("807452")
	elif speaker == "Mia":
		coat = Color("487e77")
		hair = Color("394153")
	elif speaker == "Alex":
		coat = Color("476b9e")
		hair = Color("382f2d")
	elif speaker == "Ms. Reyes":
		coat = Color("8a675b")
		hair = Color("302c39")
	elif speaker == "Leah":
		# Leah is not a BlueTech employee: a warm, non-corporate palette keeps
		# her visually distinct from Mia/Ramon's teal-and-slate work attire.
		skin = Color("dab48f")
		coat = Color("b1543f")
		hair = Color("4a2e22")
	if not speaking:
		skin = skin.darkened(0.4)
		coat = coat.darkened(0.4)
	draw_rect(Rect2(7, 32, 34, 16), coat.darkened(0.25))
	draw_rect(Rect2(11, 30, 26, 18), coat)
	draw_rect(Rect2(20, 25, 8, 10), skin.darkened(0.12))
	draw_rect(Rect2(13, 7, 22, 22), hair)
	draw_rect(Rect2(16, 13, 16, 16), skin)
	draw_rect(Rect2(14, 7, 19, 8), hair)
	draw_rect(Rect2(18, 19, 3, 2), Color("13202b"))
	draw_rect(Rect2(27, 19, 3, 2), Color("13202b"))
	if fx.get("crying", false):
		var tear := Color("6fb8e0", 0.85)
		draw_rect(Rect2(18.5, 21, 2, 6), tear)
		draw_rect(Rect2(27.5, 21, 2, 6), tear)
	# Crying/sad speak more slowly than the default talking cadence.
	var talk_rate := 5.0 if fx.get("slow_talk", false) else 9.0
	var mouth_height := 3 if talking and int(clock * talk_rate) % 2 == 0 else 1
	draw_rect(Rect2(22, 25, 5, mouth_height), Color("654c47"))
	draw_rect(Rect2(17, 34, 4, 12), coat.lightened(0.15))
	draw_rect(Rect2(28, 36, 5, 3), ink)
	if speaker == "Mia":
		draw_rect(Rect2(12, 16, 4, 18), hair)
	elif speaker.begins_with("Ramon") or speaker == "Ms. Reyes":
		draw_rect(Rect2(16, 17, 8, 6), ink, false, 1)
		draw_rect(Rect2(25, 17, 8, 6), ink, false, 1)
	elif speaker == "Leah":
		# Long hair on both sides — a clearly different silhouette from
		# Mia's single-side hair and Ramon's glasses.
		draw_rect(Rect2(11, 15, 5, 21), hair)
		draw_rect(Rect2(32, 15, 5, 21), hair)
	elif speaker != "Alex":
		draw_rect(Rect2(12, 17, 4, 9), ink)
		draw_line(Vector2(14, 25), Vector2(20, 28), ink, 2)
	draw_set_transform(Vector2.ZERO)

## Read defensively via the tree rather than the bare autoload identifier:
## this Control can be constructed before the node is inside the tree (see
## decision_workspace.gd's _dialogue()), so SettingsService may not be
## reachable yet — absent, motion is simply not reduced.
func _reduced_motion() -> bool:
	if not is_inside_tree():
		return false
	var settings: Node = get_node_or_null("/root/SettingsService")
	return settings != null and bool(settings.reduced_motion)


func _frame(ink: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172c35") if speaking else Color("101b24")
	style.border_color = ink
	style.set_border_width_all(2 if speaking else 1)
	return style
