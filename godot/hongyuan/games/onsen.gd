extends RefCounted
## 浦岛酒店温泉：夕阳 → 黄昏 → 星夜。玩家先点他旁边的位置，阿鱼滑过去；
## 然后每点一下说一句（头顶气泡），天色随对白慢慢暗下来，结尾留一会儿星空。
const StoryCaption := preload("res://hongyuan/ui/story_caption.gd")
const BG := ["w2/shizuoka/bg_onsen_sunset.png", "w2/shizuoka/bg_onsen_dusk_r2.png", "w2/shizuoka/bg_onsen_night_r2.png"]
const AYU_TEX := "w2/shizuoka/ayu_onsen_r2.png"
const TORETTO_TEX := "w2/shizuoka/toretto_onsen_r2.png"
# 透明图里真正有像素的范围（素材清单），透明边不参与比例
const AYU_USED := Rect2(447, 277, 416, 509)
const TORETTO_USED := Rect2(392, 62, 745, 850)
const AYU_H := 58.0
const TORETTO_H := 66.0
const WATER_Y := 438.0   # 人物下沿 = 池水线
const TORETTO_X := 238.0
const SPOT_X := 176.0
const START_X := 78.0
const NIGHT_HOLD := 1.5
const STEAM := [Vector2(34, 392), Vector2(322, 384), Vector2(110, 352), Vector2(252, 356), Vector2(180, 372)]

var r
var phase := "enter"   # enter → join → glide → talk → outro → done
var t := 0.0
var li := 0
var reveal := 0.0
var lines: Array = []
var ayu_x := START_X
var sky_s := 0.0
var _stars: Array = []
var _guest_textures: Dictionary = {}


func start(runner, beat: Dictionary) -> void:
	r = runner
	lines = beat.get("lines", [])
	r.hint = ""
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in range(46):
		_stars.append({"p": Vector2(rng.randf_range(8, 352), rng.randf_range(24, 232)), "ph": rng.randf() * TAU, "sp": rng.randf_range(1.4, 3.4), "big": i % 5 == 0})


func _world_transform() -> Transform2D:
	var full: Rect2 = r.view_rect
	var k := maxf(full.size.x / 360.0, full.size.y / 640.0)
	return Transform2D(Vector2(k, 0), Vector2(0, k), full.get_center() - Vector2(360,640) * k * 0.5)

func _spot() -> Rect2:
	return _world_transform() * Rect2(SPOT_X - 46, WATER_Y - 66, 92, 100)


func _target_sky() -> float:
	if phase in ["enter", "join", "glide"]:
		return 0.0
	if phase in ["outro", "done"]:
		return 2.0
	return clampf(float(li) / maxf(1.0, float(lines.size() - 1)) * 2.0, 0.0, 2.0)


func _text() -> String:
	return r.t_(str(lines[li].get("say", ""))) if li < lines.size() else ""


func process(dt: float) -> bool:
	t += dt
	sky_s = move_toward(sky_s, _target_sky(), dt * 0.55)
	match phase:
		"enter":
			if t >= 2.5:
				phase = "join"
				t = 0.0
				r.hint = r.t_("A4-P3")
		"glide":
			var k := clampf(t / 1.1, 0.0, 1.0)
			ayu_x = lerpf(START_X, SPOT_X, k * k * (3.0 - 2.0 * k))
			if k >= 1.0:
				phase = "talk"
				t = 0.0
				reveal = 0.0
				r.hint = ""
		"talk":
			reveal = minf(reveal + dt * 22.0, float(_text().length()))
		"outro":
			if t >= NIGHT_HOLD and sky_s >= 1.99:
				phase = "done"
	return phase == "done"


func input(kind: String, pos: Vector2) -> void:
	if kind != "tap":
		return
	match phase:
		"join":
			if _spot().grow(14).has_point(pos):
				phase = "glide"
				t = 0.0
				r.hint = ""
				r.play("blip")
		"talk":
			if t < 0.15:
				return
			if reveal < _text().length():
				reveal = _text().length()
				return
			li += 1
			t = 0.0
			reveal = 0.0
			if li >= lines.size():
				phase = "outro"
			else:
				r.play("blip")


func skip() -> void:
	phase = "done"
	li = lines.size()
	sky_s = 2.0
	ayu_x = SPOT_X
	r.hint = ""


# ---------- 画 ----------

func draw(ci) -> void:
	var full: Rect2 = ci.view_rect
	ci.draw_rect(full, Color.BLACK)
	for i in range(3):
		var tex: Texture2D = ci.texture(BG[i])
		if not tex:
			continue
		var a := 1.0 if i == 0 else clampf(sky_s - (i - 1), 0.0, 1.0)
		if a > 0.0:
			var size := tex.get_size() * maxf(full.size.x / tex.get_width(), full.size.y / tex.get_height())
			ci.draw_texture_rect(tex, Rect2(full.get_center()-size*0.5,size), false, Color(1, 1, 1, a))
	var xf := _world_transform()
	ci.draw_set_transform_matrix(xf)
	_draw_stars(ci)
	_draw_foam(ci)
	_draw_steam(ci, 0.0)
	var warm := clampf(1.0 - sky_s, 0.0, 1.0)
	var tint := Color(0.78, 0.74, 0.86).lerp(Color(1.0, 0.86, 0.74), warm)
	tint = tint.lerp(Color(0.52, 0.56, 0.78), clampf(sky_s - 1.0, 0.0, 1.0))
	_draw_guests(ci, tint)
	if phase != "enter":
		_draw_person(ci, TORETTO_TEX, TORETTO_USED, TORETTO_X, TORETTO_H, tint, 0.0)
		_draw_person(ci, AYU_TEX, AYU_USED, ayu_x, AYU_H, tint, 1.3)
		_draw_water_line(ci, TORETTO_X, 30.0, 0.0)
		_draw_water_line(ci, ayu_x, 27.0, 1.3)
	else:
		_draw_arrival(ci)
		ci.draw_set_transform_matrix(xf)
	_draw_steam(ci, 1.0)
	if phase == "join":
		_draw_spot(ci)
	ci.draw_set_transform(Vector2.ZERO)
	if phase == "join" and t < 0.35: ci.draw_rect(ci.view_rect,Color(0.04,0.05,0.08,1-t/0.35))
	if phase == "enter":
		StoryCaption.draw_caption(ci, "日本 · 浦岛酒店", "narrator")
	elif phase == "talk" and li < lines.size():
		_draw_bubble(ci)


func _bob(phase_shift: float) -> float:
	return sin(r.time * 1.6 + phase_shift) * 0.8


func _draw_person(ci, name: String, used: Rect2, x: float, h: float, tint: Color, shift: float) -> void:
	var tex: Texture2D = ci.texture(name)
	if not tex:
		ci.draw_rect(Rect2(x - 20, WATER_Y - h, 40, h), Color("#6b3fa0"))
		return
	var k := h / used.size.y
	var w := used.size.x * k
	var y := WATER_Y + _bob(shift)
	ci.draw_texture_rect_region(tex, Rect2(x - w * 0.5, y - h, w, h), used, tint)


func _head_anchor(who: String) -> Vector2:
	if who == "toretto":
		return _world_transform() * Vector2(TORETTO_X, WATER_Y - TORETTO_H)
	if who == "ayu":
		return _world_transform() * Vector2(ayu_x, WATER_Y - AYU_H)
	return Vector2(-1, -1)


func _draw_water_line(ci, x: float, half: float, shift: float) -> void:
	# 池水盖住身体下沿：半透明水带 + 轻晃的高光线 + 往外扩的涟漪
	var wob: float = r.time * 2.2 + shift
	var top := WATER_Y - 4.0
	var pts := PackedVector2Array()
	var n := 10
	for i in range(n + 1):
		var px := x - half - 4.0 + (half * 2.0 + 8.0) * i / n
		pts.append(Vector2(px, top + sin(wob + i * 0.9) * 1.2))
	var poly := PackedVector2Array(pts)
	poly.append(Vector2(x + half + 4.0, WATER_Y + 12.0))
	poly.append(Vector2(x - half - 4.0, WATER_Y + 12.0))
	var deep := Color(0.10, 0.42, 0.52, 0.78).lerp(Color(0.06, 0.16, 0.36, 0.82), clampf(sky_s, 0.0, 2.0) * 0.5)
	ci.draw_colored_polygon(poly, deep)
	ci.draw_polyline(pts, Color(1, 1, 1, 0.5), 1.0)
	for i in range(2):
		var k: float = fposmod(r.time * 0.45 + shift * 0.3 + i * 0.5, 1.0)
		var rx := half + 6.0 + k * 22.0
		var pr := PackedVector2Array()
		for j in range(25):
			var a := TAU * j / 24.0
			pr.append(Vector2(x + cos(a) * rx, WATER_Y + 4.0 + sin(a) * rx * 0.2))
		ci.draw_polyline(pr, Color(1, 1, 1, 0.38 * (1.0 - k)), 1.0)


func _draw_foam(ci) -> void:
	# 池沿外侧的海浪：4 相位循环，像素短浪线和小弧。
	var f := int(r.time / 0.32) % 4
	var rim := 300.0
	var col := Color(1, 1, 1, 0.62 - 0.22 * clampf(sky_s - 1.0, 0.0, 1.0))
	for row in range(3):
		var y: float = rim - 2.0 - row * 5.0 + [0.0, 1.0, 2.0, 1.0][(f + row) % 4]
		var step := 38.0
		for i in range(-1, 11):
			var x0 := i * step + (f * 6.0 + row * 13.0)
			x0 = fposmod(x0, 400.0) - 20.0
			var len := 14.0 + 6.0 * ((i + row) % 3)
			if (i + row + f) % 5 == 0:
				continue
			ci.draw_rect(Rect2(roundf(x0), roundf(y), len, 2), col)
			ci.draw_rect(Rect2(roundf(x0 + 3), roundf(y - 2), len - 8, 2), Color(col, col.a * 0.7))
	# 拍到池沿时溅起的小水点
	var splash: float = [0.0, 0.5, 1.0, 0.5][f]
	for i in range(7):
		var x := 36.0 + i * 46.0 + (i % 2) * 9.0
		ci.draw_rect(Rect2(roundf(x), roundf(rim - 6.0 - splash * 4.0 * ((i + f) % 3)), 2, 2), Color(1, 1, 1, 0.5 * splash + 0.1))


func _draw_steam(ci, layer: float) -> void:
	for i in range(STEAM.size() * 3):
		var src: Vector2 = STEAM[i % STEAM.size()]
		if (i / STEAM.size()) % 2 != int(layer):
			continue
		var k: float = fposmod(r.time * 0.12 + i * 0.173, 1.0)
		var rx: float = src.x + sin(r.time * 0.7 + i * 1.7) * 8.0 + (i % 3 - 1) * 9.0
		var ry := src.y - k * 82.0
		var a := sin(k * PI) * 0.2
		var rad := 7.0 + k * 13.0
		ci.draw_circle(Vector2(rx, ry), rad, Color(1, 1, 1, a))
		ci.draw_circle(Vector2(rx + rad * 0.5, ry + 3.0), rad * 0.7, Color(1, 1, 1, a * 0.8))


func _draw_stars(ci) -> void:
	var night := clampf(sky_s - 1.0, 0.0, 1.0)
	if night <= 0.0:
		return
	for s: Dictionary in _stars:
		var tw: float = 0.5 + 0.5 * sin(r.time * float(s.sp) + float(s.ph))
		var p: Vector2 = s.p
		var a := night * (0.25 + 0.75 * tw)
		ci.draw_rect(Rect2(roundf(p.x), roundf(p.y), 2, 2), Color(1, 0.98, 0.85, a))
		if bool(s.big) and tw > 0.55:
			ci.draw_rect(Rect2(roundf(p.x) - 2, roundf(p.y) + 0.5, 6, 1), Color(1, 1, 0.9, a * 0.8))
			ci.draw_rect(Rect2(roundf(p.x) + 0.5, roundf(p.y) - 2, 1, 6), Color(1, 1, 0.9, a * 0.8))


func _draw_spot(ci) -> void:
	var c := Vector2(SPOT_X, WATER_Y - 6.0)
	var a: float = 0.55 + sin(r.time * 4.5) * 0.25
	var pts := PackedVector2Array()
	var rx: float = 24.0 + sin(r.time * 4.5) * 3.0
	for j in range(25):
		var ang := TAU * j / 24.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * rx * 0.32))
	ci.draw_polyline(pts, Color(1.0, 0.92, 0.65, a), 2.0)
	ci.draw_circle(c, 4.0, Color(1.0, 0.92, 0.65, a))
	var by: float = c.y - 32.0 + sin(r.time * 5.0) * 3.0
	ci.draw_colored_polygon(PackedVector2Array([Vector2(c.x - 8, by), Vector2(c.x + 8, by), Vector2(c.x, by + 11)]), Color(1.0, 0.92, 0.65, 0.9))


func _draw_bubble(ci) -> void:
	var line: Dictionary = lines[li]
	var who := str(line.get("who", "narrator"))
	var text := _text()
	var shown := int(reveal)
	var done := reveal >= text.length()
	StoryCaption.draw_caption(ci, text, who, shown, false, _head_anchor(who))
	if done:
		var box := StoryCaption.caption_rect(text, who, _head_anchor(who))
		var by: float = box.end.y - 12.0 + sin(r.time * 6.0) * 1.5
		var bx := box.end.x - 16.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(bx - 5, by - 4), Vector2(bx + 5, by - 4), Vector2(bx, by + 3)]), ci.WOOD)


func _draw_arrival(ci) -> void:
	# The full bodies stay on the dry foreground stone; the cut into the pool is
	# a short dip-to-black, avoiding clothed legs sliding through the water.
	var xf := _world_transform()
	var k := smoothstep(0, 1, clampf(t / 2.1, 0, 1))
	for i in range(2):
		var at := Vector2(126 + i * 70, lerpf(657, 552, k))
		var name: String = "w2/common/ayu_walk_back_%d.png" % (1 + int(t * 6) % 4) if i == 0 else "w2/common/toretto_back_r2.png"
		var tex: Texture2D = ci.texture(name)
		if tex:
			var used: Rect2 = ci.WorldScale.visible_rect(tex)
			var h := 116.0 + i * 6
			var size := used.size * (h / used.size.y)
			ci.draw_texture_rect_region(tex, Rect2(at - Vector2(size.x * 0.5, size.y), size), used)
	var fade := clampf((t - 2.1) / 0.4, 0, 1)
	if fade > 0:
		ci.draw_set_transform(Vector2.ZERO)
		ci.draw_rect(ci.view_rect,Color(0.04,0.05,0.08,fade))
		ci.draw_set_transform_matrix(xf)

func _draw_guests(ci, tint: Color) -> void:
	# Distinct background bathers: only heads and shoulders, with no trouser or
	# standing-body silhouette in the water. These use the existing guest atlas.
	var positions := [Vector2(48,391),Vector2(91,367),Vector2(270,376),Vector2(302,404)]
	var ids := ["02","06","09","11"]
	for i in range(4):
		var path := "res://assets/characters/lm/chr_LM-GUEST-%s.png" % ids[i]
		if not _guest_textures.has(path):
			_guest_textures[path] = load(path) if ResourceLoader.exists(path) else null
		var tex: Texture2D = _guest_textures[path]
		if not tex: continue
		# 12 is the rear-view pose. A short side glance every few seconds gives
		# the group a different rhythm without having them pace through a pool.
		var frame := 12 if fmod(r.time + i * 2.3, 9.0) < 7.4 else (4 if i < 2 else 8)
		var source := Rect2(frame * 64 + 14, 0, 36, 34)
		var at: Vector2 = positions[i] + Vector2(0,sin(r.time*1.2+i)*0.6)
		var h := 21.0 + (i % 2) * 3
		var size := source.size * (h / source.size.y)
		ci.draw_texture_rect_region(tex,Rect2(at-Vector2(size.x*0.5,h),size),source,tint)
		ci.draw_rect(Rect2(at.x-size.x*0.6,at.y-2,size.x*1.2,6),Color(0.12,0.4,0.47,0.82))
		var points := PackedVector2Array()
		for j in range(17):
			var a := TAU * j/16.0
			points.append(at+Vector2(cos(a)*(size.x*0.7+3),sin(a)*2.8))
		ci.draw_polyline(points,Color(0.8,0.9,0.9,0.35),1)
