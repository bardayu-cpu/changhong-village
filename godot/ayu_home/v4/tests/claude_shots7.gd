extends SceneTree
## 第七轮截图（540×960 开真窗口）：对话框、顶栏、面板、按钮、话泡、提示泡；前后同一份脚本，老代码没有的跳过
const Home=preload("res://ayu_home/v4/home.gd")
var h
var vp:SubViewport
var out:=""
func _initialize() -> void:call_deferred("run")
func shot(tag:String) -> void:
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out+tag+".png");print("SHOT ",tag)
func tick(n:=30) -> void:
	for i in n:h._process(0.05);h.world._process(0.05)
	h.transition=false;h.fade.color.a=0
func stand(room:String,at:Vector2,from:="") -> void:
	h.enter_room(room,false,from);h.player.position=h.world.nearest(at);h.camera=h.player.position-Vector2(0,65);tick(40)
func panel(tag:String,f:Callable) -> void:
	f.call();await create_timer(.35).timeout;await shot(tag);h.close_modal()
func run() -> void:
	var size:=Vector2i(540,960)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):out=a.substr(6)
		if a=="--tall":size=Vector2i(540,1168)
	if not out.ends_with("/"):out+="/"
	DirAccess.make_dir_recursive_absolute(out)
	var save:=OS.get_user_data_dir()+"/claude-shots7.json";DirAccess.remove_absolute(save);DirAccess.remove_absolute(save+".bak")
	vp=SubViewport.new();vp.size=size;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	h=Home.new();h.town_profile={"id":"claude-shots7","avatar":2};h.save_path=save;vp.add_child(h);await process_frame;h.set_process(false);h.sound_on=false;h.admitted=true;h.close_modal();h.set_test_clock(14.5)
	# 顶栏、提示条、提示泡、物件名字牌
	stand("exterior",Vector2(800,600),"side_path");h.note="";tick(2);h.show_toast("走近物件，气泡才会出现，点气泡就能做事。");await create_timer(.5).timeout;await shot("01-顶栏和提示条-院子")
	stand("living",Vector2(200,300),"exterior");await create_timer(4.5).timeout;await shot("02-顶栏-客厅")
	# 对话框
	stand("kitchen",Vector2(200,200),"dining")
	h.dialogue("妈妈","今天愿不愿意帮我煮一锅热汤？做好再来找我，我想听听你怎么做的。","mother");h.talk_chars=999;tick(2);await create_timer(1.5).timeout;await shot("10-对话框-妈妈")
	h.close_modal()
	h.dialogue("门上的字条","我们出门一小会儿，十点前后陆续回来。门没锁，先进屋坐，桌上有水。——阿鱼","");h.talk_chars=999;tick(2);await create_timer(2.5).timeout;await shot("11-对话框-没有头像")
	h.close_modal()
	if h.has_method("say_lines"):
		h.say_lines("爸爸",["来，坐这边。","手作房里那只木鸟，是我磨了一个下午的。","你要是喜欢，下回教你。"],"father");tick(2);await create_timer(1.5).timeout;await shot("12-对话框-三句-有跳过")
		h.close_modal()
	# 面板
	await panel("20-面板-家里的人",h.family_page)
	h.set_test_clock(21.0);stand("living",Vector2(200,300),"exterior");tick(900);await panel("20b-面板-家里的人-晚上九点",h.family_page);h.set_test_clock(14.5);stand("kitchen",Vector2(200,200),"dining")
	await panel("21-面板-人物卡",func():h.family_card("father"))
	await panel("22-面板-生活册",h.life_book)
	await panel("23-面板-设置",h.settings_page)
	await panel("24-面板-地图",func():h.navigation("一楼"))
	await panel("25-面板-今日小事",h.today)
	await panel("26-信纸-欢迎信",h.welcome)
	await panel("27-面板-挂历",h.calendar_page)
	# 按钮：小包打开、场景按钮、吃饭邀请
	stand("living",Vector2(200,300),"exterior");h.toggle_tools(true);tick(2);await create_timer(.4).timeout;await shot("30-按钮-小包打开");h.toggle_tools(false)
	stand("guest",Vector2(200,250),"stairs2");var bed:Dictionary=h.world.spot("bed")
	if not bed.is_empty():h.stay_choices(bed);tick(3);await create_timer(.4).timeout;await shot("31-按钮-客房床边三个选择");h.clear_scene_controls()
	h.life.data.resident=true;h.life.data.invites.clear();h.set_test_clock(12.1);stand("living",Vector2(200,300),"exterior");h.check_meal_invite();tick(2);await create_timer(.4).timeout;await shot("32-按钮-叫吃饭");h.dismiss_invite()
	# 话泡
	h.set_test_clock(14.5);stand("exterior",Vector2(760,700),"side_path");h.player.say("家里给你留了一碗汤。");tick(1);await shot("40-话泡-玩家")
	print("DONE");h.stop_audio();vp.queue_free();await process_frame;quit()
