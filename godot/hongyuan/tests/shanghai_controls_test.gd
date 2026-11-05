extends SceneTree

class Harness extends "res://hongyuan/player.gd":
	func _save() -> void:
		pass

var failures := 0
func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
	else:
		print("PASS ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var p := Harness.new()
	root.add_child(p)
	p.set_process(false)
	p._enter_step(p.step_indices["shanghai/board_car"])
	check(p._controlled_walk(), "Shanghai controlled walk")
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(60,550)
	p._on_stage_input(down)
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(100,530)
	p._on_stage_input(drag)
	for i in range(120): p._move(0.016)
	check(p.stage.player_feet.x > 104 and p.stage.player_feet.y >= 412, "Lower-left drag moves with polygon constraint")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = drag.position
	p._on_stage_input(up)
	check(p.stage.walk_frame == -1 and not p.moving, "Joystick release returns to idle immediately")
	p.stage.player_feet = Vector2(104,451)
	p._handle_tap(Vector2(263, 380))
	check(not p.moving and p.shot.id == "board_car", "Far car tap does not move or trigger")
	p._walk_to(Vector2(263,432), "")
	for i in range(180): p._move(0.016)
	check(p.shot.id == "board_car" and not p._nearby_hotspot().is_empty(), "Arrival never automatically triggers")
	p._handle_tap(p.Stage.interaction_rect(p._nearby_hotspot()).get_center())
	check(p.shot.id == "drive", "Explicit nearby icon boards car")
	p._set_lane(2)
	p.stage.distance = 4.9
	p.stage.lane = 1
	p._drive(0.016)
	check(p.stage.slow > 0 and p.shot.id == "drive", "Collision slows without failure")
	p._enter_step(p.step_indices["shanghai/park"])
	for i in range(200): p._process(0.016)
	check(p.shot.id == "park" and not p.parking_done and p.elapsed == 0, "Parking waits for player")
	p.parking_held = true
	p.parking_started = true
	for i in range(60): p._process(0.016)
	check(p.parking_progress > 0 and p.parking_speed < 1, "Brake hold moves and slows car")
	var stopped_at: float = p.parking_progress
	p.parking_held = false
	p.parking_align = true
	for i in range(80): p._process(0.016)
	check(p.parking_done, "Brake release completes automatic alignment")
	check(p.parking_progress == stopped_at and p.parking_speed == 0 and p.parking_angle == 0, "Release stops translation and straightens only")
	p._enter_step(p.step_indices["shanghai/approach_axiao"])
	for x in range(-100,500,9):
		for y in range(200,700,11):
			var q := p._clamp_walk(Vector2(x,y))
			check_point(p, q)
	p.stage.player_feet = Vector2(232,456)
	p.stage.facing = -1
	p._advance()
	check(p.stage._feet({"id":"ayu"}) == Vector2(232,456), "Dialogue preserves feet")
	check(not p.stage.stick_visible and p.stage.interaction.is_empty(), "Dialogue hides movement and interaction controls")
	p.state.erase("parking")
	p._enter_step(p.step_indices["shanghai/park"], true)
	check(p.parking_done, "Legacy W1 park resumes existing narration")
	p._enter_step(p.step_indices["chengdu/panda_walk"] if p.step_indices.has("chengdu/panda_walk") else p.step_indices["prologue/open"] if p.step_indices.has("prologue/open") else 0)
	check(not p._controlled_walk(), "Other chapters keep existing controls")
	# Restore fixtures are serialized through JSON as actual version-1 saves are.
	p.state = {"version": 1, "runId": "d2-fixture", "materials": {}, "feet": [160, 450], "facing": -1, "walking": true, "walkTarget": [210, 450]}
	p.state = JSON.parse_string(JSON.stringify(p.state))
	p._enter_step(p.step_indices["shanghai/board_car"], true)
	check(p.stage.player_feet == Vector2(160,450) and p.moving and p.movement_target == Vector2(210,450), "Walking save restores feet and tap destination")
	for fixture in [
		{"started":true,"done":false,"progress":0.23,"speed":0.5,"align":false,"angle":-0.14},
		{"started":true,"done":false,"progress":0.23,"speed":0.0,"align":true,"angle":-0.07},
		{"started":true,"done":true,"progress":0.23,"speed":0.0,"align":true,"angle":0.0}
	]:
		p.state.parking = JSON.parse_string(JSON.stringify(fixture))
		p._enter_step(p.step_indices["shanghai/park"], true)
		check(is_equal_approx(p.parking_progress,0.23) and p.parking_done == fixture.done and not p.parking_held, "Parking restore preserves progress and clears physical hold")
		p._process(0.016)
		check(is_equal_approx(p.parking_progress,0.23), "Parking restore never translates without a new press")
	p.state.parking = {"started":true,"done":false,"progress":0.3,"speed":0.0,"align":true}
	p._enter_step(p.step_indices["shanghai/park"], true)
	check(p.parking_angle < 0 and not p.parking_done, "R2 save without angle gets compatible alignment")
	print("FAILURES ", failures)
	p.queue_free()
	quit(failures)

func check_point(p: Node, q: Vector2) -> void:
	# Closest-point boundary output must be a fixed point of the clamp as well.
	if q.distance_to(p._clamp_walk(q)) > 0.001:
		failures += 1
