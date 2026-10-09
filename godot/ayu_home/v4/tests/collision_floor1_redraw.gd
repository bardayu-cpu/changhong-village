extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var h
var checks:Array=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp);h=Home.new();h.town_profile={"id":"floor1-collision"};h.save_path="/private/tmp/ayu-floor1-collision.json";vp.add_child(h);await process_frame;h.set_process(false);h.set_test_clock(12.25);h.admitted=true;h.close_modal();h.sound_on=false
	var cases={"living":[838,645,KEY_LEFT],"dining":[656,282,KEY_LEFT],"kitchen":[275,231,KEY_UP],"laundry":[236,392,KEY_UP],"cats":[785,278,KEY_RIGHT],"stairs1":[935,310,KEY_LEFT],"mahjong":[1325,249,KEY_LEFT],"parents":[1343,690,KEY_LEFT],"workshop":[127,690,KEY_UP],"garage":[475,645,KEY_LEFT],"closet1":[1107,450,KEY_RIGHT],"bath1":[1264,495,KEY_UP]}
	for room in cases:
		h.enter_room(room,false)
		for i in 15:h._process(.1)
		var c:Array=cases[room];var cfg:Dictionary=h.world.cfg;var p:=Vector2(c[0]-cfg.source_crop[0]+cfg.source_offset[0],c[1]-cfg.source_crop[1]+cfg.source_offset[1]);h.player.position=h.world.nearest(p);var start:Vector2=h.player.position
		var e:=InputEventKey.new();e.physical_keycode=c[2];e.pressed=true;Input.parse_input_event(e);await process_frame
		for i in 20:h._process(.1)
		var stopped:Vector2=h.player.position
		for i in 20:h._process(.1)
		e.pressed=false;Input.parse_input_event(e);await process_frame
		var ok:bool=h.area==room and h.world.walkable(h.player.position) and stopped.distance_to(h.player.position)<.01 and stopped.distance_to(start)>2
		checks.append({"room":room,"pass":ok,"distance_until_blocked":stopped.distance_to(start),"continued_key_drift":stopped.distance_to(h.player.position)});print(JSON.stringify(checks.back()))
	# The existing explicit stair route visits the treads; normal door cooldown remains active.
	h.enter_room("stairs1",false)
	for i in 15:h._process(.1)
	var before:int=h.stair_steps;h.go("to_stairs2");var ticks:=0
	while h.area=="stairs1" and ticks<600:
		h._process(.1);ticks+=1
		if ticks%20==0:await process_frame
	if h.transition:await create_timer(.4).timeout
	checks.append({"room":"stairs1","pass":h.area=="stairs2" and h.stair_steps-before>=8,"stair_treads":h.stair_steps-before,"arrived":h.area})
	var f:=FileAccess.open("res://ayu_home/v4/evidence/floor1-redraw/collision-checks.json",FileAccess.WRITE);f.store_string(JSON.stringify(checks,"  "));f.close();var failed:Array=checks.filter(func(c):return not c.pass);print("RESULT ","PASS" if failed.is_empty() else "FAIL");h.stop_audio();vp.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
