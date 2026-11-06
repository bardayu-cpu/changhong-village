extends RefCounted
## 文昌烟花：触点就是绽放中心，三色五帧；最后一朵用四帧凝成火漆。

const COLORS := ["red", "gold", "blue"]
var r
var t := 0.0
var bursts: Array = []
var count := 0
var need := 5
var phase := "play"
var finale_t := 0.0
var color_offset := 0

func start(runner, beat: Dictionary) -> void:
	r = runner
	need = int(beat.get("count", 5))
	color_offset = randi_range(0, 2)

func _burst(at: Vector2, color: String, big := false) -> void:
	bursts.append({"at": at, "color": color, "t": 0.0, "big": big})
	r.play("pop")

func process(dt: float) -> bool:
	t += dt
	for b: Dictionary in bursts:
		b.t += dt
	bursts = bursts.filter(func(b: Dictionary) -> bool: return b.t < 1.6 or b.big)
	match phase:
		"play":
			if count >= need:
				phase = "finale"
				finale_t = 0.0
		"finale":
			finale_t += dt
			if finale_t > 0.8 and bursts.filter(func(b: Dictionary) -> bool: return b.big).is_empty():
				_burst(Vector2(180, 230), "red", true)
			if finale_t > 2.0:
				phase = "wax"
				finale_t = 0.0
		"wax":
			finale_t += dt
			if finale_t > 2.4:
				return true
	return false

func input(kind: String, pos: Vector2) -> void:
	if phase == "play" and kind == "down" and pos.y >= 0 and pos.y < 440:
		_burst(pos, COLORS[(count + color_offset) % COLORS.size()])
		count += 1

func draw(ci) -> void:
	for b: Dictionary in bursts:
		if b.big and phase == "wax":
			continue
		var frame := mini(5, 1 + int(b.t / 0.24))
		var tex: Texture2D = ci.texture("w2/hainan/firework_%s_%d.png" % [b.color, frame])
		if tex:
			var sz: Vector2 = tex.get_size() * ci.S * (1.35 if b.big else 1.0)
			var fade := clampf((1.6 - b.t) / 0.4, 0, 1)
			ci.draw_texture_rect(tex, Rect2(b.at - sz * 0.5, sz), false, Color(1, 1, 1, fade))
	if phase == "wax":
		var frame := mini(4, 1 + int(finale_t / 0.4))
		var wax: Texture2D = ci.texture("w2/hainan/firework_wax_%d.png" % frame)
		if wax:
			var sz: Vector2 = wax.get_size() * ci.S
			ci.draw_texture_rect(wax, Rect2(Vector2(180, 230) - sz * 0.5, sz), false)
	if phase == "play" and count == 0:
		var a := 0.6 + 0.4 * sin(t * 5.0)
		var p0 := Vector2(180, 220)
		ci.draw_arc(p0, 14 + fmod(t * 20.0, 14.0), 0, TAU, 24, Color(ci.PAPER, a * 0.6), 2.0)
		ci.draw_circle(p0, 8, Color(ci.PAPER, a))
