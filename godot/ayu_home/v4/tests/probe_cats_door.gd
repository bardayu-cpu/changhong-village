extends SceneTree
## 阿鱼截图：客厅通猫窝走道的门口冒「这里过不去」。站在门口附近各处，点门洞 / 门外各处、方向键往上推，看会不会冒这句、过不过得去
var h
func _initialize() -> void:call_deferred("run")
func step(n:int) -> void:
	for i in n:
		h._process(.05);h.world._process(.05)
		if h.transition:h.transition=false;h.fade.color.a=0
func run() -> void:
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp)
	h=load("res://ayu_home/v4/home.gd").new();h.town_profile={"id":"pcd"};h.save_path=OS.get_user_data_dir()+"/pcd.json";vp.add_child(h);await process_frame;h.set_process(false);h.admitted=true;h.close_modal();h.sound_on=false;h.set_test_clock(14.5)
	var d:Dictionary=h.world.spot("to_cats") if false else {}
	h.enter_room("living",false,"exterior");d=h.world.spot("to_cats");var pl:Dictionary=h.world.door_plane(d)
	print("门槛 ",pl)
	var bad:=0;var n:=0
	for sx in [-30,-15,0,15,30]:
		for sy in [30,60,100]:
			for mode in ["click_in","click_out","key"]:
				h.enter_room("living",false,"exterior");h.cooldown=0;h.player.position=h.world.nearest(pl.point+Vector2(sx,sy));step(5);h.player.bubble_time=0;h.blocked_notice_until=0
				if mode=="key":
					var e:=InputEventKey.new();e.keycode=KEY_UP;e.physical_keycode=KEY_UP;e.pressed=true;Input.parse_input_event(e);Input.flush_buffered_events()
					for i in 80:
						step(1)
						if h.area!="living":break
					e.pressed=false;Input.parse_input_event(e);Input.flush_buffered_events()
				else:
					var p:Vector2=pl.point+Vector2(sx,-4 if mode=="click_in" else -40)
					var ev:=InputEventMouseButton.new();ev.button_index=MOUSE_BUTTON_LEFT;ev.pressed=true;ev.position=h.world.get_global_transform_with_canvas()*p;h._unhandled_input(ev)
					for i in 300:
						step(1)
						if h.area!="living":break
				n+=1
				var said:String=h.player.bubble.text if h.player.bubble_time>0 else ""
				if h.area!="cats" or said.contains("过不去"):bad+=1;print("× ",mode," 站在偏 ",Vector2(sx,sy)," → ",h.area," 说「",said,"」")
	print("RESULT ","PASS" if bad==0 else "FAIL"," ",n," 次 ",bad," 次不对");quit()
