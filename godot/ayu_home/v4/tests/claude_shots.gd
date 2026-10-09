extends SceneTree
## Claude 修体验的截图：开真窗口、手机竖屏 540×960（--tall 是 1170×2532 长屏），人是真的走过去、点过去。
## 用法：Godot --path godot --script res://ayu_home/v4/tests/claude_shots.gd -- --out=目录 --batch=fix1 [--tall]
const Home=preload("res://ayu_home/v4/home.gd")
var h
var vp:SubViewport
var out:=""
var batch:="fix1"
var tall:=false
func _initialize() -> void:call_deferred("run")
func shot(tag:String) -> void:
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out+tag+".png");print("SHOT ",tag," area=",h.area," pos=",h.player.position.round())
func tick(n:=30) -> void:
	for i in n:h._process(0.05)
	h.transition=false;h.fade.color.a=0
func room(r:String,from:="") -> void:
	h.enter_room(r,false,from);tick(30)
func go(id:String) -> void:
	h.go(id)
	for i in 900:
		h._process(0.05);h.transition=false
		if h.pending.is_empty() and h.player.route.is_empty():break
	for i in 6:h._process(0.05)
	h.fade.color.a=0
	await process_frame
func press(copy:String) -> void:
	for b in h.find_children("*","Button",true,false):
		if b.text==copy and b.is_visible_in_tree():b.pressed.emit();break
	tick(4)
func clean() -> void:
	if h.games.root:h.games.close(false)
	if h.activities.root:h.activities.close()
	if h.immersive.root:h.immersive.close(false)
	if h.photo.root:h.photo.close(false)
	h.close_modal();h.clear_scene_controls();h.stand_up();h.dismiss_invite()
func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):out=a.substr(6)
		elif a.begins_with("--batch="):batch=a.substr(8)
		elif a=="--tall":tall=true
	if not out.ends_with("/"):out+="/"
	DirAccess.make_dir_recursive_absolute(out)
	var save:=OS.get_user_data_dir()+"/claude-shots-"+batch+".json";DirAccess.remove_absolute(save);DirAccess.remove_absolute(save+".bak")
	vp=SubViewport.new();vp.size=Vector2i(540,960);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	if tall:vp.size=Vector2i(1170,2532);vp.size_2d_override=Vector2i(540,1168);vp.size_2d_override_stretch=true
	h=Home.new();h.town_profile={"id":"claude-shots-"+batch,"avatar":2};h.save_path=save;h.test_panel_enabled=true;vp.add_child(h);await process_frame;h.set_process(false);h.set_test_clock(12.25);h.sound_on=false;h.admitted=true;h.close_modal()
	var pre:="L-" if tall else ""
	match batch:
		"fix1":
			room("living","exterior");await go("sofa");tick(2);await shot(pre+"01-客厅-坐沙发");clean()
			room("living","exterior");await go("seat_2");tick(2);await shot(pre+"02-客厅-侧边沙发");clean()
			room("parents","stairs1");await go("bed");tick(40);await shot(pre+"03-爸妈卧室-躺下");clean()
			room("ayu_room","stairs2");await go("bed");tick(40);await shot(pre+"04-阿鱼卧室-躺下");clean()
			room("guest","stairs2");await go("bed");press("先躺一会儿");tick(40);await shot(pre+"05-客房-先躺一会儿");clean()
			room("study","stairs2");await go("computer");tick(2);await shot(pre+"06-书房-电脑前");clean()
			room("dining","living");await go("seat_0");tick(2);await shot(pre+"07-餐厅-餐椅");clean()
			room("kitchen","dining");await go("sink");tick(8);await shot(pre+"08-厨房-窗光不穿墙");h.interact("sink");clean()
			room("living","exterior");tick(5);await shot(pre+"09-客厅-窗光");clean()
		"bubble":
			room("exterior","side_path");await go("xiduo");tick(2);await shot(pre+"20-院子-摸喜多话泡");clean()
			room("kitchen","dining");await go("sink");tick(4);await shot(pre+"21-厨房-洗手话泡");h.interact("sink");clean()
			room("study","stairs2");await go("computer");tick(2);await shot(pre+"22-书房-坐下话泡");clean()
			room("study","stairs2");await go("chair");tick(2);await shot(pre+"23-书房-读书话泡");clean()
			h.set_test_clock(15.5);room("living","exterior");tick(5);await shot(pre+"24-客厅-下午");clean()
		"hud":
			room("grove","garden");tick(5);await shot(pre+"30-树林-秋千-界面");
			h.toggle_tools();tick(3);await shot(pre+"31-树林-工具展开");h.toggle_tools();clean()
			room("exterior","side_path");tick(5);await shot(pre+"32-院子-界面");clean()
			room("living","exterior");await go("tv");tick(5);await shot(pre+"33-客厅-看电视操作");clean()
			h.settings_page();await shot(pre+"34-设置");clean()
			h.navigation("屋外");await shot(pre+"35-地图");clean()
			room("mahjong");h.interact("pairs");await create_timer(.4).timeout;await shot(pre+"36-翻牌-收起按钮");clean()
		"doors1":
			# 一楼每扇门：站到门口（门内侧一点）截一张
			var rooms1:=[]
			for r in h.definitions:
				if int(h.definitions[r].floor)==1:rooms1.append(r)
			for r in rooms1:
				for d in h.definitions[r].doors:
					room(r);var inward:Vector2=h.dir(str(d.face));h.player.position=h.world.nearest(h.World.v(d.approach)+inward*40);h.camera=h.player.position-Vector2(0,65);tick(12)
					await shot(pre+"D-"+r+"-"+str(d.id))
		"rooms1":
			for r in h.definitions:
				if int(h.definitions[r].floor)==1:room(r);await shot(pre+"R-"+r)
		"seasons":
			for cfg in [[1,12.25,"clear","冬"],[10,12.25,"rain","雨"],[10,12.25,"clear","秋"],[3,12.25,"clear","春"],[7,12.25,"clear","夏"]]:
				h.set_test_clock(cfg[1],cfg[0],cfg[2])
				room("exterior","side_path");await shot(pre+"S-院子-"+cfg[3])
				room("living","exterior");h.player.position=h.world.nearest(Vector2(150,380));h.camera=h.player.position-Vector2(0,65);tick(10);await shot(pre+"S-客厅-"+cfg[3])
			h.set_test_clock(12.25,1,"clear");room("grove","garden");await shot(pre+"S-树林-冬")
			h.set_test_clock(12.25,1,"clear");room("ayu_room","stairs2");await shot(pre+"S-阿鱼卧室-冬")
			h.set_test_clock(12.25,7,"clear");room("ayu_room","stairs2");await shot(pre+"S-阿鱼卧室-夏")
		"games":
			var ctx:={"month":10,"hour":12.25,"weather":"clear","sound":false}
			room("garden","exterior");h.games.open("fruit",h.life,ctx);await create_timer(.3).timeout
			var f:Dictionary=h.games.fruits[0];h.games.pointer_down(f.pos);for i in 6:h.games._process(.05)
			h.games.basket_x=f.pos.x-40;await shot(pre+"50-摘果-果子掉下来拖篮子接");h.games.close(false)
			h.games.open("net",h.life,ctx);await create_timer(.2).timeout;var fish:Dictionary=h.games.net_fish[1];h.games.holding=true
			for i in 6:h.games.pointer=fish.pos;h.games._process(.05)
			await shot(pre+"51-捞鱼-网兜停在鱼底下");h.games.holding=false;h.games.close(false)
			h.games.open("pairs",h.life,ctx);await create_timer(.3).timeout;await shot(pre+"52-翻牌-开局先亮牌")
			h.games.pair_round=2;h.games.start_pairs();h.games.peek_until=0;h.games.flipped=[0,1];await create_timer(.2).timeout;await shot(pre+"53-翻牌-第二局十二张");h.games.close(false)
			h.games.open("stars",h.life,{"month":10,"hour":21.0,"weather":"clear","sound":false});await create_timer(.2).timeout
			h.games.pointer_down(h.games.stars[0]);h.games.pointer_down(h.games.stars[1]);h.games.star_hint();await create_timer(.3).timeout;await shot(pre+"54-看星星-下一颗在闪");h.games.close(false)
			h.games.open("stars",h.life,ctx);await create_timer(.2).timeout;h.games.pointer_down(h.games.cloud_pos(h.games.clouds[0]));await create_timer(.2).timeout;await shot(pre+"55-看云-点像小动物的云");h.games.close(false)
		"round3":
			h.set_test_clock(23.5);room("parents","closet1");h.player.position=h.world.nearest(Vector2(176,330));h.camera=h.player.position-Vector2(0,65);tick(30);await shot(pre+"70-深夜爸妈在床上")
			h.set_test_clock(12.25);h.life.data.resident=true;h.life.data.invites.clear();room("dining","living");h.eat_together(h.world.spot("meal"));tick(4);h.serve_family();tick(3);await shot(pre+"71-吃饭夹菜家人回话");clean()
			room("living","exterior");await go("sofa");tick(2);await shot(pre+"72-坐沙发起身按钮");clean()
			room("living","exterior");await go("tv");tick(5);await shot(pre+"73-看电视起身按钮");clean()
			var ctx:={"month":10,"hour":12.25,"weather":"clear","sound":false}
			room("kitchen","dining");h.games.open("soup",h.life,ctx);await create_timer(.3).timeout;await shot(pre+"74-煮汤开局清水");h.games.close(false)
			h.games.open("pairs",h.life,ctx);await create_timer(.2).timeout;h.games.pair_round=2;h.games.start_pairs();h.games.peek_until=h.games.elapsed+5;await create_timer(.3).timeout;await shot(pre+"75-翻牌第二局");h.games.close(false)
			h.games.open("fruit",h.life,ctx);await create_timer(.3).timeout;await shot(pre+"76-摘果开局");h.games.close(false)
			room("workshop","exterior");await go("seat_0");tick(2);await shot(pre+"77-手作房坐凳子");clean()
		"twofloors":
			room("stairs2","stairs1");h.player.position=h.world.nearest(Vector2(200,300));h.camera=h.player.position-Vector2(0,65);tick(12);await shot(pre+"80-二楼过道")
			room("guest","stairs2");tick(8);await shot(pre+"81-二楼客房")
			room("living","exterior");h.player.position=h.world.nearest(Vector2(150,110));h.camera=h.player.position-Vector2(0,65);tick(12);await shot(pre+"82-一楼客厅上方的门")
			room("closet1","living");tick(8);await shot(pre+"83-一楼东侧过道")
		"panels":
			room("exterior","side_path");h.welcome();await create_timer(.3).timeout;await shot(pre+"90-信");clean()
			h.today();await create_timer(.3).timeout;await shot(pre+"91-今日小事");clean()
		"paths":
			room("garden","exterior");h.player.position=h.world.nearest(Vector2(1300,371));tick(10);await shot(pre+"40-后园-去老屋的小桥")
			await go("to_oldhouse");tick(10);await shot(pre+"41-老屋-从果园过来");clean()
			room("side_path","exterior");tick(5);await shot(pre+"42-院外小道");clean()
			room("garden","exterior");tick(5);await shot(pre+"43-后园-出口");clean()
	print("DONE");h.stop_audio();vp.queue_free();await process_frame;quit()
