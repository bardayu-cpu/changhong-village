extends RefCounted
## 码头短钓：按住蓄力，松手甩竿；等 2～4 秒浮标下沉，点「收！」。错过了浮标回来，再甩一次，不计次数。

var r
var phase := "aim"   # aim → fly → wait → bite → caught
var t := 0.0
var power := 0.0
var holding := false
var bob := Vector2.ZERO
var from := Vector2.ZERO
var wait_for := 3.0
var rng := RandomNumberGenerator.new()
var fish_t := 0.0
var missed := false


func start(runner, _beat: Dictionary) -> void:
	r = runner
	rng.seed = Time.get_ticks_usec()
	r.pose = "fishing"
	r.facing = 1.0


func _tip() -> Vector2:
	return r.feet + Vector2(26 * r.facing, -118)


func process(dt: float) -> bool:
	t += dt
	match phase:
		"aim":
			if holding:
				power = fmod(power + dt * 0.9, 2.0)
		"fly":
			var k := clampf(t / 0.6, 0.0, 1.0)
			bob = from.lerp(_landing(), k) + Vector2(0, -sin(k * PI) * 70.0)
			if k >= 1.0:
				phase = "wait"
				t = 0.0
				wait_for = rng.randf_range(2.0, 4.0)
				r.play("blip")
		"wait":
			if t >= wait_for:
				phase = "bite"
				t = 0.0
				r.play("blip")
		"bite":
			if t >= 1.8:
				phase = "aim"
				missed = true
				power = 0.0
				t = 0.0
		"caught":
			fish_t += dt
			if fish_t >= 1.6:
				r.pose = ""
				return true
	return false


func _p() -> float:
	return power if power <= 1.0 else 2.0 - power


func _landing() -> Vector2:
	return Vector2(r.feet.x + 40 + _p() * 60.0, r.feet.y - 70 - _p() * 150.0)


func input(kind: String, pos: Vector2) -> void:
	match phase:
		"aim":
			if kind == "down":
				holding = true
				power = 0.0
				missed = false
			elif kind == "up" and holding:
				holding = false
				phase = "fly"
				t = 0.0
				from = _tip()
				r.play("blip")
		"bite":
			if kind == "down":
				phase = "caught"
				t = 0.0
				fish_t = 0.0
				r.play("pop")
		"wait":
			if kind == "down" and t > 0.4:
				# 太早收了：浮标回来，再来一次
				phase = "aim"
				missed = true
				power = 0.0


func draw(ci) -> void:
	var tip := _tip()
	if phase in ["fly", "wait", "bite"]:
		var b := bob
		if phase == "wait":
			b = _landing() + Vector2(0, sin(t * 4.0) * 1.5)
		elif phase == "bite":
			b = _landing() + Vector2(0, 4 + sin(t * 30.0) * 2.0)
		_line(ci, tip, b)
		_bobber(ci, b, phase == "bite")
		if phase != "fly":
			ci.draw_arc(b + Vector2(0, 4), 10 + fmod(t * 8.0, 8.0), 0, TAU, 20, Color(1, 1, 1, 0.35), 1.0)
	if phase == "caught":
		var k := clampf(fish_t / 0.9, 0.0, 1.0)
		var p := _landing().lerp(r.feet + Vector2(-34, -20), k) + Vector2(0, -sin(k * PI) * 90.0)
		_line(ci, tip, p)
		var fish: Texture2D = ci.texture("w2/shizuoka/fish.png")
		if fish:
			var sz: Vector2 = fish.get_size() * ci.S
			ci.draw_texture_rect(fish, Rect2(p - sz * 0.5, sz), false)
		else:
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-14, 0), p + Vector2(0, -7), p + Vector2(12, 0), p + Vector2(0, 7)]), Color("#9fb7c9"))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(12, 0), p + Vector2(20, -6), p + Vector2(20, 6)]), Color("#7d97ab"))
			ci.draw_rect(Rect2(p + Vector2(-9, -2), Vector2(2, 2)), Color("#1d1d1d"))
		if fish_t < 0.5:
			for i in range(6):
				var a := TAU * i / 6.0
				ci.draw_rect(Rect2(_landing() + Vector2(cos(a), sin(a) * 0.5) * fish_t * 50.0, Vector2(3, 3)), Color(1, 1, 1, 1.0 - fish_t * 2.0))
	if phase == "aim":
		var base: Vector2 = r.feet + Vector2(-60, -60)
		ci.draw_rect(Rect2(base, Vector2(12, 70)), Color(ci.INK, 0.8))
		ci.draw_rect(Rect2(base + Vector2(2, 68 - 66 * _p()), Vector2(8, 66 * _p())), ci.GOLD)
		if not holding:
			var a := 0.6 + 0.4 * sin(t * 5.0)
			ci.draw_arc(Vector2(180, 590), 18, 0, TAU, 28, Color(ci.PAPER, a), 3.0)
			ci.draw_circle(Vector2(180, 590), 10, Color(ci.PAPER, a))
	if phase == "bite":
		var pulse := 1.0 + 0.08 * sin(t * 18.0)
		var rect := Rect2(Vector2(180, 560) - Vector2(60, 26) * pulse, Vector2(120, 52) * pulse)
		ci.pill(rect, ci.t_("A4-P2"), 24, ci.RED, ci.PAPER)


func _line(ci, a: Vector2, b: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in range(13):
		var k := i / 12.0
		pts.append(a.lerp(b, k) + Vector2(0, sin(k * PI) * 10.0))
	ci.draw_polyline(pts, Color(1, 1, 1, 0.75), 1.0)


func _bobber(ci, p: Vector2, sinking: bool) -> void:
	var tex: Texture2D = ci.texture("w2/shizuoka/bobber_%d.png" % (2 if sinking else 1))
	if tex:
		var sz: Vector2 = tex.get_size() * ci.S
		ci.draw_texture_rect(tex, Rect2(p - sz * 0.5, sz), false)
		return
	ci.draw_rect(Rect2(p + Vector2(-3, -6), Vector2(6, 6)), Color("#d63c3c"))
	if not sinking:
		ci.draw_rect(Rect2(p + Vector2(-3, 0), Vector2(6, 4)), Color("#f5f0e6"))
