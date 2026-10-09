extends SceneTree
## 第四轮前后对比截图（540×960，开真窗口）
const Home=preload("res://ayu_home/v4/home.gd")
var h
var vp:SubViewport
var out:=""
func _initialize() -> void:call_deferred("run")
func shot(tag:String) -> void:
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out+tag+".png");print("SHOT ",tag)
func tick(n:=30) -> void:
	for i in n:h._process(0.05)
	h.transition=false;h.fade.color.a=0
func stand(room:String,at:Vector2,from:="") -> void:
	h.enter_room(room,false,from);h.player.position=h.world.nearest(at);h.camera=h.player.position-Vector2(0,65);tick(40)
func near_person(id:String,offset:Vector2) -> void:
	var a=h.people[id];h.player.position=h.world.nearest(a.position+offset);h.camera=h.player.position-Vector2(0,65);tick(30)
func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):out=a.substr(6)
	if not out.ends_with("/"):out+="/"
	DirAccess.make_dir_recursive_absolute(out)
	var save:=OS.get_user_data_dir()+"/claude-shots4.json";DirAccess.remove_absolute(save);DirAccess.remove_absolute(save+".bak")
	vp=SubViewport.new();vp.size=Vector2i(540,960);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	h=Home.new();h.town_profile={"id":"claude-shots4","avatar":2};h.save_path=save;vp.add_child(h);await process_frame;h.set_process(false);h.sound_on=false;h.admitted=true;h.close_modal()
	# 1 家人头上的「!」
	var got:=false
	for hr in [15.5,20.0,19.0,16.5,10.5,21.0]:
		h.set_test_clock(hr);h.enter_room("living",false,"exterior");tick(900)
		for id in ["ayu","mother","father"]:
			if h.people[id].visible and h.family_state[id].room=="living" and h.people[id].route.is_empty():
				near_person(id,Vector2(60,30));print("living ",hr," ",id," action=",h.people[id].action);await shot("01-客厅-家人头上的感叹号");got=true;break
		if got:break
	h.set_test_clock(23.5);stand("parents",Vector2(176,330),"closet1");near_person("mother",Vector2(40,90));await shot("02-深夜-妈妈睡着头上的感叹号")
	# 2 东侧过道门板
	h.set_test_clock(12.25);stand("closet1",Vector2(110,150),"living");await shot("03-东侧过道-门板")
	# 3 煮汤
	var ctx:={"month":10,"hour":12.25,"weather":"clear","sound":false}
	h.games.open("soup",h.life,ctx);await create_timer(.3).timeout;await shot("04-煮汤-清水")
	h.games.placed=[0,1,2];h.games.stage=1;h.games.progress=.4;h.games.holding=true;h.games.pointer=Vector2(300,300);await create_timer(.3).timeout;await shot("05-煮汤-搅");h.games.close(false)
	# 4 二楼衣柜去浴室
	stand("closet2",Vector2(150,170),"stairs2");await shot("06-二楼衣柜-门气泡")
	# 5 爸妈床躺下
	h.set_test_clock(12.25);stand("parents",Vector2(226,193),"closet1");h.go("bed")
	for i in 400:
		h._process(.05)
		if h.pending.is_empty() and h.player.route.is_empty():break
	tick(40);await shot("07-爸妈床-躺下")
	print("DONE");h.stop_audio();vp.queue_free();await process_frame;quit()
