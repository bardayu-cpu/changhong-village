extends SceneTree
## 第八轮截图（540×960 开真窗口）：设计师 002 看第七轮提的 5 处——顶栏两行、提示条一行、红按钮留白、面板不吊字、小游戏格子字。
## 机位照第七轮（claude_shots7.gd），前后同一份脚本
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
	var save:=OS.get_user_data_dir()+"/claude-shots8.json";DirAccess.remove_absolute(save);DirAccess.remove_absolute(save+".bak")
	vp=SubViewport.new();vp.size=size;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	h=Home.new();h.town_profile={"id":"claude-shots8","avatar":2};h.save_path=save;vp.add_child(h);await process_frame;h.set_process(false);h.sound_on=false;h.admitted=true;h.close_modal();h.set_test_clock(14.5)
	# 顶栏、提示条、提示泡、物件名字牌
	stand("exterior",Vector2(800,600),"side_path");h.note="";tick(2);h.show_toast("走近东西，点气泡就能做事" if h.note.is_empty() else h.note);await create_timer(.5).timeout;await shot("01-顶栏和提示条-院子")
	stand("living",Vector2(200,300),"exterior");await create_timer(4.5).timeout;await shot("02-顶栏-客厅")
	# 面板
	await panel("20-面板-家里的人",h.family_page)
	h.set_test_clock(21.0);stand("living",Vector2(200,300),"exterior");tick(900);await panel("20b-面板-家里的人-晚上九点",h.family_page);h.set_test_clock(14.5);stand("kitchen",Vector2(200,200),"dining")
	await panel("25-面板-今日小事",h.today)
	await panel("21-面板-人物卡-爸爸",func():h.family_card("father"))
	await panel("24-面板-地图",func():h.navigation("一楼"))
	await panel("28-面板-收集册",h.collection_page)
	# 按钮：小包打开、场景按钮、吃饭邀请
	stand("living",Vector2(200,300),"exterior");h.toggle_tools(true);tick(2);await create_timer(.4).timeout;await shot("30-按钮-小包打开");h.toggle_tools(false)
	stand("guest",Vector2(200,250),"stairs2");var bed:Dictionary=h.world.spot("bed")
	if not bed.is_empty():h.stay_choices(bed);tick(3);await create_timer(.4).timeout;await shot("31-按钮-客房床边三个选择");h.clear_scene_controls()
	h.life.data.resident=true;h.life.data.invites.clear();h.set_test_clock(12.1);stand("living",Vector2(200,300),"exterior");h.check_meal_invite();tick(2);await create_timer(.4).timeout;await shot("32-按钮-叫吃饭");h.dismiss_invite()
	# 小游戏：画上的字（煮茶步骤、菜地格子、果园、磨木头、钓鱼）
	var ctx:={"hour":14.5,"month":10,"sound":false}
	h.games.open("tea",h.life,ctx);h.games.stage=2;h.games.status.text="第三步 · 杯子温好了，把左边的茶叶拖进壶里。";await create_timer(.4).timeout;await shot("50-小游戏-煮茶-第三步");h.games.close(false)
	var t:float=h.life.now()
	h.life.data.plots[0]={"tilled":true,"crop":"radish","planted":t-1000,"watered":true,"watered_at":t-1000}
	h.life.data.plots[1]={"tilled":true,"crop":"tulip","planted":t,"watered":false}
	h.life.data.plots[2]={"tilled":true}
	h.life.data.plots[3]={"tilled":true,"crop":"pea","planted":t-20000,"watered":true,"watered_at":t-20000}
	h.games.open("garden",h.life,ctx);await create_timer(.4).timeout;await shot("51-小游戏-菜地");h.games.close(false)
	h.games.open("tree",h.life,ctx);await create_timer(.4).timeout;await shot("52-小游戏-果树");h.games.close(false)
	h.games.open("wood",h.life,ctx);await create_timer(.4).timeout;await shot("53-小游戏-磨木头");h.games.close(false)
	h.games.open("fishing",h.life,ctx);h.games.stage=1;await create_timer(.4).timeout;await shot("54-小游戏-钓鱼");h.games.close(false)
	print("DONE");h.stop_audio();vp.queue_free();await process_frame;quit()
