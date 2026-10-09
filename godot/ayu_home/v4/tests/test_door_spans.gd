extends SceneTree
## 每扇门照阿鱼说的走一遍（门的冷却、过门判定照原样）：
## 点门洞左 / 中 / 右，点门外左 / 中 / 右，方向键贴着门洞左边 / 中间 / 右边往外推，九种都要过、过去不被弹回。
## 用法：Godot --headless --path godot --script res://ayu_home/v4/tests/test_door_spans.gd [-- --rooms=a,b]
const World=preload("res://ayu_home/v4/world.gd")
var h
var vp:SubViewport
func _initialize() -> void:call_deferred("run")
func step(n:int) -> void:
	for i in n:
		h._process(.05);h.world._process(.05)
		if h.transition:h.transition=false;h.fade.color.a=0 # 换房间的淡入（真玩时 0.38 秒）这里直接收尾
func click(p:Vector2) -> void:
	var s:Vector2=h.world.get_global_transform_with_canvas()*p
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=s;h._unhandled_input(e)
func key(code:Key,down:bool) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func run() -> void:
	var only:Array=[]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rooms="):only=Array(a.substr(8).split(","))
	vp=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp)
	var save:=OS.get_user_data_dir()+"/door-spans.json";DirAccess.remove_absolute(save)
	h=load("res://ayu_home/v4/home.gd").new();h.town_profile={"id":"door-spans","avatar":2};h.save_path=save;vp.add_child(h);await process_frame
	h.set_process(false);h.set_test_clock(14.5);h.admitted=true;h.close_modal();h.sound_on=false
	var total:=0;var bad:=0;var fails:=[]
	for room in (only if not only.is_empty() else h.definitions.keys()):
		for d in h.definitions[room].doors:
			if str(d.id) in ["to_stairs1","to_stairs2"]:continue # 楼梯是一级级走的楼梯路线，另测
			for mode in ["门洞","门外","方向键"]:
				for side in [-1,0,1]:
					h.enter_room(room,false);h.transition=false;h.fade.color.a=0;h.cooldown=0
					var plane:Dictionary=h.world.door_plane(d);var n:Vector2=plane.normal;var t:=Vector2(-n.y,n.x);var w:float=plane.width
					var off:Vector2=t*side*maxf(0,w*.5-10)
					var inside:Vector2=h.world.nearest(plane.point+off-n*50)
					h.player.position=inside;h.camera=inside;step(12)
					match mode:
						"门洞":click(plane.point+off+n*4)
						"门外":click(plane.point+off+n*40)
						"方向键":
							var code:Key=KEY_RIGHT if n.x>.5 else (KEY_LEFT if n.x<-.5 else (KEY_DOWN if n.y>.5 else KEY_UP))
							key(code,true)
							for i in 120:
								step(1)
								if h.area!=room:break
							key(code,false)
					for i in 400:
						step(1)
						if h.area!=room:break
					h.transition=false;var ok:bool=h.area==str(d.target)
					if ok:
						step(30);ok=h.area==str(d.target)
					total+=1
					if not ok:
						bad+=1;fails.append("%s %s %s%s 到了 %s 人在 %s"%[room,d.id,mode,["左","中","右"][side+1],h.area,str(h.player.position.round())])
	# 阿鱼点名的几处：点院子台阶进家门（不是坐下）；在客厅点门外那段石板路（一楼画上）走出门；院门口点左右两边的土路走出去、走到点的地方
	var extras:=[["exterior",Vector2(780,615),"living","点台阶"],["living",Vector2(330,520),"exterior","客厅点门外石板路左"],["living",Vector2(420,520),"exterior","客厅点门外石板路右"],["exterior",Vector2(420,1000),"side_path","院门口点左边土路"],["exterior",Vector2(1080,1000),"side_path","院门口点右边土路"],["side_path",Vector2(745,880),"exterior","小道点院子里"]]
	for x in extras:
		h.enter_room(x[0],false);h.transition=false;h.cooldown=0
		if x[0]=="exterior":h.player.position=h.world.nearest(Vector2(745,960) if x[3].begins_with("院门") else Vector2(783,700))
		else:h.player.position=h.world.nearest(Vector2(355,380))
		h.camera=h.player.position;step(12);click(x[1])
		for i in 600:
			step(1)
			if h.area==x[2] and h.player.route.is_empty() and h.pending.is_empty():break
		step(10);total+=1
		var ok:bool=h.area==x[2] and h.player.action!="sit"
		if x[3].ends_with("土路"):ok=ok and h.player.position.distance_to(h.world.nearest(x[1]))<12 # 走到点的地方
		print("EXTRA ",x[3]," → ",h.area," 人在 ",h.player.position.round()," 动作 ",h.player.action)
		if not ok:bad+=1;fails.append(x[3]+" 到了 "+h.area)
	for f in fails:print("没过 ",f)
	print("RESULT ","PASS" if bad==0 else "FAIL"," 共 %d 次，没过 %d 次"%[total,bad])
	h.stop_audio();vp.queue_free();await process_frame;quit()
