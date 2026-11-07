extends SceneTree
const Runner := preload("res://hongyuan/scene_runner.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func step(g, duration: float) -> void:
	for i in range(ceili(duration / 0.02)): g.process(0.02)
func run() -> void:
	var r := Runner.new()
	r.setup({"personHeight":128,"start":[180,400],"beats":[{"game":"fishing"}]},{},{})
	root.add_child(r);r.set_process(false);r.begin(0)
	var g = r.game
	g.input("down",Vector2(180,560));step(g,0.6);g.input("up",Vector2(180,560))
	check(g.phase == "backcast", "release first shows backcast")
	check(g.has_method("draw_body"),"backswing uses the articulated same Ayu body")
	step(g,0.3)
	check(g.phase == "cast","backswing enters a visible forward swing")
	step(g,0.24)
	check(g.phase == "fly" and g.from.distance_to(g._tip()) < 4,"lure launches at the visible forward rod tip")
	check(r._player_frame().ends_with("ayu_fish_hold.png"),"forward swing returns to same Ayu fishing body")
	step(g,0.65)
	check(g.phase == "wait" and g.bob.distance_to(g._landing()) < 0.01,"flight lands continuously at water point")
	g.wait_for = 0.1;step(g,0.12);g.input("tap",Vector2(180,560))
	check(g.phase == "reel","bite input starts a visible retrieve before reward")
	step(g,0.6)
	check(g.phase == "caught" and g.bob.distance_to(r.feet) < 55,"retrieve pulls fish near hand before landing")
	step(g,1.7)
	check(g.process(0) and r.pose == "","finish returns to standing pose")
	g.phase = "bite";g.t = 2.9;step(g,0.2)
	check(g.phase == "aim" and g.missed,"missed bite returns to a retry without failure")
	r.free()
	print("FAILURES ",failures)
	quit(failures)
