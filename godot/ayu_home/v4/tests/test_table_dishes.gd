extends SceneTree
## 第六轮第 20 条：早饭前后家人从门口走到座位的一路，每一帧量：画在人前面的菜碗有没有压到人的头脸
var h
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp)
	h=load("res://ayu_home/v4/home.gd").new();h.town_profile={"id":"td"};h.save_path=OS.get_user_data_dir()+"/td.json";vp.add_child(h);await process_frame;h.set_process(false);h.admitted=true;h.close_modal();h.sound_on=false
	var bad:=0;var frames:=0
	for start in [7.2,11.9,17.9]:
		h.set_test_clock(start);h.enter_room("dining",false,"living");h.player.position=h.world.nearest(Vector2(300,330));print("桌面层 ",h.world.table_top," 家人 ",[h.people.ayu.visible,h.people.mother.visible])
		for i in 1800:
			if i%60==0:h.test_hour=start+i/60*.02;h.read_clock();h.sync_family(false)
			h._process(.05);h.world._process(.05)
			if i%3:continue
			if h.world.table_top==null:continue
			var center:Vector2=h.World.v(h.world.cfg.get("meal_center",[159,232]))
			for id in ["ayu","father","mother"]:
				var a=h.people[id]
				if not a.visible:continue
				frames+=1
				var face:=Rect2(a.position+Vector2(-15,a.head_top()),Vector2(30,34))
				# 菜画在人前面 = 桌子那层排在人后面画（桌子前沿比人的脚靠前）
				var dish_front:bool=h.world.table_top.position.y>a.position.y
				for k in 3:
					var at:Vector2=center+Vector2(cos(k*TAU/3)*45,sin(k*TAU/3)*32)
					if dish_front and Rect2(at-Vector2(23,17),Vector2(46,34)).grow(-6).intersects(face):bad+=1;print("压 ",id," ",a.position.round()," 动作 ",a.action);break
		h.set_test_clock(start+.5)
	print("RESULT ","PASS" if bad==0 else "FAIL"," 量了 %d 帧人，菜碗压头 %d 次"%[frames,bad]);quit()
