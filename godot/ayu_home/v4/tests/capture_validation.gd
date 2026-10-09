extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
const World=preload("res://ayu_home/v4/world.gd")
var out:="res://ayu_home/v4/evidence/"
func _initialize() -> void:call_deferred("run")
func capture(vp:SubViewport,file:String) -> void:
	await process_frame;await process_frame;await process_frame;RenderingServer.force_draw(false);vp.get_texture().get_image().save_png(out+file)
func run() -> void:
	for dir in ["runtime","native"]:DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out+dir))
	var rooms:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/rooms.json")).rooms
	for room in rooms:
		var vp:=SubViewport.new();vp.size=Vector2i(rooms[room].size[0],rooms[room].size[1]);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
		var w=World.new();w.effects_enabled=false;vp.add_child(w);w.load_room(room);w.set_process(false);await capture(vp,"native/"+room+".png");vp.queue_free();await process_frame
	for height in [960,1168]:
		var vp:=SubViewport.new();vp.size=Vector2i(540,height);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
		if height==1168:vp.size=Vector2i(1170,2532);vp.size_2d_override=Vector2i(540,1168);vp.size_2d_override_stretch=true
		var h=Home.new();h.town_profile={"id":"v4-resolution-"+str(height),"avatar":2};h.save_path="/private/tmp/ayu-v4-resolution-"+str(height)+".json";vp.add_child(h);await process_frame;h.set_process(false);h.set_test_clock(12.25);h.admitted=true;h.close_modal()
		for room in rooms:h.enter_room(room,false);h._process(.016);await capture(vp,"runtime/"+room+"-"+str(height)+".png")
		for kind in h.Games.TITLES:
			h.games.open(kind,h.life,{"hour":20.0,"month":10});await capture(vp,"runtime/play-"+kind+"-"+str(height)+".png");h.games.close(false)
		for kind in ["guitar","puzzle","album"]:h.activities.open(kind,{"v2_art":true});await capture(vp,"runtime/play-"+kind+"-"+str(height)+".png");h.activities.close()
		h.welcome();await capture(vp,"runtime/welcome-"+str(height)+".png");h.close_modal();h.today();await capture(vp,"runtime/today-"+str(height)+".png");h.close_modal()
		h.collection_page();await capture(vp,"runtime/collection-"+str(height)+".png");h.close_modal()
		for person in ["ayu","mother","father"]:h.dialogue(h.NAMES[person],"喜欢这里就留下来住吧。家里给你留了菜，慢慢吃。",person);h.talk_chars=999;h._process(.016);await capture(vp,"runtime/dialogue-"+person+"-"+str(height)+".png");h.close_modal()
		for spec in [[3,12.25,"clear"],[7,20.0,"clear"],[10,18.5,"rain"],[1,23.0,"clear"]]:
			h.set_test_clock(spec[1],spec[0],spec[2]);h.enter_room("grove",false);h.player.position=h.world.nearest(Vector2(724,459));h.camera=h.player.position-Vector2(0,65);h.layout();await capture(vp,"runtime/grove-season-"+str(spec[0])+"-"+str(height)+".png")
			h.take_photo();await capture(vp,"runtime/photo-season-"+str(spec[0])+"-"+str(height)+".png");h.photo.close(false)
		h.stop_audio();vp.queue_free();await process_frame
	print("RESULT PASS capture validation 27 native / 2 portrait resolutions");quit()
