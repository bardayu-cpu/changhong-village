extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var h
var vp:SubViewport
var segment:=""
var frame_no:=0
var recorded_segments:Dictionary={}
var failures:Array=[]
var checks:Array=[]
var started:=0
var out:="res://ayu_home/v4/evidence/play/"
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks.append({"pass":ok,"name":label});print("CHECK ",label," ",ok)
	if not ok:failures.append(label)
func shot() -> void:
	if segment.is_empty():return
	await process_frame;RenderingServer.force_draw(false)
	vp.get_texture().get_image().save_png(out+segment+"/%04d.png"%frame_no);frame_no+=1
func begin(name:String) -> void:
	segment=name;frame_no=0;DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out+name))
	if not recorded_segments.has(name):
		for file in DirAccess.get_files_at(out+name):
			if file.ends_with(".png") and file.get_basename().is_valid_int():DirAccess.remove_absolute(ProjectSettings.globalize_path(out+name+"/"+file))
		recorded_segments[name]=true
func wait_for(seconds:float) -> void:
	var left:=seconds
	while left>0:
		await create_timer(minf(.35,left)).timeout;left-=.35;await shot()
func touch(p:Vector2,down:bool) -> void:
	var e:=InputEventScreenTouch.new();e.index=0;e.position=p;e.pressed=down;vp.push_input(e,true);await process_frame
func move(p:Vector2,relative:Vector2=Vector2.ZERO) -> void:
	var e:=InputEventScreenDrag.new();e.index=0;e.position=p;e.relative=relative;vp.push_input(e,true);await process_frame
func click_control(c:Control) -> void:
	if not is_instance_valid(c):check(false,"按钮存在 "+segment);return
	var p:=c.get_global_rect().get_center()
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=p;vp.push_input(e,true);await process_frame
	await wait_for(.2)
func find_button(n:Node,copy:String):
	if n is Button and n.text==copy:return n
	for c in n.get_children():
		var b=find_button(c,copy)
		if b:return b
	return null
func button(copy:String) -> void:
	var b=find_button(h,copy)
	if b:await click_control(b)
	else:check(false,"缺按钮 "+copy+" "+segment)
func point(p:Vector2) -> Vector2:return h.games.canvas.get_global_transform()*(h.games.offset()+p*h.games.scale_factor())
func tap(p:Vector2) -> void:
	await touch(point(p),true);await touch(point(p),false);await wait_for(.15)
func drag(a:Vector2,b:Vector2,seconds:=.65) -> void:
	await touch(point(a),true)
	for i in 8:await move(point(a.lerp(b,float(i+1)/8)));await create_timer(seconds/8).timeout
	await touch(point(b),false);await shot()
func hold(p:Vector2,seconds:float) -> void:
	await touch(point(p),true);await wait_for(seconds);await touch(point(p),false)
func open_game(kind:String,room:String,id:String,record_as:="") -> void:
	h.close_modal();h.games.close(false);h.activities.close();h.immersive.close(false);h.photo.close(false);h.enter_room(room,false);await create_timer(.2).timeout
	begin(kind if record_as.is_empty() else record_as);h.go(id);var deadline:=Time.get_ticks_msec()+60000
	while h.games.root==null and Time.get_ticks_msec()<deadline:await wait_for(.3)
	check(h.games.root!=null,"走近进入 "+kind)
	if h.games.root==null:push_error("Cannot reach game: "+kind);quit(1);return
	await wait_for(.4)
func end_game() -> void:
	check(h.games.root!=null and h.games.finished,"完整完成 "+segment);await wait_for(.8);await button("收起");check(h.games.root==null,"退出 "+segment);segment=""
func run() -> void:
	started=Time.get_ticks_msec();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var path:="/private/tmp/ayu-v4-touch-play.json"
	if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	vp=SubViewport.new();vp.size=Vector2i(540,960);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(vp)
	h=Home.new();h.town_profile={"id":"touch-play-isolated","avatar":2};h.save_path=path;vp.add_child(h);await process_frame;await process_frame;h.set_test_clock(12.25);h.admitted=true;h.close_modal();h.sound_on=true
	await open_game("tea","mahjong","tea")
	await hold(Vector2(121,131),4.2);check(h.games.stage==1,"烧水完成")
	await hold(Vector2(121,131),3.3);check(h.games.stage==2,"温杯松手判定")
	await drag(Vector2(90,156),Vector2(231,296));check(h.games.stage==3,"放茶叶")
	await hold(Vector2(121,131),3.3);await wait_for(5.3);await tap(Vector2(338,461));await end_game()
	await open_game("soup","kitchen","stove")
	for p in [Vector2(90,115),Vector2(225,110),Vector2(367,120)]:await drag(p,Vector2(230,295))
	var center:=Vector2(230,294);await touch(point(center+Vector2(84,0)),true)
	for i in 80:await move(point(center+Vector2.from_angle(float(i)*TAU/28)*84));await create_timer(.045).timeout
	await touch(point(center),false);await wait_for(5.1);await drag(center,Vector2(346,464));await end_game()
	await open_game("laundry","laundry","wash")
	for p in [Vector2(70,135),Vector2(213,104),Vector2(371,132)]:await drag(p,Vector2(232,311))
	await hold(Vector2(232,227),4.3)
	for i in 3:await drag(Vector2(145+i*82,316),Vector2(92+i*124,446))
	await end_game()
	await open_game("wood","workshop","wood")
	await touch(point(Vector2(100,250)),true)
	for i in 90:await move(point(Vector2(100 if i%2==0 else 360,250+sin(i)*35)));await create_timer(.1).timeout;if i%4==0:await shot()
	await touch(point(Vector2(360,250)),false);await end_game()
	await open_game("fruit","garden","fruit")
	# Claude 10/5：摘果改成「点熟果子让它掉、拖篮子去接」
	var picked:=0
	for f in h.games.fruits:
		if not f.ripe or picked>=3:continue
		var at:Vector2=f.pos;await tap(at);await drag(Vector2(h.games.basket_x,480),Vector2(at.x,480),.25);await wait_for(1.0);picked+=1
	await button("送一份给家人");await end_game()
	for spec in [["garden","garden","garden_play",0],["flower_garden","garden","flowers",1],["tree","grove","tree",0]]:
		await open_game(spec[0],spec[1],spec[2]);var pos:Vector2=h.games.plot_rect(spec[3]).get_center()
		await tap(pos);await button("播种");await tap(pos);await button("浇水");await tap(pos);await end_game()
	await open_game("flowers","dining","flowers")
	for i in 3:await drag(Vector2(80+i*142,135),Vector2(168+i*53,280+(i%2)*40))
	await end_game()
	await open_game("fishing","bridge","fish")
	await drag(Vector2(360,530),Vector2(217,232));await wait_for(9.7)
	# Capturing a PNG can stall the main thread on a busy machine. Keep the
	# tension controller responsive between sparse evidence frames; never
	# force the game state, completion, or its normal difficulty.
	var down:=false;var safety:=Time.get_ticks_msec()+180000;var next_fishing_shot:=0
	while h.games.stage==2 and Time.get_ticks_msec()<safety:
		if not down and h.games.tension<.4:await touch(point(Vector2(240,250)),true);down=true
		if down and h.games.tension>.73:await touch(point(Vector2(240,250)),false);down=false
		await create_timer(.08).timeout
		if Time.get_ticks_msec()>=next_fishing_shot:
			await shot();next_fishing_shot=Time.get_ticks_msec()+1500
	if down:await touch(point(Vector2(240,250)),false)
	await button("带回鱼缸");await end_game()
	await open_game("net","garden","pond")
	# Claude 10/5：捞鱼要把网兜慢慢停在鱼底下一会儿
	for i in 3:
		var f:Dictionary=h.games.net_fish[i];await touch(point(f.pos+Vector2(30,0)),true)
		for k in 16:await move(point(f.pos));await create_timer(.06).timeout
		await touch(point(f.pos),false);await shot()
	await end_game()
	await open_game("pairs","mahjong","pairs");await wait_for(1.8) # 开局先亮牌给你记
	for value in 4:
		for i in 8:
			if h.games.pairs[i]==value:await tap(h.games.card_rect(i).get_center())
	await end_game()
	h.set_test_clock(20,7)
	await open_game("stars","terrace","stars")
	for i in 6:await tap(h.games.stars[i])
	await wait_for(maxf(.2,10.1-h.games.elapsed));await tap(Vector2(219,123));await wait_for(.4)
	if h.games.wish_input:
		h.games.wish_input.grab_focus()
		for unicode_value in "下次和家人一起看星星。".to_utf32_buffer().size()/4:
			var e:=InputEventKey.new();e.pressed=true;e.unicode="下次和家人一起看星星。".unicode_at(unicode_value);vp.push_input(e,true);await process_frame
		await button("记在生活册")
	check(h.life.data.wishes.size()>0,"流星愿望保存");await end_game()
	h.set_test_clock(12.25,10)
	for kind in ["guitar","puzzle","album"]:
		begin(kind);h.activities.open(kind,{"v2_art":true});await wait_for(.5);var a=h.activities
		if kind=="guitar":
			for n in a.melody:await click_control(a.note_buttons[n]);await wait_for(.15)
		elif kind=="puzzle":
			for i in 9:
				if a.order[i]!=i:var j:int=a.order.find(i);await click_control(a.tiles[i]);await click_control(a.tiles[j])
		else:
			for tile in a.album_tray:await click_control(tile);await click_control(a.album_slots[tile.index])
		check(a.finished,"完成 "+kind);await wait_for(.8);await button("收起");segment=""
	begin("fish-feeding");h.enter_room("living",false);h.immersive.open("fish",{"hour":12.25,"fish":h.life.data.fish});await wait_for(.5)
	for i in 6:await button("轻轻投食");await wait_for(2.5)
	await wait_for(5);check(h.immersive.finished,"鱼群追食吃饱");await button("收起")
	begin("pets");h.set_test_clock(23);h.enter_room("cats",false);await wait_for(.4)
	for id in ["qiuqiu","luoluo","tiantian"]:
		h.go("person:"+id);var deadline:=Time.get_ticks_msec()+30000
		while not h.pending.is_empty() and Time.get_ticks_msec()<deadline:await wait_for(.4)
		await button("喂猫条");await button("逗一逗");await wait_for(2)
	check(h.life.cats_today()==3,"场景里摸喂三猫")
	begin("football");h.set_test_clock(12.25);h.enter_room("exterior",false);h.go("ball");await wait_for(5);await button("踢一脚");await wait_for(15);check(h.ball_return_count>0,"喜多沿路叼球回来");await button("摸摸喜多");await button("喂狗零食");await wait_for(2)
	begin("polaroid");h.clear_scene_controls();h.take_photo();await wait_for(1);await button("换姿势");await button("咔嚓，拍一张");await wait_for(3.5);await button("收进相册");check(h.life.data.photos.size()>0,"拍立得参数保存");await button("收起")
	# Harvest visuals use only this isolated fixture clock. Production has no fast-forward.
	for spec in [["garden","garden","garden_play",0,14401],["flower_garden","garden","flowers",1,14401],["tree","grove","tree",0,259201]]:
		h.life.now_override=Time.get_unix_time_from_system()+spec[4]
		await open_game(spec[0],spec[1],spec[2],"harvest-"+spec[0]);await wait_for(1);await button("收成");await tap(h.games.plot_rect(spec[3]).get_center());await end_game()
	h.life.now_override=-1
	segment="";var report={"checks":checks,"failures":failures,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"saved_events":h.life.data.completed}
	var f:=FileAccess.open("res://ayu_home/v4/evidence/gesture-play.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print("RESULT ","PASS" if failures.is_empty() else "FAIL", " ",JSON.stringify(failures));h.stop_audio();vp.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
