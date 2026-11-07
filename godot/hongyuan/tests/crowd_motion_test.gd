extends SceneTree
const Crowd := preload("res://hongyuan/crowd_motion.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func _initialize() -> void:
	var crowd := Crowd.new()
	crowd.setup([{"a":[0,0],"b":[100,0],"speed":20,"pause":1,"radius":12}])
	for i in range(100): crowd.advance(0.05,Vector2(50,0),true)
	check(crowd.at(0).pos.x <= 38.1 and not crowd.at(0).walking, "walker waits at player personal space")
	var before: Vector2 = crowd.at(0).pos
	crowd.advance(0.05,Vector2(50,50),true)
	check(crowd.at(0).pos.x > before.x and crowd.at(0).pos.distance_to(before) <= 1.01,"walker resumes without teleport after player leaves")
	for i in range(62): crowd.advance(0.05,Vector2.ZERO,false)
	check(crowd.at(0).pos.is_equal_approx(Vector2(100,0)) and crowd.at(0).pause > 0,"walker stops at end of route")
	var distance := float(crowd.at(0).distance)
	for i in range(8): crowd.advance(0.05,Vector2.ZERO,false)
	check(is_equal_approx(crowd.at(0).distance,distance) and not crowd.at(0).walking,"idle pause does not advance walking animation")
	for i in range(25): crowd.advance(0.05,Vector2.ZERO,false)
	check(crowd.at(0).pos.x < 100 and crowd.at(0).heading.x < 0,"walker turns and walks back continuously")
	crowd.setup([{"a":[0,0],"b":[100,0],"speed":40},{"a":[0,0],"b":[100,0],"speed":10,"phase":0.15}])
	for i in range(30): crowd.advance(0.05,Vector2.ZERO,false)
	check(crowd.at(0).pos.distance_to(crowd.at(1).pos) >= 11.9,"faster walker waits behind slower pedestrian")
	crowd.setup([])
	crowd.advance(1,Vector2.ZERO,false)
	check(crowd.states.is_empty(),"scene reset removes old walkers")
	print("FAILURES ",failures)
	quit(failures)
