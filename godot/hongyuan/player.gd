extends Control

const Stage := preload("res://hongyuan/stage.gd")
const Checkpoint := preload("res://hongyuan/checkpoint.gd")
const FONT := preload("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2")
const COPY_PATH := "res://hongyuan/copy.json"
const WALK_BOUNDS := Rect2(35, 396, 290, 60)
const SAVE_INTERVAL := 0.35
const CHAT_ACCELERATED_INTERVAL := 0.50
const PHONE_NOTIFICATION := Rect2(34, 77, 292, 34)
const DIALOGUE_BOX := Rect2(22, 453, 316, 144)
const CHAT_FONT_SIZE := 13
const CHAT_LINE_SPACING := 2
const CHAT_PADDING_X := 8.0
const CHAT_PADDING_Y := 6.0
const CHAT_GAP := 4.0

var stage := Stage.new()
var slots := Control.new()
var title := Label.new()
var copy: Dictionary
var playlist: Array[Dictionary] = []
var step_indices: Dictionary = {}
var state: Dictionary = {}
var shot: Dictionary
var active_index := 0
var elapsed := 0.0
var since_save := 0.0
var movement_target := Vector2.ZERO
var moving := false
var pending_hotspot := ""
var distance_walked := 0.0
var lane_target := 1
var hit_index := -1
var chat_fast := false
var paused := false
var page_hidden_callback: Variant
var chime := AudioStreamPlayer.new()
# Pointer gestures follow the wedding input: short release taps, lower-left drags steer.
# project.godot maps real touches to these mouse events on mobile as well.
var pointer_down := false
var pointer_start := Vector2.ZERO
var pointer_started := 0
var pointer_dragged := false
var stick := Vector2.ZERO
var stick_pointer := false
var parking_held := false
var parking_started := false
var parking_done := true
var parking_progress := 0.0
var parking_speed := 1.0
var parking_align := false
var parking_angle := 0.0


func _ready() -> void:
	copy = _read_json(COPY_PATH)
	stage.manifest = _read_json("res://hongyuan/assets/manifest.json")
	if not _load_playlist():
		_show_data_error()
		return
	stage.size = Stage.CANVAS
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage.gui_input.connect(_on_stage_input)
	add_child(stage)
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(slots)
	_style_label(title, Rect2(18, 14, 324, 34), 16, Stage.CREAM)
	stage.add_child(title)
	chime.stream = _make_chime()
	chime.volume_db = -16.0
	add_child(chime)
	resized.connect(_fit_canvas)
	_fit_canvas()

	state = Checkpoint.read()
	active_index = int(step_indices.get(state.get("stepId", ""), -1))
	if active_index < 0 or not state.get("materials", null) is Dictionary:
		state = {
			"version": 1, "revision": int(state.get("revision", 0)),
			"runId": Crypto.new().generate_random_bytes(16).hex_encode(),
			"materials": {}, "pandaUsed": false,
		}
		active_index = 0
		_enter_step(0)
	else:
		_enter_step(active_index, true)

	if OS.has_feature("web"):
		page_hidden_callback = JavaScriptBridge.create_callback(_on_browser_visibility)
		var document := JavaScriptBridge.get_interface("document")
		var window := JavaScriptBridge.get_interface("window")
		document.addEventListener("visibilitychange", page_hidden_callback)
		window.addEventListener("pagehide", page_hidden_callback)

func _fit_canvas() -> void:
	var safe := Rect2(Vector2.ZERO, size)
	if OS.has_feature("web"):
		var values := str(JavaScriptBridge.eval("""[
			innerWidth, innerHeight, ...['top', 'right', 'bottom', 'left'].map(
				edge => parseFloat(getComputedStyle(document.body).getPropertyValue('--hy-' + edge)) || 0
			)
		].join(',')""", true)).split(",")
		if values.size() == 6 and float(values[0]) > 0.0 and float(values[1]) > 0.0:
			var scale_to_view := size / Vector2(float(values[0]), float(values[1]))
			safe.position = Vector2(float(values[5]), float(values[2])) * scale_to_view
			safe.size -= safe.position + Vector2(float(values[3]), float(values[4])) * scale_to_view
	var fit := minf(safe.size.x / Stage.CANVAS.x, safe.size.y / Stage.CANVAS.y)
	stage.scale = Vector2.ONE * fit
	stage.position = safe.position + (safe.size - Stage.CANVAS * fit) * 0.5

func _load_playlist() -> bool:
	var order := _read_json("res://hongyuan/chapter_order.json")
	for chapter_id: String in order.get("chapters", []):
		var chapter := _read_json("res://hongyuan/chapters/%s.json" % chapter_id)
		if chapter.get("chapterId") != chapter_id or not copy.has(chapter.get("titleId")):
			return false
		for step: Dictionary in chapter.get("steps", []):
			step.chapterId = chapter_id
			step.titleId = step.get("titleId", chapter.titleId)
			step.fullId = chapter_id + "/" + str(step.get("id"))
			if step_indices.has(step.fullId) or not _validate_shot(step):
				push_error("Invalid Hongyuan shot: " + step.fullId)
				return false
			step_indices[step.fullId] = playlist.size()
			playlist.append(step)
	return not playlist.is_empty() and playlist[-1].type == "terminal"

func _validate_shot(step: Dictionary) -> bool:
	for key in ["id", "type", "sceneId", "speaker", "actorMode", "actorSlot", "background", "visibleActors"]:
		if not step.has(key):
			return false
	for key in ["copyId", "titleId", "objectiveId", "groupId"]:
		if step.has(key) and not copy.has(step[key]):
			return false
	if not step.type in ["invite", "narration", "transition", "walk", "drive", "dialogue", "wait", "chat", "material", "notification", "phone", "terminal"]:
		return false
	var backdrop: Dictionary = stage.manifest.get("backgrounds", {}).get(step.background, {})
	var baked: Array = backdrop.get("bakedActors", [])
	var actors := {}
	for actor: Dictionary in step.visibleActors:
		if not actor.has_all(["id", "mode", "slot", "layer"]):
			return false
		if actors.has(actor.id) or not actor.mode in ["baked", "sprite"]:
			return false
		if (actor.id in baked) != (actor.mode == "baked"):
			return false
		if step.chapterId == "shanghai" and actor.id == "toretto" and actor.layer != "phone":
			return false
		actors[actor.id] = actor
	for actor_id in baked:
		if not actors.has(actor_id):
			return false
	if actors.has(step.speaker):
		return actors[step.speaker].mode == step.actorMode and actors[step.speaker].slot == step.actorSlot
	return step.actorMode == "none" and step.actorSlot == null

func _read_json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return data if data is Dictionary else {}

func _enter_step(index: int, resume := false) -> void:
	var previous_scene: String = shot.get("sceneId", "")
	var previous_type: String = shot.get("type", "")
	active_index = index
	shot = playlist[index]
	stage.shot = shot
	_clear_movement()
	_reset_pointer()
	since_save = 0.0
	if not resume:
		state.stepId = shot.fullId
		state.elapsed = 0.0
		if shot.sceneId != previous_scene:
			stage.player_feet = _starting_feet(shot.sceneId)
			stage.facing = 1.0
		if shot.fullId == "shanghai/park":
			state.parking = {"started": false, "done": false, "progress": 0.0, "speed": 1.0, "align": false, "angle": -0.14}
		if shot.type == "drive":
			state.driveDistance = 0.0
			state.lane = 1
			state.lanePosition = 1.0
			state.slow = 0.0
			state.hitIndex = -1
		if shot.type != "chat" or previous_type != "chat":
			chat_fast = false
		state.chatFast = chat_fast
	else:
		var feet: Array = state.get("feet", [])
		stage.player_feet = Vector2(float(feet[0]), float(feet[1])) if feet.size() == 2 else _starting_feet(shot.sceneId)
		stage.facing = float(state.get("facing", 1.0))
		chat_fast = bool(state.get("chatFast", false))
	elapsed = clampf(float(state.get("elapsed", 0.0)), 0.0, float(shot.get("duration", 0.0)))
	stage.time = elapsed
	stage.distance = float(state.get("driveDistance", 0.0))
	stage.slow = float(state.get("slow", 0.0))
	lane_target = clampi(int(state.get("lane", 1)), 0, 2)
	stage.lane = clampf(float(state.get("lanePosition", lane_target)), 0.0, 2.0)
	hit_index = int(state.get("hitIndex", -1))
	var parking: Dictionary = state.get("parking", {})
	parking_started = bool(parking.get("started", false))
	# W1 park was an automatic scene: missing parking data means already parked.
	parking_done = bool(parking.get("done", true))
	parking_progress = float(parking.get("progress", 1.0))
	parking_speed = float(parking.get("speed", 1.0))
	parking_align = bool(parking.get("align", false))
	parking_angle = float(parking.get("angle", 0.0 if parking_done else -0.14))
	if _controlled_walk():
		stage.player_feet = _clamp_walk(stage.player_feet)
		var target: Array = state.get("walkTarget", [])
		if resume and bool(state.get("walking", false)) and target.size() == 2:
			_walk_to(Vector2(float(target[0]), float(target[1])), "")
	_sync_controls()

	if shot.type == "material":
		var key := _material_key(shot)
		match state.materials.get(key, ""):
			"applied":
				_advance()
				return
			"pending":
				elapsed = 0.0
				stage.time = 0.0
			_:
				state.materials[key] = "pending"
	_sync_materials()
	_save()
	_present()
	if shot.type == "chat" and not resume:
		chime.play()

func _starting_feet(scene: String) -> Vector2:
	match scene:
		"shanghai_street": return Vector2(104, 451)
		"shanghai_parking": return Vector2(96, 456)
		"chengdu_day": return Vector2(169, 456)
	return Vector2(96, 456)

func _advance() -> void:
	if active_index + 1 < playlist.size():
		_enter_step(active_index + 1)

func _process(delta: float) -> void:
	if shot.is_empty() or paused or shot.type == "terminal":
		return
	var dt := minf(delta, 0.08)
	if shot.fullId == "shanghai/park" and not parking_done:
		_park(dt)
		_sync_controls()
		if since_save >= SAVE_INTERVAL:
			_save()
		since_save += dt
		stage.queue_redraw()
		return
	elapsed += dt
	stage.time = elapsed
	since_save += dt
	var duration := float(shot.get("duration", 0.0))
	match shot.type:
		"walk":
			_move(dt)
		"drive":
			_drive(dt)
			if stage.distance >= duration:
				_advance()
		"chat":
			if chat_fast and duration < 1.0:
				duration = CHAT_ACCELERATED_INTERVAL
			if elapsed >= duration:
				_advance()
		"material":
			if elapsed >= duration:
				state.materials[_material_key(shot)] = "applied"
				_advance()
		"narration", "dialogue", "wait", "transition", "phone":
			if elapsed >= duration:
				_advance()
	if since_save >= SAVE_INTERVAL and (shot.has("duration") or moving):
		_save()
	_sync_controls()
	stage.queue_redraw()

func _move(dt: float) -> void:
	stage.panda_time = maxf(stage.panda_time - dt, 0.0)
	if _controlled_walk() and stick.length() > 0.05:
		movement_target = _clamp_walk(stage.player_feet + stick * 126.0 * dt)
		moving = true
	if not moving:
		return
	var before: Vector2 = stage.player_feet
	stage.player_feet = before.move_toward(movement_target, dt * 126.0)
	if _controlled_walk():
		stage.player_feet = _clamp_walk(stage.player_feet)
	var displacement: Vector2 = stage.player_feet - before
	if absf(displacement.x) > 0.01:
		stage.facing = signf(displacement.x)
	distance_walked += displacement.length()
	stage.walk_frame = floori(distance_walked / 11.0)
	if stage.player_feet == movement_target and stick.length() <= 0.05:
		var reached := pending_hotspot
		_clear_movement()
		match reached:
			"panda":
				if not state.get("pandaUsed", false):
					state.pandaUsed = true
					stage.panda_time = 0.85
					_sync_materials()
					_save()
			"car", "axiao", "phone":
				_advance()
			_:
				_save()

func _clear_movement() -> void:
	moving = false
	pending_hotspot = ""
	distance_walked = 0.0
	stage.walk_frame = -1

func _drive(dt: float) -> void:
	stage.slow = maxf(0.0, stage.slow - dt)
	stage.lane = move_toward(stage.lane, float(lane_target), 4.4 * dt)
	stage.distance += dt * (0.44 if stage.slow > 0.0 else 1.0)
	for index in range(10):
		if index <= hit_index:
			continue
		var depth := Stage.traffic_depth(index, stage.distance)
		if depth > 0.81 and depth < 0.94 and absf(stage.lane - Stage.traffic_lane(index)) < 0.48:
			hit_index = index
			stage.slow = 0.88
			chime.play()
			_save()
			break

func _on_stage_input(event: InputEvent) -> void:
	if paused:
		return
	if not _controlled_walk() and shot.type != "drive" and not _parking_active():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_tap(event.position)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointer_down = true
			pointer_start = event.position
			pointer_started = Time.get_ticks_msec()
			pointer_dragged = false
			stick_pointer = _controlled_walk() and event.position.x < 180 and event.position.y > 320
			if _parking_active() and Stage.BRAKE.has_point(event.position):
				parking_held = true
				parking_started = true
				_save()
		else:
			if not pointer_down:
				return
			var quick := not pointer_dragged and Time.get_ticks_msec() - pointer_started < 350
			if parking_held:
				parking_align = true
				parking_speed = 0.0
			if stick_pointer and pointer_dragged:
				_clear_movement()
			_reset_pointer()
			if quick and _controlled_walk():
				_handle_tap(event.position)
			_save()
		stage.accept_event()
	elif event is InputEventMouseMotion and pointer_down:
		var offset: Vector2 = event.position - pointer_start
		if offset.length() > 12:
			pointer_dragged = true
		if pointer_dragged:
			if stick_pointer:
				stick = (offset / 36.0).limit_length()
			elif shot.type == "drive" and absf(offset.x) >= 28:
				_set_lane(lane_target + (1 if offset.x > 0 else -1))
				pointer_start = event.position
		stage.accept_event()

func _reset_pointer() -> void:
	pointer_down = false
	pointer_dragged = false
	stick_pointer = false
	stick = Vector2.ZERO
	parking_held = false

func _controlled_walk() -> bool:
	return shot.get("chapterId") == "shanghai" and shot.get("type") == "walk"

func _parking_active() -> bool:
	return shot.get("fullId") == "shanghai/park" and not parking_done

func _walk_polygon() -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for point: Array in shot.get("walkArea", []):
		polygon.append(Vector2(float(point[0]), float(point[1])))
	return polygon

func _clamp_walk(point: Vector2) -> Vector2:
	var polygon := _walk_polygon()
	if polygon.size() < 3:
		return point.clamp(WALK_BOUNDS.position, WALK_BOUNDS.end)
	if Geometry2D.is_point_in_polygon(point, polygon):
		return point
	var nearest := polygon[0]
	for index in range(polygon.size()):
		var candidate := Geometry2D.get_closest_point_to_segment(point, polygon[index], polygon[(index + 1) % polygon.size()])
		if candidate.distance_squared_to(point) < nearest.distance_squared_to(point):
			nearest = candidate
	return nearest

func _nearby_hotspot() -> Dictionary:
	if not _controlled_walk():
		return {}
	for hotspot: Dictionary in shot.get("hotspots", []):
		var target := Vector2(float(hotspot.target[0]), float(hotspot.target[1]))
		if stage.player_feet.distance_to(target) <= 40.0:
			return hotspot
	return {}

func _sync_controls() -> void:
	stage.interaction = _nearby_hotspot() if not paused else {}
	stage.stick_visible = _controlled_walk() and not paused
	stage.stick_origin = pointer_start if stick_pointer else Vector2(64, 558)
	stage.stick_vector = stick
	stage.parking_active = _parking_active()
	stage.parking_progress = parking_progress
	stage.parking_pressed = parking_held
	stage.parking_angle = parking_angle

func _park(dt: float) -> void:
	if parking_align:
		parking_speed = 0.0
		parking_angle = move_toward(parking_angle, 0.0, dt * 0.28)
		if is_zero_approx(parking_angle):
			parking_done = true
			elapsed = 0.0
			stage.time = 0.0
			_present()
			_save()
	elif parking_held:
		parking_speed = move_toward(parking_speed, 0.12, dt * 0.8)
		parking_progress = minf(0.85, parking_progress + dt * parking_speed * 0.55)

func _unhandled_key_input(event: InputEvent) -> void:
	if paused or shot.get("type") != "drive" or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_left"):
		_set_lane(lane_target - 1)
	elif event.is_action_pressed("ui_right"):
		_set_lane(lane_target + 1)

func _handle_tap(position: Vector2) -> void:
	if paused:
		return
	match shot.type:
		"drive":
			if position.y >= 155.0:
				_set_lane(floori(position.x / 120.0))
		"chat":
			chat_fast = true
			_save()
		"notification":
			if Stage.PHONE.has_point(position):
				_advance()
		"walk":
			if _controlled_walk():
				var nearby := _nearby_hotspot()
				if not nearby.is_empty() and Stage.interaction_rect(nearby).has_point(position):
					_clear_movement()
					_advance()
					return
				if Geometry2D.is_point_in_polygon(position, _walk_polygon()):
					_walk_to(position, "")
				return
			for hotspot: Dictionary in shot.hotspots:
				var hit: Array = hotspot.hit
				if Rect2(float(hit[0]), float(hit[1]), float(hit[2]), float(hit[3])).has_point(position):
					_walk_to(Vector2(float(hotspot.target[0]), float(hotspot.target[1])), hotspot.id)
					return
			if Rect2(16, 385, 328, 94).has_point(position):
				_walk_to(position, "")

func _walk_to(destination: Vector2, hotspot: String) -> void:
	movement_target = _clamp_walk(destination) if _controlled_walk() else destination.clamp(WALK_BOUNDS.position, WALK_BOUNDS.end)
	pending_hotspot = hotspot
	moving = true

func _set_lane(target: int) -> void:
	lane_target = clampi(target, 0, 2)
	_save()

func _material_key(step: Dictionary) -> String:
	return "%s+%s+%s" % [state.runId, step.chapterId, step.materialId]

func _sync_materials() -> void:
	var applied := {}
	for step: Dictionary in playlist:
		if step.type == "material":
			applied[step.materialId] = state.materials.get(_material_key(step), "")
	applied.panda_used = state.get("pandaUsed", false)
	stage.materials = applied

func _save() -> void:
	state.elapsed = elapsed
	state.feet = [stage.player_feet.x, stage.player_feet.y]
	state.facing = stage.facing
	state.driveDistance = stage.distance
	state.slow = stage.slow
	state.lane = lane_target
	state.lanePosition = stage.lane
	state.hitIndex = hit_index
	state.chatFast = chat_fast
	state.walking = moving
	state.walkTarget = [movement_target.x, movement_target.y]
	state.parking = {"started": parking_started, "done": parking_done, "progress": parking_progress, "speed": parking_speed, "align": parking_align, "angle": parking_angle}
	state.revision = int(state.revision) + 1
	stage.save_failed = not Checkpoint.write(state)
	if stage.save_failed:
		state.revision = int(state.revision) - 1
	since_save = 0.0

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_set_paused(true)
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_IN]:
		_set_paused(false)

func _on_browser_visibility(args: Array) -> void:
	var pagehide: bool = not args.is_empty() and str(args[0].type) == "pagehide"
	_set_paused(pagehide or bool(JavaScriptBridge.get_interface("document").hidden))

func _set_paused(value: bool) -> void:
	if shot.is_empty() or paused == value:
		return
	paused = value
	if paused:
		if not _controlled_walk():
			_clear_movement()
		_reset_pointer()
		_save()
		_sync_controls()
		stage.queue_redraw()

func _present() -> void:
	for child in slots.get_children():
		slots.remove_child(child)
		child.queue_free()
	stage.chat_rows.clear()
	var chapter_title := "" if shot.type == "terminal" else _text(shot.titleId)
	if title.text != chapter_title:
		title.text = chapter_title
		_fade_in(title)
	var kind: String = shot.type
	match kind:
		"invite":
			_button(shot.objectiveId, Rect2(102, 72, 156, 41), _advance)
			_dialogue(_text(shot.copyId))
		"dialogue", "narration", "transition":
			if shot.has("copyId") and not _parking_active():
				_dialogue(_text(shot.copyId))
		"walk":
			_label(_text(shot.objectiveId), Rect2(24, 65, 312, 50), 15, Stage.CREAM, true)
		"chat":
			_present_chat()
		"notification":
			_button(shot.copyId, PHONE_NOTIFICATION, _advance)
		"phone":
			_label(_text(shot.groupId), Rect2(91, 453, 178, 55), 16, Stage.CREAM, true)
		"terminal":
			_label(_text(shot.copyId), Rect2(91, 441, 178, 59), 19, Stage.CREAM, true)
	if kind in ["walk", "drive"] and _needs_art():
		for child in slots.get_children():
			child.hide()
		_label("【缺图】", Rect2(20, 70, 320, 38), 15, Stage.ACCENT, true)
	stage.queue_redraw()

func _needs_art() -> bool:
	var backgrounds: Dictionary = stage.manifest.get("backgrounds", {})
	var background: String = "driving" if shot.type == "drive" else shot.background
	if not backgrounds.has(background):
		return true
	for actor: Dictionary in shot.visibleActors:
		if actor.mode == "sprite" and actor.layer == "world" and not stage.manifest.get("sprites", {}).has(actor.id):
			return true
	return false

func _present_chat() -> void:
	var first := active_index
	while first > 0 and playlist[first - 1].type == "chat" and playlist[first - 1].sceneId == shot.sceneId:
		first -= 1
	var y := 440.0
	var screen := stage.phone_screen_rect()
	for index in range(first, active_index + 1):
		var message: Dictionary = playlist[index]
		var text := _text(message.copyId)
		var latest := index == active_index
		if message.speaker == "system":
			stage.chat_rows.append({"speaker": "system", "skin": "bubble_system", "bubble": PHONE_NOTIFICATION})
			_label(text, PHONE_NOTIFICATION, 12, Stage.CREAM, latest)
			continue

		var right: bool = message.speaker == "ayu"
		var avatar_width := Stage.AVATAR_SIZE * 0.5
		var avatar_x := screen.end.x - avatar_width - 5 if right else screen.position.x + 5
		var width := 96.0 if right else 139.0
		var x := avatar_x - width - 4 if right else avatar_x + avatar_width + 4
		var label := Label.new()
		var text_box := Rect2(x + CHAT_PADDING_X, y + CHAT_PADDING_Y, width - CHAT_PADDING_X * 2, 1)
		_style_label(label, text_box, CHAT_FONT_SIZE, Stage.DARK_RED)
		label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		label.add_theme_constant_override("line_spacing", CHAT_LINE_SPACING)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.text = text
		slots.add_child(label)

		var line_count := label.get_line_count()
		var text_height := 0
		for line in range(line_count):
			text_height += label.get_line_height(line)
		text_height += CHAT_LINE_SPACING * maxi(0, line_count - 1)
		label.size.y = text_height
		var height := maxf(float(text_height) + 2 * CHAT_PADDING_Y, avatar_width + 2)
		stage.chat_rows.append({
			"speaker": message.speaker,
			"skin": "bubble_right" if right else "bubble_left",
			"bubble": Rect2(x, y, width, height),
			"avatar": Vector2(avatar_x, y + (height - avatar_width) * 0.5),
		})
		if latest:
			_fade_in(label, 2.0)
		y += height + CHAT_GAP

func _dialogue(text: String) -> void:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = DIALOGUE_BOX.position
	panel.size = DIALOGUE_BOX.size
	var skin := stage.pixel_skin("bubble_left")
	if skin:
		panel.add_theme_stylebox_override("panel", skin)
	slots.add_child(panel)
	_label(text, Rect2(42, 465, 276, 119), 18, Stage.DARK_RED, true)

func _button(id: String, rect: Rect2, action: Callable) -> void:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = _text(id)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 15)
	for state_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state_name, Stage.DARK_RED)
	var normal := stage.pixel_skin("bubble_right")
	var hover := stage.pixel_skin("bubble_left")
	if normal and hover:
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(func() -> void:
		if not paused:
			action.call()
	)
	slots.add_child(button)
	_fade_in(button)

func _label(text: String, rect: Rect2, font_size: int, color: Color, animate: bool, alignment := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	if "😂" in text:
		var rich := RichTextLabel.new()
		rich.bbcode_enabled = true
		rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rich.position = rect.position
		rich.size = rect.size
		rich.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rich.horizontal_alignment = alignment
		rich.add_theme_font_override("normal_font", FONT)
		rich.add_theme_font_size_override("normal_font_size", font_size)
		rich.add_theme_color_override("default_color", color)
		rich.text = text.replace("😂", "[img=18x18]res://hongyuan/assets/laugh.svg[/img]")
		slots.add_child(rich)
		if animate:
			_fade_in(rich)
		return
	var label := Label.new()
	_style_label(label, rect, font_size, color)
	label.horizontal_alignment = alignment
	label.text = text
	slots.add_child(label)
	if animate:
		_fade_in(label)

func _style_label(label: Label, rect: Rect2, font_size: int, color: Color) -> void:
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("line_spacing", 5)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.12, 0.02, 0.04, 0.74) if color == Stage.CREAM else Color.TRANSPARENT)
	label.add_theme_constant_override("shadow_offset_y", 1)

func _fade_in(control: Control, rise := 4.0) -> void:
	var target := control.position.y
	control.modulate.a = 0.0
	control.position.y += rise
	var tween := control.create_tween().set_parallel()
	tween.tween_property(control, "modulate:a", 1.0, 0.20)
	tween.tween_property(control, "position:y", target, 0.20)

func _text(id: String) -> String:
	return copy.get(id, "【待补】")

func _show_data_error() -> void:
	var label := Label.new()
	label.text = "【待补】"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _make_chime() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.mix_rate = 22050
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	var samples := PackedByteArray()
	samples.resize(1764 * 2)
	for frame in range(1764):
		var t := float(frame) / 22050.0
		var envelope := minf(t * 180.0, 1.0) * pow(1.0 - float(frame) / 1764.0, 2.0)
		var sample := int((sin(t * TAU * 740.0) + sin(t * TAU * 1110.0) * 0.32) * envelope * 12000.0)
		samples.encode_s16(frame * 2, sample)
	stream.data = samples
	return stream
