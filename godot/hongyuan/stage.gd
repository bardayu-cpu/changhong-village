extends Control

const CANVAS := Vector2(360, 640)
const ASSET_ROOT := "res://hongyuan/assets/"
const CREAM := Color("#f7ead6")
const PAPER := Color("#fff1d5")
const INK := Color("#583864")
const NIGHT := Color("#121422")
const ACCENT := Color("#e7ad81")
const PHONE := Rect2(22, 65, 316, 559)
const PARKING := [Vector2(103, 392), Vector2(259, 392)]
const STREET_CAR := Vector2(263, 420)
const PANDA := Vector2(111, 445)
const PHONE_HOTSPOT := Vector2(263, 400)
const CAR_DEPTH := 0.89

var manifest: Dictionary
var shot: Dictionary
var materials: Dictionary
var chat_rows: Array[Dictionary] = []
var player_feet := Vector2(96, 456)
var facing := 1.0
var walk_frame := -1
var time := 0.0
var distance := 0.0
var lane := 1.0
var slow := 0.0
var panda_time := 0.0
var save_failed := false
var texture_cache: Dictionary = {}

func _draw() -> void:
	if shot.is_empty():
		return
	var kind: String = shot.type
	var background: String = shot.background
	draw_rect(Rect2(Vector2.ZERO, CANVAS), NIGHT)
	match background:
		"invitation":
			_invitation()
		"road":
			if kind == "drive":
				_road()
			else:
				_line_to_road()
		"night":
			_night()
		"phone":
			_phone()
		_:
			_world(background)
	if save_failed:
		draw_arc(Vector2(336, 29), 6, 0, TAU, 20, Color("#ed8b7e"), 1.5, true)
		draw_line(Vector2(336, 26), Vector2(336, 30), Color("#ed8b7e"), 1.5, true)
		draw_circle(Vector2(336, 33), 0.9, Color("#ed8b7e"))

func _invitation() -> void:
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color("#331b2b"))
	for index in range(12):
		var glow := Color("#a05255")
		glow.a = 0.018
		draw_circle(Vector2(171, 281), 250.0 - index * 16.0, glow)
	round_box(Rect2(26, 130, 308, 295), Color("#1f1423"), 11)
	round_box(Rect2(25, 125, 310, 295), PAPER, 10, Color("#d9a782"))
	round_box(Rect2(35, 135, 290, 275), Color.TRANSPARENT, 6, Color("#d6ab8c"))
	round_box(Rect2(41, 141, 278, 263), Color.TRANSPARENT, 5, Color("#edcfa7"))
	_rosette(Vector2(180, 213), 25.0, Color("#a95c62"))
	draw_line(Vector2(119, 252), Vector2(241, 252), Color("#d9ab87"), 1.0, true)
	for y in [272, 290, 308, 326, 344, 370]:
		draw_line(Vector2(76, y), Vector2(284, y), Color("#dcbfa3"), 1.0, true)

	var pen_progress := 1.0 if materials.get("pen") == "applied" else 0.0
	var ink_progress := 1.0 if materials.get("ink") == "applied" else 0.0
	if shot.type == "material":
		if shot.materialId == "pen":
			pen_progress = clampf((time - 0.55) / 0.9, 0.0, 1.0)
			var tip := Vector2(237, 571).lerp(Vector2(85 + 177 * pen_progress, 342), clampf(time / 0.55, 0.0, 1.0))
			_pen(tip, clampf(time / 0.45, 0.08, 1.0))
		else:
			ink_progress = clampf((time - 0.19) / 1.55, 0.0, 1.0)
	if pen_progress > 0.0:
		var end_x := 85.0 + 177.0 * pen_progress
		draw_line(Vector2(85, 343), Vector2(end_x, 343), Color("#b0717c"), 2.4, true)
		if ink_progress > 0.0:
			var ink_end := lerpf(85.0, end_x, ink_progress)
			for width in [15, 10, 6]:
				draw_line(Vector2(85, 343), Vector2(ink_end, 343), Color(0.34, 0.20, 0.47, 0.15), width, true)
			draw_line(Vector2(85, 343), Vector2(ink_end, 343), INK, 3.4, true)
			draw_line(Vector2(85, 326), Vector2(85 + 162 * ink_progress, 326), Color("#9c7a9e"), 1.0, true)
	if shot.get("effect", "") == "ink_to_chengdu":
		var amount := clampf(time / float(shot.duration), 0.0, 1.0)
		draw_circle(Vector2(263, 343), 560 * amount, Color(0.33, 0.21, 0.36, amount * 0.94), true, -1, true)

func _rosette(center: Vector2, radius: float, tint: Color) -> void:
	for index in range(8):
		var direction := Vector2.RIGHT.rotated(index * TAU / 8.0)
		draw_circle(center + direction * radius * 0.56, radius * 0.33, tint, false, 1.0, true)
	draw_circle(center, radius, tint, false, 1.0, true)
	draw_circle(center, radius * 0.16, tint, true, -1, true)

func _pen(tip: Vector2, length: float) -> void:
	var base := tip + Vector2(47, -53) * length
	draw_line(tip + Vector2(4, -4), base, Color("#2c1f36"), 10.0 * length, true)
	draw_line(tip + Vector2(9, -10), tip + Vector2(25, -28) * length, ACCENT, 7.0 * length, true)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(12, -6) * length, tip + Vector2(6, -13) * length]), ACCENT)

func _line_to_road() -> void:
	_invitation()
	var progress := smoothstep(0.12, 0.92, time / float(shot.duration))
	var wash := NIGHT
	wash.a = progress
	draw_rect(Rect2(Vector2.ZERO, CANVAS), wash)
	var start := Vector2(76, 344).lerp(Vector2(179, 174), progress)
	var finish := Vector2(284, 344).lerp(Vector2(180, 640), progress)
	var width := 1.0 + 32.0 * progress * progress
	draw_line(start, finish, Color("#d8b59c"), width, true)
	draw_colored_polygon(PackedVector2Array([
		start + Vector2(-3, 0), start + Vector2(3, 0),
		finish + Vector2(230 * progress, 0), finish - Vector2(230 * progress, 0)
	]), Color(0.28, 0.25, 0.37, progress))
	draw_line(start, finish, Color("#edceae"), 1.0 + progress * 3.0, true)

func _world(background: String) -> void:
	var backdrop: Dictionary = manifest.get("backgrounds", {}).get(background, {})
	var texture := _texture(str(backdrop.get("file", "")))
	if texture:
		_cover(texture, Rect2(0, 0, 360, 640))
	else:
		draw_rect(Rect2(12, 126, 336, 404), Color("#343247") if background == "chengdu" else Color("#3d3048"))
		round_box(Rect2(18, 132, 324, 392), Color.TRANSPARENT, 9, Color("#685367"))
		draw_line(Vector2(27, 456), Vector2(333, 456), Color("#846977"), 1, true)
	if background == "street":
		_vehicle(STREET_CAR, 115.0, "car")
	elif background == "parking":
		for index in range(int(shot.get("cars", 0))):
			_vehicle(PARKING[index], 99.0, "car")
	if shot.type == "walk":
		_world_hotspots()
	var sorted: Array = shot.visibleActors.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _feet(a).y < _feet(b).y
	)
	for actor: Dictionary in sorted:
		if actor.mode == "sprite" and actor.layer == "world":
			_world_actor(actor)
	_vignette()
	if shot.type == "dialogue":
		var speaker_x := 96.0 if shot.speaker == "ayu" else 264.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(speaker_x, 445), Vector2(speaker_x - 7, 454), Vector2(speaker_x + 7, 454)
		]), ACCENT)

func _world_hotspots() -> void:
	for hotspot: Dictionary in shot.hotspots:
		if hotspot.id == "panda":
			if panda_time <= 0 and not materials.get("panda_used", false):
				_pin(PANDA + Vector2(0, 12))
		elif hotspot.id == "phone":
			round_box(Rect2(PHONE_HOTSPOT - Vector2(14, 21), Vector2(28, 42)), NIGHT, 6, ACCENT)
			round_box(Rect2(PHONE_HOTSPOT - Vector2(9, 15), Vector2(18, 29)), Color("#dba58e"), 3)
			_pin(PHONE_HOTSPOT + Vector2(0, 31))
		elif hotspot.id == "car":
			_pin(STREET_CAR + Vector2(0, 16))
		else:
			_pin(Vector2(264, 459))

func _pin(position: Vector2) -> void:
	var alpha := 0.65 + sin(time * 4.5) * 0.17
	draw_circle(position, 6, Color(1.0, 0.86, 0.7, alpha), true, -1, true)
	draw_circle(position, 11, Color(1.0, 0.86, 0.7, alpha), false, 1.1, true)

func _feet(actor: Dictionary) -> Vector2:
	if actor.id == "ayu":
		return Vector2(96, 456) if shot.type == "dialogue" else player_feet
	if actor.id == "panda":
		return PANDA
	return Vector2(264 if actor.slot == "right" else 96, 456)

func _world_actor(actor: Dictionary) -> void:
	var feet := _feet(actor)
	var key: String = actor.id
	var info: Dictionary = manifest.get("sprites", {}).get(key, {})
	var file: String = info.get("idle", "")
	var frames: Array = info.get("walk", [])
	if key == "ayu" and walk_frame >= 0 and not frames.is_empty():
		file = frames[walk_frame % frames.size()]
	if key == "panda" and panda_time > 0.0:
		file = info.get("action", file)
	var texture := _texture(file)
	if not texture:
		# Missing actors use an unlabelled ground mark; their text card is in a fixed slot.
		draw_arc(feet, 11, 0, TAU, 24, ACCENT, 1.4, true)
		return
	var tall := 122.0 if shot.type == "dialogue" else 82.0
	if key == "panda":
		tall = 69.0
	var wide := tall * texture.get_size().aspect()
	_shadow(feet, wide * 0.4)
	var flip: bool = key == "ayu" and facing < 0.0 and shot.type != "dialogue"
	if flip:
		draw_set_transform(feet, 0.0, Vector2(-1, 1))
		draw_texture_rect(texture, Rect2(-wide * 0.5, -tall, wide, tall), false)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect(texture, Rect2(feet - Vector2(wide * 0.5, tall), Vector2(wide, tall)), false)

func _vignette() -> void:
	for i in range(22):
		var y := float(i) * 5.0
		var alpha := 0.86 * pow(1.0 - y / 110.0, 2.0)
		draw_rect(Rect2(0, y, 360, 5), Color(0.09, 0.07, 0.14, alpha))
		draw_rect(Rect2(0, 635 - y, 360, 5), Color(0.09, 0.07, 0.14, alpha))

func _road() -> void:
	var background := _texture(str(manifest.get("backgrounds", {}).get("driving", {}).get("file", "")))
	if background:
		_cover(background, Rect2(0, 0, 360, 640))
	else:
		draw_rect(Rect2(0, 0, 360, 640), Color("#494260"))
		draw_rect(Rect2(0, 158, 360, 482), Color("#755965"))
	draw_colored_polygon(PackedVector2Array([
		_project(-1.5, 0), _project(1.5, 0), _project(1.5, 1.09), _project(-1.5, 1.09)
	]), Color("#383443"))
	for edge in [-1.5, 1.5]:
		draw_line(_project(edge, 0), _project(edge, 1.09), Color("#9a7d88"), 2, true)
	for divider in [-0.5, 0.5]:
		for index in range(13):
			var depth := fposmod(float(index) / 12.0 + distance * 0.14, 1.1)
			draw_line(_project(divider, depth), _project(divider, depth + 0.034), Color("#d9baa8"), 1.0 + depth * 2.0, true)
	for index in range(10):
		var depth := traffic_depth(index, distance)
		if depth >= 0.0 and depth <= 1.06:
			_vehicle(_project(traffic_lane(index) - 1.0, depth), 7 + 74 * depth * depth, traffic_image(index))
	_vehicle(_project(lane - 1.0, CAR_DEPTH), 78.0, "car_rear")
	_vignette()
	for target in range(3):
		var center := Vector2(66 + target * 114, 570)
		var fill := Color("#86516c") if roundi(lane) == target else Color("#261d31")
		round_box(Rect2(center - Vector2(35, 20), Vector2(70, 40)), fill, 14, Color("#ad8193"))
		draw_circle(center, 4, CREAM, true, -1, true)
	draw_rect(Rect2(20, 618, 320, 2), Color("#796174"))
	draw_rect(Rect2(20, 618, 320 * clampf(distance / float(shot.duration), 0.0, 1.0), 2), ACCENT)
	if slow > 0.0:
		draw_rect(Rect2(0, 110, 360, 500), Color(0.68, 0.31, 0.29, slow * 0.11))

static func traffic_depth(index: int, progress: float) -> float:
	return (progress - 0.8 - index * 4.55) * 0.21

static func traffic_lane(index: int) -> int:
	return [1, 0, 2, 1, 2, 0, 1, 0, 2, 1][index]

static func traffic_image(index: int) -> String:
	return ["traffic_silver", "traffic_blue", "traffic_gold"][index % 3]

func _project(offset: float, depth: float) -> Vector2:
	return Vector2(180 + offset * (10 + 151 * depth), 166 + 478 * pow(depth, 1.65))

func _vehicle(feet: Vector2, wide: float, key: String) -> void:
	var texture := image_asset(key)
	if not texture and key != "car":
		texture = image_asset("car")
	_shadow(feet, wide * 0.47)
	if texture:
		var tall := wide / texture.get_size().aspect()
		draw_texture_rect(texture, Rect2(feet - Vector2(wide / 2.0, tall), Vector2(wide, tall)), false)
	else:
		var tint := Color("#8965a2") if key.begins_with("car") else Color("#aeb1c6")
		round_box(Rect2(feet - Vector2(wide / 2.0, wide * 0.43), Vector2(wide, wide * 0.41)), tint, 4)
		draw_line(feet - Vector2(wide * 0.35, wide * 0.22), feet + Vector2(wide * 0.35, -wide * 0.22), NIGHT, 2, true)

func _shadow(feet: Vector2, wide: float) -> void:
	draw_set_transform(feet + Vector2(0, 1), 0.0, Vector2(1, 0.23))
	draw_circle(Vector2.ZERO, wide, Color(0.08, 0.05, 0.13, 0.30), true, -1, true)
	draw_set_transform(Vector2.ZERO)

func _night() -> void:
	var progress := smoothstep(0.0, 0.9, time / float(shot.duration))
	var daylight: Dictionary = manifest.get("backgrounds", {}).get("chengdu", {})
	var image := _texture(daylight.get("file", ""))
	if image:
		_cover(image, Rect2(Vector2.ZERO, CANVAS))
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.035, 0.047, 0.098, progress))
	var phone_size := Vector2(50, 88).lerp(PHONE.size, smoothstep(0.42, 1.0, progress))
	var phone_rect := Rect2(PHONE.get_center() - phone_size * 0.5, phone_size)
	round_box(phone_rect, Color(0.063, 0.055, 0.094, progress), 23, Color(0.50, 0.40, 0.47, progress))
	round_box(phone_rect.grow(-5), Color(0.145, 0.16, 0.26, progress), 19)

func _phone() -> void:
	var terminal: bool = shot.type == "terminal"
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color("#0f1120") if terminal else Color("#221c2c"))
	var screen := Color("#252943") if terminal else Color("#31293b")
	round_box(PHONE, Color("#100e18"), 23, Color("#806577"))
	round_box(PHONE.grow(-5), screen, 19)
	round_box(Rect2(155, 71, 50, 4), Color("#120f1c"), 2)
	round_box(Rect2(145, 614, 70, 3), Color("#8f758f"), 2)
	if terminal:
		for index in range(6):
			draw_circle(Vector2(180, 303), 76 + index * 9, Color(0.69, 0.64, 0.9, 0.035), false, 1.0, true)
		_avatar("toretto", Rect2(130, 253, 100, 100))
		draw_arc(Vector2(180, 303), 56, 0, TAU, 64, Color("#a899bd"), 1.5, true)
		return
	if shot.type == "chat":
		for row: Dictionary in chat_rows:
			var right: bool = row.speaker == "ayu"
			var y: float = row.y
			_avatar(row.speaker, Rect2(282 if right else 43, y + 8, 29, 29))
			var bubble := Rect2(159 if right else 80, y, 114 if right else 188, float(row.height))
			round_box(bubble, Color("#496054") if right else Color("#44394e"), 8)
			if right and int(time * 3.0) % 2 == 0:
				draw_line(Vector2(237, y + 11), Vector2(237, y + 27), CREAM, 1.2, true)
	elif shot.type == "phone":
		for index in range(shot.visibleActors.size()):
			_avatar(shot.visibleActors[index].id, Rect2(82 + index * 71, 276, 52, 52))
	else:
		round_box(Rect2(130, 247, 100, 100), Color("#55405d"), 24, Color("#876787"))
		round_box(Rect2(148, 269, 63, 43), CREAM, 12)
		draw_colored_polygon(PackedVector2Array([Vector2(156, 301), Vector2(156, 320), Vector2(174, 306)]), CREAM)
		for x in [167, 180, 193]:
			draw_circle(Vector2(x, 291), 2.5, Color("#55405d"), true, -1, true)

func _avatar(id: String, rect: Rect2) -> void:
	var allowed := false
	for actor: Dictionary in shot.visibleActors:
		if actor.id == id and actor.layer == "phone":
			allowed = true
			break
	if not allowed:
		return
	var image := image_asset(id + "_avatar")
	if image:
		_cover(image, rect)
	else:
		round_box(rect, Color("#68536f"), 7, Color("#988099"))
		draw_circle(rect.get_center(), rect.size.x * 0.17, Color("#c3a9b2"), false, 1.1, true)

func image_asset(key: String) -> Texture2D:
	return _texture(str(manifest.get("images", {}).get(key, "")))

func _texture(file: String) -> Texture2D:
	if file.is_empty():
		return null
	if not texture_cache.has(file):
		var path := ASSET_ROOT + file
		texture_cache[file] = load(path) if ResourceLoader.exists(path) else null
	return texture_cache[file]

func _cover(texture: Texture2D, rect: Rect2) -> void:
	var source := texture.get_size()
	var crop_size := rect.size / maxf(rect.size.x / source.x, rect.size.y / source.y)
	draw_texture_rect_region(texture, rect, Rect2((source - crop_size) * 0.5, crop_size))

func round_box(rect: Rect2, fill: Color, radius: int, border := Color.TRANSPARENT) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.border_color = border
	if border.a > 0.0:
		box.set_border_width_all(1)
	draw_style_box(box, rect)
