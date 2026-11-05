extends RefCounted
## 套圈：往后拖动瞄准（像拉弹弓），松手投出。落点套中木桩就挂上去，没中就落在地上。
## 投一次后可以按「继续」走，投满两次自动往下走。不要求全中，没有奖品。

var r
var pegs: Array[Vector2] = []
var hand := Vector2.ZERO
var phase := "aim"   # aim → fly → land → (aim | done)
var t := 0.0
var dragging := false
var drag_from := Vector2.ZERO
var drag_to := Vector2.ZERO
var aim := Vector2.ZERO
var thrown := 0
var rings: Array = []   # {at, peg}
var hit_flash := 0.0


func start(runner, beat: Dictionary) -> void:
	r = runner
	for p: Array in beat.get("pegs", [[132, 228], [180, 216], [228, 228], [156, 256], [204, 256]]):
		pegs.append(Vector2(float(p[0]), float(p[1])))
	r.facing = 1.0
	r.pose = "throw"
	hand = r.feet + Vector2(14, -100)


func process(dt: float) -> bool:
	t += dt
	hit_flash = maxf(0.0, hit_flash - dt)
	match phase:
		"fly":
			if t >= 0.7:
				phase = "land"
				t = 0.0
				var best := -1
				for i in range(pegs.size()):
					if aim.distance_to(pegs[i]) < 16.0 and (best < 0 or aim.distance_to(pegs[i]) < aim.distance_to(pegs[best])):
						best = i
				rings.append({"at": pegs[best] if best >= 0 else aim, "peg": best >= 0})
				if best >= 0:
					hit_flash = 0.8
					r.play("pop")
					r.pose = "cheer"
				else:
					r.play("blip")
		"land":
			if t >= 0.9:
				r.pose = "throw"
				if thrown >= 2:
					r.pose = ""
					return true
				phase = "aim"
				t = 0.0
	return false


func _predict() -> Vector2:
	var pull := drag_to - drag_from
	var p := hand - pull * 1.6
	return Vector2(clampf(p.x, 40, 320), clampf(p.y, 120, 330))


func _continue_rect() -> Rect2:
	return Rect2(250, 580, 92, 40)


func input(kind: String, pos: Vector2) -> void:
	if phase != "aim":
		return
	if kind == "tap" and thrown >= 1 and _continue_rect().grow(6).has_point(pos):
		thrown = 2
		phase = "land"
		t = 1.0
		return
	if kind == "down" and not (thrown >= 1 and _continue_rect().grow(6).has_point(pos)):
		dragging = true
		drag_from = pos
		drag_to = pos
	elif kind == "move" and dragging:
		drag_to = pos
	elif kind == "up" and dragging:
		dragging = false
		if drag_to.distance_to(drag_from) > 18.0:
			aim = _predict()
			phase = "fly"
			t = 0.0
			thrown += 1
			r.play("blip")


func draw(ci) -> void:
	var stall: Texture2D = ci.texture("w2/hainan/ring_stall.png")
	if not stall:
		_placeholder_stall(ci)
	for i in range(pegs.size()):
		var lit := false
		for ring: Dictionary in rings:
			if ring.peg and ring.at == pegs[i]:
				lit = true
		_peg(ci, pegs[i], lit)
	for ring: Dictionary in rings:
		_ring(ci, ring.at + (Vector2(0, -6) if ring.peg else Vector2.ZERO), 1.0, 0.0)
	if phase == "fly":
		var k := clampf(t / 0.7, 0.0, 1.0)
		var p := hand.lerp(aim, k) + Vector2(0, -sin(k * PI) * 90.0)
		_ring(ci, p, lerpf(1.3, 1.0, k), t * 14.0)
	if phase == "aim":
		if dragging and drag_to.distance_to(drag_from) > 8.0:
			var target := _predict()
			var pts := PackedVector2Array()
			for i in range(11):
				var k := i / 10.0
				pts.append(hand.lerp(target, k) + Vector2(0, -sin(k * PI) * 90.0))
			for i in range(0, pts.size() - 1, 2):
				ci.draw_line(pts[i], pts[i + 1], Color(ci.PAPER, 0.8), 2.0)
			ci.draw_arc(target, 10, 0, TAU, 20, ci.GOLD, 2.0)
			ci.draw_line(drag_from, drag_to, Color(ci.PAPER, 0.5), 2.0)
		else:
			_ring(ci, hand, 1.2, 0.0)
			var a := 0.6 + 0.4 * sin(t * 4.0)
			var k2 := fmod(t, 1.4) / 1.4
			var p0 := Vector2(180, 560) + Vector2(0, 40) * k2
			ci.draw_circle(p0, 9, Color(ci.PAPER, a))
			ci.draw_line(Vector2(180, 560), Vector2(180, 600), Color(ci.PAPER, 0.4 * a), 2.0)
		if thrown >= 1:
			ci.pill(_continue_rect(), ci.t_("G-19"), 16, ci.RED, ci.PAPER)
	if hit_flash > 0.0:
		ci.draw_rect(Rect2(0, 0, 360, 640), Color(1, 0.9, 0.5, hit_flash * 0.15))


func _placeholder_stall(ci) -> void:
	ci.draw_rect(Rect2(96, 190, 168, 92), Color("#c08a4e"))
	ci.draw_rect(Rect2(96, 190, 168, 92), Color("#50332a"), false, 2.0)
	ci.draw_rect(Rect2(90, 140, 180, 22), Color("#d84b4b"))
	for i in range(9):
		ci.draw_rect(Rect2(90 + i * 20, 140, 10, 22), Color("#fff1d5"))
	ci.draw_rect(Rect2(92, 162, 6, 120), Color("#50332a"))
	ci.draw_rect(Rect2(262, 162, 6, 120), Color("#50332a"))


func _peg(ci, p: Vector2, lit: bool) -> void:
	var tex: Texture2D = ci.texture("w2/hainan/peg.png")
	if tex:
		var sz: Vector2 = tex.get_size() * ci.S
		ci.draw_texture_rect(tex, Rect2(p - Vector2(sz.x * 0.5, sz.y), sz), false)
	else:
		ci.draw_rect(Rect2(p + Vector2(-3, -18), Vector2(6, 18)), Color("#6b4a2c"))
		ci.draw_circle(p + Vector2(0, -20), 6, Color("#f4d495") if not lit else Color("#ffe27a"))
	if lit:
		ci.draw_arc(p + Vector2(0, -10), 14, 0, TAU, 20, Color(1, 0.9, 0.5, 0.7), 2.0)


func _ring(ci, p: Vector2, s: float, spin: float) -> void:
	var tex: Texture2D = ci.texture("w2/hainan/ring_fly_1.png")
	if tex:
		var sz: Vector2 = tex.get_size() * ci.S * s
		ci.draw_texture_rect(tex, Rect2(p - sz * 0.5, sz), false)
		return
	var w := 12.0 * s
	var h := 5.0 * s * (0.6 + 0.4 * absf(cos(spin)))
	var pts := PackedVector2Array()
	for i in range(17):
		var a := TAU * i / 16.0
		pts.append(p + Vector2(cos(a) * w, sin(a) * h))
	ci.draw_polyline(pts, Color("#e0403a"), 3.0)
