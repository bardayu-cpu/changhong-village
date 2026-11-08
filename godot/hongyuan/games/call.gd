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
	return Rect2(146, 400, 68, 68)  # 接听键放在头像下面，不压住 Toretto 的脸


func _listen_rect() -> Rect2:
	return r.view_rect


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
	var who := str(lines[li].get("who", "narrator")) if li < lines.size() else "narrator"
	var monologue := who == "narrator"
	if phase != "ring" and not monologue:
		var bg: Texture2D = ci.texture("round1/people/call_split.png")
		if bg: preload("res://hongyuan/ui/desk_art.gd").cover(ci,bg,ci.view_rect)
	if phase == "ring":
		PhoneShell._round_box(ci,Rect2(55,293,250,177),Color(0.10,0.16,0.22,0.92),18)
		ci.text_at(Vector2(70,330),ci.t_("A3-C1"),20,ci.PAPER,220)
		var face: Texture2D = ci.texture("toretto_avatar.png")
		if face: ci.draw_texture_rect(face,Rect2(156,342,48,48),false)
		var pulse := 0.5 + 0.5 * sin(t * 6.0)
		ci.draw_circle(_accept_rect().get_center(),25 + 3 * pulse,Color("#4b995c"))
		ci.draw_arc(_accept_rect().get_center(),31 + 5 * pulse,0,TAU,32,Color(0.6,0.95,0.65,0.6 * (1 - pulse)),2)
		ci.text_at(Vector2(145,443),"接听",16,ci.PAPER,70)
		StoryCaption.draw_caption(ci,aside,"narrator")
	elif phase in ["talk","birthday","reply"] and li < lines.size():
		var anchor := Vector2(-1,-1) if monologue else _head(who)
		StoryCaption.draw_caption(ci,_line_text(),who,int(reveal),false,anchor)
		ci.pill(Rect2(88,572,184,34),ci.t_("G-HOLD") if phase == "talk" else "轻点继续",15,Color(ci.WOOD,0.75),ci.PAPER)
		if holding:
			for i in range(5):
				var h := 3+absf(sin(call_time*8+i))*7
				ci.draw_rect(Rect2(163+i*7,550-h*.5,3,h),ci.GOLD)
	elif phase == "hangup":
		ci.pill(Rect2(90,555,180,36),"通话结束",16,Color(ci.INK,clampf(1-t/0.6,0,1)),ci.PAPER)
	if birthday_flash > 0:ci.draw_rect(ci.view_rect,Color(1,1,1,birthday_flash))

func _head(who: String) -> Vector2:
	var size := Vector2(916,1717)
	var k := maxf(r.view_rect.size.x/size.x,r.view_rect.size.y/size.y)
	var point := Vector2(520,380) if who == "ayu" else Vector2(500,1120)
	return r.view_rect.get_center()-size*k*0.5+point*k
