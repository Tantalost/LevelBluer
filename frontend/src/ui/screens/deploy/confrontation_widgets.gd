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

class JoiningImpact extends Control:
	# Presentation only: the screen advances this clock and owns all audio cues.
	const REVEAL_AT: float = 5.8
	const FINISH_AT: float = 9.8
	var elapsed: float = 0.0
	var connecting: bool = false
	var gentle: bool = false
	var reveal: TitleImpact
	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		clip_contents = true
		reveal = TitleImpact.new()
		reveal.mouse_filter = MOUSE_FILTER_IGNORE
		reveal.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		add_child(reveal)
		advance(elapsed,connecting,gentle)
	func advance(time: float, started: bool, reduced: bool) -> void:
		elapsed = time
		connecting = started
		gentle = reduced
		if is_instance_valid(reveal):
			reveal.visible = connecting and elapsed >= REVEAL_AT
			reveal.elapsed = maxf(0,elapsed-REVEAL_AT)
			reveal.gentle = gentle
			reveal.queue_redraw()
		queue_redraw()
	func line(text: String, y: float, pixels: int, color: Color) -> void:
		var u: float = ConfrontationWidgets.unit(self)
		draw_string(UI.FONT,Vector2(16*u,y),text,HORIZONTAL_ALIGNMENT_CENTER,size.x-32*u,ceili(pixels*u),color)
	func _draw() -> void:
		var u: float = ConfrontationWidgets.unit(self)
		draw_rect(Rect2(Vector2.ZERO,size),BG)
		if connecting and elapsed >= 5.2: return
		var backdrop: Texture2D = AssetManager.get_texture("hearing_debate_v1")
		if backdrop != null: draw_texture_rect(backdrop,Rect2(Vector2.ZERO,size),false,Color(1,1,1,.24))
		for index: int in 12:
			var x: float = size.x*index/11.0
			draw_line(Vector2(x,0),Vector2(x-size.x*.18,size.y),Color(BORDER,.55),u)
		if not connecting:
			var card: Rect2 = Rect2(size*Vector2(.13,.08),size*Vector2(.74,.84))
			draw_style_box(UI.box(PANEL,CYAN,ceili(10*u)),card)
			line("SIR RHAM INVITED YOU",size.y*.23,18,CYAN)
			line("THE CLUB HEARING",size.y*.43,30,CREAM)
			line("Zoom meeting / John",size.y*.62,19,CREAM)
			line("Your evidence is ready. So are they.",size.y*.79,17,CYAN)
			return
		if elapsed < 1.8:
			var center: Vector2 = size*Vector2(.5,.42)
			for ring: int in 3:
				var radius: float = (25+ring*18)*u
				var angle: float = 0 if gentle else elapsed*(1.6+ring*.4)
				draw_arc(center,radius,angle,angle+TAU*(.65+ring*.08),64,Color(CYAN,1-ring*.25),2*u,true)
			line("JOINING THE HEARING",size.y*.77,24,CREAM)
			line("Connecting audio and video...",size.y*.91,16,CYAN)
			return
		line("CONNECTED / CLUB HEARING",size.y*.1,19,CYAN)
		var names: PackedStringArray = ["John","Sir Rham","Eric","Dan","Mika","Jobert"]
		var gap: float = 10*u
		var area: Rect2 = Rect2(size.x*.12,size.y*.17,size.x*.76,size.y*.66)
		var cell: Vector2 = (area.size-Vector2(2*gap,gap))/Vector2(3,2)
		for index: int in names.size():
			var arrival: float = 1.8+index*.45
			var live: bool = elapsed >= arrival
			var tile: Rect2 = Rect2(area.position+Vector2(index%3,index/3)*(cell+Vector2.ONE*gap),cell)
			if live and not gentle: tile.position.y += (1-smoothstep(arrival,arrival+.3,elapsed))*12*u
			draw_style_box(UI.box(CARD,CYAN if live else BORDER,ceili(6*u)),tile)
			if live:
				ConfrontationWidgets.draw_person(self,names[index],Rect2(tile.position+Vector2(4,2)*u,tile.size-Vector2(8,23)*u),0,Color.WHITE,true)
				draw_circle(tile.position+Vector2(10,10)*u,3*u,GREEN)
			draw_rect(Rect2(tile.position+Vector2(0,tile.size.y-23*u),Vector2(tile.size.x,23*u)),PANEL)
			draw_string(UI.FONT,tile.position+Vector2(8*u,tile.size.y-6*u),names[index] if live else "Connecting...",HORIZONTAL_ALIGNMENT_LEFT,tile.size.x-16*u,ceili(16*u),CREAM if live else CYAN)
		line("Everyone is here. " if elapsed >= 4.5 else "Participants are joining...",size.y*.95,18,CREAM)

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

static func draw_person(canvas: Control, person: String, rect: Rect2, pose: int = 0, tint: Color = Color.WHITE, close_up: bool = false) -> void:
	var sheet: Texture2D = AssetManager.get_texture("chapter1_"+person.to_lower())
	if sheet == null:
		# Camera-off participants remain part of the remote hearing.
		canvas.draw_circle(rect.position+rect.size*Vector2(.5,.28),rect.size.y*.14,Color("173058"))
		canvas.draw_colored_polygon(PackedVector2Array([rect.position+rect.size*Vector2(.3,.48),rect.position+rect.size*Vector2(.7,.48),rect.end,rect.position+Vector2(0,rect.size.y)]),Color("173058"))
		return
	var split: float = float({"John":512.0,"Eric":524.0,"Jobert":546.0}.get(person,512.0))
	var source: Rect2 = Rect2((pose%3)*512,0 if pose < 3 else split,512,split if pose < 3 else 1024-split)
	source.position.x += 100 if close_up else 38
	source.size.x -= 200 if close_up else 76
	source.size.y *= .51 if close_up else .7
	var ratio: float = minf(rect.size.x/source.size.x,rect.size.y/source.size.y)
	var image_size: Vector2 = source.size*ratio
	canvas.draw_texture_rect_region(sheet,Rect2(rect.position+Vector2((rect.size.x-image_size.x)*.5,0),image_size),source,tint)

class CommandAnimation extends Control:
	## Owner-driven clock: no independent process/tween survives a paused hearing.
	signal finished
	signal sound_requested(id: String)
	enum State { ANTICIPATION, ENTER, TYPE, CONFIRM, RETURN, READY, EXECUTE }
	var step: State = State.ANTICIPATION
	var age: float = 0.0
	var running: bool = true
	var firing: bool = false
	var gentle: bool = false
	var durations: PackedFloat32Array = [.25,.40,.80,.45,.70]
	var curves: PackedFloat32Array = [.25,.22,1.0,.3,.25]
	var sounds: PackedStringArray = ["command_open","command_snap","command_type","command_ready","command_send"]
	var sound_offsets: PackedFloat32Array = [0,0,0,0,0]
	var fire_duration: float = .32
	var fire_curve: float = 2.0
	var fire_sound: String = "command_send"
	var evidence_title: String = ""
	var target_fraction: Vector2 = Vector2(.4,.6)
	var source_fraction: Vector2 = Vector2(.4,.9)
	var cue_fired: bool = false
	var veil: ColorRect
	var terminal: PanelContainer
	var prompt: Label
	var command: Label
	var status: Label
	var u: float = 1.0
	var command_bounds: Rect2

	func _ready() -> void:
		name = "EvidenceCommandAnimation"
		mouse_filter = MOUSE_FILTER_STOP
		clip_contents = true
		u = ConfrontationWidgets.unit(self)
		veil = ColorRect.new()
		veil.name = "Backdrop"
		veil.mouse_filter = MOUSE_FILTER_IGNORE
		veil.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		add_child(veil)
		terminal = PanelContainer.new()
		terminal.name = "Terminal"
		terminal.mouse_filter = MOUSE_FILTER_IGNORE
		terminal.add_theme_stylebox_override("panel",UI.box(PANEL,CYAN,ceili(16*u)))
		if firing:
			terminal.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		add_child(terminal)
		var lines: VBoxContainer = UI.column(terminal,ceili(10*u))
		lines.mouse_filter = MOUSE_FILTER_IGNORE
		prompt = ConfrontationWidgets.copy("JOHN@HEARING  >  LOAD EVIDENCE",u,CYAN,16)
		prompt.mouse_filter = MOUSE_FILTER_IGNORE
		lines.add_child(prompt)
		command = ConfrontationWidgets.copy("",u,CREAM,24)
		command.mouse_filter = MOUSE_FILTER_IGNORE
		command.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if firing:
			command.add_theme_color_override("font_color",CYAN)
			command.add_theme_color_override("font_outline_color",BG)
			command.add_theme_constant_override("outline_size",ceili(6*u))
		if firing: add_child(command)
		else: lines.add_child(command)
		status = ConfrontationWidgets.copy("",u,CYAN,16)
		status.mouse_filter = MOUSE_FILTER_IGNORE
		lines.add_child(status)
		step = State.EXECUTE if firing else State.ANTICIPATION
		paint()

	func duration() -> float:
		if firing: return maxf(.05,fire_duration)
		return maxf(.05,durations[step])

	func _cue() -> void:
		if cue_fired or step == State.READY: return
		var offset: float = 0 if firing else clampf(sound_offsets[step],0,duration())
		if age < offset: return
		cue_fired = true
		var id: String = fire_sound if firing else sounds[step]
		if not id.is_empty(): sound_requested.emit(id)

	func advance(delta: float) -> void:
		if not running: return
		var remaining: float = maxf(0,delta)
		_cue()
		while running:
			var consumed: float = minf(remaining,maxf(0,duration()-age))
			age += consumed
			remaining -= consumed
			_cue()
			if age < duration(): break
			if firing or step == State.RETURN:
				step = State.READY
				running = false
				paint()
				finished.emit()
				return
			step = (int(step)+1) as State
			age = 0
			cue_fired = false
			_cue()
			if remaining <= 0: break
		paint()

	func paint() -> void:
		if not is_instance_valid(terminal): return
		u = ConfrontationWidgets.unit(self)
		var progress: float = 1 if step == State.READY else clampf(age/duration(),0,1)
		var curve: float = fire_curve if firing else curves[mini(int(step),4)]
		var eased: float = ease(progress,curve)
		command.text = "> refute \""+evidence_title+"\"" if firing else "> evidence.load \""+evidence_title+"\""
		var width: float = minf(size.x-32*u,640*u)
		if firing: width = minf(width,UI.FONT.get_string_size(command.text,HORIZONTAL_ALIGNMENT_LEFT,-1,ceili(24*u)).x+16*u)
		command.visible_ratio = (eased if step == State.TYPE and not gentle else 1.0)
		if step in [State.ANTICIPATION,State.ENTER]: command.visible_ratio = 0
		prompt.visible = not firing
		status.visible = not firing
		status.text = ["OPENING SESSION_","TERMINAL CONNECTED_","LOADING RECORD_","COMMAND READY","READY / TAP THE CLAIM","COMMAND READY","EXECUTE_"][step]
		terminal.size.x = width
		var height: float = terminal.get_combined_minimum_size().y
		if firing: height = UI.FONT.get_multiline_string_size(command.text,HORIZONTAL_ALIGNMENT_LEFT,width,ceili(24*u)).y
		var point: Vector2 = (size-Vector2(width,height))*.5
		terminal.modulate = Color.WHITE
		terminal.visible = not firing and step != State.ANTICIPATION
		veil.color = Color(BG,.62 if not firing else .16)
		if step == State.ENTER and not gentle:
			var overshoot: float = eased+sin(eased*PI)*.08
			point.x += (1-overshoot)*size.x
		elif step == State.RETURN:
			if not gentle: point.y = lerpf(point.y,size.y-height-4*u,eased)
			terminal.modulate.a = 1-eased
			veil.color.a *= 1-eased
		elif step == State.EXECUTE:
			var origin: Vector2 = size*source_fraction
			var target: Vector2 = size*target_fraction
			point = (target if gentle else origin.lerp(target,eased))-Vector2(width,height)*.5
			veil.color.a = .12
		# Snap movement to physical pixels; keep the complete command within the safe area.
		point.x = clampf(point.x,8*u,maxf(8*u,size.x-width-8*u)) if step != State.ENTER or gentle else point.x
		point.y = clampf(point.y,8*u,maxf(8*u,size.y-height-8*u))
		terminal.position = (point/(2*u)).round()*(2*u)
		terminal.size = Vector2(width,height)
		if firing:
			command.position = terminal.position
			command.size = Vector2(width,height)
		command_bounds = Rect2(terminal.position,Vector2(width,height))
		queue_redraw()

	func _draw() -> void:
		if step == State.ANTICIPATION:
			var p: float = clampf(age/duration(),0,1)
			for index: int in 7:
				var y: float = size.y*index/7.0
				var width: float = size.x if gentle else size.x*ease(p,curves[0])
				draw_rect(Rect2(0,y,width,5*u),Color(CYAN,.7*(1-p)))
		elif step == State.EXECUTE and not gentle:
			var p: float = clampf(age/duration(),0,1)
			var origin: Vector2 = size*source_fraction
			var target: Vector2 = size*target_fraction
			for index: int in 16:
				var trail: float = maxf(0,ease(p,fire_curve)-index*.025)
				var point: Vector2 = origin.lerp(target,trail)+Vector2((index%3-1)*10*u,0)
				draw_rect(Rect2((point/(3*u)).round()*(3*u),Vector2.ONE*(3+index%3)*u),Color(CYAN,(1-index/16.0)*.7))
		elif step == State.CONFIRM:
			var p: float = clampf(age/duration(),0,1)
			var x: float = command_bounds.position.x+command_bounds.size.x*ease(p,curves[3])
			draw_rect(Rect2(x,command_bounds.position.y-6*u,10*u,3*u),CYAN)

class RebuttalImpact extends Control:
	var elapsed: float = 0.0
	var gentle: bool = false
	var phrase: String = ""
	var evidence: String = ""
	func _draw() -> void:
		var u: float = ConfrontationWidgets.unit(self)
		draw_rect(Rect2(Vector2.ZERO,size),BG)
		if elapsed < .55:
			var hit: Vector2 = size*Vector2(.47,.48)
			if elapsed < .22:
				var flight: float = 1 if gentle else smoothstep(0,.22,elapsed)
				var command_point: Vector2 = (size*Vector2(.06,.88)).lerp(hit,flight)
				draw_string(UI.FONT,Vector2(20*u,command_point.y-28*u),"> refute \""+evidence+"\"",HORIZONTAL_ALIGNMENT_CENTER,size.x-40*u,ceili(23*u),CYAN)
				return
			var spread: float = 0 if gentle else clampf((elapsed-.22)/.33,0,1)
			for index: int in 18:
				var direction: Vector2 = Vector2((index%6-2.5)*.4,(-1 if index%2 else 1)*.6)
				var pixel: Vector2 = hit+direction*(20+spread*size.x*.5)
				draw_rect(Rect2((pixel/(4*u)).round()*(4*u),Vector2.ONE*(4+index%3)*u),Color(CYAN,.8-spread*.6))
			if gentle:
				draw_string(UI.FONT,Vector2(20*u,hit.y),phrase,HORIZONTAL_ALIGNMENT_CENTER,size.x-40*u,ceili(24*u),ORANGE)
				return
			var words: PackedStringArray = phrase.split(" ")
			var word_x: float = (size.x-UI.FONT.get_string_size(phrase,HORIZONTAL_ALIGNMENT_LEFT,-1,ceili(24*u)).x)*.5
			for index: int in words.size():
				var origin: Vector2 = Vector2(word_x,hit.y)
				word_x += UI.FONT.get_string_size(words[index]+" ",HORIZONTAL_ALIGNMENT_LEFT,-1,ceili(24*u)).x
				origin += Vector2((index-words.size()*.5)*spread*40,(-1 if index%2 else 1)*spread*80)*u
				draw_string(UI.FONT,origin,words[index],HORIZONTAL_ALIGNMENT_LEFT,-1,ceili(24*u),Color(ORANGE,1-spread))
			return
		var progress: float = clampf((elapsed-.55)/.25,0,1)
		var counter_art: Texture2D = AssetManager.get_texture("john_counter_lettered_v1")
		if counter_art == null:
			draw_string(UI.FONT,Vector2(20*u,size.y*.5),"COUNTER!",HORIZONTAL_ALIGNMENT_CENTER,size.x-40*u,ceili(48*u),CYAN)
			return
		var texture_size: Vector2 = counter_art.get_size()
		# Fit the complete lettered illustration so mobile ratios never crop COUNTER.
		var zoom: float = 1.0 if gentle else .96+progress*.04
		var scale_factor: float = minf(size.x/texture_size.x,size.y/texture_size.y)*zoom
		var image_size: Vector2 = texture_size*scale_factor
		draw_texture_rect(counter_art,Rect2((size-image_size)*.5,image_size),false)
		draw_string_outline(UI.FONT,Vector2(size.x*.04,size.y*.87),"CLAIM REFUTED   /   +15",HORIZONTAL_ALIGNMENT_LEFT,-1,ceili(20*u),ceili(3*u),INK)
		draw_string(UI.FONT,Vector2(size.x*.04,size.y*.87),"CLAIM REFUTED   /   +15",HORIZONTAL_ALIGNMENT_LEFT,-1,ceili(20*u),CYAN)

class CastPanel extends Control:
	var speaker: String = "Jobert"
	var round_index: int = 0
	var u: float = 1.0
	var transition: float = 1.0
	var gentle: bool = false
	func _draw() -> void:
		var backdrop: Texture2D = AssetManager.get_texture("hearing_debate_v1")
		draw_rect(Rect2(Vector2.ZERO,size),BG)
		if backdrop != null: draw_texture_rect(backdrop,Rect2(Vector2.ZERO,size),false)
		for index: int in 12:
			var x: float = index*size.x/11
			draw_line(Vector2(x,0),Vector2(x-size.x*.22,size.y),Color(BORDER,.65),u)
		draw_colored_polygon(PackedVector2Array([Vector2(size.x*.13,0),Vector2(size.x*.78,0),Vector2(size.x*.66,size.y),Vector2(size.x*.03,size.y)]),Color(.05,.16,.15,.28))
		var offset: float = 0 if gentle else (1-smoothstep(0,.4,transition))*40*u
		var pose: int = [1,5,2,3][round_index] if speaker == "Jobert" else 4 if speaker == "John" else 0
		ConfrontationWidgets.draw_person(self,speaker,Rect2(size.x*.2+offset,-18*u,size.x*.49,size.y*1.15),pose)
		# A close-up sits in an angled broadcast frame, not a shared physical room.
		var inset: Rect2 = Rect2(size.x*.77,0,size.x*.23,size.y*.79)
		draw_rect(inset,Color(.06,.12,.25,.82))
		ConfrontationWidgets.draw_person(self,speaker,inset,pose,Color.WHITE,true)
		draw_colored_polygon(PackedVector2Array([Vector2(inset.position.x,0),Vector2(inset.position.x+25*u,0),Vector2(inset.position.x,size.y*.79)]),PANEL)
		draw_line(Vector2(inset.position.x+25*u,0),Vector2(inset.position.x,size.y*.79),CREAM,3*u)
		draw_string(UI.FONT,Vector2(inset.position.x+12*u,size.y*.73),speaker.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,ceili(16*u),CREAM)
		var slot: int = 0
		for person: String in ["John","Eric","Jobert"]:
			if person == speaker: continue
			var tile: Rect2 = Rect2(8*u,34*u+slot*57*u,64*u,50*u)
			draw_rect(tile,BG)
			ConfrontationWidgets.draw_person(self,person,tile,0,Color(.4,.48,.56),true)
			draw_rect(tile,BORDER,false,u)
			slot += 1
		draw_string(UI.FONT,Vector2(12*u,22*u),"LIVE / CLUB HEARING",HORIZONTAL_ALIGNMENT_LEFT,-1,ceili(14*u),CYAN)
		if speaker not in ["John","Eric","Jobert"]:
			draw_string(UI.FONT,Vector2(size.x*.28,size.y*.43),"CAMERA OFF / "+speaker.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,ceili(20*u),CYAN)

class DebateStage extends Control:
	signal rebuttal_submitted(evidence: String, weak_point: String)
	signal evidence_requested
	signal hold_requested
	signal reflection_finished
	var selected: String = ""
	var weak: String = ""
	var portraits: CastPanel
	var statement: Label
	var suffix: Label
	var name_strip: Label
	var target: Button
	var claim_text: RichTextLabel
	var load_button: Button
	var hold_button: Button
	var reflection_button: Button
	var claim_panel: PanelContainer
	var claim_stack: VBoxContainer
	var banner: Label
	var u: float = 1.0
	var round_index: int = 0
	var transition: float = 1.0
	var load_age: float = 1.0
	var reflecting: bool = false
	var entrance: float = 0.0
	var gentle: bool = false
	var _speaker: String = ""

	func build(scale_unit: float) -> void:
		u = scale_unit
		gentle = SettingsService.reduced_motion
		clip_contents = true
		portraits = CastPanel.new()
		portraits.u = u
		portraits.round_index = round_index
		portraits.gentle = gentle
		portraits.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(portraits)
		claim_panel = PanelContainer.new()
		claim_panel.add_theme_stylebox_override("panel",UI.box(Color(.02,.04,.09,.82),Color(0,0,0,0),ceili(10*u)))
		add_child(claim_panel)
		claim_stack = UI.column(claim_panel,0)
		name_strip = ConfrontationWidgets.copy("",u,INK,17)
		name_strip.add_theme_stylebox_override("normal",UI.box(CREAM,CREAM,ceili(4*u)))
		claim_stack.add_child(name_strip)
		statement = ConfrontationWidgets.copy("",u,CREAM,21)
		claim_stack.add_child(statement)
		target = ConfrontationWidgets.button("",func() -> void: rebuttal_submitted.emit(selected,weak),u)
		target.name = "WeakPoint"
		target.alignment = HORIZONTAL_ALIGNMENT_LEFT
		target.custom_minimum_size.y = 48*u
		target.add_theme_font_size_override("font_size",ceili(23*u))
		for skin: String in ["normal","hover","pressed","focus","disabled"]:
			target.add_theme_stylebox_override(skin,UI.box(Color(0,0,0,0),Color(0,0,0,0),0))
		target.add_theme_color_override("font_color",ORANGE)
		target.add_theme_color_override("font_hover_color",CYAN)
		target.add_theme_color_override("font_pressed_color",CYAN)
		claim_stack.add_child(target)
		claim_text = RichTextLabel.new()
		claim_text.bbcode_enabled = true
		claim_text.fit_content = true
		claim_text.scroll_active = false
		claim_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		claim_text.add_theme_font_override("normal_font",UI.FONT)
		claim_text.add_theme_font_size_override("normal_font_size",ceili(22*u))
		claim_text.add_theme_color_override("default_color",CREAM)
		claim_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		claim_text.offset_top = 6*u
		claim_text.offset_bottom = -6*u
		target.add_child(claim_text)
		suffix = ConfrontationWidgets.copy("",u,CREAM,21)
		claim_stack.add_child(suffix)
		load_button = ConfrontationWidgets.button("",func() -> void: evidence_requested.emit(),u)
		load_button.name = "EvidenceCommand"
		load_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		load_button.add_theme_stylebox_override("normal",UI.box(Color("153b37"),CYAN,ceili(10*u)))
		var command_skin: StyleBoxFlat = UI.box(Color("153b37"),CYAN,ceili(12*u))
		load_button.add_theme_stylebox_override("normal",command_skin)
		load_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(load_button)
		hold_button = ConfrontationWidgets.button("HOLD",func() -> void: hold_requested.emit(),u)
		add_child(hold_button)
		reflection_button = ConfrontationWidgets.button("REPLAY DISCUSSION",func() -> void: reflection_finished.emit(),u,true)
		reflection_button.name = "ReplayDiscussion"
		reflection_button.hide()
		add_child(reflection_button)
		banner = ConfrontationWidgets.copy("",u,CREAM,30)
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		banner.add_theme_stylebox_override("normal",UI.box(Color("153b37"),CYAN,ceili(12*u)))
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(banner)
		resized.connect(_arrange)
		_arrange.call_deferred()

	func _arrange() -> void:
		if not is_instance_valid(portraits): return
		portraits.position = Vector2.ZERO
		portraits.size = Vector2(size.x,maxf(0,size.y-58*u))
		var width: float = size.x*.74
		claim_panel.position.x = 8*u
		claim_panel.size.x = width
		if target.visible:
			target.custom_minimum_size.y = maxf(64*u,claim_text.get_content_height()+12*u)
		var height: float = claim_stack.get_combined_minimum_size().y+20*u
		claim_panel.position.y = maxf(30*u,size.y-66*u-height)
		claim_panel.size = Vector2(width,height)
		load_button.position = Vector2(0,size.y-50*u)
		load_button.size = Vector2(size.x-92*u,50*u)
		hold_button.position = Vector2(size.x-84*u,size.y-50*u)
		hold_button.size = Vector2(84*u,50*u)
		reflection_button.position = load_button.position
		reflection_button.size = load_button.size
		var banner_x: float = 0 if gentle else maxf(0,(entrance-2.0)/.4)*size.x
		banner.position = Vector2(banner_x,portraits.size.y*.32)
		banner.size = Vector2(size.x,74*u)

	func show_statement(speaker: String, text: String, weak_point: String, armed: String, held: bool) -> void:
		if _speaker != speaker:
			transition = 0
			_speaker = speaker
		if selected != armed: load_age = 0
		weak = weak_point
		selected = armed
		name_strip.text = "  "+speaker.to_upper()+"  /  "+("THINKING" if reflecting else "ROUND %02d" % (round_index+1))
		var match_at: int = text.to_lower().find(weak_point.to_lower()) if not weak_point.is_empty() else -1
		statement.text = "" if match_at >= 0 else text
		target.text = ""
		# One large touch target contains the actual sentence, with an inline weak phrase.
		# Tapping nearby whitespace is the mobile precision alternative to aiming at letters.
		claim_text.text = text.substr(0,match_at)+"[color=#FFB648][u]"+text.substr(match_at,weak_point.length())+"[/u][/color]"+text.substr(match_at+weak_point.length()) if match_at >= 0 else ""
		suffix.text = ""
		statement.visible = not statement.text.is_empty()
		suffix.visible = not suffix.text.is_empty()
		target.visible = match_at >= 0
		target.disabled = weak_point.is_empty() or entrance > 0 or reflecting
		target.accessibility_name = "Challenge: "+weak_point
		load_button.text = "> "+str(Case.exhibit(armed).get("title","LOAD EVIDENCE"))+ ("  _" if armed.is_empty() else " / READY")
		hold_button.text = "RESUME" if held else "HOLD"
		portraits.speaker = speaker
		load_button.visible = not reflecting
		reflection_button.visible = reflecting
		_arrange.call_deferred()
		portraits.queue_redraw()

	func animate(delta: float, remaining_entrance: float) -> void:
		transition += delta
		load_age += delta
		entrance = remaining_entrance
		portraits.transition = transition
		portraits.queue_redraw()
		banner.visible = entrance > 0
		claim_panel.visible = entrance <= 0
		banner.text = "MAKE YOUR ARGUMENT!" if entrance > .8 else "LOAD YOUR EVIDENCE"
		target.disabled = weak.is_empty() or reflecting or entrance > 0
		load_button.disabled = entrance > 0
		if not gentle:
			load_button.modulate = Color.WHITE.lerp(CYAN,maxf(0,1-load_age/.5)*.4)
		_arrange()

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
	var inactive_connections: int = 1
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
		if inactive_connections >= 2:
			draw_rect(Rect2(bounds.position+Vector2(dimensions.x*.5,0),Vector2(dimensions.x*.25,dimensions.y)),Color(0,0,0,.92))

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
