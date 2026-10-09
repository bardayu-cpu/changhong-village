extends SceneTree
## 第五轮截图（540×960，开真窗口，门的冷却照原样）
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
func stand(room:String,at:Vector2,from:="") -> void:
	h.enter_room(room,false,from);h.player.position=h.world.nearest(at);h.camera=h.player.position-Vector2(0,65);tick(40)
func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):out=a.substr(6)
	if not out.ends_with("/"):out+="/"
	DirAccess.make_dir_recursive_absolute(out)
	var save:=OS.get_user_data_dir()+"/claude-shots5.json";DirAccess.remove_absolute(save);DirAccess.remove_absolute(save+".bak")
	vp=SubViewport.new();vp.size=Vector2i(540,960);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	h=Home.new();h.town_profile={"id":"claude-shots5","avatar":2};h.save_path=save;vp.add_child(h);await process_frame;h.set_process(false);h.sound_on=false;h.admitted=true;h.close_modal();h.set_test_clock(10.0)
	# 1 墙缺口
	stand("laundry",Vector2(100,90),"dining");await shot("10-卫生间左上墙")
	# 2 门：客厅通猫窝走道的门（阿鱼截图里站在门口冒「这里过不去」），门板是静态斜开的原画样子
	stand("living",Vector2(258,140),"exterior");await shot("20-客厅通猫窝走道门口")
	h.player.route=h.world.path(h.player.position,h.player.position+Vector2(0,-60));h.pending=""
	for i in 200:
		h._process(.05);h.world._process(.05)
		if h.area!="living":break
	tick(20);await shot("21-走过去进了猫窝走道")
	# 大门：客厅南门门洞右半边点出去
	stand("living",Vector2(420,380),"exterior");await shot("22-客厅南门-门洞右半边")
	# 3 绕路
	stand("exterior",Vector2(200,640),"side_path");await shot("30-院子左边-没有侧门了")
	stand("side_path",Vector2(140,990),"exterior");await shot("31-院外小道左头-去后园")
	h.go("to_garden")
	for i in 300:
		h._process(.05);h.world._process(.05)
		if h.area!="side_path":break
	tick(20);await shot("32-到了后园左下")
	stand("garden",Vector2(700,960),"cats");await shot("33-后园底下-两个出口分开")
	# 4 车库
	stand("exterior",Vector2(560,680),"side_path");await shot("40-院子-进车库在卷帘门")
	# 第五轮后半：家人坐沙发、做饭的「!」、名字牌、贴着猫、手作房、煮汤
	h.set_test_clock(20.0);h.enter_room("living",false,"exterior");tick(900);h.player.position=h.world.nearest(Vector2(190,420));h.camera=h.player.position-Vector2(0,65);tick(30);await shot("50-晚上家人坐沙发")
	h.set_test_clock(6.5);h.enter_room("kitchen",false,"dining");tick(900)
	if h.people.mother.visible:h.player.position=h.world.nearest(h.people.mother.position+Vector2(40,40))
	h.camera=h.player.position-Vector2(0,65);tick(30);await shot("51-妈妈做饭头上的感叹号")
	h.set_test_clock(14.5);stand("cats",Vector2(165,370),"living");await shot("52-猫窝走道-门气泡和名字牌")
	stand("oldhouse",Vector2(1236,232),"bridge");await shot("53-老屋门口-台阶和敲门")
	stand("cats",Vector2(165,330),"living")
	for id in ["qiuqiu","luoluo","tiantian"]:
		if h.people[id].visible:h.player.position=h.world.nearest(h.people[id].position+Vector2(14,10));h.camera=h.player.position-Vector2(0,65);tick(20);await shot("54-贴着猫站");break
	h.set_test_clock(14.5);stand("workshop",Vector2(160,300),"exterior");h.go("seat_0")
	for i in 300:
		h._process(.05);h.world._process(.05)
		if h.pending.is_empty() and h.player.route.is_empty():break
	tick(20);await shot("55-手作房坐凳子")
	var ctx:={"month":10,"hour":12.25,"weather":"clear","sound":false}
	h.games.open("soup",h.life,ctx);await create_timer(.4).timeout;await shot("56-煮汤开局");h.games.close(false)
	print("DONE");h.stop_audio();vp.queue_free();await process_frame;quit()
