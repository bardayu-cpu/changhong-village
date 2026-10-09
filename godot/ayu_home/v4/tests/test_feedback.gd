extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var h
var checks:Array=[]
var failures:Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks.append({"pass":ok,"name":label})
	if not ok:failures.append(label)
func run() -> void:
	var file:="/private/tmp/ayu-v4-feedback.json"
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(file+suffix):DirAccess.remove_absolute(file+suffix)
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp)
	h=Home.new();h.town_profile={"id":"v4-feedback","avatar":2};h.save_path=file;vp.add_child(h);await process_frame
	h.set_process(false);h.set_test_clock(23);h.admitted=true;h.close_modal();h.enter_room("living",false)
	var on:bool=h.world.lamp_on;h.interact("lamp");check(h.world.lamp_on!=on,"灯点一次实际改变明暗")
	h.enter_room("dining",false);h.enter_room("living",false);check(h.world.lamp_on!=on,"返回房间保留灯的状态")
	h.interact("lamp");check(h.world.lamp_on==on,"再点一次切回原状态")
	for room in h.definitions:
		for spot in h.definitions[room].hotspots:
			if spot.get("kind","")!="tap":continue
			h.enter_room(room,false);h.interact(spot.id);h.update_water_audio();check(h.world.toggles.get(spot.id,false) and h.water_audio.playing,room+" 开水与水声同步")
			h.interact(spot.id);h.update_water_audio();check(not h.world.toggles.get(spot.id,true) and not h.water_audio.playing,room+" 关水立即停止")
	h.enter_room("guest_bath",false);h.interact("shower");h.elapsed=h.scene_until+.1;h.update_scene_action(.1);h.update_water_audio()
	check(not h.world.toggles.shower and h.player.action=="idle" and not h.water_audio.playing,"淋浴完成关闭水与动作，留下热气")
	check(h.world.steam_player_until>h.world.elapsed,"洗澡收尾保留场景热气")
	h.enter_room("study",false);h.interact("music");h.elapsed=h.scene_until+.1;h.update_scene_action(.1);check(h.scene_action.is_empty() and h.scene_until==0,"音乐完成不无限续播")
	for month in [3,7,10,1]:
		var list:Array=h.life.available(month,"flower");check(list.size()==3,"每季三种不同的花 "+str(month))
	check(not h.life.plant(0,"tomato",1),"不能在冬天种夏季种子")
	var f:=FileAccess.open("res://ayu_home/v4/evidence/feedback.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));f.close()
	print("RESULT ","PASS" if failures.is_empty() else "FAIL"," feedback ",checks.size()," ",JSON.stringify(failures));h.stop_audio();vp.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
