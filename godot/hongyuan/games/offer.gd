extends RefCounted
const Laptop := preload("res://hongyuan/ui/laptop.gd")
## 电脑上看英文 Offer：过肩看阿鱼的笔记本。点开未读邮件 → 上滑/点按读正式录用函 → 点「Accept」。
## 不写职位、薪资、日期。

const VIEW := Rect2(38, 180, 286, 285)   # 信件可视区（只在里面画整行）
const LINE := 18.0
const NAVY := Color("#1f3a68")
const TEXT := Color("#2a2f3a")

var r
var phase := "list"   # list → letter → accepted → done
var t := 0.0
var scroll := 0.0
var max_scroll := 0.0
var dragging := false
var last_y := 0.0
var _items: Array = []
var _built := false
var _drag_total := 0.0


func start(runner, _beat: Dictionary) -> void:
	r = runner
	r.play("blip")


func process(dt: float) -> bool:
	t += dt
	if phase == "accepted" and t > 1.0:
		phase = "done"
		r.hint = ""
	return phase == "done"


func _row() -> Rect2:
	var k := maxf(r.view_rect.size.x/841.0,r.view_rect.size.y/1870.0)
	var origin: Vector2 = r.view_rect.get_center()-Vector2(841,1870)*k*0.5
	return Rect2(origin+Vector2(464,836)*k,Vector2(257,221)*k)


func _button_rect() -> Rect2:
	for it: Dictionary in _items:
		if it.kind == "button":
			return Rect2(VIEW.position.x + (VIEW.size.x - 130) * 0.5, VIEW.position.y + float(it.y) - scroll, 130, 30)
	return Rect2()


func _build() -> void:
	if _built:
		return
	_built = true
	var y := 8.0
	_items.append({"kind": "text", "s": r.t_("B-G0-HDR"), "size": 13, "y": y + 12, "col": NAVY, "center": true})
	y += 20.0
	_items.append({"kind": "rule", "y": y})
	y += 14.0
	_items.append({"kind": "text", "s": r.t_("B-G0-TITLE"), "size": 14, "y": y + 12, "col": Color("#7a1f2b"), "center": true})
	y += 30.0
	_items.append({"kind": "text", "s": r.t_("B-G0-DEAR"), "size": 13, "y": y + 12, "col": TEXT})
	y += 24.0
	for key in ["B-G0-P1", "B-G0-P2"]:
		for ln: String in Laptop.wrap(r, r.t_(key), VIEW.size.x - 24, 13):
			_items.append({"kind": "text", "s": ln, "size": 13, "y": y + 12, "col": TEXT})
			y += LINE
		y += 8.0
	_items.append({"kind": "text", "s": r.t_("B-G0-REGARDS"), "size": 13, "y": y + 12, "col": TEXT})
	y += LINE
	_items.append({"kind": "text", "s": r.t_("B-G0-SIGN"), "size": 13, "y": y + 12, "col": NAVY})
	y += LINE + 8.0
	# 中文小字：玩家不用读英文也知道信里说了什么
	for ln: String in Laptop.wrap(r, r.t_("B-G0-ZH"), VIEW.size.x - 24, 12):
		_items.append({"kind": "text", "s": ln, "size": 12, "y": y + 12, "col": Color(TEXT, 0.6)})
		y += LINE - 2.0
	y += 8.0
	_items.append({"kind": "button", "y": y})
	y += 30.0 + 10.0
	max_scroll = maxf(0.0, y - VIEW.size.y)


func input(kind: String, pos: Vector2) -> void:
	if phase == "list":
		if kind == "tap" and _row().grow(8).has_point(pos):
			phase = "letter"
			t = 0.0
			scroll = 0.0
			_build()
			r.play("pop")
			r.hint = r.t_("G-OFFER-READ")
		return
	if phase != "letter":
		return
	if kind == "down":
		dragging = VIEW.grow(10).has_point(pos)
		last_y = pos.y
		_drag_total = 0.0
	elif kind == "move" and dragging:
		var dy := pos.y - last_y
		last_y = pos.y
		_drag_total += absf(dy)
		scroll = clampf(scroll - dy, 0.0, max_scroll)
	elif kind == "up":
		dragging = false
	elif kind == "tap" and t > 0.25:
		var b := _button_rect()
		if _button_visible() and b.grow(10).has_point(pos):
			phase = "accepted"
			t = 0.0
			r.hint = ""
			r.play("pop")
		else:
			var before := scroll
			scroll = minf(max_scroll, scroll + 72.0)
			if scroll != before:
				r.play("blip")


func skip() -> void:
	phase = "done"
	r.hint = ""


func _button_visible() -> bool:
	var b := _button_rect()
	return b.size.x > 0 and b.position.y >= VIEW.position.y and b.end.y <= VIEW.end.y


# ---------- 画 ----------

func draw(ci) -> void:
	var bg: Texture2D = ci.texture("round1/people/offer_room.png")
	if bg: preload("res://hongyuan/ui/desk_art.gd").cover(ci,bg,ci.view_rect)
	if phase == "list":
		var at := _row().get_center()+Vector2(8,-10)
		ci.draw_rect(Rect2(at-Vector2(14,10),Vector2(28,20)),Color("#e6b44f"))
		ci.draw_line(at-Vector2(14,10),at+Vector2(0,2),Color.WHITE,1)
		ci.draw_line(at+Vector2(14,-10),at+Vector2(0,2),Color.WHITE,1)
		ci.draw_circle(at+Vector2(12,-10),3,Color("#b74242"))
		ci.pill(Rect2(75,530,210,42),"电脑上有一封新邮件",15,Color(0.96,0.96,0.93,0.96),ci.INK)
	else:
		ci.draw_rect(Rect2(20,132,320,365),Color(0.97,0.96,0.93,0.97))
		ci.text_at(Vector2(38,163),"Mail  /  Offer of Appointment",14,NAVY,286)
		_draw_letter(ci)


func _draw_letter(ci) -> void:
	ci.draw_rect(Rect2(VIEW.position.x - 6, VIEW.position.y - 8, VIEW.size.x + 12, VIEW.size.y + 16), Color("#eef0f5"))
	ci.draw_rect(Rect2(VIEW.position.x - 2, VIEW.position.y - 4, VIEW.size.x + 4, VIEW.size.y + 8), Color("#ffffff"))
	ci.draw_rect(Rect2(VIEW.position.x - 2, VIEW.position.y - 4, VIEW.size.x + 4, VIEW.size.y + 8), Color("#c9ced9"), false, 1.0)
	for it: Dictionary in _items:
		var y: float = VIEW.position.y + float(it.y) - scroll
		match str(it.kind):
			"text":
				if y - 13 < VIEW.position.y or y + 4 > VIEW.end.y:
					continue
				var size := int(it.size)
				if bool(it.get("center", false)):
					ci.draw_string(ci.FONT, Vector2(VIEW.position.x, y), str(it.s), HORIZONTAL_ALIGNMENT_CENTER, VIEW.size.x, size, it.col)
				else:
					ci.draw_string(ci.FONT, Vector2(VIEW.position.x + 12, y), str(it.s), HORIZONTAL_ALIGNMENT_LEFT, VIEW.size.x - 24, size, it.col)
			"rule":
				if y >= VIEW.position.y and y <= VIEW.end.y:
					ci.draw_rect(Rect2(VIEW.position.x + 12, y, VIEW.size.x - 24, 2), Color("#7a1f2b"))
			"button":
				var b := _button_rect()
				if not _button_visible():
					continue
				var done: bool = phase == "accepted"
				var pulse := 0.0 if done else 0.5 + 0.5 * sin(ci.time * 5.0)
				var fill := Color("#3d8f55") if done else Color("#2f6fd0").lerp(Color("#4b8cf0"), pulse)
				ci.pill(b, ci.t_("G-OFFER-ACCEPT"), 12, fill, Color.WHITE)
	# 滚动条
	if max_scroll > 0.0:
		var h := VIEW.size.y * VIEW.size.y / (VIEW.size.y + max_scroll)
		var ty := VIEW.position.y + (VIEW.size.y - h) * scroll / max_scroll
		ci.draw_rect(Rect2(VIEW.end.x + 1, ty, 3, h), Color("#9aa3b5"))


func restore_checkpoint() -> void:
	dragging = false
	_drag_total = 0.0
	if phase in ["letter", "accepted"]:
		_build()
		scroll = clampf(scroll, 0.0, max_scroll)
		r.hint = r.t_("G-OFFER-READ") if phase == "letter" else ""
