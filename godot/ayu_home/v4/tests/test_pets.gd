extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp);var h=Home.new();h.town_profile={"id":"pet-probe"};h.save_path="/private/tmp/ayu-v4-pet-probe.json";vp.add_child(h);await process_frame;h.set_test_clock(23);h.admitted=true;h.enter_room("cats",false);h.close_modal();h.set_process(false)
	for id in ["qiuqiu","luoluo","tiantian"]:
		print("BEFORE ",id," area=",h.area," target=",h.people[id].position," visitor=",h.player.position," visible=",h.people[id].visible)
		h.go("person:"+id)
		for i in 150:h._process(.1);await process_frame
		print("AFTER ",id," area=",h.area," pending=",h.pending," route=",h.player.route.size()," busy=",h.busy()," controls=",h.scene_controls," visitor=",h.player.position," note=",h.note," cats=",h.life.cats_today())
	h.stop_audio();vp.queue_free();await process_frame;quit()
