extends SceneTree
## 第六轮第 11、12 条：喜多一天在哪（只在屋外、大部分在院子）、在院子里自己玩球、走近偶尔叫一声
var h
var barks:=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp)
	h=load("res://ayu_home/v4/home.gd").new();h.town_profile={"id":"dog"};h.save_path=OS.get_user_data_dir()+"/dog.json";vp.add_child(h);await process_frame;h.set_process(false);h.admitted=true;h.close_modal()
	var places:={};var slots:=0;var fails:=[]
	for q in range(7*4,22*4):
		h.set_test_clock(q/4.0);var loc:String=h.dog_loc();places[loc]=places.get(loc,0)+1;slots+=1
		if not h.definitions[loc].get("outdoor",false):fails.append("进屋了 "+loc)
	print("白天每一刻钟喜多在哪：",places)
	if places.get("exterior",0)*1.0/slots<.75:fails.append("在院子的时间不到七成五")
	# 院子里自己玩球：看 90 秒里球动了几次、喜多走了多远
	h.set_test_clock(14.0);h.enter_room("exterior",false,"side_path");h.player.position=h.world.nearest(Vector2(400,640))
	var kicks:=0;var last:String=h.ball_phase;var moved:=0.0;var prev:Vector2=h.people.xiduo.position
	for i in 1800:
		h._process(.05);h.world._process(.05)
		if h.ball_phase=="dog_roll" and last!="dog_roll":kicks+=1
		last=h.ball_phase;moved+=h.people.xiduo.position.distance_to(prev);prev=h.people.xiduo.position
	print("90 秒里喜多自己拱球 ",kicks," 次，走了 ",int(moved)," 像素")
	if kicks<5:fails.append("自己玩球太少")
	# 走近叫一声：来回走近 40 次，数叫了几次（不是每次）；关了声音不响
	var played:=0
	h.sfx.finished.connect(func():pass)
	for k in 40:
		h.player.position=h.world.nearest(h.people.xiduo.position+Vector2(200,0));h._process(.05)
		h.elapsed+=30.0;h.sfx.stream=null
		h.player.position=h.world.nearest(h.people.xiduo.position+Vector2(30,0));h._process(.05)
		if h.sfx.stream!=null and h.sfx.stream==preload("res://ayu_home/v4/sfx.gd").get_sound("bark"):played+=1
	print("走近 40 次叫了 ",played," 次")
	if played==0 or played>=30:fails.append("叫的次数不对")
	h.sound_on=false;var quiet:=0
	for k in 20:
		h.player.position=h.world.nearest(h.people.xiduo.position+Vector2(200,0));h._process(.05);h.elapsed+=30.0;h.sfx.stream=null
		h.player.position=h.world.nearest(h.people.xiduo.position+Vector2(30,0));h._process(.05)
		if h.sfx.stream!=null:quiet+=1
	if quiet>0:fails.append("关了声音还响")
	for f in fails:print("× ",f)
	print("RESULT ","PASS" if fails.is_empty() else "FAIL");quit()
