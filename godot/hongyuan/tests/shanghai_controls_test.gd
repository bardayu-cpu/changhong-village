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
	check(p.moving and p.shot.id == "board_car", "Far car tap approaches without triggering the interaction")
	p._walk_to(Vector2(263,432), "")
	for i in range(180): p._move(0.016)
	check(p.shot.id == "board_car" and not p._nearby_hotspot().is_empty(), "Arrival never automatically triggers")
	p._handle_tap(p.Stage.interaction_rect(p._nearby_hotspot()).get_center())
	check(p.shot.id == "drive", "Explicit nearby icon boards car")
	var drive = p.runner.game
	for i in range(100): drive.process(0.05)
	check(drive.scroll == 0 and drive.phase == "ready", "Current driving waits for explicit start")
	drive.input("tap", drive._go_rect().get_center())
	drive.input("down", Vector2(180,500))
	drive.input("move", Vector2(230,500))
	drive.input("up", Vector2(230,500))
	check(drive.lane == 2, "Current driving accepts swipe")
	drive.car_x = drive.LANES[2]
	drive.speed = 200
	drive.traffic = [{"lane":2,"y":500.0,"v":100.0,"kind":1,"hit":false}]
	drive._traffic(0.016)
	check(drive.bump > 0 and drive.speed < 200, "Collision slows without failure")
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
	p._enter_step(p.step_indices["chengdu/chengdu_walk"])
	check(p._controlled_walk(), "Chengdu uses the same walking controls")
	p.state.bambooHeld = false
	p.state.pandaUsed = false
	p.stage.player_feet = Vector2(111,445)
	check(p._nearby_hotspot().is_empty(), "Cannot feed without bamboo")
	p.stage.player_feet = Vector2(182,437)
	p._handle_tap(p.Stage.interaction_rect(p._nearby_hotspot()).get_center())
	check(p.state.bambooHeld and not p.state.pandaUsed, "Picking bamboo does not advance")
	p.stage.player_feet = Vector2(111,445)
	p._handle_tap(p.Stage.interaction_rect(p._nearby_hotspot()).get_center())
	check(not p.state.bambooHeld and p.state.pandaUsed and p.stage.panda_time > 0, "Feeding consumes bamboo with visible response")
	p.stage.player_feet = Vector2(263,449)
	p._handle_tap(p.Stage.interaction_rect(p._nearby_hotspot()).get_center())
	check(p.shot.id == "chengdu_ping", "Phone opens only after manual interaction")
	p._enter_step(p.step_indices["chengdu/chengdu_walk"])
	p.state.pandaUsed = false
	p.stage.player_feet = Vector2(263,449)
	p._handle_tap(p.Stage.interaction_rect(p._nearby_hotspot()).get_center())
	check(p.shot.id == "chengdu_ping" and not p.state.pandaUsed, "Skipping optional feed reaches the same locked phone story")
	# Restore fixtures are serialized through JSON as actual version-1 saves are.
	p.state = {"version": 1, "runId": "d2-fixture", "materials": {}, "feet": [160, 450], "facing": -1, "walking": true, "walkTarget": [210, 450]}
	p.state = JSON.parse_string(JSON.stringify(p.state))
	p._enter_step(p.step_indices["shanghai/board_car"], true)
	check(p.stage.player_feet == Vector2(160,450) and p.moving and p.movement_target == Vector2(210,450), "Walking save restores feet and tap destination")
	print("FAILURES ", failures)
	p.queue_free()
	quit(failures)

func check_point(p: Node, q: Vector2) -> void:
	# Closest-point boundary output must be a fixed point of the clamp as well.
	if q.distance_to(p._clamp_walk(q)) > 0.001:
		failures += 1
