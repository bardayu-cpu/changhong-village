extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var h
var checks:Array=[]
var failures:Array=[]
func _initialize() -> void:call_deferred("run")
func close_ui() -> void:
	h.close_modal();h.games.close(false);h.activities.close();h.immersive.close(false);h.photo.close(false);h.clear_scene_controls();h.stand_up()
func tick(n:int) -> void:
	for i in n:
		h._process(.1)
		if i%20==0:await process_frame
func walk(id:String,room:String,door:=false) -> void:
	close_ui();h.go(id);var route_start:int=h.player.route.size();var i:=0
	while not h.pending.is_empty() and h.area==room and i<4000:
		h._process(.1);i+=1
		if i%25==0:await process_frame
	if h.transition:await create_timer(.5).timeout
	var opened_room:String=h.area
	if not door:
		await tick(40)
		var ok:bool=h.area==room and h.pending.is_empty() and route_start>0
		checks.append({"room":room,"object":id,"ok":ok,"route_points":route_start,"after_room":h.area,"steps":i})
		if not ok:failures.append(checks.back())
	else:
		var target:String=h.definitions[room].doors.filter(func(d):return d.id==id)[0].target
		var ok:bool=opened_room==target
		checks.append({"room":room,"door":id,"ok":ok,"after_room":opened_room,"stair_steps":h.stair_steps})
		if not ok:failures.append(checks.back())
	print(JSON.stringify(checks.back()))
func run() -> void:
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp)
	h=Home.new();h.town_profile={"id":"v4-actions-isolated","avatar":2};h.save_path="/private/tmp/ayu-v4-actions.json";vp.add_child(h);await process_frame
	h.set_process(false);h.set_test_clock(12.25);h.admitted=true;h.close_modal()
	for room in h.definitions:
		for spot in h.definitions[room].hotspots:
			close_ui();h.enter_room(room,false);await tick(15);await walk(spot.id,room)
		for door in h.definitions[room].doors:
			close_ui();h.enter_room(room,false);await tick(15);await walk(door.id,room,true)
	var f:=FileAccess.open("res://ayu_home/v4/evidence/walk-actions.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));f.close()
	h.stop_audio();vp.queue_free();await process_frame;print("RESULT ","PASS" if failures.is_empty() else "FAIL", " checks=",checks.size()," failures=",failures.size());quit(0 if failures.is_empty() else 1)
