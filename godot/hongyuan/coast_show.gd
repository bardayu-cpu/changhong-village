extends RefCounted
## A continuous seaside memory, not a click/count minigame. The saved scene
## clock drives identical bursts and reflections after reloading.
const COLORS := [Color("#ffd281"), Color("#ff8b97"), Color("#a4d7ff")]
const TYPES := ["gold", "red", "blue"]
const BURSTS := [
	[0.0, Vector2(76, 146), 0, 116.0], [0.85, Vector2(270, 102), 1, 138.0],
	[1.65, Vector2(174, 210), 2, 146.0], [2.55, Vector2(104, 77), 0, 138.0],
	[3.4, Vector2(268, 236), 2, 112.0], [4.3, Vector2(181, 123), 1, 166.0],
	[5.2, Vector2(61, 235), 2, 103.0], [6.0, Vector2(278, 157), 0, 144.0],
	[6.7, Vector2(174, 65), 0, 129.0], [7.45, Vector2(101, 275), 1, 115.0],
	[8.1, Vector2(243, 267), 2, 128.0], [8.65, Vector2(182, 172), 0, 184.0],
]

static func draw(ci, elapsed: float) -> void:
	var clock := fmod(elapsed, 11.6)
	var flash := 0.0
	for entry: Array in BURSTS:
		var age: float = clock - float(entry[0])
		if age < 0 or age > 2.8: continue
		var at: Vector2 = entry[1]
		var color: Color = COLORS[entry[2]]
		if age < 0.5:
			var a := Vector2(at.x + 12, 370)
			var head := a.lerp(at, ease(age / 0.5, 0.65))
			var tail := a.lerp(at, maxf(0, ease(age / 0.5, 0.65) - 0.12))
			ci.draw_line(tail, head, Color(color, 0.65), 1.2)
			ci.draw_circle(head, 1.4, color)
			continue
		var bloom := age - 0.5
		var frame := clampi(1 + int(bloom / 0.34), 1, 5)
		var texture: Texture2D = ci.texture("w2/hainan/firework_%s_%d.png" % [TYPES[entry[2]], frame])
		var alpha := minf(1, (2.3 - bloom) / 0.9)
		var size: float = entry[3] * lerpf(0.5, 1.15, clampf(bloom / 1.7, 0, 1))
		if texture:
			ci.draw_texture_rect(texture, Rect2(at - Vector2.ONE * size * 0.5, Vector2.ONE * size), false, Color(1, 1, 1, alpha))
		# Dense sparkling trails surround the existing five-frame blossom art.
		var radius := float(entry[3]) * 0.46 * (1.0 - exp(-bloom * 2.5))
		for ray in range(56):
			var angle := TAU * ray / 56.0 + float(entry[0])
			var length_k := 0.76 + 0.24 * sin(ray * 2.43 + float(entry[0]))
			for tail in range(3):
				var radius_k := radius * length_k * (1.0 - tail * 0.065)
				var point := at + Vector2(cos(angle), sin(angle)) * radius_k + Vector2(0, bloom * bloom * 8)
				var a := alpha * (1.0 - tail * 0.25) * (0.75 + 0.25 * sin(elapsed * 22 + ray))
				ci.draw_rect(Rect2(point, Vector2(1.5, 1.5)), Color(color.lerp(Color.WHITE, 0.4 if tail == 0 else 0.0), a))
		flash = maxf(flash, maxf(0, 1.0 - bloom / 0.25))
		for j in range(10):
			var y := 384.0 + j * 4.1
			var x := at.x + sin(elapsed * 1.8 + j * 1.7) * 8
			var w := (10 + j * 2.0) * alpha
			ci.draw_line(Vector2(x - w, y), Vector2(x + w, y), Color(color, alpha * 0.11), 1.5)
	# Gentle moving glints remain visible between the bursts.
	for j in range(8):
		var x := 38 + j * 38.0 + sin(elapsed * 0.6 + j) * 5
		var y := 401 + sin(elapsed * 0.8 + j * 1.6) * 8
		ci.draw_line(Vector2(x, y), Vector2(x + 17, y), Color(1, 0.86, 0.7, 0.10), 1)
	if flash > 0: ci.draw_rect(Rect2(0, 0, 360, 640), Color(1, 0.9, 0.7, flash * 0.025))
