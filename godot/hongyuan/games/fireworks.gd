extends RefCounted
## 文昌烟花：点天空哪里，哪里就开一朵（没有火箭升空）。放够几朵后，最后一朵自动在正中绽放，
## 再收拢凝成一颗火漆。

const COLORS := [Color("#ff6a5a"), Color("#ffd36a"), Color("#7fc8ff"), Color("#ff9ad5"), Color("#b6ff8a")]

var r
var t := 0.0
var bursts: Array = []
var count := 0
var need := 5
var phase := "play"   # play → finale → wax → done
var finale_t := 0.0
var rng := RandomNumberGenerator.new()


func start(runner, beat: Dictionary) -> void:
	r = runner
	need = int(beat.get("count", 5))
	rng.seed = Time.get_ticks_usec()


func _burst(at: Vector2, color: Color, big := false) -> void:
	var parts: Array = []
	var n := 36 if big else 22
	for i in range(n):
		var a := TAU * i / n + rng.randf_range(-0.08, 0.08)
		parts.append(Vector2(cos(a), sin(a)) * rng.randf_range(0.75, 1.0) * (120.0 if big else 70.0))
	bursts.append({"at": at, "c": color, "t": 0.0, "parts": parts, "big": big})
	r.play("pop")


func process(dt: float) -> bool:
	t += dt
	for b: Dictionary in bursts:
		b.t += dt
	bursts = bursts.filter(func(b: Dictionary) -> bool: return b.t < 2.0 or (b.big and phase != "play"))
	match phase:
		"play":
			if t > 10.0 and count >= 2:
				count = need
			if count >= need:
				phase = "finale"
				finale_t = 0.0
		"finale":
			finale_t += dt
			if finale_t > 0.8 and bursts.filter(func(b: Dictionary) -> bool: return b.big).is_empty():
				_burst(Vector2(180, 230), Color("#ff5a4a"), true)
			if finale_t > 2.0:
				phase = "wax"
				finale_t = 0.0
		"wax":
			finale_t += dt
			if finale_t > 2.4:
				return true
	return false


func input(kind: String, pos: Vector2) -> void:
	if phase == "play" and kind == "down" and pos.y < 440:
		count += 1
		_burst(pos, COLORS[count % COLORS.size()])


func draw(ci) -> void:
	for b: Dictionary in bursts:
		var k := clampf(b.t / 1.2, 0.0, 1.0)
		var ease := 1.0 - pow(1.0 - k, 3.0)
		var fade := clampf(1.6 - b.t, 0.0, 1.0)
		if b.big and phase == "wax":
			# 收拢：所有火花往中心聚，凝成火漆
			var w := clampf(finale_t / 1.4, 0.0, 1.0)
			ease = lerpf(1.0, 0.0, w * w)
			fade = 1.0
		var c: Color = b.c
		for p: Vector2 in b.parts:
			var pos: Vector2 = b.at + p * ease + Vector2(0, 30.0 * k * k) * (0.0 if b.big and phase == "wax" else 1.0)
			c.a = fade
			ci.draw_rect(Rect2(pos.round(), Vector2(3, 3)), c)
			if k < 0.6:
				ci.draw_rect(Rect2((b.at + p * ease * 0.8).round(), Vector2(2, 2)), Color(1, 1, 0.9, fade * 0.6))
	if phase == "wax":
		var w2 := clampf((finale_t - 1.0) / 0.8, 0.0, 1.0)
		if w2 > 0.0:
			var at := Vector2(180, 230)
			var wax: Texture2D = ci.texture("w2/hainan/firework_wax_4.png")
			if wax:
				var sz: Vector2 = wax.get_size() * ci.S
				ci.draw_texture_rect(wax, Rect2(at - sz * 0.5, sz), false, Color(1, 1, 1, w2))
			else:
				ci.draw_circle(at, 26 * w2, Color("#9e1b1b"))
				ci.draw_circle(at, 19 * w2, Color("#c23a2a"))
				ci.draw_arc(at, 13 * w2, 0, TAU, 20, Color("#7d1414"), 2.0)
				ci.draw_circle(at + Vector2(-8, -8) * w2, 4 * w2, Color(1, 0.75, 0.65, 0.7))
	if phase == "play" and count == 0:
		var a := 0.6 + 0.4 * sin(t * 5.0)
		var p0 := Vector2(180, 220)
		ci.draw_arc(p0, 14 + fmod(t * 20.0, 14.0), 0, TAU, 24, Color(ci.PAPER, a * 0.6), 2.0)
		ci.draw_circle(p0, 8, Color(ci.PAPER, a))
