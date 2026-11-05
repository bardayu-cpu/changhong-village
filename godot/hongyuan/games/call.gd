extends RefCounted
## 来电：手机拿起来，显示「Toretto 来电」，阿鱼嘀咕一句，玩家亲手按接听；
## 接通后显示「通话中」，beat.lines 里的对白一句句播（点屏幕翻页）。

var r
var phase := "ring"   # ring → talk → done
var t := 0.0
var lines: Array = []
var li := 0
var reveal := 0.0
var aside := ""


func start(runner, beat: Dictionary) -> void:
	r = runner
	lines = beat.get("lines", [])
	aside = r.t_(str(beat.get("aside", "")))
	r.play("blip")


func process(dt: float) -> bool:
	t += dt
	reveal += dt * 26.0
	if phase == "ring" and fmod(t, 1.2) < dt:
		r.play("blip")
	return phase == "done"


func _accept_rect() -> Rect2:
	return Rect2(146, 470, 68, 68)


func input(kind: String, pos: Vector2) -> void:
	if kind != "tap":
		return
	if phase == "ring":
		if _accept_rect().grow(12).has_point(pos):
			phase = "talk"
			t = 0.0
			li = 0
			reveal = 0.0
			r.play("pop")
	elif phase == "talk":
		var text := _line_text()
		if reveal < text.length():
			reveal = text.length()
		elif t > 0.25:
			li += 1
			reveal = 0.0
			t = 0.0
			if li >= lines.size():
				phase = "done"


func _line_text() -> String:
	if li >= lines.size():
		return ""
	return r.t_(str(lines[li].get("say", "")))


func draw(ci) -> void:
	ci.draw_rect(Rect2(0, 0, 360, 640), Color(0, 0, 0, 0.55))
	var frame: Texture2D = ci.texture("w2_ui/phone_frame_w2_r1.png")
	var screen := Rect2(34, 52, 292, 520)
	if frame:
		ci.draw_texture_rect(frame, Rect2(Vector2(14, 32), frame.get_size() * ci.S), false)
		var paper: Texture2D = ci.texture("w2_ui/phone_screen_paper_w2_r1.png")
		if paper:
			ci.draw_texture_rect(paper, Rect2(Vector2(22, 40), paper.get_size() * ci.S), false)
	else:
		ci.draw_rect(Rect2(24, 40, 312, 548), Color("#2b1d19"))
		ci.draw_rect(screen, ci.PAPER)
	var av: Texture2D = ci.texture("toretto_avatar.png")
	var wobble := sin(t * 30.0) * 2.0 if phase == "ring" and fmod(t, 1.2) < 0.5 else 0.0
	if av:
		ci.draw_texture_rect(av, Rect2(Vector2(140 + wobble, 120), Vector2(80, 80)), false)
	ci.text_at(Vector2(30, 236), ci.t_("A3-C1") if phase == "ring" else ci.t_("A3-C2"), 22, ci.INK, 300)
	if phase == "ring":
		if aside != "":
			ci.text_at(Vector2(50, 300), "阿鱼：" + aside, 15, ci.WOOD, 260)
		var acc: Texture2D = ci.texture("w2_ui/call_accept_w2_r1.png")
		var rr := _accept_rect()
		var k := 1.0 + 0.06 * sin(t * 8.0)
		var rr2 := Rect2(rr.get_center() - rr.size * 0.5 * k, rr.size * k)
		if acc:
			ci.draw_texture_rect(acc, rr2, false)
		else:
			ci.draw_circle(rr.get_center(), 32 * k, Color("#4f9d5a"))
		ci.text_at(Vector2(100, 562), ci.t_("A3-B1"), 16, ci.INK, 160)
	elif phase == "talk" and li < lines.size():
		var who := str(lines[li].get("who", "narrator"))
		var text := _line_text().substr(0, int(reveal))
		var y := 300.0
		var box := Rect2(44, y + 10, 272, 160)
		ci.draw_rect(box, Color(1, 1, 1, 0.35))
		var label: String = "" if who == "narrator" else ci.NAMES.get(who, who)
		if label != "":
			ci.pill(Rect2(box.position + Vector2(8, -12), Vector2(26 + 14 * label.length(), 24)), label, 14, ci.RED, ci.PAPER)
		ci.text_at(box.position + Vector2(12, 38), text, 16, ci.INK, box.size.x - 24, HORIZONTAL_ALIGNMENT_LEFT if label != "" else HORIZONTAL_ALIGNMENT_CENTER)
		var end: Texture2D = ci.texture("w2_ui/call_end_w2_r1.png")
		if end:
			ci.draw_texture_rect(end, Rect2(Vector2(146, 490), Vector2(68, 68)), false, Color(1, 1, 1, 0.5))
