extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var h
var vp:SubViewport
var checks:Array=[]
var out:="res://ayu_home/v4/evidence/floor1-redraw/"
func _initialize() -> void:call_deferred("run")
func snap(name:String) -> void:
	if h.games.canvas:h.games.canvas.queue_redraw()
	for i in 5:await process_frame
	RenderingServer.force_draw(false);vp.get_texture().get_image().save_png(out+name+".png")
func check(ok:bool,name:String) -> void:checks.append({"pass":ok,"name":name});print("CHECK ",ok," ",name)
func tick(seconds:float) -> void:
	for i in int(ceil(seconds/.1)):h.games._process(.1)
	await process_frame
func touch(p:Vector2,down:bool) -> void:
	var e:=InputEventScreenTouch.new();e.index=0;e.position=h.games.canvas.get_global_transform()*(h.games.offset()+p*h.games.scale_factor());e.pressed=down;vp.push_input(e,true);await process_frame
func move(p:Vector2) -> void:
	var e:=InputEventScreenDrag.new();e.index=0;e.position=h.games.canvas.get_global_transform()*(h.games.offset()+p*h.games.scale_factor());vp.push_input(e,true);await process_frame
func tap(p:Vector2) -> void:await touch(p,true);await touch(p,false)
func drag(a:Vector2,b:Vector2) -> void:
	await touch(a,true)
	for i in 8:await move(a.lerp(b,float(i+1)/8))
	await touch(b,false)
func hold(p:Vector2,seconds:float) -> void:await touch(p,true);await tick(seconds);await touch(p,false)
func finish_game(kind:String) -> void:
	check(h.games.finished,kind+" completed through existing gestures")
	await snap("game-"+kind+"-finished")
	h.games.close();check(h.games.root==null,kind+" close")
func open_game(kind:String,hour:=12.25) -> void:
	h.games.open(kind,h.life,{"hour":hour,"month":10,"sound":false});h.games.set_process(false);await snap("game-"+kind+("-night" if kind=="stars" and hour>=18 else ("-day" if kind=="stars" else "")))
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var path:="/private/tmp/ayu-floor1-redraw-captures.json"
	if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	vp=SubViewport.new();vp.size=Vector2i(540,960);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(vp)
	h=Home.new();h.town_profile={"id":"redraw-capture","avatar":2};h.save_path=path;vp.add_child(h);await process_frame;h.set_process(false);h.set_test_clock(12.25);h.admitted=true;h.close_modal();h.sound_on=false
	for room in h.definitions:
		if int(h.definitions[room].floor)!=1:continue
		h.enter_room(room,false);h._process(.1);h.camera=h.World.v(h.world.cfg.source_offset)+(Vector2(h.world.cfg.source_crop[2]-h.world.cfg.source_crop[0],h.world.cfg.source_crop[3]-h.world.cfg.source_crop[1])*.5);h.layout();await snap("room-"+room)
	h.enter_room("dining",false);h.eat_together(h.world.spot("meal"));h.camera=h.World.v(h.world.cfg.meal_center)+Vector2(0,10);h.layout();await snap("meal");h.stand_up()
	await open_game("flowers")
	for i in 3:await drag(Vector2(80+i*142,135),Vector2(168+i*53,280+(i%2)*40))
	await finish_game("flowers")
	await open_game("tea")
	await hold(Vector2(121,131),4.2);await hold(Vector2(121,131),3.3);await drag(Vector2(90,156),Vector2(231,296));await hold(Vector2(121,131),3.3);await tick(5.3);await tap(Vector2(338,461));await finish_game("tea")
	await open_game("soup")
	for p in [Vector2(90,115),Vector2(225,110),Vector2(367,120)]:await drag(p,Vector2(230,295))
	var center:=Vector2(230,294);await touch(center+Vector2(84,0),true)
	for i in 80:await move(center+Vector2.from_angle(float(i)*TAU/28)*84)
	await touch(center,false);await tick(5.1);await drag(center,Vector2(346,464));await finish_game("soup")
	await open_game("laundry")
	for p in [Vector2(70,135),Vector2(213,104),Vector2(371,132)]:await drag(p,Vector2(232,311))
	await hold(Vector2(232,227),4.3)
	for i in 3:await drag(Vector2(145+i*82,316),Vector2(92+i*124,446))
	await finish_game("laundry")
	await open_game("wood");await touch(Vector2(100,250),true)
	for i in 90:await move(Vector2(100 if i%2==0 else 360,250+sin(i)*35));await tick(.1)
	await touch(Vector2(360,250),false);await finish_game("wood")
	await open_game("pairs")
	for value in 4:
		for i in 8:
			if h.games.pairs[i]==value:await tap(h.games.card_rect(i).get_center())
	await finish_game("pairs")
	await open_game("tree");var pos:Vector2=h.games.plot_rect(0).get_center();await tap(pos)
	h.games.footer.get_child(1).pressed.emit();await tap(pos);h.games.footer.get_child(2).pressed.emit();await tap(pos);await finish_game("tree")
	await open_game("fruit")
	for p in [Vector2(132,201),Vector2(288,173),Vector2(350,287)]:await tap(p)
	await finish_game("fruit")
	await open_game("stars",12.25);h.games.footer.get_child(0).pressed.emit();h.games.close()
	await open_game("stars",20)
	for p in h.games.stars.duplicate():await tap(p)
	await tick(10.2);await snap("game-stars-constellation-meteor");await tap(Vector2(219,123));check(h.games.wish_input!=null,"stars opens wish on meteor");h.games.close()
	# Requested football artwork only; no outdoor walking or world regression.
	h.enter_room("exterior",false);h.start_ball();h.update_ball(.016);h.camera=h.ball_position-Vector2(0,45);h.layout();await snap("football");h.clear_scene_controls()
	var failed:Array=checks.filter(func(c):return not c.pass)
	var f:=FileAccess.open(out+"game-checks.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failed,"scope":"only redrawn activities at 540x960, real viewport touch input; timers advanced in isolated test save"},"  "));f.close();print("RESULT ","PASS" if failed.is_empty() else "FAIL");h.stop_audio();vp.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
