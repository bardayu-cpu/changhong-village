extends RefCounted
## 来电：手机拿起来，显示「Toretto 来电」，阿鱼嘀咕一句，玩家亲手按接听；
## 接通后按住手机才播放字幕；松手保留当前句和进度。

const LETTERS_PER_SECOND := 12.0
const LINE_REST := 0.6

var r
var phase := "ring"   # ring → talk → birthday → reply → hangup → done
var t := 0.0
var lines: Array = []
var li := 0
var reveal := 0.0
var aside := ""
var holding := false
var birthday_seen := false
var birthday_flash := 0.0
var call_time := 0.0
var hint_t := 0.0
var speaker_on := false


func start(runner, beat: Dictionary) -> void:
	r = runner
	lines = beat.get("lines", [])
	aside = r.t_(str(beat.get("aside", "")))
	r.play("blip")


func process(dt: float) -> bool:
	birthday_flash = maxf(0.0, birthday_flash - dt)
	if phase in ["talk", "birthday", "reply"]:
		call_time += dt
	if phase == "ring":
		t += dt
		if fmod(t, 1.2) < dt:
			r.play("blip")
	elif phase == "talk":
		if not holding:
			hint_t += dt
			return false
		hint_t = 0.0
		t += dt
		var length := _line_text().length()
		reveal = minf(float(length), reveal + dt * LETTERS_PER_SECOND)
		if str(lines[li].get("say", "")) == "A3-2d" and reveal >= length:
			phase = "birthday"
			birthday_flash = 0.3 if not birthday_seen else 0.0
			birthday_seen = true
			r.pose = "surprised"
			r.play("pop")
			t = 0.0
			holding = false
		elif t >= float(length) / LETTERS_PER_SECOND + LINE_REST:
			li += 1
			reveal = 0.0
			t = 0.0
	elif phase == "birthday":
		t += dt
		if t >= LINE_REST:
			li += 1
			phase = "reply"
			reveal = _line_text().length()
			t = 0.0
	elif phase == "reply":
		t += dt
	elif phase == "hangup":
		t += dt
		if t >= 0.6:
			phase = "done"
	return phase == "done"


func restore_checkpoint() -> void:
	# Refresh replays the current sentence from its beginning, never a held finger.
	if phase == "talk" and li >= 4:
		phase = "reply" if li < lines.size() else "hangup"
	holding = false
	t = 0.0
	hint_t = 0.0
	birthday_flash = 0.0
	if phase == "talk": reveal = 0.0
	if phase == "reply": reveal = _line_text().length()
	if birthday_seen or li >= 4: r.pose = "surprised"


func _accept_rect() -> Rect2:
	return Rect2(146, 470, 68, 68)


func _listen_rect() -> Rect2:
	return Rect2(0, 0, 360, 640)


func _speaker_rect() -> Rect2:
	return Rect2(252, 222, 54, 54)


func input(kind: String, pos: Vector2) -> void:
	if phase == "talk":
		if kind == "down":
			holding = _listen_rect().has_point(pos)
		elif kind == "up":
			holding = false
		# A release can also generate a tap. Neither event skips a line.
		return
	if phase == "reply" and kind == "tap" and t >= 0.12:
		if li == 6:
			if not _speaker_rect().grow(8).has_point(pos): return
			speaker_on = true
			r.play("pop")
		li += 1
		t = 0.0
		if li >= lines.size():
			phase = "hangup"
		else:
			reveal = _line_text().length()
		return
	if phase == "ring" and kind == "tap":
		if _accept_rect().grow(12).has_point(pos):
			phase = "talk"
			t = 0.0
			li = 0
			reveal = 0.0
			r.play("pop")


func _line_text() -> String:
	if li >= lines.size():
		return ""
	return r.t_(str(lines[li].get("say", "")))


func draw(ci) -> void:
	var slide := 640.0 * pow(clampf(t / 0.6, 0.0, 1.0), 2) if phase == "hangup" else 0.0
	ci.draw_set_transform(Vector2(0, slide))
	_draw_phone(ci)
	ci.draw_set_transform(Vector2.ZERO)
	if birthday_flash > 0.0:
		ci.draw_rect(Rect2(0, 0, 360, 640), Color(1, 1, 1, birthday_flash))


func _draw_phone(ci) -> void:
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
	if phase in ["birthday", "reply"]:
		ci.sprite("w2/common/ayu_surprised.png|ayu_idle.png", Vector2(70, 282), false, 0.6)
	ci.text_at(Vector2(30, 236 if phase == "ring" else 88), ci.t_("A3-C1") if phase == "ring" else ci.t_("A3-C2"), 22, ci.INK, 300)
	if phase != "ring":
		ci.text_at(Vector2(80, 112), "%02d:%02d" % [int(call_time) / 60, int(call_time) % 60], 14, ci.WOOD, 200)
	if phase == "reply" and li >= 6:
		var icon := _speaker_rect()
		var col: Color = ci.GOLD if speaker_on else ci.WOOD
		ci.draw_rect(icon, ci.WOOD if speaker_on else ci.PAPER)
		ci.draw_rect(icon, ci.GOLD, false, 2)
		var at := icon.get_center() - Vector2(6, 0)
		ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-12, -6), at + Vector2(-6, -6),
			at + Vector2(3, -14), at + Vector2(3, 14), at + Vector2(-6, 6), at + Vector2(-12, 6)]), col)
		ci.draw_arc(at + Vector2(3, 0), 11, -PI / 3, PI / 3, 12, col, 2)
		if speaker_on:
			ci.draw_arc(at + Vector2(3, 0), 18, -PI / 3, PI / 3, 12, col, 2)
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
	elif phase in ["talk", "birthday", "reply"] and li < lines.size():
		var who := str(lines[li].get("who", "narrator"))
		var text := _line_text().substr(0, int(reveal))
		var y := 300.0
		var box := Rect2(44, y + 10, 272, 160)
		ci.draw_rect(box, Color(1, 1, 1, 0.35))
		var label: String = "" if who == "narrator" else ci.NAMES.get(who, who)
		if label != "":
			ci.pill(Rect2(box.position + Vector2(8, -12), Vector2(26 + 14 * label.length(), 24)), label, 14, ci.RED, ci.PAPER)
		ci.text_at(box.position + Vector2(12, 38), text, 16, ci.INK, box.size.x - 24, HORIZONTAL_ALIGNMENT_LEFT if label != "" else HORIZONTAL_ALIGNMENT_CENTER)
		if phase == "talk":
			var flash := hint_t >= 10.0 and fmod(hint_t, 10.0) < 0.6
			ci.pill(Rect2(68, 508, 224, 40), ci.t_("G-HOLD"), 16, ci.GOLD if flash or holding else ci.WOOD, ci.PAPER)
		elif phase == "reply":
			ci.pill(Rect2(68, 514, 224, 34), ci.t_("G-SPEAKER") if li == 6 else ci.t_("G-19"), 16, ci.WOOD, ci.PAPER)
