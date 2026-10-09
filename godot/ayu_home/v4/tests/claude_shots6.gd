extends SceneTree
## 第六轮截图（540×960，开真窗口，门的冷却照原样）；前后同一份脚本，老代码没有的东西跳过
const Home=preload("res://ayu_home/v4/home.gd")
var h
var vp:SubViewport
var out:=""
func _initialize() -> void:call_deferred("run")
func shot(tag:String) -> void:
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out+tag+".png");print("SHOT ",tag," area=",h.area," pos=",h.player.position.round())
func tick(n:=30) -> void:
	for i in n:h._process(0.05);h.world._process(0.05)
	h.transition=false;h.fade.color.a=0
func cam() -> void:h.camera=h.player.position-Vector2(0,65)
func stand(room:String,at:Vector2,from:="") -> void:
	h.enter_room(room,false,from);h.player.position=h.world.nearest(at);cam();tick(40)
func click(q:Vector2) -> void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=h.world.get_global_transform_with_canvas()*q;h._unhandled_input(e)
func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):out=a.substr(6)
	if not out.ends_with("/"):out+="/"
	DirAccess.make_dir_recursive_absolute(out)
	var save:=OS.get_user_data_dir()+"/claude-shots6.json";DirAccess.remove_absolute(save);DirAccess.remove_absolute(save+".bak")
	vp=SubViewport.new();vp.size=Vector2i(540,960);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	h=Home.new();h.town_profile={"id":"claude-shots6","avatar":2};h.save_path=save;vp.add_child(h);await process_frame;h.set_process(false);h.sound_on=false;h.admitted=true;h.close_modal();h.set_test_clock(14.5)
	# 3 家里的人
	stand("living",Vector2(200,300),"exterior");h.family_page();await create_timer(.3).timeout;await shot("03-家里的人");h.close_modal()
	h.set_test_clock(23.5);stand("living",Vector2(200,300),"exterior");h.family_page();await create_timer(.3).timeout;await shot("03b-家里的人-深夜");h.close_modal()
	h.set_test_clock(14.5)
	# 4 屋里房间之间：客厅站猫房门口、点门框边上
	stand("living",Vector2(258,150),"exterior");await shot("04-客厅通猫房门口")
	stand("dining",Vector2(250,330),"living");await shot("04b-餐厅-屋里门口")
	# 6、13 一楼门板
	stand("mahjong",Vector2(296,267),"living");await shot("06-麻将室-门10")
	stand("parents",Vector2(299,213),"living");await shot("06b-爸妈卧室-门11")
	stand("guest",Vector2(200,250),"living");await shot("06c-客房")
	stand("workshop",Vector2(160,300),"exterior");await shot("06d-手作房")
	# 7、21 同一时间只出一个提示
	h.set_test_clock(6.5);h.enter_room("kitchen",false,"dining");tick(900)
	if h.people.mother.visible:h.player.position=h.world.nearest(h.people.mother.position+Vector2(40,40))
	cam();tick(30);await shot("07-厨房妈妈做饭-提示")
	h.set_test_clock(14.5);stand("exterior",Vector2(800,600),"side_path");await shot("07b-院子-提示")
	# 8 院子车、车库车
	stand("exterior",Vector2(330,700),"side_path");await shot("08-院子左边-车的位置")
	stand("garage",Vector2(266,200),"exterior");await shot("08b-车库")
	# 9、22、23 话泡
	h.set_test_clock(20.0);h.enter_room("living",false,"exterior");tick(900)
	for id in ["mother","father","ayu"]:
		if h.people[id].visible:
			h.player.position=h.world.nearest(h.people[id].position+Vector2(30,40));cam();tick(10)
			h.people[id].say("来做客不用拘束，想做什么就慢慢试。");tick(1);await shot("09-沙发上"+id+"说长话");break
	for id in ["father","mother"]:
		if h.people[id].visible:h.people[id].say("好。");tick(1);await shot("09b-"+id+"说短话");break
	h.set_test_clock(14.5);h.enter_room("exterior",false,"side_path");tick(5)
	var dog=h.people.xiduo
	if dog.visible:h.player.position=h.world.nearest(dog.position+Vector2(4,-14));cam();tick(10);dog.say("汪！尾巴摇起来了。");tick(1);await shot("09c-喜多说话-玩家在后面")
	# 10 棚子下
	stand("exterior",Vector2(1040,600),"side_path");await shot("10-院子棚子下")
	stand("exterior",Vector2(1100,640),"side_path");await shot("10b-院子棚子下右")
	# 11 喜多
	stand("exterior",Vector2(900,760),"side_path");tick(400);h.player.position=h.world.nearest(h.people.xiduo.position+Vector2(60,40));cam();tick(5);await shot("11-喜多在院子")
	tick(200);h.player.position=h.world.nearest(h.people.xiduo.position+Vector2(60,40));cam();tick(5);await shot("11b-喜多在院子-过一会")
	# 15 水龙头
	h.set_test_clock(14.5)
	for r in [["kitchen","dining"],["laundry","dining"],["bath1","living"],["guest_bath","guest"],["bath2","stairs2"]]:
		h.enter_room(r[0],false,r[1]);tick(5)
		for hs in h.world.cfg.get("hotspots",[]):
			if hs.get("kind","")=="tap":h.world.toggles[hs.id]=true;h.player.position=h.world.nearest(Vector2(hs.pos[0],hs.pos[1])+Vector2(60,70))
		cam();tick(10);await shot("15-水龙头-"+r[0])
	# 16 麻将桌
	stand("mahjong",Vector2(240,240),"living");await shot("16-麻将桌")
	# 18 楼梯扶手
	for p in [Vector2(110,230),Vector2(110,300),Vector2(130,180)]:
		stand("stairs1",p,"living");await shot("18-楼梯-%d"%p.y)
	# 20 餐桌
	h.set_test_clock(12.2);h.enter_room("dining",false,"living");tick(600);h.player.position=h.world.nearest(Vector2(296,323));cam();tick(5);await shot("20-午饭餐桌")
	h.set_test_clock(18.3);h.enter_room("dining",false,"living");tick(600);h.player.position=h.world.nearest(Vector2(296,323));cam();tick(5);await shot("20b-晚饭餐桌")
	# 25 小桥点老屋
	h.set_test_clock(14.5);h.enter_room("bridge",false,"side_path");h.cooldown=0;tick(5);cam();tick(1);await shot("25-小桥-点老屋前")
	click(Vector2(1312,372))
	for i in 600:
		tick(1)
		if h.area=="oldhouse" and h.player.route.is_empty() and h.pending.is_empty():break
	cam();tick(2);await shot("25b-点完以后")
	print("DONE");h.stop_audio();vp.queue_free();await process_frame;quit()
