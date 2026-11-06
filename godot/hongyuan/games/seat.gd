extends RefCounted
## 入席：宾客（终章选的形象和名字）从红毯走进宴会厅，点一张桌子走过去坐下。
## 底图 w2/finale/bg_banquet_hall.png 裁自婚宴场景 scene_roman_banquet_v11/base.png（同一画风）。

const BG_Y := 80.0
const K := 0.464          # 原图像素 → 画布
const OFF_X := -380.0 * K
const CARPET_X := 167.0
const ENTRY := Vector2(167, 560)
const TABLES := [Vector2(51, 228), Vector2(283, 228), Vector2(51, 307), Vector2(283, 307), Vector2(51, 391), Vector2(283, 391)]
const SPEED := 70.0
const GUEST_H := 46.0

var r
var phase := "walk_in"   # walk_in → pick → walk → seated → done
var t := 0.0
var pos := ENTRY + Vector2(0, 40)
var path: Array[Vector2] = []
var table := -1
var dir := "up"
var walk_d := 0.0
var sheet: Texture2D
var guest_name := ""


func start(runner, _beat: Dictionary) -> void:
	r = runner
	var res: Dictionary = r.result if r.result is Dictionary else {}
	var look := str(res.get("look", "01"))
	guest_name = str(res.get("name", ""))
	var p := "res://hongyuan/assets/w2/finale/chr_LM-GUEST-07.png" if look == "07" else "res://assets/characters/lm/chr_LM-GUEST-%s.png" % look
	sheet = load(p) if ResourceLoader.exists(p) else null
	path = [ENTRY]


func process(dt: float) -> bool:
	t += dt
	if phase in ["walk_in", "walk"]:
		if path.is_empty():
			if phase == "walk_in":
				phase = "pick"
			else:
				phase = "seated"
				t = 0.0
				r.play("pop")
			return false
		var target: Vector2 = path[0]
		var d := target - pos
		if d.length() < 1.0:
			pos = target
			path.pop_front()
		else:
			var step := minf(SPEED * dt, d.length())
			pos += d.normalized() * step
			walk_d += step
			if absf(d.x) > absf(d.y):
				dir = "right" if d.x > 0 else "left"
			else:
				dir = "down" if d.y > 0 else "up"
	elif phase == "seated" and t >= 2.4:
		phase = "done"
	return phase == "done"


func _seat_of(i: int) -> Vector2:
	var c: Vector2 = TABLES[i]
	return c + Vector2(30 if c.x < CARPET_X else -30, 14)


func input(kind: String, p: Vector2) -> void:
	if kind != "tap" or phase != "pick":
		return
	for i in range(TABLES.size()):
		if Rect2(TABLES[i] - Vector2(36, 34), Vector2(72, 64)).has_point(p):
			table = i
			var seat := _seat_of(i)
			path = [Vector2(CARPET_X, seat.y), seat]
			phase = "walk"
			r.play("blip")
			return


func draw(ci) -> void:
	ci.draw_rect(Rect2(0, 0, 360, 640), Color("#2a1210"))
	var bg: Texture2D = ci.texture("w2/finale/bg_banquet_hall.png")
	if bg:
		ci.draw_texture_rect(bg, Rect2(0, BG_Y, 360, 360.0 * bg.get_height() / bg.get_width()), false)
	# 新人站在台前
	ci.person_height = 50.0
	ci.sprite("ayu_wedding_idle.png|ayu_idle.png", Vector2(CARPET_X - 12, 198))
	ci.sprite("w2/common/toretto_stand.png", Vector2(CARPET_X + 12, 198), true)
	if phase == "pick":
		var a := 0.5 + 0.5 * sin(t * 4.0)
		for i in range(TABLES.size()):
			ci.draw_arc(TABLES[i], 34, 0, TAU, 32, Color(ci.GOLD, 0.35 + 0.5 * a), 3.0)
	if table >= 0:
		ci.draw_arc(TABLES[table], 34, 0, TAU, 32, ci.GOLD, 3.0)
	_draw_guest(ci)
	# 上方文字
	ci.draw_rect(Rect2(0, 20, 360, 44), Color(ci.INK, 0.72))
	var line := ""
	match phase:
		"walk_in", "pick":
			line = ci.t_("A7-2c")
		"walk":
			line = ci.t_("A7-B1")
		_:
			line = ci.t_("A7-1e")
	ci.text_at(Vector2(0, 30), line, 16, ci.PAPER, 360)


func _draw_guest(ci) -> void:
	var feet := pos
	ci.draw_colored_polygon(_ellipse(feet, 10, 3), Color(0, 0, 0, 0.25))
	if sheet:
		var row := {"down": 0, "left": 4, "right": 8, "up": 12}
		var moving := phase in ["walk_in", "walk"] and not path.is_empty()
		var f: int = row.get(dir if phase != "seated" else "down", 0) + (int(walk_d / 8.0) % 4 if moving else 0)
		var w := GUEST_H * 64.0 / 84.0
		ci.draw_texture_rect_region(sheet, Rect2(feet - Vector2(w * 0.5, GUEST_H), Vector2(w, GUEST_H)), Rect2(f * 64, 0, 64, 84))
	else:
		ci.draw_rect(Rect2(feet - Vector2(8, 40), Vector2(16, 40)), Color("#6b3fa0"))
	if guest_name != "":
		var nw := 20.0 + guest_name.length() * 13.0
		ci.pill(Rect2(feet.x - nw * 0.5, feet.y - GUEST_H - 26, nw, 22), guest_name, 13, ci.RED, ci.PAPER)


func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
