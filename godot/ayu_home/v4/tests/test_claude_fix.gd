extends SceneTree
## Claude 修体验的回归：门保持游戏原样（不改冷却），只模拟玩家点地面、点门、方向键。
## 1 点地面随便走不会被门带走（车库左下角那类）；2 每扇门点过去、朝门走都还能过；3 坐、躺画在家具上面。
const Home=preload("res://ayu_home/v4/home.gd")
const World=preload("res://ayu_home/v4/world.gd")
var h
var vp:SubViewport
var fails:Array=[]
var only:=""
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	print("CHECK ",ok," ",label)
	if not ok:fails.append(label)
func tick(n:int) -> void:
	for i in n:h._process(.05)
func click_ground(p:Vector2) -> void:
	# 和真的点地面一样：stand_up、清 pending、按导航走
	h.pending="";h.player.destination_action="idle";h.player.route=h.world.path(h.player.position,p)
func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):only=a.get_slice("=",1)
	vp=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp)
	h=Home.new();h.town_profile={"id":"claude-fix","avatar":2};h.save_path=OS.get_user_data_dir()+"/claude-fix.json";vp.add_child(h);await process_frame
	h.set_process(false);h.set_test_clock(12.25);h.admitted=true;h.close_modal()
	if only in ["","ghost"]:
		# 1 车库三个固定点 + 每间随机点地面 60 次（离门 70 像素以外），门正常触发
		for p in [Vector2(50,390),Vector2(100,395),Vector2(150,394)]:
			h.enter_room("garage",false,"dining");h.transition=false;tick(10)
			click_ground(p);var t:=0
			while t<600 and h.area=="garage" and not h.player.route.is_empty():h._process(.05);t+=1
			check(h.area=="garage","车库点地面去 "+str(p)+" 不被传走（现在在 "+h.area+"）")
		var rng:=RandomNumberGenerator.new();rng.seed=4004;var ghosts:=0;var walks:=0
		for room in h.definitions:
			h.enter_room(room,false);h.transition=false;tick(5)
			var w=h.world;var size:Vector2=World.v(w.cfg.size);var doors:Array=[]
			for d in w.cfg.doors:doors.append(w.nearest(World.v(d.approach)))
			var n:=0;var tries:=0
			while n<60 and tries<3000:
				tries+=1;var target:=Vector2(rng.randf_range(0,size.x),rng.randf_range(0,size.y))
				if not w.passable(target):continue
				var far:=true
				for dp in doors:
					if target.distance_to(dp)<70:far=false
				# 门洞（门有多宽就多宽）本身也算门：点在那里就是要出门
				for d in w.cfg.doors:
					var pl:Dictionary=w.door_plane(d);var rel:Vector2=target-pl.point;var tn:=Vector2(-pl.normal.y,pl.normal.x)
					if rel.dot(pl.normal)>-40 and absf(rel.dot(tn))<pl.width*.5+20:far=false
				if not far:continue
				n+=1;walks+=1;click_ground(target);var t:=0
				while t<600 and h.area==room and not h.player.route.is_empty():h._process(.05);t+=1
				if h.area!=room:
					ghosts+=1;print("GHOST ",room," -> ",h.area," 去 ",target.round());h.enter_room(room,false);h.transition=false;tick(3);w=h.world
		check(ghosts==0,"27 间随机点地面 %d 次，被看不见的门带走 %d 次"%[walks,ghosts])
	if only in ["","doors"]:
		# 2a 点门（走到门口）每扇都能过；2b 点门槛上的地面也能过
		var bad:=0;var total:=0
		for room in h.definitions:
			for d in h.definitions[room].doors:
				for mode in ["bubble","ground"]:
					h.enter_room(room,false);h.transition=false;tick(10);total+=1
					if mode=="bubble":h.go(d.id)
					else:click_ground(h.world.nearest(World.v(d.approach)))
					var t:=0
					while t<1500 and h.area==room and (not h.player.route.is_empty() or not h.pending.is_empty()):h._process(.05);t+=1
					if h.area!=d.target:bad+=1;print("DOOR FAIL ",room," ",d.id," ",mode," -> ",h.area)
		check(bad==0,"每扇门点门、点门槛都能过：%d 次里 %d 次没过"%[total,bad])
	if only in ["","through"]:
		# 4 点画上看得见的隔壁房间（同一张一楼图上），人自己穿门进去、走到点的地方
		var cases:=[["living","dining"],["living","cats"],["dining","kitchen"],["dining","garage"],["closet1","parents"],["side_path","bridge"]]
		var bad:=0
		for c in cases:
			h.enter_room(c[0],false);h.transition=false;tick(5)
			var target_room:String=c[1];var tw=h.nav(target_room);var goal:Vector2=tw.spawn()
			var p:Vector2=h.from_canvas(c[0],h.to_canvas(target_room,goal))
			var ok_start:bool=h.walk_into_room(p);var t:=0
			while t<1500 and (not h.pending.is_empty() or not h.player.route.is_empty() or h.area==c[0]):h._process(.05);h.transition=false;t+=1
			var ok:bool=ok_start and h.area==target_room and h.player.position.distance_to(h.world.nearest(goal))<12
			if not ok:bad+=1
			print("THROUGH ",c[0],"→",target_room," 到了 ",h.area," 离点的地方 ",h.player.position.distance_to(h.world.nearest(goal)))
		check(bad==0,"点隔壁房间自己穿门走过去：%d 组里 %d 组不对"%[cases.size(),bad])
	if only in ["","seat"]:
		# 3 坐、躺：人排在家具前面（画在上面），人和座位对得上
		for item in [["living","seat_0"],["living","seat_1"],["living","seat_2"],["living","sofa"],["study","computer"],["guest","bed"],["ayu_room","bed"],["parents","bed"],["dining","seat_2"],["mahjong","chair"]]:
			h.enter_room(item[0],false);h.transition=false;tick(5);h.go(item[1])
			var t:=0
			while t<800 and (not h.pending.is_empty() or not h.player.route.is_empty()):h._process(.05);t+=1
			if item[1]=="bed" and item[0]=="guest" and h.scene_controls:
				# 客房先弹三个选择，点「先躺一会儿」
				for b in h.scene_controls.find_children("*","Button",true,false):
					if b.text=="先躺一会儿":b.pressed.emit()
			tick(2)
			var covered:=[]
			for p in h.world.props:
				if float(p.config.foot)>h.player.position.y and h.prop_covers(p,h.player.position-Vector2(0,h.player.lift+4)):covered.append(str(p.config.file).get_file())
			check(h.player.action in ["sit","sleep","computer","drink"] and covered.is_empty(),"%s %s：动作 %s，抬 %.0f，盖住人的家具 %s"%[item[0],item[1],h.player.action,h.player.lift,str(covered)])
			h.stand_up();h.clear_scene_controls()
	h.stop_audio();vp.queue_free();await process_frame
	print("RESULT ","PASS" if fails.is_empty() else "FAIL"," ",fails.size());quit(0 if fails.is_empty() else 1)
