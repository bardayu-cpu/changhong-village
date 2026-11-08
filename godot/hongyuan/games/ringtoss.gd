extends RefCounted
## 套圈：往后拖动瞄准（像拉弹弓），松手投出。落点套中木桩就挂上去，没中就落在地上。
## 两人轮流各投两次，四次后自动往下走。不要求全中，没有奖品。

# R2: 300×220 源图的五根木桩颈部，绘制和命中共用同一变换。
const STALL_ORIGIN := Vector2(80, 385 - 220.0 * 2.0 / 3.0)
const PEG_PIXELS := [Vector2(73, 90), Vector2(112, 90), Vector2(150, 90), Vector2(188, 90), Vector2(226, 90)]
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
var turn := 0
var auto_t := 0.0
var rings: Array = []   # {at, peg}
var hit_flash := 0.0


func start(runner, beat: Dictionary) -> void:
	r = runner
	for p: Vector2 in PEG_PIXELS:
		pegs.append(STALL_ORIGIN + p * r.S)
	if beat.has("pegs"):
		pegs.clear()
		for p: Array in beat.pegs:
			pegs.append(Vector2(float(p[0]), float(p[1])))
	r.facing = 1.0
	r.comp_pos = r.feet + Vector2(72,-4)
	r.pose = "throw"
	hand = r.feet + Vector2(14, -100) * (r.person_height_at(r.feet.y) / 128.0)


func process(dt: float) -> bool:
	t += dt
	hand = (r.feet if turn % 2 == 0 else r.comp_pos) + Vector2(14,-92) * (r.person_height_at(r.feet.y)/128.0)
	if phase == "auto_aim" and t >= 0.9:
		aim = pegs[turn % pegs.size()] + Vector2(8,3)
		phase = "fly";t = 0;thrown += 1;r.play("blip")
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
				if thrown >= 4:
					r.pose = ""
					return true
				turn += 1
				phase = "aim" if turn % 2 == 0 else "auto_aim"
				t = 0.0
	return false


func _predict() -> Vector2:
	var pull := drag_to - drag_from
	var p := hand - pull * 1.6
	return Vector2(clampf(p.x, 40, 320), clampf(p.y, 160, 420))


func _continue_rect() -> Rect2:
	return Rect2(250, 580, 92, 40)


func input(kind: String, pos: Vector2) -> void:
	if phase != "aim":
		return
	if kind == "down":
		dragging = true
		drag_from = pos
		drag_to = pos
	elif kind == "move" and dragging:
		drag_to = pos
	elif kind == "up" and dragging:
		dragging = false
		var short := drag_to.distance_to(drag_from) <= 18.0
		if short and pos.y < 460.0:
			# 点一下目标也能扔：泳圈飞向点的位置
			drag_to = drag_from
			aim = Vector2(clampf(pos.x, 40, 320), clampf(pos.y, 160, 420))
			phase = "fly"
			t = 0.0
			thrown += 1
			r.play("blip")
		elif not short:
			aim = _predict()
			phase = "fly"
			t = 0.0
			thrown += 1
			r.play("blip")


func draw(ci) -> void:
	ci.pill(Rect2(72,92,216,30),"轮到阿鱼了" if turn % 2 == 0 else "轮到 Toretto 了",15,Color(ci.WOOD,0.76),ci.PAPER)
	for i in range(pegs.size()):
		var lit := false
		for ring: Dictionary in rings:
			if ring.peg and ring.at == pegs[i]:
				lit = true
		_peg(ci, pegs[i], lit)
	for ring: Dictionary in rings:
		var roll := Vector2.ZERO
		if not ring.peg:
			var k := clampf(t / 0.6, 0, 1) if phase == "land" and ring == rings.back() else 1.0
			roll = Vector2(12 * signf(ring.at.x - 180 + 0.01) * k, -sin(k * PI) * 8 + 6 * k)
		_ring(ci, ring.at + roll, 1.0, t if not ring.peg else 0.0)
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

	if phase == "aim" and thrown == 0 and not dragging:
		ci.pill(Rect2(40, 140, 280, 36), ci.t_("G-RING-HOW"), 15, Color(ci.INK, 0.86), ci.PAPER)
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
	var bob := Vector2(0,sin(ci.time*1.4+p.x)*1.5)
	var at := p+bob
	var color := Color("#ffd06c") if int(p.x)%2==0 else Color("#d6a4d7")
	# Small floating toys in the actual pool, no market stall or prize counter.
	ci.draw_arc(at+Vector2(0,5),13,0,TAU,20,Color(0.85,1,1,0.35),1)
	ci.draw_circle(at+Vector2(0,-2),8,color)
	ci.draw_circle(at+Vector2(5,-9),5,color)
	ci.draw_colored_polygon(PackedVector2Array([at+Vector2(8,-10),at+Vector2(15,-8),at+Vector2(8,-6)]),Color("#de8750"))
	ci.draw_rect(Rect2(at+Vector2(6,-11),Vector2(1.5,1.5)),ci.INK)
	if lit:ci.draw_arc(at,14,0,TAU,20,Color(1,0.9,0.5,0.7),2)


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

func companion_frame() -> String:
	return "w2/common/toretto_cheer.png" if turn % 2 == 1 and phase in ["fly","land"] else "w2/common/toretto_neutral_r2.png"


func restore_checkpoint() -> void:
	dragging = false
	if absf(r.comp_pos.x-r.feet.x) < 55.0:
		r.comp_pos = r.feet + Vector2(72,-4)
