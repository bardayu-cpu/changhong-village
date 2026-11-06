extends RefCounted
const Laptop := preload("res://hongyuan/ui/laptop.gd")
## 电脑上看英文 Offer：过肩看阿鱼的笔记本。点开未读邮件 → 上滑/点按读正式录用函 → 点「Accept」。
## 不写职位、薪资、日期。

const VIEW := Rect2(38, 134, 286, 160)   # 信件可视区（只在里面画整行）
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
	return Rect2(38, 130, 286, 54)


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
	y += LINE + 12.0
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
	Laptop.draw_room(ci, ci.time)
	Laptop.draw_laptop(ci)
	Laptop.draw_window_bar(ci)
	if phase == "list":
		_draw_list(ci)
	else:
		_draw_letter(ci)
	Laptop.draw_ayu_back(ci)


func _draw_list(ci) -> void:
	# 其余几行只画灰条，不写任何假邮件内容
	for i in range(3):
		var y := 196.0 + i * 36.0
		ci.draw_rect(Rect2(46, y, 120, 6), Color("#c9ced9"))
		ci.draw_rect(Rect2(46, y + 12, 220, 5), Color("#dde1ea"))
		ci.draw_line(Vector2(38, y + 28), Vector2(324, y + 28), Color("#e4e7ee"), 1.0)
	var row := _row()
	var glow := 0.55 + 0.2 * sin(t * 5.0)
	ci.draw_rect(row, Color(1.0, 0.93, 0.7, glow))
	ci.draw_rect(row, Color("#c99a3c"), false, 2.0)
	ci.draw_circle(row.position + Vector2(12, 14), 4.0, Color("#d63c3c"))
	ci.draw_string(ci.FONT, row.position + Vector2(24, 18), ci.t_("A6-M1"), HORIZONTAL_ALIGNMENT_LEFT, 120, 12, ci.INK)
	ci.pill(Rect2(row.end.x - 70, row.position.y + 6, 62, 18), ci.t_("A6-M2"), 12, Color("#7a1f2b"), Color("#fff1d5"))
	ci.draw_string(ci.FONT, row.position + Vector2(24, 42), ci.t_("B-G0-TITLE"), HORIZONTAL_ALIGNMENT_LEFT, 250, 13, TEXT)


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
