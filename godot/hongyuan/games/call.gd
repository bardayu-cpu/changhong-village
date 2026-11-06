extends RefCounted
const PhoneShell := preload("res://hongyuan/ui/phone_shell.gd")
const StoryCaption := preload("res://hongyuan/ui/story_caption.gd")
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
	return Rect2(146, 366, 68, 68)


func _listen_rect() -> Rect2:
	return Rect2(0, 0, 360, 640)


func _speaker_rect() -> Rect2:
	return Rect2(252, 402, 54, 54)


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
	var who := str(lines[li].get("who", "narrator")) if li < lines.size() else "narrator"
	var monologue := phase in ["talk", "birthday", "reply"] and who == "narrator"
	if monologue:
		# 阿鱼独自听电话/心里想：保留她自己的房间与人物，不叠对方肖像。
		ci.draw_rect(Rect2(0, 0, 360, 640), Color(0.02, 0.03, 0.05, 0.16))
		ci.pill(Rect2(68, 514, 224, 34), ci.t_("A3-C2"), 16, Color(ci.INK, 0.85), ci.PAPER)
	else:
		ci.draw_rect(Rect2(0, 0, 360, 640), Color(0, 0, 0, 0.55))
		PhoneShell.draw_shell(ci, true)
		if phase == "ring":
			# 来电时先呈现阿鱼的疑惑；接听后的双人对白才显示双方。
			var face: Texture2D = ci.texture("ayu_avatar.png")
			if face: ci.draw_texture_rect(face, Rect2(140, 146, 80, 80), false)
			ci.text_at(Vector2(30, 278), ci.t_("A3-C1"), 22, ci.PAPER, 300)
		else:
			for i in range(2):
				var person := "ayu" if i == 0 else "toretto"
				var center := Vector2(106 + i * 148, 335)
				var face: Texture2D = ci.texture(person + "_avatar.png")
				if face: ci.draw_texture_rect(face, Rect2(center - Vector2(37, 37), Vector2(74, 74)), false)
				ci.text_at(Vector2(center.x - 60, 395), ci.NAMES[person], 16, ci.PAPER, 120)
				if who == person:
					for bar in range(5):
						var height := 4 + absf(sin(call_time * 7 + bar)) * 12
						ci.draw_rect(Rect2(center + Vector2(-16 + bar * 7, 78 - height / 2), Vector2(3, height)), ci.GOLD)
			ci.text_at(Vector2(30, 98), ci.t_("A3-C2"), 22, ci.PAPER, 300)
			ci.text_at(Vector2(80, 127), "%02d:%02d" % [int(call_time) / 60, int(call_time) % 60], 14, ci.PAPER, 200)
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
			StoryCaption.draw_caption(ci, aside, "narrator")
		var acc: Texture2D = ci.texture("w2_ui/call_accept_w2_r1.png")
		var rr := _accept_rect()
		var k := 1.0 + 0.06 * sin(t * 8.0)
		var rr2 := Rect2(rr.get_center() - rr.size * 0.5 * k, rr.size * k)
		if acc:
			ci.draw_texture_rect(acc, rr2, false)
		else:
			ci.draw_circle(rr.get_center(), 32 * k, Color("#4f9d5a"))
		ci.text_at(Vector2(100, 462), ci.t_("A3-B1"), 16, ci.PAPER, 160)
	elif phase in ["talk", "birthday", "reply"] and li < lines.size():
		StoryCaption.draw_caption(ci, _line_text(), who, int(reveal), false, Vector2(106 if who == "ayu" else 254, 294) if who != "narrator" else Vector2(-1, -1))
		if phase == "talk":
			var flash := hint_t >= 10.0 and fmod(hint_t, 10.0) < 0.6
			ci.pill(Rect2(68, 568 if monologue else 462, 224, 40), ci.t_("G-HOLD"), 16, ci.GOLD if flash or holding else ci.WOOD, ci.PAPER)
		elif phase == "reply":
			ci.pill(Rect2(68, 568 if monologue else 462, 224, 34), ci.t_("G-SPEAKER") if li == 6 else ci.t_("G-19"), 16, ci.WOOD, ci.PAPER)
