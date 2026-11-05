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
func run() -> void:
	var p := Harness.new()
	root.add_child(p)
	p.set_process(false)
	p._enter_step(p.step_indices["shanghai/drive"])
	for frame in range(4000): p._process(0.016)
	check(p.stage.distance == 0 and p.shot.id == "drive", "No-input driving never advances to parking")
	p._set_lane(1)
	check(not p.drive_started, "Selecting current lane cannot fake a steering action")
	p._set_lane(0)
	p._process(0.016)
	check(p.drive_started and p.stage.lane < 1 and p.stage.distance > 0, "Steering starts actual travel and lane movement")
	p.stage.distance = 43.0
	p.stage.lane = 0.0
	for frame in range(1600): p._process(0.016)
	check(p.shot.id == "drive" and p.stage.distance < 45 and p.stage.drive_exit, "Car waits at marked entrance until steered toward it")
	p._set_lane(2)
	for frame in range(300):
		if p.shot.id == "drive": p._process(0.016)
	check(p.shot.id == "park", "Steering into entrance completes arrival and reaches parking")
	check(p.Stage.traffic_lane(2, 0) == 2 and is_equal_approx(p.Stage.traffic_depth(2, 10.0, 0), 0.021), "Legacy traffic pattern remains unchanged")
	var different := false
	for index in range(1,10):
		if p.Stage.traffic_depth(index,10,111) != p.Stage.traffic_depth(index,10,222): different = true
	check(different, "Different seeds change traffic timing")
	p.state.driveDistance = 12.4
	p.state.driveStarted = true
	p.state.trafficSeed = 12345
	p.state.driveArrival = 0.0
	p._enter_step(p.step_indices["shanghai/drive"], true)
	check(p.drive_started and is_equal_approx(p.stage.distance,12.4) and p.stage.traffic_seed == 12345, "Resume keeps traffic seed and distance")
	p.state.erase("driveStarted")
	p.state.erase("trafficSeed")
	p._enter_step(p.step_indices["shanghai/drive"], true)
	check(p.drive_started and p.stage.traffic_seed == 0, "Old mid-drive save resumes its original traffic")
	p.stage.distance = 45.0
	p._drive(0.016)
	check(p.drive_arrival > 0 and p.parking_sound.playing, "Arrival has a dedicated sound and visible feedback interval")
	print("FAILURES ",failures)
	p.queue_free()
	await process_frame
	quit(failures)
