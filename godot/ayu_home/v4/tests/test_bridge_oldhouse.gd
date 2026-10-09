extends SceneTree
## 第六轮第 25 条：小桥点老屋那边的地面，人自己走过去（门的冷却、换房间都照原样）
var h
func _initialize() -> void:call_deferred("run")
func step(n:int) -> void:
	for i in n:
		h._process(.05);h.world._process(.05)
		if h.transition:h.transition=false;h.fade.color.a=0
func run() -> void:
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp)
	h=load("res://ayu_home/v4/home.gd").new();h.town_profile={"id":"bo"};h.save_path=OS.get_user_data_dir()+"/bo.json";vp.add_child(h);await process_frame;h.set_process(false);h.admitted=true;h.close_modal();h.sound_on=false;h.set_test_clock(14.5)
	var bad:=0
	for q in [Vector2(1312,372),Vector2(1343,416),Vector2(1300,330),Vector2(1380,450)]:
		h.enter_room("bridge",false,"side_path");h.cooldown=0;step(5)
		print("  老屋能站=",h.nav("oldhouse").passable(q)," 小桥能站=",h.world.passable(q))
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=h.world.get_global_transform_with_canvas()*q;h._unhandled_input(e)
		for i in 600:
			step(1)
			if h.area=="oldhouse" and h.player.route.is_empty() and h.pending.is_empty():break
		var d:float=h.player.position.distance_to(h.world.nearest(q)) if h.area=="oldhouse" else 9999.0
		print("小桥点老屋 ",q," → ",h.area," 离点的地方 ",int(d))
		if h.area!="oldhouse" or d>16:bad+=1
	print("RESULT ","PASS" if bad==0 else "FAIL");quit()
