extends RefCounted
const Laptop := preload("res://hongyuan/ui/laptop.gd")
## 写邀请邮件：阿鱼在电脑前。每点一下，打出下一栏（收件人 → 主题 → 正文）；
## 写完点「发送」，信封飞出屏幕，然后接已有的请柬玩法。正文 = 请柬原文（地点：罗曼山庄 / 时间：永恒）。

const FIELDS := ["B-F4-TO", "B-F4-SUBJ", "BODY"]
const CPS := 14.0   # 打字速度：每秒字数
const BLUE := Color("#2f6fd0")

var r
var phase := "write"   # write → ready → sending → sent → done
var t := 0.0
var field := 0          # 正在写/下一个要写的栏
var typed := 0.0
var typing := false


func start(runner, _beat: Dictionary) -> void:
	r = runner
	r.hint = r.t_("G-MAIL-TYPE")
	r.play("blip")


func _full(i: int) -> String:
	if FIELDS[i] == "BODY":
		return r.t_("A7-1a") + "\n" + r.t_("A7-1c")
	return r.t_(FIELDS[i])


func _send_rect() -> Rect2:
	return Rect2(Laptop.SCREEN.end.x - 62, Laptop.SCREEN.position.y + 26, 54, 22)


func process(dt: float) -> bool:
	t += dt
	if typing:
		typed += dt * CPS
		if typed >= _full(field).length():
			_finish_field()
	if phase == "sending" and t >= 1.3:
		phase = "sent"
		t = 0.0
	elif phase == "sent" and t >= 1.0:
		phase = "done"
	return phase == "done"


func _finish_field() -> void:
	typing = false
	typed = _full(field).length()
	field += 1
	if field >= FIELDS.size():
		phase = "ready"
		t = 0.0
		r.hint = ""


func input(kind: String, pos: Vector2) -> void:
	if kind != "tap":
		return
	match phase:
		"write":
			if typing:
				typed = _full(field).length()
				_finish_field()
			else:
				typing = true
				typed = 0.0
				r.play("blip")
		"ready":
			if t > 0.2 and _send_rect().grow(16).has_point(pos):
				phase = "sending"
				t = 0.0
				r.play("pop")


func skip() -> void:
	phase = "done"
	r.hint = ""


# ---------- 画 ----------

func _shown(i: int) -> String:
	if i < field or phase != "write":
		return _full(i)
	if i == field and typing:
		return _full(i).substr(0, int(typed))
	return ""


func draw(ci) -> void:
	Laptop.draw_room(ci, ci.time)
	Laptop.draw_laptop(ci)
	Laptop.draw_window_bar(ci, ci.t_("G-MAIL-NEW"))
	_draw_compose(ci)
	Laptop.draw_ayu_back(ci)
	if phase == "sending":
		_draw_flight(ci)


func _draw_compose(ci) -> void:
	var s: Rect2 = Laptop.SCREEN
	var x := s.position.x + 10
	# 工具栏 + 发送
	var b := _send_rect()
	var ready: bool = phase != "write"
	var sending: bool = phase in ["sending", "sent"]
	var fill := Color("#b9bfcc")
	if ready:
		fill = BLUE.lerp(Color("#4b8cf0"), 0.5 + 0.5 * sin(ci.time * 5.0)) if phase == "ready" else Color("#8fb4ea")
	ci.pill(b, ci.t_("G-MAIL-SEND"), 12, fill, Color.WHITE)
	var rows := [{"label": "G-MAIL-TO", "y": 78.0}, {"label": "G-MAIL-SUBJ", "y": 106.0}]
	for i in range(2):
		var y: float = s.position.y + float(rows[i].y)
		ci.draw_string(ci.FONT, Vector2(x, y + 14), ci.t_(str(rows[i].label)), HORIZONTAL_ALIGNMENT_LEFT, 56, 12, Color("#6a7283"))
		ci.draw_string(ci.FONT, Vector2(x + 58, y + 14), _shown(i), HORIZONTAL_ALIGNMENT_LEFT, s.size.x - 78, 12, Color("#20242a"))
		ci.draw_line(Vector2(x, y + 22), Vector2(s.end.x - 10, y + 22), Color("#dde1ea"), 1.0)
		_caret(ci, i, Vector2(x + 58, y + 14), _shown(i))
	# 正文
	var body_top := s.position.y + 136.0
	var lines := Laptop.wrap(ci, _shown(2), s.size.x - 28, 12)
	for i in range(lines.size()):
		ci.draw_string(ci.FONT, Vector2(x + 4, body_top + 14 + i * 20), str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, s.size.x - 28, 12, Color("#20242a"))
	if lines.size() > 0:
		_caret(ci, 2, Vector2(x + 4, body_top + 14 + (lines.size() - 1) * 20), str(lines[lines.size() - 1]))
	if phase == "sent":
		var k := clampf(t / 0.2, 0.0, 1.0)
		ci.pill(Rect2(s.position.x + 80, s.position.y + 92, 140, 34), ci.t_("G-MAIL-SENT"), 12, Color(0.18, 0.5, 0.3, k), Color(1, 1, 1, k))


func _caret(ci, i: int, at: Vector2, shown: String) -> void:
	var active: bool = phase == "write" and i == field
	if not active or int(ci.time * 2.5) % 2 == 1:
		return
	var w: float = ci.FONT.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	ci.draw_rect(Rect2(at.x + w + 2, at.y - 11, 2, 14), Color("#2f6fd0"))


func _draw_flight(ci) -> void:
	var k := clampf(t / 1.3, 0.0, 1.0)
	var p0: Vector2 = _send_rect().get_center()
	var p1 := Vector2(250, 20)
	var p2 := Vector2(420, -60)
	var e: float = k * k
	var pos := p0.lerp(p1, e).lerp(p1.lerp(p2, e), e)
	var sc := lerpf(1.6, 0.6, k)
	for i in range(4):
		var kk := maxf(0.0, k - i * 0.05)
		var q := p0.lerp(p1, kk * kk).lerp(p1.lerp(p2, kk * kk), kk * kk)
		ci.draw_circle(q, 3.0 - i * 0.6, Color(1, 0.92, 0.7, 0.5 - i * 0.12))
	var w := 26.0 * sc
	var h := 18.0 * sc
	ci.draw_rect(Rect2(pos - Vector2(w, h) * 0.5, Vector2(w, h)), ci.WHEAT)
	ci.draw_polyline(PackedVector2Array([pos + Vector2(-w * 0.5, -h * 0.5), pos + Vector2(0, h * 0.05), pos + Vector2(w * 0.5, -h * 0.5)]), ci.WOOD, 1.5)
	ci.draw_rect(Rect2(pos - Vector2(w, h) * 0.5, Vector2(w, h)), ci.WOOD, false, 1.5)
