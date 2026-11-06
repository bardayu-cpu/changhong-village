extends Control

const CANVAS := Vector2(360, 640)
const ASSET_ROOT := "res://hongyuan/assets/"
const ART_SCALE := 2.0 / 3.0
const CREAM := Color("#fef2d3")
const DARK_RED := Color("#400a0c")
const NIGHT := Color("#240307")
const ACCENT := Color("#d6a43c")
const ROOM_EDGE := Color("#20110a")
const ROOM_TINT := Color(0.77, 0.73, 0.71)
const PHONE := Rect2(22, 65, 316, 559)
const PHONE_ORIGIN := Vector2(14, 37)
const PHONE_OPENING := Rect2(12, 22, 474, 820)
const PHONE_HEADER := Rect2(22, 52, 316, 56)
const PHONE_TEXT := Color("#281a1a")
const CARD_ORIGIN := Vector2(56, 120)
const CARD_STROKE_FROM := Vector2(50, 172)
const CARD_STROKE_TO := Vector2(310, 172)
const PEN_TIP_ANCHOR := Vector2(6, 50)
const ROOM_ORIGIN := Vector2(20, 36)
const AVATAR_SIZE := 64.0 * ART_SCALE
const PARKING := [Vector2(93, 379), Vector2(265, 379)]
const STREET_CAR := Vector2(260, 405)
const PANDA := Vector2(111, 445)
const PHONE_HOTSPOT := Vector2(263, 400)
const CAR_DEPTH := 0.89
const BRAKE := Rect2(260, 530, 64, 64)
const STEERING := Rect2(106, 522, 80, 80)

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
var drive_started := false
var drive_exit := false
var drive_arrival := 0.0
var traffic_seed := 0
var panda_time := 0.0
var save_failed := false
var interaction: Dictionary = {}
var stick_visible := false
var stick_origin := Vector2(64, 558)
var stick_vector := Vector2.ZERO
var parking_active := false
var parking_progress := 0.0
var parking_pressed := false
var parking_angle := 0.0
var parking_offset := Vector2.ZERO
var parking_steer := 0.0
var parking_assisting := false
var parking_feedback := 0.0
var control_time := 0.0
var texture_cache: Dictionary = {}
var skin_cache: Dictionary = {}

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
	_controls()
	if save_failed:
		draw_arc(Vector2(336, 29), 6, 0, TAU, 20, Color("#ed8b7e"), 1.5, true)
		draw_line(Vector2(336, 26), Vector2(336, 30), Color("#ed8b7e"), 1.5, true)
		draw_circle(Vector2(336, 33), 0.9, Color("#ed8b7e"))

func _invitation() -> void:
	draw_rect(Rect2(Vector2.ZERO, CANVAS), DARK_RED)
	if shot.sceneId == "invitation" and shot.type in ["invite", "narration", "material"]:
		_draw_background("invitation_desk")
	_draw_art("invite_card", CARD_ORIGIN)

	var pen_progress := 1.0 if materials.get("pen") == "applied" else 0.0
	var ink_progress := 1.0 if materials.get("ink") == "applied" else 0.0
	if shot.type == "material":
		if shot.materialId == "pen":
			pen_progress = clampf((time - 0.55) / 0.9, 0.0, 1.0)
			var line_tip := CARD_ORIGIN + CARD_STROKE_FROM.lerp(CARD_STROKE_TO, pen_progress) * ART_SCALE
			var tip := Vector2(222, 564).lerp(line_tip, clampf(time / 0.55, 0.0, 1.0))
			_draw_art("pen_tip", tip - PEN_TIP_ANCHOR * ART_SCALE)
		else:
			ink_progress = clampf((time - 0.19) / 1.55, 0.0, 1.0)
	_reveal_card_layer("invite_pen_stroke", pen_progress)
	_reveal_card_layer("invite_ink_tint", ink_progress)
	_draw_art("invite_slot_pen", CARD_ORIGIN, Color(1, 1, 1, smoothstep(0.7, 1.0, pen_progress)))
	_draw_art("invite_slot_ink", CARD_ORIGIN, Color(1, 1, 1, smoothstep(0.7, 1.0, ink_progress)))
	for actor: Dictionary in shot.visibleActors:
		if actor.id == "ayu" and actor.layer == "invitation":
			_draw_sprite(image_asset("ayu_formal"), Vector2(325, 456), 4.0)
	if shot.get("effect", "") == "ink_to_chengdu":
		var amount := clampf(time / float(shot.duration), 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.15, 0.05, 0.10, amount * 0.93))

func _reveal_card_layer(key: String, progress: float) -> void:
	var texture := image_asset(key)
	if not texture or progress <= 0.0:
		return
	var source_size := texture.get_size()
	source_size.x = source_size.x if progress >= 1.0 else floorf(lerpf(CARD_STROKE_FROM.x, CARD_STROKE_TO.x, progress))
	if source_size.x > 0.0:
		draw_texture_rect_region(texture, Rect2(CARD_ORIGIN, source_size * ART_SCALE), Rect2(Vector2.ZERO, source_size))

func _line_to_road() -> void:
	_invitation()
	var progress := smoothstep(0.12, 0.92, time / float(shot.duration))
	var wash := NIGHT
	wash.a = progress
	draw_rect(Rect2(Vector2.ZERO, CANVAS), wash)
	var start := (CARD_ORIGIN + CARD_STROKE_FROM * ART_SCALE).lerp(Vector2(179, 174), progress)
	var finish := (CARD_ORIGIN + CARD_STROKE_TO * ART_SCALE).lerp(Vector2(180, 640), progress)
	var width := 1.0 + 32.0 * progress * progress
	draw_line(start, finish, Color("#d9c29e"), width, true)
	draw_colored_polygon(PackedVector2Array([
		start + Vector2(-3, 0), start + Vector2(3, 0),
		finish + Vector2(230 * progress, 0), finish - Vector2(230 * progress, 0)
	]), Color(0.28, 0.25, 0.37, progress))
	draw_line(start, finish, Color("#edceae"), 1.0 + progress * 3.0, true)

func _world(background: String) -> void:
	_draw_background(background)
	if background == "street":
		_vehicle(STREET_CAR, 0.0, "car_street")
	elif background == "parking":
		for index in range(int(shot.get("cars", 0))):
			var feet: Vector2 = PARKING[index]
			if index == 0:
				# Already at the bay edge. Release holds this exact position;
				# parking assist straightens the angle without another drive.
				feet += parking_offset
			_vehicle(feet, 0.0, "car_parking", parking_angle if index == 0 else 0.0)
	if shot.type == "walk":
		_world_hotspots()
	var sorted: Array = shot.visibleActors.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _feet(a).y < _feet(b).y
	)
	for actor: Dictionary in sorted:
		if actor.mode == "sprite" and actor.layer == "world" and not parking_active:
			_world_actor(actor)
	_vignette()
	if shot.type == "dialogue":
		var speaker_x := 96.0 if shot.speaker == "ayu" else 264.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(speaker_x, 445), Vector2(speaker_x - 7, 454), Vector2(speaker_x + 7, 454)
		]), ACCENT)

func _world_hotspots() -> void:
	if shot.get("chapterId") == "shanghai":
		return
	for hotspot: Dictionary in shot.hotspots:
		if hotspot.id == "bamboo":
			if not materials.get("bamboo_held", false) and not materials.get("panda_used", false):
				var bamboo := _texture("w2/chengdu/bamboo_clump.png")
				if bamboo:
					draw_texture_rect(bamboo, Rect2(165, 390, 34, 47), false)
		elif hotspot.id == "panda":
			if panda_time <= 0 and not materials.get("panda_used", false):
				_pin(PANDA + Vector2(0, 12))
		elif hotspot.id == "phone":
			var texture := image_asset("phone_prop")
			if texture:
				var size := texture.get_size() * ART_SCALE
				draw_texture_rect(texture, Rect2(PHONE_HOTSPOT - size * 0.5, size), false)
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
		if shot.type == "dialogue" and shot.get("chapterId") != "shanghai":
			return Vector2(96, 456)
		return player_feet
	if actor.id == "panda":
		return PANDA
	if actor.id == "axiao" and shot.get("sceneId") == "shanghai_parking":
		return Vector2(222, 410)  # 站在她哥那辆车（右边车位）跟前
	return Vector2(264 if actor.slot == "right" else 96, 456)

func _world_actor(actor: Dictionary) -> void:
	var key: String = actor.id
	var info: Dictionary = manifest.get("sprites", {}).get(key, {})
	var file: String = info.get("idle", "")
	var frames: Array = info.get("walk", [])
	if key == "ayu" and walk_frame >= 0 and not frames.is_empty():
		file = frames[walk_frame % frames.size()]
	elif key == "axiao" and shot.type == "dialogue" and shot.speaker == "axiao":
		file = info.get("phone", file)
	elif key == "panda":
		if panda_time > 0.45:
			file = info.get("action", file)
		elif panda_time > 0.0:
			file = info.get("slow", file)
		elif materials.get("panda_used", false):
			file = info.get("sleep", file)
	var flip: bool = key == "ayu" and facing < 0.0 and (shot.type != "dialogue" or shot.get("chapterId") == "shanghai")
	var feet := _feet(actor)
	if key == "ayu" and walk_frame >= 0 and shot.get("chapterId") == "shanghai":
		feet.y -= float(walk_frame % 2) * 1.5
	var height: float = PEOPLE_HEIGHT.get(str(shot.get("sceneId", "")), 0.0) if key in ["ayu", "axiao"] else 0.0
	if height > 0.0:
		_draw_person(_texture(file), feet, height, flip)
	else:
		_draw_sprite(_texture(file), feet, float(info.get("footBottom", 0)), flip)
	if key == "ayu" and materials.get("bamboo_held", false):
		var held := _texture("w2/chengdu/bamboo_held.png")
		if held:
			draw_texture_rect(held, Rect2(player_feet + Vector2(20 * facing - 8, -51), Vector2(16, 44)), false)

## 有车做参照的场景里，人按和车匹配的身高画；按图里不透明部分量身高，阿鱼和阿晓一样高。
const PEOPLE_HEIGHT := {"shanghai_street": 82.0, "shanghai_parking": 82.0}
var _used_rects := {}

func _draw_person(texture: Texture2D, feet: Vector2, height: float, flip: bool) -> void:
	if not texture:
		return
	if not _used_rects.has(texture):
		_used_rects[texture] = texture.get_image().get_used_rect()
	var used: Rect2 = Rect2(_used_rects[texture])
	var k := height / used.size.y
	var size := used.size * k
	feet = _pixel_position(feet)
	_shadow(feet, size.x * 0.3)
	draw_set_transform(feet, 0.0, Vector2(-1, 1) if flip else Vector2.ONE)
	draw_texture_rect_region(texture, Rect2(Vector2(-size.x * 0.5, -size.y), size), used)
	draw_set_transform(Vector2.ZERO)

func _draw_sprite(texture: Texture2D, feet: Vector2, foot_bottom := 0.0, flip := false) -> void:
	if not texture:
		return
	var size := texture.get_size() * ART_SCALE
	feet = _pixel_position(feet)
	_shadow(feet, size.x * 0.32)
	var top_left := Vector2(-floorf(texture.get_width() * 0.5) * ART_SCALE, -size.y + foot_bottom * ART_SCALE)
	draw_set_transform(feet, 0.0, Vector2(-1, 1) if flip else Vector2.ONE)
	draw_texture_rect(texture, Rect2(top_left, size), false)
	draw_set_transform(Vector2.ZERO)

func _pixel_position(position: Vector2) -> Vector2:
	return (position / ART_SCALE).round() * ART_SCALE

func _vignette() -> void:
	for i in range(22):
		var y := float(i) * 5.0
		var alpha := 0.86 * pow(1.0 - y / 110.0, 2.0)
		draw_rect(Rect2(0, y, 360, 5), Color(0.14, 0.02, 0.035, alpha))
		draw_rect(Rect2(0, 635 - y, 360, 5), Color(0.14, 0.02, 0.035, alpha))

func _road() -> void:
	_draw_background("driving")
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
		var depth := traffic_depth(index, distance, traffic_seed)
		if depth >= 0.0 and depth <= 1.06:
			_vehicle(_project(traffic_lane(index, traffic_seed) - 1.0, depth), 7 + 74 * depth * depth, traffic_image(index))
	var player_car := _project(lane - 1.0, CAR_DEPTH)
	player_car.x = clampf(player_car.x, 47.0, CANVAS.x - 47.0)
	_vehicle(player_car, 78.0, "car_rear")
	_vignette()
	if not drive_started:
		for side in [-1.0, 1.0]:
			var tip := player_car + Vector2(side * (57 + sin(control_time * 4) * 3), -25)
			draw_line(tip + Vector2(-side * 9, -7), tip, CREAM, 3)
			draw_line(tip, tip + Vector2(-side * 9, 7), CREAM, 3)
	if drive_exit:
		var exit_pos := Vector2(294, 542)
		var glow := Color(0.9, 0.73, 0.34, 0.6 + 0.2 * sin(control_time * 5))
		draw_arc(exit_pos, 25, 0, TAU, 24, glow, 3)
		draw_polyline(PackedVector2Array([exit_pos + Vector2(-10,0), exit_pos + Vector2(9,0), exit_pos + Vector2(2,-7)]), CREAM, 3)
		draw_line(exit_pos + Vector2(9,0), exit_pos + Vector2(2,7), CREAM, 3)
	if drive_arrival > 0.0:
		var glow := Color(0.98, 0.9, 0.75, 1.0 - drive_arrival / 0.5)
		draw_arc(player_car + Vector2(0,-24), 48 + drive_arrival * 30, PI, TAU, 24, glow, 3)
	for target in range(3):
		var center := Vector2(66 + target * 114, 596)
		_draw_skin("bubble_right" if roundi(lane) == target else "bubble_system",
			Rect2(center - Vector2(35, 15), Vector2(70, 30)))
		draw_circle(center, 3, DARK_RED if roundi(lane) == target else CREAM)
	draw_rect(Rect2(20, 620, 320, 2), Color("#662016"))
	draw_rect(Rect2(20, 620, 320 * clampf(distance / float(shot.duration), 0.0, 1.0), 2), ACCENT)
	if slow > 0.0:
		draw_rect(Rect2(0, 110, 360, 500), Color(0.68, 0.31, 0.29, slow * 0.11))

static func traffic_depth(index: int, progress: float, seed_value := 0) -> float:
	var jitter := 0.0 if seed_value == 0 or index == 0 else float((seed_value * 31 + index * 71) % 101) / 100.0 * 1.4 - 0.7
	return (progress - 0.8 - index * 4.55 - jitter) * 0.21

static func traffic_lane(index: int, seed_value := 0) -> int:
	if seed_value == 0 or index == 0:
		return [1, 0, 2, 1, 2, 0, 1, 0, 2, 1][index]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + index * 7919
	return rng.randi_range(0, 2)

static func traffic_image(index: int) -> String:
	return ["traffic_silver", "traffic_blue", "traffic_gold"][index % 3]

func _project(offset: float, depth: float) -> Vector2:
	return Vector2(180 + offset * (10 + 151 * depth), 166 + 478 * pow(depth, 1.65))

func _vehicle(feet: Vector2, wide: float, key: String, angle := 0.0) -> void:
	var texture := image_asset(key)
	if not texture:
		texture = image_asset("car")
	if not texture:
		return
	if wide <= 0.0:
		var native_size := texture.get_size() * ART_SCALE
		feet = _pixel_position(feet)
		_shadow(feet, native_size.x * 0.47)
		var origin := _pixel_position(feet - Vector2(native_size.x * 0.5, native_size.y))
		if is_zero_approx(angle):
			draw_texture_rect(texture, Rect2(origin, native_size), false)
		else:
			draw_set_transform(origin + native_size * 0.5, angle)
			draw_texture_rect(texture, Rect2(-native_size * 0.5, native_size), false)
			draw_set_transform(Vector2.ZERO)
		return
	var native_wide := texture.get_width() * ART_SCALE
	var divisor := pow(2.0, maxf(0.0, roundf(log(native_wide / wide) / log(2.0))))
	var size := (texture.get_size() / divisor).round() * ART_SCALE
	feet = _pixel_position(feet)
	_shadow(feet, size.x * 0.47)
	draw_texture_rect(texture, Rect2(_pixel_position(feet - Vector2(size.x * 0.5, size.y)), size), false)

func _shadow(feet: Vector2, wide: float) -> void:
	draw_set_transform(feet + Vector2(0, 1), 0.0, Vector2(1, 0.23))
	draw_circle(Vector2.ZERO, wide, Color(0.08, 0.05, 0.13, 0.30), true, -1, true)
	draw_set_transform(Vector2.ZERO)

func _night() -> void:
	var progress := smoothstep(0.0, 0.9, time / float(shot.duration))
	_draw_background("chengdu")
	_draw_room(progress)
	_draw_phone_shell(progress)

func _draw_room(opacity: float = 1.0) -> void:
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(ROOM_EDGE, opacity))
	var night: Dictionary = manifest.get("backgrounds", {}).get("night", {})
	var room := _texture(night.get("file", ""))
	if room:
		draw_texture_rect(room, Rect2(ROOM_ORIGIN * ART_SCALE, room.get_size() * ART_SCALE), false,
			Color(ROOM_TINT, opacity))

func phone_screen_rect() -> Rect2:
	return Rect2(PHONE_ORIGIN + PHONE_OPENING.position * ART_SCALE, PHONE_OPENING.size * ART_SCALE)

func _draw_phone_shell(opacity: float = 1.0, _incoming := false) -> void:
	var screen := phone_screen_rect()
	var tint := Color(1, 1, 1, opacity)
	var paper := image_asset("w2_phone_screen_paper")
	var header := image_asset("w2_phone_header")
	if paper:
		draw_texture_rect(paper, screen, false, tint)
	if header:
		draw_texture_rect(header, PHONE_HEADER, false, tint)
	_draw_art("w2_phone_frame", PHONE_ORIGIN, tint)

func _phone() -> void:
	var terminal: bool = shot.type == "terminal"
	if terminal:
		_draw_room()
	else:
		_draw_background("parking" if shot.chapterId == "shanghai" else "chengdu")
		draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.12, 0.08, 0.06, 0.28))
	_draw_phone_shell()
	if terminal:
		_draw_skin("w2_bubble_right", Rect2(138, 194, 84, 84))
		_avatar("toretto", Vector2(144, 200), 1.6875)
		# W1 stops at an incoming call: one indication, no answer/reject handlers.
		var call_icon := image_asset("w2_call_accept")
		if call_icon:
			draw_texture_rect(call_icon, Rect2(158, 452, 44, 44), false)
	elif shot.type == "chat":
		for row: Dictionary in chat_rows:
			if not row.get("visible", true):
				continue
			_draw_skin(row.skin, row.bubble)
			if row.speaker != "system":
				_avatar(row.speaker, row.avatar, 0.75)
			if row.speaker == "ayu" and int(time * 3.0) % 2 == 0:
				draw_rect(Rect2(row.bubble.end.x - 9, row.bubble.position.y + 10, ART_SCALE, 14), PHONE_TEXT)
	elif shot.type == "phone":
		for index in range(shot.visibleActors.size()):
			var origin := Vector2(78 + index * 86, 266)
			_avatar(shot.visibleActors[index].id, origin, 0.75)

func _avatar(id: String, origin: Vector2, ratio := 1.0) -> void:
	for actor: Dictionary in shot.visibleActors:
		if actor.id == id and actor.layer == "phone":
			var info: Dictionary = manifest.get("sprites", {}).get(id, {})
			var region: Array = info.get("avatarRegion", [])
			if region.size() == 4:
				var face := _texture(str(info.get("avatarFile", "")))
				if face:
					draw_texture_rect_region(face, Rect2(_pixel_position(origin), Vector2(64,64) * ART_SCALE * ratio),
						Rect2(region[0], region[1], region[2], region[3]))
			else:
				var texture := image_asset(id + "_avatar")
				if texture:
					var size := texture.get_size() * ART_SCALE * ratio
					draw_texture_rect(texture, Rect2(_pixel_position(origin), size), false)
			return

func _draw_art(key: String, origin: Vector2, tint := Color.WHITE) -> void:
	var texture := image_asset(key)
	if texture and tint.a > 0.0:
		draw_texture_rect(texture, Rect2(_pixel_position(origin), texture.get_size() * ART_SCALE), false, tint)

func _draw_background(key: String) -> void:
	var backdrop: Dictionary = manifest.get("backgrounds", {}).get(key, {})
	var texture := _texture(str(backdrop.get("file", "")))
	if texture:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, CANVAS), false)

func _draw_skin(key: String, rect: Rect2) -> void:
	var skin := pixel_skin(key)
	if skin:
		draw_set_transform(_pixel_position(rect.position), 0.0, Vector2.ONE * ART_SCALE)
		draw_style_box(skin, Rect2(Vector2.ZERO, rect.size / ART_SCALE))
		draw_set_transform(Vector2.ZERO)

func pixel_skin(key: String) -> StyleBoxTexture:
	if not skin_cache.has(key):
		var texture := image_asset(key)
		if not texture:
			return null
		var skin := StyleBoxTexture.new()
		skin.texture = texture
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			skin.set_texture_margin(side, 12)
			skin.set_content_margin(side, 0)
		skin_cache[key] = skin
	return skin_cache[key]

func image_asset(key: String) -> Texture2D:
	return _texture(str(manifest.get("images", {}).get(key, "")))

func _texture(file: String) -> Texture2D:
	if file.is_empty():
		return null
	if not texture_cache.has(file):
		var path := ASSET_ROOT + file
		texture_cache[file] = load(path) if ResourceLoader.exists(path) else null
	return texture_cache[file]

static func interaction_rect(hotspot: Dictionary) -> Rect2:
	return Rect2(Vector2(float(hotspot.target[0]) - 22, float(hotspot.target[1]) - 70), Vector2(44, 44))

func _controls() -> void:
	if stick_visible:
		var base := _texture("w2/common/joystick_base.png")
		var knob := _texture("w2/common/joystick_knob.png")
		if base and knob:
			draw_texture_rect(base, Rect2(stick_origin - Vector2(36, 36), Vector2(72, 72)), false)
			draw_texture_rect(knob, Rect2(stick_origin + stick_vector * 25 - Vector2(16, 16), Vector2(32, 32)), false)
	if not interaction.is_empty():
		var rect := interaction_rect(interaction)
		_draw_skin("bubble_right", rect)
		var icon := _texture(str(interaction.iconFile)) if interaction.has("iconFile") else image_asset(str(interaction.get("icon", "interaction_hand")))
		if icon:
			draw_texture_rect(icon, Rect2(rect.position + Vector2(6, 6), Vector2(32, 32)), false)
	if parking_feedback > 0.0 and shot.background == "parking":
		var glow := Color(0.98, 0.86, 0.55, parking_feedback * 1.6)
		var center: Vector2 = PARKING[0] + parking_offset + Vector2(0, -18)
		for side in [-1.0, 1.0]:
			var tip := center + Vector2(side * (60.0 + (0.45 - parking_feedback) * 18.0), -8)
			draw_line(tip, tip + Vector2(side * 5, -4), glow, 2)
	if parking_active:
		_draw_parking_steering()
		_draw_skin("bubble_left" if parking_pressed else "bubble_right", BRAKE)
		# A brake-pedal pictogram: no added copy or button labels.
		var center := BRAKE.get_center()
		draw_style_box(_pedal_skin(), Rect2(center - Vector2(14, 19), Vector2(28, 34)))
		for row in range(3):
			draw_line(center + Vector2(-9, -12 + row * 9), center + Vector2(9, -12 + row * 9), CREAM, 2)
		draw_line(center + Vector2(0, 15), center + Vector2(6, 23), DARK_RED, 4)

func _pedal_skin() -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	skin.bg_color = DARK_RED
	skin.set_corner_radius_all(3)
	return skin

func _draw_parking_steering() -> void:
	var center := STEERING.get_center()
	var tint := CREAM if parking_pressed else Color(0.98, 0.9, 0.75, 0.8)
	# One-finger gesture: hold either pictogram, slide sideways to steer.
	_draw_skin("bubble_left" if parking_pressed else "bubble_right", STEERING)
	draw_arc(center, 24, 0, TAU, 32, DARK_RED, 4)
	var rotation_angle := parking_steer * 0.8
	for spoke in [0.0, PI, PI * 0.5]:
		var tip := center + Vector2.from_angle(spoke + rotation_angle) * 22.0
		draw_line(center, tip, DARK_RED, 3)
	draw_circle(center, 5, DARK_RED)
	if not parking_assisting:
		var hint := 3.0 * sin(control_time * 4.0) if not parking_pressed else 0.0
		for side in [-1.0, 1.0]:
			var tip := center + Vector2(side * (53 + hint), 0)
			draw_line(tip + Vector2(-side * 10, -7), tip, tint, 2)
			draw_line(tip, tip + Vector2(-side * 10, 7), tint, 2)
	# At the bay, a level guide makes the car's angle readable without copy.
	var bay: Vector2 = PARKING[0] + parking_offset + Vector2(0, 6)
	draw_line(bay - Vector2(34, 0), bay + Vector2(34, 0), Color(0.98, 0.9, 0.75, 0.6), 1)
	var aligned := absf(parking_angle) < 0.025
	var tick_tint := Color("#b9d5a1") if aligned else ACCENT
	var tip := Vector2(24, 0).rotated(parking_angle)
	draw_line(bay - tip, bay + tip, tick_tint, 2)
