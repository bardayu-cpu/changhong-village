extends SceneTree
const Home = preload("res://ayu_home/home.gd")
const Data = preload("res://ayu_home/home_data.gd")
var home
var surface: SubViewport
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		push_error("INTEGRATION_FAIL " + label)
		quit(1)
		assert(value,label)

func touch(point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = true
	surface.push_input(event,true)
	await process_frame
	event = InputEventScreenTouch.new()
	event.position = point
	event.pressed = false
	surface.push_input(event,true)
	await process_frame

func press(text: String) -> void:
	for node in home.ui.find_children("*","Button",true,false):
		if node.text == text:
			await touch(node.get_global_rect().get_center())
			return
	check(false,"button missing: " + text)

func run() -> void:
	surface = SubViewport.new()
	surface.size = Vector2i(540,960)
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	home = Home.new()
	home.save_path = "/private/tmp/ayu-integration-life-%s.json" % Time.get_ticks_usec()
	surface.add_child(home)
	for i in range(4): await process_frame
	check(home.bootstrapped,"all art decoded before scene begins")
	home.overview = true
	home.set_test_clock(12.5,10)
	home._camera(true)
	var door: Dictionary = Data.hotspots("exterior")[0]
	await touch(home.world.position + door.pos * home.frame_scale)
	check(home.pending.get("id","") == "door","real touch selects front door")
	for step in range(3000):
		if home.player_path.is_empty(): break
		home._move_player(1.0/30.0)
		check(home.world.walkable(home.player.position),"touch route stays on walkable ground")
	check(is_instance_valid(home.overlay) and not home.admitted,"knocking waits for invitation")
	await process_frame
	await press("进门做客")
	check(home.area == "floor1" and home.admitted,"real touch accepts invitation")
	await process_frame
	await press("屋内导览")
	check(is_instance_valid(home.overlay),"touch opens navigation")
	var position_before: Vector2 = home.player.position
	await touch(Vector2(530,300))
	check(home.player.position == position_before and home.player_path.is_empty(),"modal blocks background walking")
	home._close_panel()
	for area in ["floor1","floor2","garden","exterior"]:
		home._switch_area(area)
		for month in [4,7,10,1]:
			home.set_test_clock(15.5,month)
			check(home.world.art != null,"scene art present " + area)
	# A complete UI-driven visit never alters the shared wedding wallet.
	check(not home.journal.has("coins"),"life save is independent of wallet")
	home.set_test_clock(12,10)
	home.admitted = true
	home._switch_area("floor1")
	home._open_activity("garden")
	var garden = home.activities.garden_panel
	garden.plant(0,"南瓜")
	garden.water_all()
	var next_time: float = home.journal.garden_state.beds[0].ready_at
	home.activities.close()
	home.journal.garden_state = {}
	home._load_life()
	check(absf(float(home.journal.garden_state.beds[0].ready_at) - next_time) < 0.01,"watering persists across reload")
	home._open_activity("garden")
	home.activities.garden_panel.now_override = next_time + 1
	home.activities.garden_panel.harvest(0)
	var harvests: int = home.journal.completed.get("garden",0)
	home.activities.close()
	home._load_life()
	home._open_activity("garden")
	home.activities.garden_panel.harvest(0)
	check(int(home.journal.completed.get("garden",0)) == harvests,"reload cannot duplicate a harvest")
	home.activities.close()
	home._switch_area("exterior")
	home._interact("gate")
	var has_exit := false
	for node in home.ui.find_children("*","Button",true,false):
		if node.text == "回到镇上":
			for connection in node.pressed.get_connections():
				has_exit = has_exit or connection.callable.get_method() == "_return_to_town"
	check(has_exit,"gate has a wired return to main scene")
	home.queue_free()
	await process_frame
	print("RESULT PASS integration ",checks," touch / invitation / modal / all art / persistent gardening / no duplicate harvest")
	quit()
