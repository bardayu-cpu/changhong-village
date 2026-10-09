extends SceneTree
## 第六轮第 9、22、23 条：话泡、提示泡压不压任何人的头和脸（手机竖屏 540×960、长屏 540×1168 各量一遍）
var h
var fails:=[]
var n:=0
func _initialize() -> void:call_deferred("run")
func step(k:int) -> void:
	for i in k:h._process(.05);h.world._process(.05)
func measure(tag:String) -> void:
	await process_frame
	var xf:Transform2D=h.world.get_global_transform_with_canvas();var faces:={}
	for a in [h.player]+h.people.values():
		if a.visible:faces[a]=h.face_rect(a,xf)
	for a in [h.player]+h.people.values():
		if not (a.visible and a.bubble.visible):continue
		var r:=Rect2(xf*(a.position+a.bubble.position),a.bubble.size*h.view_scale);n+=1
		if OS.get_cmdline_user_args().has("--debug"):print("  泡 ",a.id," ",r," 脸 ",faces.values()," 顶 ",h.hud_bottom())
		for b in faces:
			if faces[b].intersects(r.grow(-1)):fails.append(tag+"：话泡（"+a.id+"「"+a.bubble.text+"」）压到 "+b.id+" 的头脸")
		if r.position.x<8 or r.end.x>h.get_viewport_rect().size.x-8:fails.append(tag+"：话泡出了左右安全区")
	for m in h.marker_nodes:
		if not m.button.visible:continue
		var r:=Rect2(m.button.position,m.button.size).grow(-3);n+=1
		var owner=h.people.get(str(m.hot.id).substr(7)) if str(m.hot.id).begins_with("person:") else null
		for b in faces:
			if b!=owner and faces[b].intersects(r):fails.append(tag+"：提示泡（"+str(m.hot.id)+"）压到 "+b.id+" 的头脸")
		if owner:
			var d:float=(r.get_center()-(xf*(owner.position+Vector2(0,owner.head_top())))).length()
			if d>90:fails.append(tag+"：「!」离主人 %.0f 像素"%d)
	var shown:int=h.marker_nodes.filter(func(m):return m.button.visible).size()
	if shown>1:fails.append(tag+"：同时出了 %d 个提示泡"%shown)
	print(tag," 提示泡 ",shown," 个")
func run() -> void:
	for tall in [false,true]:
		var vp:=SubViewport.new();vp.size=Vector2i(540,1168 if tall else 960);root.add_child(vp)
		h=load("res://ayu_home/v4/home.gd").new();h.town_profile={"id":"sf"};h.save_path=OS.get_user_data_dir()+"/sf.json";vp.add_child(h);await process_frame;h.set_process(false);h.admitted=true;h.close_modal();h.sound_on=false
		var pre:="长屏 " if tall else ""
		# 喜多说话、玩家站在喜多正后面
		h.set_test_clock(14.5);h.enter_room("exterior",false,"side_path");step(5)
		var dog=h.people.xiduo
		if dog.visible:
			h.player.position=h.world.nearest(dog.position+Vector2(4,-14));h.camera=h.player.position;step(10);dog.say("好吃！");step(1);await measure(pre+"喜多说话、玩家在后面")
			h.player.position=h.world.nearest(dog.position+Vector2(-20,-8));step(5);dog.say("汪！尾巴摇起来了。");step(1);await measure(pre+"喜多说长一点的话")
		# 晚上沙发上三个人挨着，跟妈妈说话
		h.set_test_clock(20.0);h.enter_room("living",false,"exterior");step(900)
		for id in ["mother","father","ayu"]:
			if h.people[id].visible:
				h.player.position=h.world.nearest(h.people[id].position+Vector2(30,40));h.camera=h.player.position;step(10)
				h.people[id].say("来做客不用拘束，想做什么就慢慢试。");step(1);await measure(pre+"沙发上"+id+"说话");break
		# 玩家自己靠着顶栏说话
		h.set_test_clock(12.25);h.enter_room("kitchen",false,"dining");h.go("sink");step(200);step(3);await measure(pre+"厨房洗手玩家说话")
		# 吃饭夹菜
		h.life.data.resident=true;h.enter_room("dining",false,"living");step(30);h.eat_together(h.world.spot("meal"));step(4);h.serve_family();step(2);await measure(pre+"吃饭夹菜")
		# 猫旁边站
		h.set_test_clock(12.5);h.enter_room("living",false,"exterior");step(20)
		for c in ["qiuqiu","luoluo","tiantian"]:
			if h.people[c].visible:h.player.position=h.world.nearest(h.people[c].position+Vector2(0,-8));step(10);await measure(pre+"贴着猫站");break
		h.set_test_clock(23.5);h.enter_room("cats",false,"living");step(20);h.player.position=h.world.nearest(Vector2(165,300));step(10);await measure(pre+"深夜猫挤在一起")
		h.set_test_clock(7.6);h.enter_room("dining",false,"living");step(200);await measure(pre+"早饭餐厅")
		h.stop_audio();vp.queue_free();await process_frame
	for f in fails:print("× ",f)
	print("RESULT ","PASS" if fails.is_empty() else "FAIL"," 量了 %d 个泡，%d 处不对"%[n,fails.size()]);quit()
