class_name ConfrontationWidgets
extends RefCounted
## Presentation-only controls. The screen owns progress, rewards and timing.
const UI: GDScript = preload("res://src/ui/screens/intel/study_ui.gd")
const Case: GDScript = preload("res://src/gameplay/decision/confrontation_chapter.gd")
const BG: Color = Color("050b18")
const PANEL: Color = Color("0a1730")
const CARD: Color = Color("102040")
const BORDER: Color = Color("173058")
const CYAN: Color = Color("4fe0d4")
const CREAM: Color = Color("f3ecd6")
const INK: Color = Color("101623")
const GREEN: Color = Color("33d17a")
const ORANGE: Color = Color("ffb648")

static func unit(control: Control) -> float:
	return 1.0 / maxf(0.25,control.get_viewport().get_final_transform().get_scale().y)

static func copy(text: String, u: float, color: Color = CREAM, pixels: int = 18) -> Label:
	return UI.label(text,ceili(pixels*u),color)

static func button(text: String, action: Callable, u: float, primary: bool = false) -> Button:
	var result: Button = UI.button(text,action,primary)
	result.custom_minimum_size = Vector2(64,48)*u
	result.add_theme_font_size_override("font_size",ceili(17*u))
	for state: String in ["normal","hover","pressed","focus"]:
		result.add_theme_stylebox_override(state,UI.box(Color("2e6bff") if primary else CARD,CYAN if state != "normal" else BORDER,ceili(8*u)))
	result.add_theme_color_override("font_color",CREAM)
	result.add_theme_color_override("font_hover_color",CREAM)
	result.add_theme_color_override("font_pressed_color",CREAM)
	return result

static func art(id: String, height: float) -> TextureRect:
	var image: TextureRect = TextureRect.new()
	image.texture = AssetManager.get_texture(id)
	image.custom_minimum_size.y = height
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.clip_contents = true
	return image

static func grayscale(image: TextureRect) -> void:
	var shader: Shader = Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ vec4 c=texture(TEXTURE,UV); float g=dot(c.rgb,vec3(.299,.587,.114)); COLOR=vec4(vec3(g)*.78,c.a); }"
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	image.material = material

class TitleImpact extends Control:
	var elapsed: float = 0.0
	var gentle: bool = false
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color.BLACK)
		var progress: float = clampf(elapsed/0.8,0,1)
		var gain: float = 1.0 if gentle else (1.4-0.4*ease(progress,0.3))
		var font_size: int = maxi(24,int(size.x/12.0))
		for index: int in 32:
			var p: Vector2 = Vector2(fmod(index*173.7,1000)/1000.0,fmod(index*97.1,600)/600.0)*size
			var radius: float = (3+index%8)*size.x/1000.0
			draw_circle(p,radius,Color("ff5c5c")*Color(0.5,0.15,0.15,0.7))
		draw_set_transform(size*Vector2(0.5,0.49),-0.08 if gentle else -0.13,Vector2.ONE*gain)
		var title: String = "CONFRONTATION"
		var width: float = UI.FONT.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		draw_string(UI.FONT,Vector2(-width/2,0),title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("ff5c5c"))
		var rise: String = "ALL RISE!"
		var rise_size: int = int(font_size*1.12)
		width = UI.FONT.get_string_size(rise,HORIZONTAL_ALIGNMENT_LEFT,-1,rise_size).x
		draw_string(UI.FONT,Vector2(-width/2,font_size*0.7),rise,HORIZONTAL_ALIGNMENT_LEFT,-1,rise_size,CREAM)
		draw_set_transform(Vector2.ZERO)
		draw_string(UI.FONT,Vector2(size.x*.06,size.y*.88),"CHAPTER 05  /  THE HEARING",HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(18,int(size.y*.045)),CYAN)
		if not gentle and elapsed < .55:
			for index: int in 8:
				var y: float = size.y*(index/8.0)
				draw_line(Vector2(0,y),Vector2(size.x, y-size.y*.2),Color(CYAN,(.55-elapsed)*.3),2)

class RebuttalImpact extends Control:
	var elapsed: float = 0.0
	var gentle: bool = false
	func _draw() -> void:
		var alpha: float = 1.0-clampf((elapsed-.5)/.5,0,1)
		var middle: Vector2 = size*.5
		var progress: float = 1 if gentle else clampf(elapsed/.3,0,1)
		draw_rect(Rect2(0,size.y*.3,size.x,size.y*.38),Color(.02,.04,.09,.96*alpha))
		draw_line(Vector2(0,middle.y),Vector2(middle.x*progress,middle.y),Color(CYAN,alpha),3)
		draw_arc(middle,24,0,TAU,32,Color(CYAN,alpha),3)
		var font_size: int = maxi(22,int(size.x/22))
		draw_string(UI.FONT,Vector2(0,middle.y+font_size*.25),"CLAIM REFUTED!",HORIZONTAL_ALIGNMENT_CENTER,size.x,font_size,Color(GREEN,alpha))

class CastPanel extends Control:
	var speaker: String = "Jobert"
	var round_index: int = 0
	var u: float = 1.0
	func _draw() -> void:
		draw_style_box(UI.box(PANEL,BORDER,0),Rect2(Vector2.ZERO,size))
		var people: Array[String] = ["John","Eric","Jobert"]
		# Separate video tiles: dim listeners remain present without sharing a room.
		for index: int in 3:
			var person: String = people[index]
			var active: bool = person == speaker
			var tile: Rect2 = Rect2(0,size.y*.69+index*0.0, size.x*.49,size.y*.31)
			if person == "Eric": tile.position.x = size.x*.51
			if person == "Jobert": tile = Rect2(0,0,size.x,size.y*.66)
			var pose: int = 4 if person == "John" else 0
			if person == "Jobert": pose = [1,5,2,3][round_index]
			var sheet: Texture2D = AssetManager.get_texture("chapter1_"+person.to_lower())
			if sheet != null:
				var split: float = {"John":512.0,"Eric":524.0,"Jobert":546.0}[person]
				var source: Rect2 = Rect2((pose%3)*512,0 if pose < 3 else split,512,split if pose < 3 else 1024-split)
				# Upper-body crop keeps expressions readable on a phone.
				source.position.x += 86
				source.size.x -= 172
				source.size.y *= .72
				var ratio: float = minf(tile.size.x/source.size.x,tile.size.y/source.size.y)
				var image_size: Vector2 = source.size*ratio
				var image_rect: Rect2 = Rect2(tile.position+Vector2((tile.size.x-image_size.x)*.5,0),image_size)
				draw_texture_rect_region(sheet,image_rect,source,Color.WHITE if active else Color(.42,.48,.56))
			draw_rect(tile,CYAN if active else BORDER,false,2*u)
			draw_rect(Rect2(tile.position+Vector2(0,tile.size.y-23*u),Vector2(tile.size.x,23*u)),Color(0.02,.04,.09,.92))
			draw_string(UI.FONT,tile.position+Vector2(8*u,tile.size.y-6*u),person.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,ceili(16*u),CYAN if active else CREAM)
		if speaker not in people:
			var camera: Rect2 = Rect2(0,0,size.x,size.y*.66)
			draw_rect(camera,PANEL)
			draw_rect(camera,CYAN,false,2*u)
			draw_string(UI.FONT,Vector2(12*u,camera.size.y*.45),speaker.to_upper(),HORIZONTAL_ALIGNMENT_CENTER,camera.size.x-24*u,ceili(23*u),CREAM)
			draw_string(UI.FONT,Vector2(12*u,camera.size.y*.65),"CAMERA OFF / SPEAKING",HORIZONTAL_ALIGNMENT_CENTER,camera.size.x-24*u,ceili(14*u),CYAN)

class DebateStage extends VBoxContainer:
	signal rebuttal_submitted(evidence: String, weak_point: String)
	signal evidence_requested
	signal hold_requested
	var selected: String = ""
	var weak: String = ""
	var portraits: CastPanel
	var statement: Label
	var target: Button
	var load_button: Button
	var hold_button: Button
	var u: float = 1.0
	var round_index: int = 0

	func build(scale_unit: float) -> void:
		u = scale_unit
		add_theme_constant_override("separation",ceili(8*u))
		var body: HBoxContainer = HBoxContainer.new()
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation",ceili(12*u))
		add_child(body)
		portraits = CastPanel.new()
		portraits.u = u
		portraits.round_index = round_index
		portraits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portraits.size_flags_stretch_ratio = .36
		body.add_child(portraits)
		var argument: VBoxContainer = UI.column(body,ceili(8*u))
		argument.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		argument.size_flags_stretch_ratio = .64
		argument.add_child(ConfrontationWidgets.copy("NONSTOP DEBATE / ROUND %d" % (round_index+1),u,CYAN,16))
		var text_scroll: VBoxContainer = UI.scroll_column(argument)
		statement = ConfrontationWidgets.copy("",u)
		text_scroll.add_child(statement)
		target = ConfrontationWidgets.button("",func() -> void: rebuttal_submitted.emit(selected,weak),u)
		target.name = "WeakPoint"
		target.custom_minimum_size.y = 52*u
		target.add_theme_stylebox_override("normal",UI.box(Color("302313"),ORANGE,ceili(8*u)))
		target.add_theme_color_override("font_color",ORANGE)
		argument.add_child(target)
		var tools: HBoxContainer = HBoxContainer.new()
		tools.add_theme_constant_override("separation",ceili(8*u))
		add_child(tools)
		load_button = ConfrontationWidgets.button("LOAD EVIDENCE",func() -> void: evidence_requested.emit(),u,true)
		load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tools.add_child(load_button)
		hold_button = ConfrontationWidgets.button("HOLD",func() -> void: hold_requested.emit(),u)
		tools.add_child(hold_button)

	func show_statement(speaker: String, text: String, weak_point: String, armed: String, held: bool) -> void:
		weak = weak_point
		selected = armed
		statement.text = speaker.to_upper()+"  /  "+text
		target.text = "◎  "+weak_point if not weak_point.is_empty() else "LISTENING / THE CLAIM IS COMING"
		target.disabled = weak_point.is_empty()
		load_button.text = "EVIDENCE / "+str(Case.exhibit(armed).get("title","Select a record"))
		hold_button.text = "RESUME" if held else "HOLD"
		portraits.speaker = speaker
		portraits.queue_redraw()

class EvidenceDrawer extends PanelContainer:
	signal evidence_selected(id: String)
	signal closed
	var chosen: String = ""
	var u: float = 1.0
	var preview: VBoxContainer
	var select_button: Button
	var compare: bool = false
	var first: String = ""
	var tiles: Dictionary[String,Button] = {}
	var hinted: String = ""

	func build(options: Array, scale_unit: float, hint: String = "", review: bool = false, comparison: bool = false) -> void:
		u = scale_unit
		compare = comparison
		hinted = hint
		add_theme_stylebox_override("panel",UI.box(CREAM,CYAN,ceili(12*u)))
		var layout: VBoxContainer = UI.column(self,ceili(8*u))
		var header: HBoxContainer = HBoxContainer.new()
		layout.add_child(header)
		var heading: Label = ConfrontationWidgets.copy("CASE RECORD / "+("COMPARE TWO" if compare else "EVIDENCE"),u,INK)
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(heading)
		header.add_child(ConfrontationWidgets.button("CLOSE",func() -> void: closed.emit(),u))
		var body: HBoxContainer = HBoxContainer.new()
		body.add_theme_constant_override("separation",ceili(12*u))
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		layout.add_child(body)
		var grid_scroll: ScrollContainer = ScrollContainer.new()
		grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid_scroll.size_flags_stretch_ratio = .42
		body.add_child(grid_scroll)
		var grid: GridContainer = GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation",ceili(8*u))
		grid.add_theme_constant_override("v_separation",ceili(8*u))
		grid_scroll.add_child(grid)
		for id: String in options:
			var item: Dictionary = Case.exhibit(id)
			var tile: Button = ConfrontationWidgets.button(str(item.mark)+"\n"+str(item.title),_select.bind(id),u)
			tile.custom_minimum_size = Vector2(100,88)*u
			tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tile.name = "Evidence_"+id
			if id == hint:
				tile.text += "\nHINT"
				tile.add_theme_stylebox_override("normal",UI.box(Color("153b37"),GREEN,ceili(8*u)))
			grid.add_child(tile)
			tiles[id] = tile
		preview = UI.scroll_column(body)
		(preview.get_parent() as Control).size_flags_stretch_ratio = .58
		select_button = ConfrontationWidgets.button("SELECT AN EXHIBIT",_commit,u,true)
		select_button.disabled = true
		select_button.visible = not review or compare
		layout.add_child(select_button)
		if not options.is_empty(): _select(str(options[0]))

	func _select(id: String) -> void:
		chosen = id
		for key: String in tiles:
			var fill: Color = Color("153b37") if key in [id,hinted] else CARD
			var border: Color = GREEN if key == hinted else (CYAN if key == id else BORDER)
			tiles[key].add_theme_stylebox_override("normal",UI.box(fill,border,ceili(8*u)))
		UI.clear(preview)
		if compare and not first.is_empty(): _detail(first)
		_detail(id)
		select_button.disabled = compare and first == id
		select_button.text = "PIN FIRST EXHIBIT" if compare and first.is_empty() else ("COMPARING / CLOSE WHEN READY" if compare else "LOAD THIS EVIDENCE")
		if compare and not first.is_empty(): select_button.disabled = true

	func _detail(id: String) -> void:
		var item: Dictionary = Case.exhibit(id)
		var illustration: EvidenceIcon = EvidenceIcon.new()
		illustration.kind = id
		illustration.custom_minimum_size.y = 62*u
		illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(illustration)
		preview.add_child(ConfrontationWidgets.copy(str(item.title),u,INK,21))
		preview.add_child(ConfrontationWidgets.copy(str(item.source),u,Color("315b57"),16))
		preview.add_child(ConfrontationWidgets.copy(str(item.detail),u,INK))

	func _commit() -> void:
		if chosen.is_empty(): return
		if compare:
			first = chosen
			select_button.text = "CHOOSE A SECOND EXHIBIT"
			select_button.disabled = true
		else: evidence_selected.emit(chosen)

class EvidenceIcon extends Control:
	var kind: String = "coffee"
	func _draw() -> void:
		var h: float = size.y
		var center: Vector2 = size*.5
		var document: Rect2 = Rect2(center-Vector2(h*.5,h*.42),Vector2(h,h*.84))
		draw_style_box(UI.box(Color("153b37"),CYAN,0),document)
		if kind in ["coffee","whisper","borrow"]:
			for index: int in 2:
				var bubble: Rect2 = Rect2(document.position+Vector2(h*.12,h*(.13+index*.3)),Vector2(h*.74,h*.21))
				draw_rect(bubble,CREAM if index == 0 else CYAN)
		elif kind in ["call","timeline","urgency"]:
			draw_arc(center,h*.29,0,TAU,32,CREAM,2)
			draw_line(center,center+Vector2(0,-h*.2),CYAN,3)
			draw_line(center,center+Vector2(h*.17,h*.08),CYAN,3)
		elif kind == "short":
			for offset: float in [-.2,.2]: draw_arc(center+Vector2(h*offset,0),h*.2,-.8,PI+.8,24,CYAN,4)
		else:
			draw_line(document.position,document.get_center(),CREAM,2)
			draw_line(Vector2(document.end.x,document.position.y),document.get_center(),CREAM,2)
			draw_string(UI.FONT,center+Vector2(h*.08,h*.25),"Aa" if kind.begins_with("typo") else "@",HORIZONTAL_ALIGNMENT_CENTER,h*.35,int(h*.3),ORANGE)

class ClosingArgument extends VBoxContainer:
	signal frame_placed(id: String, slot: int)
	signal check_requested
	var selected: String = ""
	var page: int = 0
	var order: Array = []
	var u: float = 1.0
	var stage: HBoxContainer
	var instruction: Label
	var page_button: Button

	func build(saved: Array, scale_unit: float) -> void:
		order = saved.duplicate()
		u = scale_unit
		add_theme_constant_override("separation",ceili(8*u))
		instruction = ConfrontationWidgets.copy("Tap a frame below, then tap its place in the story.",u)
		add_child(instruction)
		stage = HBoxContainer.new()
		stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stage.add_theme_constant_override("separation",ceili(8*u))
		add_child(stage)
		var pool: ScrollContainer = ScrollContainer.new()
		pool.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		pool.custom_minimum_size.y = 96*u
		add_child(pool)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation",ceili(8*u))
		pool.add_child(row)
		for index: int in [4,1,7,2,5,0,6,3]:
			var item: Dictionary = Case.COMIC[index]
			var tile: Button = ConfrontationWidgets.button("",_select.bind(str(item.id)),u)
			tile.custom_minimum_size = Vector2(145,86)*u
			row.add_child(tile)
			var thumb: TextureRect = ConfrontationWidgets.art(str(item.art),0)
			thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tile.add_child(thumb)
			var tag: Label = ConfrontationWidgets.copy(str(item.title).trim_prefix(str(index+1).pad_zeros(2)+" / "),u,CREAM,16)
			tag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			tag.add_theme_stylebox_override("normal",UI.box(Color(.02,.04,.09,.8),BORDER,ceili(6*u)))
			tile.add_child(tag)
		var footer: HBoxContainer = HBoxContainer.new()
		footer.add_theme_constant_override("separation",ceili(8*u))
		add_child(footer)
		page_button = ConfrontationWidgets.button("PAGE 1 / 2",_turn_page,u)
		page_button.custom_minimum_size.x = 155*u
		footer.add_child(page_button)
		var check_button: Button = ConfrontationWidgets.button("CHECK RECONSTRUCTION",func() -> void: check_requested.emit(),u,true)
		check_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		footer.add_child(check_button)
		_draw_slots()

	func _select(id: String) -> void:
		selected = id
		instruction.text = "Selected: "+str(Case.frame(id).title).get_slice(" / ",1)+" / Tap a panel."
		if not str(Case.frame(id).title).contains(" / "): instruction.text = "Selected: "+str(Case.frame(id).title)+" / Tap a panel."

	func _turn_page() -> void:
		page = 1-page
		_draw_slots()

	func _draw_slots() -> void:
		UI.clear(stage)
		page_button.text = "PAGE %d / 2 / TURN" % (page+1)
		for index: int in range(page*3,page*3+3):
			var item: Dictionary = Case.frame(str(order[index]))
			var slot: Button = ConfrontationWidgets.button("",_place.bind(index),u)
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot.clip_contents = true
			stage.add_child(slot)
			var image: TextureRect = ConfrontationWidgets.art(str(item.get("art","")),0)
			image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			image.modulate = Color(.7,.7,.7)
			slot.add_child(image)
			var frame_title: String = str(item.get("title","? / PLACE FRAME"))
			if frame_title.contains(" / "): frame_title = frame_title.get_slice(" / ",1)
			var caption: Label = ConfrontationWidgets.copy("%02d / %s" % [index+1,frame_title],u,CREAM,16)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			caption.add_theme_stylebox_override("normal",UI.box(Color(0.02,0.04,0.08,.8),CYAN,ceili(4*u)))
			caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			caption.offset_top = -44*u
			slot.add_child(caption)

	func _place(slot: int) -> void:
		if selected.is_empty(): return
		frame_placed.emit(selected,slot)

class MeetingLights extends Control:
	var elapsed: float = 0.0
	var gentle: bool = false
	func _draw() -> void:
		var texture: Texture2D = AssetManager.get_texture("opening_collector_meeting_v2")
		if texture == null: return
		var factor: float = minf(size.x/texture.get_width(),size.y/texture.get_height())
		var dimensions: Vector2 = texture.get_size()*factor
		var bounds: Rect2 = Rect2((size-dimensions)*.5,dimensions)
		draw_texture_rect(texture,bounds,false)
		if not gentle and elapsed > .3 and elapsed < 1.2:
			draw_rect(bounds,Color(0,0,0,.12+.12*sin(elapsed*14)))
		var dim: float = clampf((elapsed-1.2)/1.8,0,.92)
		if not gentle and elapsed > .5 and elapsed < 2.3: dim = maxf(dim,.3+sin(elapsed*14)*.2)
		draw_rect(Rect2(bounds.position+Vector2(dimensions.x*.75,0),Vector2(dimensions.x*.25,dimensions.y)),Color(0,0,0,dim))

class RewardDisplay extends Control:
	var elapsed: float = 0.0
	var award: int = 0
	var balance: int = 0
	var gentle: bool = false
	var u: float = 1.0
	func _draw() -> void:
		var progress: float = 1.0 if gentle else smoothstep(.2,1.8,elapsed)
		var shown: int = roundi(award*progress)
		var reward: Rect2 = Rect2(0,0,size.x*.56,size.y)
		draw_style_box(UI.box(Color("153b37"),GREEN,0),reward)
		draw_string(UI.FONT,Vector2(0,size.y*.48),"+%d" % shown,HORIZONTAL_ALIGNMENT_CENTER,reward.size.x,ceili(38*u),ORANGE)
		draw_string(UI.FONT,Vector2(0,size.y*.78),"CREDITS EARNED",HORIZONTAL_ALIGNMENT_CENTER,reward.size.x,ceili(16*u),CREAM)
		var wallet_x: float = size.x*.65
		draw_string(UI.FONT,Vector2(wallet_x,size.y*.48),str(balance-award+shown),HORIZONTAL_ALIGNMENT_CENTER,size.x-wallet_x,ceili(30*u),CREAM)
		draw_string(UI.FONT,Vector2(wallet_x,size.y*.78),"WALLET",HORIZONTAL_ALIGNMENT_CENTER,size.x-wallet_x,ceili(16*u),CYAN)
		if not gentle and award > 0:
			for index: int in 4:
				var flight: float = (elapsed-.3-index*.16)/.8
				if flight > 0 and flight < 1:
					var point: Vector2 = Vector2(lerpf(size.x*.48,size.x*.8,flight),size.y*.5-sin(flight*PI)*size.y*.4)
					draw_circle(point,6*u,ORANGE)
					draw_circle(point,3*u,CREAM,false,u)
