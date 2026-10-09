extends SceneTree
## 第六轮第 24 条：点屋里、院里自己的地面永远不算出门（体验师的两处 + 每间房随机点自己的地面）
var h
func _initialize() -> void:call_deferred("run")
func step(n:int) -> void:
	for i in n:
		h._process(.05);h.world._process(.05)
		if h.transition:h.transition=false;h.fade.color.a=0
func click(p:Vector2) -> void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=h.world.get_global_transform_with_canvas()*p;h._unhandled_input(e)
func run() -> void:
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp)
	h=load("res://ayu_home/v4/home.gd").new();h.town_profile={"id":"of"};h.save_path=OS.get_user_data_dir()+"/of.json";vp.add_child(h);await process_frame;h.set_process(false);h.admitted=true;h.close_modal();h.sound_on=false;h.set_test_clock(14.5)
	var bad:=0;var n:=0
	for c in [["exterior",Vector2(742,862),Vector2(818,994)],["garden",Vector2(518,290),Vector2(451,125)]]:
		h.enter_room(c[0],false);h.cooldown=0;h.player.position=h.world.nearest(c[1]);step(3);click(c[2]);step(400);n+=1
		print("体验师那处 ",c[0]," 点 ",c[2]," → ",h.area," 人在 ",h.player.position.round())
		if h.area!=c[0]:bad+=1
	var rng:=RandomNumberGenerator.new();rng.seed=24
	for room in h.definitions:
		h.enter_room(room,false);h.cooldown=0;step(3)
		var sz:Vector2=h.World.v(h.world.cfg.size);var k:=0;var tries:=0
		while k<25 and tries<4000:
			tries+=1;var q:=Vector2(rng.randf_range(0,sz.x),rng.randf_range(0,sz.y))
			if not h.world.passable(q) or h.door_in_opening(q)!="":continue
			var on_door:=false
			for d in h.world.cfg.doors:
				if q.distance_to(h.World.v(d.pos))<26:on_door=true # 点在门的提示泡那一点上，是点门
			if on_door:continue
			k+=1;n+=1;click(q);step(300)
			if h.area!=room:bad+=1;print("× ",room," 点自己的地面 ",q.round()," 被带到 ",h.area);h.enter_room(room,false);h.cooldown=0;step(3)
	print("RESULT ","PASS" if bad==0 else "FAIL"," 点了 %d 次，出了门 %d 次"%[n,bad]);quit()
