extends RefCounted
## Shanghai Jing'an: arrive, jointly press the seal, receive the documents,
## then take a photograph. Nothing can fail and a short press can be retried.
const StoryCaption := preload("res://hongyuan/ui/story_caption.gd")
const BG := "round1/scenes/registry.png"
const AYU := "ayu_idle.png"
const TORETTO := "w2/common/toretto_neutral_r2.png"
const RED := Color("#a73339")
var r
var phase := "enter" # enter → stamp → handover → photo → flash → memory → done
var t := 0.0
var hold := 0.0
var holding := false
var handed := false
var li := 0
var reveal := 0.0
var memories: Array = ["A4-3a", "A4-3b"]
var _photo: Texture2D
var _capture_pending := false

func start(runner, beat: Dictionary) -> void:
	r = runner
	memories = beat.get("memory", memories)
	r.hint = ""
	r.player_visible = false
	r.actors.clear()
	r.walkers.clear()
	r.crowd.setup([])

func _stamp_rect() -> Rect2: return Rect2(162,214,56,29)
func _next_rect() -> Rect2: return Rect2(104,552,152,46)
func _hold_bar() -> Rect2: return Rect2(62,555,236,42)

func process(dt: float) -> bool:
	t += dt
	match phase:
		"enter":
			if t >= 2.8: phase = "stamp"; t = 0
		"stamp":
			if holding:
				hold = minf(1,hold+dt)
				if hold >= 1:
					phase = "handover";t = 0;holding = false;r.play("pop")
		"handover":
			if t >= 1.6: handed = true
		"flash":
			if t >= 1.7:
				phase = "memory";t = 0;li = 0;reveal = 0
		"memory":
			reveal = minf(_memory_text().length(),reveal+32*dt)
	return phase == "done"

func _memory_text() -> String:
	return r.t_(str(memories[li])) if li < memories.size() else ""

func input(kind: String, pos: Vector2) -> void:
	if phase == "memory" and kind == "tap" and t >= 0.15:
		if reveal < _memory_text().length():
			reveal = _memory_text().length()
		else:
			li += 1;t = 0;reveal = 0
			if li >= memories.size(): phase = "done"
		return
	if phase == "stamp":
		# 按印章本身，或者按底部的「一起按住印章」条，都算按住
		if kind == "down": holding = _stamp_rect().grow(16).has_point(pos) or _hold_bar().grow(8).has_point(pos)
		elif kind == "up":
			holding = false
			if hold < 1: hold = 0
		elif kind == "move" and not (_stamp_rect().grow(40).has_point(pos) or _hold_bar().grow(30).has_point(pos)):
			holding = false;hold = 0
	elif kind == "tap" and _next_rect().grow(8).has_point(pos):
		if phase == "handover" and handed:
			phase = "photo";t = 0
		elif phase == "photo" and t > 0.6:
			phase = "flash";t = 0;r.play("pop")

func restore_checkpoint() -> void:
	holding = false
	if phase == "stamp": hold = 0

func draw(ci) -> void:
	var bg: Texture2D = ci.texture(BG)
	if bg: preload("res://hongyuan/ui/desk_art.gd").cover(ci,bg,ci.view_rect)
	var entering := phase == "enter"
	var progress := smoothstep(0,1,clampf(t/2.4,0,1)) if entering else 1.0
	var photo_pose := phase in ["photo","flash","memory","done"]
	var y := lerpf(ci.view_rect.end.y+100,365,progress)
	if photo_pose: y = lerpf(365,470,smoothstep(0,1,clampf(t/0.6,0,1))) if phase == "photo" else 470
	var left_x := 147.0
	var right_x := 215.0
	if phase in ["stamp","handover"]: left_x = 145; right_x = 218
	elif phase == "enter":
		left_x = lerpf(147,145,progress);right_x = lerpf(215,218,progress)
	elif phase == "photo":
		var settle := smoothstep(0,1,clampf(t/0.6,0,1))
		left_x = lerpf(145,161,settle);right_x = lerpf(218,201,settle)
	elif phase in ["flash","memory","done"]:
		left_x = 161; right_x = 201
	_draw_person(ci,Vector2(left_x,y),false,entering,t)
	_draw_person(ci,Vector2(right_x,y+2),true,entering,t)
	if phase in ["stamp","handover"]:
		_draw_paper(ci)
	if phase == "stamp":
		var c := _stamp_rect().get_center()
		var down := smoothstep(0,1,hold)
		# The seal visibly descends onto the document as the shared press fills.
		_stamp(ci,c+Vector2(0,-8+12*down))
		# 印章上一圈跳动的光圈 + 进度环，玩家一眼知道按哪里
		var pulse := 0.5 + 0.5 * sin(t * 5.0)
		ci.draw_arc(c, 26 + 4 * pulse, 0, TAU, 32, Color(1, 0.88, 0.5, 0.45 + 0.4 * pulse), 2)
		ci.draw_arc(c, 22, -PI / 2, -PI / 2 + TAU * maxf(0.02, hold), 32, ci.GOLD, 4)
		var bar := _hold_bar()
		ci.pill(bar,"一起按住印章一秒",17,ci.RED,ci.PAPER)
		if hold > 0: ci.draw_rect(Rect2(bar.position + Vector2(8, bar.size.y - 6), Vector2((bar.size.x - 16) * hold, 3)), ci.GOLD)
	elif phase == "handover":
		var k := smoothstep(0,1,clampf(t/1.6,0,1))
		_certificate(ci,Vector2(188,237).lerp(Vector2(148,315),k),-0.08)
		_certificate(ci,Vector2(188,237).lerp(Vector2(221,317),k),0.08)
		if handed: ci.pill(_next_rect(),"收好证件，合张影",16,ci.RED,ci.PAPER)
	elif photo_pose:
		# 合影：两人靠拢，红本举在胸前（不是飘在胯部）
		_certificate(ci,Vector2(left_x+14,y-70),-0.08)
		_certificate(ci,Vector2(right_x-14,y-72),0.08)
		if phase == "photo":
			_camera_marks(ci)
			ci.pill(_next_rect(),"拍下这一刻",17,ci.RED,ci.PAPER)
		elif phase == "flash":
			ci.draw_rect(ci.view_rect,Color(1,1,1,maxf(0,1-t/0.35)))
	ci.text_at(Vector2(95,92),"上海 · 静安",17,ci.PAPER,184)
	ci.text_at(Vector2(95,115),"婚姻登记",15,ci.PAPER,184)
	if phase == "memory":
		StoryCaption.draw_caption(ci,_memory_text(),"narrator",int(reveal),false)

func _draw_person(ci, foot: Vector2, man: bool, walking: bool, clock: float) -> void:
	var file := TORETTO if man else AYU
	if walking:
		file = "w2/common/toretto_back_r2.png" if man else "w2/common/ayu_walk_back_%d.png" % (1+int(clock*6)%4)
	elif phase in ["stamp","handover"]:
		file = "w2/common/toretto_back_r2.png" if man else "w2/common/ayu_idle_back.png"
	var tex: Texture2D = ci.texture(file)
	if not tex: return
	var used: Rect2 = ci.WorldScale.visible_rect(tex)
	var height := 116.0 if man else 111.0
	var size := used.size * (height/used.size.y)
	var bob := sin(clock*12)*0.8 if walking else 0.0
	ci.draw_texture_rect_region(tex,Rect2(foot+Vector2(-size.x*0.5,-height+bob),size),used)

func _draw_paper(ci) -> void:
	var box := _stamp_rect()
	ci.draw_rect(Rect2(box.position+Vector2(3,4),box.size),Color(0,0,0,0.2))
	ci.draw_rect(box,Color("#fff5dc"))
	ci.draw_rect(box,Color("#c79f64"),false,1)
	for i in range(3): ci.draw_line(box.position+Vector2(6,7+i*7),box.position+Vector2(50,7+i*7),Color("#c8b694"),1)
	if phase == "handover":
		ci.draw_arc(box.get_center(),13,0,TAU,32,Color(RED,0.78),2)
		ci.draw_line(box.get_center()-Vector2(7,0),box.get_center()+Vector2(7,0),RED,2)

func _stamp(ci, at: Vector2) -> void:
	ci.draw_rect(Rect2(at+Vector2(-8,-20),Vector2(16,22)),Color("#8b4c35"))
	ci.draw_rect(Rect2(at+Vector2(-13,-4),Vector2(26,9)),Color("#b36d49"))
	ci.draw_rect(Rect2(at+Vector2(-13,5),Vector2(26,3)),RED)

func _certificate(ci, at: Vector2, angle: float) -> void:
	ci.draw_set_transform(at,angle)
	ci.draw_rect(Rect2(-10,-14,20,28),Color("#9c2834"))
	ci.draw_rect(Rect2(-8,-12,16,24),ci.GOLD,false,1)
	ci.draw_arc(Vector2(0,-3),3.5,0,TAU,16,ci.GOLD,1)
	ci.draw_line(Vector2(-6,6),Vector2(6,6),ci.GOLD,1)
	ci.draw_set_transform(Vector2.ZERO)

func _camera_marks(ci) -> void:
	var box := Rect2(102,322,166,172)
	for x in [box.position.x,box.end.x]:
		for y in [box.position.y,box.end.y]:
			var sx := 1 if x == box.position.x else -1
			var sy := 1 if y == box.position.y else -1
			ci.draw_line(Vector2(x,y),Vector2(x+sx*14,y),ci.PAPER,2)
			ci.draw_line(Vector2(x,y),Vector2(x,y+sy*14),ci.PAPER,2)
