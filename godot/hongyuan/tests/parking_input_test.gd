extends SceneTree
class Harness extends "res://hongyuan/player.gd":
	func _save() -> void:
		pass
var failures := 0
func check(ok: bool, label: String) -> void:
	if ok: print("PASS ", label)
	else:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func button(p: Node, position: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = position
	e.pressed = pressed
	p._on_stage_input(e)
func drag(p: Node, position: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = position
	p._on_stage_input(e)
func start(p: Node) -> void:
	p._enter_step(p.step_indices["shanghai/park"])
	p.parking_angle = 0.18
	p.parking_lateral = 0.0
	p._sync_controls()
func run() -> void:
	var p := Harness.new()
	root.add_child(p)
	p.set_process(false)
	var origin: Vector2 = p.Stage.STEERING.get_center()
	start(p)
	button(p, origin, true)
	p._process(0.05)
	button(p, origin, false)
	for frame in range(120): p._process(0.016)
	check(not p.parking_done and not p.parking_align and p.parking_speed == 0, "A short tap cannot auto-complete parking")
	button(p, origin, true)
	for frame in range(30): p._process(0.016)
	check(p.parking_speed > 0 and p.parking_progress > 0.05, "Holding again after a short tap resumes movement")
	button(p, origin, false)
	for frame in range(120): p._process(0.016)
	check(not p.parking_done, "Straight holding cannot substitute for steering")
	button(p, origin, true)
	drag(p, origin + Vector2(-36,0))
	button(p, origin + Vector2(-36,0), false)
	for frame in range(120): p._process(0.016)
	check(p.parking_done, "After steering the stopped car can complete without failure")
	var result: Array[float] = []
	for direction in [-1, 1]:
		start(p)
		button(p, origin, true)
		check(p.stage.parking_pressed and p.parking_sound.playing, "Press immediately draws feedback and starts sound")
		drag(p, origin + Vector2(direction * 56, 0))
		check(signf(p.parking_angle) == direction, "Drag directly changes visible car angle")
		for frame in range(40): p._process(0.016)
		result.append(p.parking_lateral)
		var stopped: Vector2 = p.stage.parking_offset
		button(p, origin + Vector2(direction * 56, 0), false)
		check(p.parking_speed == 0.0, "Real release event zeroes speed")
		for frame in range(100): p._process(0.016)
		check(p.stage.parking_offset.is_equal_approx(stopped), "Assistance and completion never translate parked car")
		check(p.parking_done and p.parking_angle == 0.0, "Poor angle straightens without failure")
	check(result[0] < -1 and result[1] > 1 and result[1] - result[0] > 4, "Opposite gestures produce different parking positions")
	start(p)
	button(p, origin, true)
	drag(p, origin + Vector2(-36, 0))
	button(p, origin + Vector2(-36, 0), false)
	check(p.parking_done and p.stage.parking_feedback > 0.0, "Accurate steering completes on release without assistance delay")
	start(p)
	button(p, origin, true)
	drag(p, origin + Vector2(500, 0))
	for frame in range(600): p._process(0.016)
	check(absf(p.parking_angle) <= 0.30 and absf(p.parking_lateral) <= 6.0, "Extreme and sustained drag stays bounded")
	p._set_paused(true)
	check(not p.parking_held and not p.pointer_down, "Focus loss clears held gesture")
	p._set_paused(false)
	var stopped: Vector2 = p.stage.parking_offset
	for frame in range(30): p._process(0.016)
	check(p.stage.parking_offset.is_equal_approx(stopped), "Focus return does not resume a physical press")
	p.state.parking = {"started":true,"done":false,"progress":0.3,"speed":0.2,"align":false,"angle":-0.14}
	p._enter_step(p.step_indices["shanghai/park"],true)
	check(p.stage.parking_offset.is_equal_approx(Vector2(12.6,7.0)), "R3 save migrates without moving its car")
	button(p, origin, true)
	drag(p, origin + Vector2(56,0))
	check(p.parking_angle > 0, "Migrated R3 save supports new steering")
	for frame in range(15): p._process(0.016)
	var offset: Vector2 = p.stage.parking_offset
	var angle: float = p.parking_angle
	p.state.parking = JSON.parse_string(JSON.stringify({"started":true,"done":false,"progress":p.parking_progress,"speed":p.parking_speed,"align":false,"angle":p.parking_angle,"lateral":p.parking_lateral,"baseX":p.parking_base_x,"steeringVersion":1}))
	p._enter_step(p.step_indices["shanghai/park"],true)
	check(p.stage.parking_offset.is_equal_approx(offset) and is_equal_approx(p.parking_angle,angle) and not p.parking_held, "R4 JSON restore keeps position and angle but no stale hold")
	var angles: Array[float] = []
	for attempt in range(5):
		p._enter_step(p.step_indices["shanghai/park"])
		angles.append(p.parking_angle)
	check(angles.min() != angles.max(), "Five entries vary initial approach angle")
	print("FAILURES ", failures)
	p.queue_free()
	await process_frame
	quit(failures)
