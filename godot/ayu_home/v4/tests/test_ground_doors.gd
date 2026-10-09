extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var h
var checks:Array=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp);h=Home.new();h.town_profile={"id":"doors-qa"};h.save_path="/private/tmp/ayu-v4-doors.json";vp.add_child(h);await process_frame;h.set_process(false);h.set_test_clock(12.25);h.admitted=true;h.close_modal()
	for room in h.definitions:
		for d in h.definitions[room].doors:
			h.enter_room(room,false)
			for i in 15:h._process(.1)
			h.pending="";h.player.route=h.world.path(h.player.position,h.world.nearest(h.World.v(d.approach)));var steps:=0
			while h.area==room and not h.player.route.is_empty() and steps<1000:h._process(.1);steps+=1;await process_frame
			if h.transition:await create_timer(.45).timeout
			var ok:bool=h.area==d.target;checks.append({"room":room,"door":d.id,"target":d.target,"arrived":h.area,"pass":ok});print(JSON.stringify(checks.back()))
	var failed:Array=checks.filter(func(c):return not c.pass);var f:=FileAccess.open("res://ayu_home/v4/evidence/ground-doors.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"));f.close();print("RESULT ","PASS" if failed.is_empty() else "FAIL"," ",failed.size());h.stop_audio();vp.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
