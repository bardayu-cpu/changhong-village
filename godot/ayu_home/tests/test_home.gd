extends SceneTree
const Data = preload("res://ayu_home/home_data.gd")
const World = preload("res://ayu_home/world.gd")
const Home = preload("res://ayu_home/home.gd")
const Art = preload("res://ayu_home/asset_store.gd")
class FailedCloud extends Node:
	func call_fn(_method: String, _args: Dictionary, callback: Callable, _timeout: float) -> void:
		call_deferred("_respond",callback)
	func _respond(callback: Callable) -> void:
		callback.call({"ok":false,"reason":"test_network"})
var failures := []
var checks := 0

func check(value: bool, name: String) -> void:
	checks += 1
	if not value: failures.append(name); print("FAIL ",name)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for time in [7.5,8.0,12.0,12.5,18.0,18.5]:
		for id in Data.FAMILY:
			var state := Data.state(id,time)
			check(state.area == "floor1" and state.action == "eat","three at table %s %s" % [time,id])
	check(Data.at_home(9.5).is_empty(),"all away")
	check(Data.at_home(10.5) == ["ayu","mother"],"only father away")
	check(Data.at_home(14.5) == ["ayu","father"],"only mother away")
	for hour in range(24):
		for id in Data.FAMILY: check(Data.state(id,float(hour)).has("action"),"24h schedule")
	for pair in [[4,0],[7,1],[10,2],[1,3]]: check(Data.season(pair[0]) == pair[1],"four seasons")
	var world := World.new()
	root.add_child(world)
	for area in Data.AREAS:
		world.set_area(area)
		var start := world.nearest(Data.spawn(area))
		for item: Dictionary in Data.hotspots(area):
			var route := world.path(start,item.approach)
			check(not route.is_empty(),"reachable %s / %s" % [area,item.id])
			for point in route: check(world.walkable(point),"route avoids wall and furniture")
		for room: String in Data.rooms(area):
			var target := world.nearest(Data.rooms(area)[room].get_center())
			check(not world.path(start,target).is_empty(),"room connected %s / %s" % [area,room])
	world.queue_free()
	var home := Home.new()
	home.save_path = "/private/tmp/ayu-life-test.json"
	root.add_child(home)
	await process_frame
	home.set_test_clock(9.5,4)
	home._knock()
	check(not home.admitted and is_instance_valid(home.overlay),"unoccupied knock has clear return options")
	home._switch_area("garden")
	home._visit(Data.hotspots("garden")[0])
	check(not home.pending.is_empty(),"unoccupied visitors can play in garden")
	home._switch_area("exterior")
	home._close_panel()
	home.set_test_clock(12.5,7)
	home._knock()
	check(home.knock_host == "father" and is_instance_valid(home.overlay),"occupied knock response")
	home.admitted = true
	home._switch_area("floor1")
	check(home.area == "floor1" and home.world.walkable(home.player.position),"entered safely")
	home._interact("exit")
	check(home.area == "exterior" and not home.admitted,"leave safely resets visitor admission")
	home.set_identity(true)
	home.set_test_clock(9.5,10)
	home._knock()
	check(home.admitted,"owner can enter when everyone away")
	home._switch_area("floor2")
	var clock_before := home.hour
	home._interact("relax")
	check(home.resting,"guest bed lies down")
	home.activities.close()
	check(not home.resting and home.hour == clock_before,"bed rises without changing time")
	check(home.world.walkable(home.player.position),"bed return foot point safe")
	home._activity_completed("guitar")
	check(home.journal.completed.get("guitar",0) > 0,"activity recorded in life book")
	home.journal.garden_saved_harvest = 5
	home._save_life()
	var saved_count: int = home.journal.entries.size()
	home.journal.entries.clear()
	home._load_life()
	check(home.journal.entries.size() == saved_count,"local life book persisted")
	check(home.journal.garden_saved_harvest == 5,"harvest count survives JSON numeric reload")
	home.queue_free()
	await process_frame
	var failing := Home.new()
	failing.save_path = "/private/tmp/ayu-life-fail-test.json"
	failing.asset_test_config = {"files":{"missing-test.png":{"bytes":1,"sha256":"invalid","file_id":""}}}
	root.add_child(failing)
	await process_frame
	check(not failing.bootstrapped and failing.player == null,"missing artwork stops cleanly before player creation")
	check(is_instance_valid(failing.overlay),"missing artwork has friendly retry and return UI")
	var mock := FailedCloud.new()
	failing.add_child(mock)
	failing.cloud_rpc = mock
	failing.art_store.cache_root = "/private/tmp/ayu-art-failed/"
	failing.art_store.config.files["missing-test.png"].file_id = "test-id"
	await failing._bootstrap()
	check(not failing.bootstrapped and is_instance_valid(failing.overlay),"failed download returns friendly retry UI")
	failing.art_store.config = Art.manifest()
	await failing._bootstrap()
	check(failing.bootstrapped and failing.player != null,"retry recovers after artwork becomes available")
	failing.queue_free()
	await process_frame
	print("HOME_CHECKS ",checks," FAILURES ",failures.size())
	print("RESULT PASS" if failures.is_empty() else "RESULT FAIL")
	quit(0 if failures.is_empty() else 1)
