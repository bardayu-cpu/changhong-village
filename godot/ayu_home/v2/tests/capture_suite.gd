extends SceneTree
const Home=preload("res://ayu_home/v2/home.gd")
var out:="res://ayu_home/v2/evidence/runtime/"
var h
var vp:SubViewport
func _initialize() -> void:call_deferred("run")
func shot(tag: String) -> void:
	await create_timer(.24).timeout
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out+tag+".png")
	var f:=FileAccess.open(out+tag+".json",FileAccess.WRITE)
	var data:={"area":h.area,"hour":h.hour,"month":h.month,"weather":h.weather,"viewport":[vp.size.x,vp.size.y],"player":[h.player.position.x,h.player.position.y],"actors":{},"phase":h.phase,"greetings":h.greeting_log}
	for id in h.people:
		var a=h.people[id];data.actors[id]={"visible":a.visible,"action":a.action,"foot":[a.position.x,a.position.y],"face":a.face}
	f.store_string(JSON.stringify(data,"  "));f.close();print("SHOT ",tag)
func focus(id: String) -> void:
	var spot:Dictionary=h.world.spot(id)
	h.player.position=h.world.nearest(Home.World.v(spot.approach));h.camera=h.player.position-Vector2(0,float(h.world.cfg.get("camera_ahead",80)));h.layout()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for dim in [Vector2i(540,960),Vector2i(1170,2532)]:
		vp=SubViewport.new();vp.size=dim;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(vp)
		h=Home.new();h.save_path="/private/tmp/ayu-v2-suite.json";vp.add_child(h);h.admitted=true
		for room in ["exterior","living","dining"]:
			for hr in [7.0,12.5,20.0,23.5]:
				h.set_test_clock(hr);h.enter_room(room,false);focus({"exterior":"door","living":"album","dining":"meal"}[room]);await shot("%s-%s-%d"%[room,str(hr).replace(".","_"),dim.x])
			h.set_test_clock(12.5,10,"rain");h.enter_room(room,false);focus({"exterior":"xiduo","living":"fish","dining":"cook"}[room]);await shot("%s-rain-%d"%[room,dim.x])
		h.set_test_clock(9.5);h.enter_room("exterior",false);h.admitted=false;focus("door");h.knock();await shot("knock-absent-%d"%dim.x);h.close_modal()
		h.set_test_clock(12.5);h.knock();await create_timer(.9).timeout;await shot("knock-present-%d"%dim.x);h.admit();await create_timer(.7).timeout
		h.set_test_clock(20);h.talk("ayu");await shot("dialogue-%d"%dim.x);h.close_modal()
		h.enter_room("exterior",false);h.set_identity(true);h.set_test_clock(9.5);focus("door");h.knock();await shot("owner-%d"%dim.x);h.close_modal();h.set_identity(false)
		h.admitted=true;h.enter_room("living",false);h.set_test_clock(7);focus("fish");h.interact("fish");await shot("fish-%d"%dim.x)
		h.set_test_clock(20);focus("sofa");h.interact("sofa");await shot("sit-%d"%dim.x);h.stand_up()
		for kind in ["guitar","puzzle","album"]:
			h.activities.open(kind,{"v2_art":true});await shot("activity-%s-%d"%[kind,dim.x]);h.activities.close()
		for state in [["breakfast",7.75,"dining","meal"],["dinner",18.5,"dining","meal"],["father-away",10.5,"dining","meal"],["mother-away",14.5,"exterior","xiduo"],["all-home",20.0,"living","sofa"]]:
			h.set_test_clock(state[1]);h.enter_room(state[2],false);focus(state[3]);await shot("state-%s-%d"%[state[0],dim.x])
		for m in [4,7,10,1]:
			h.set_test_clock(12.5,m);h.enter_room("living",false);h.player.position=Vector2(310,321);h.camera=h.player.position-Vector2(0,80);h.layout();await shot("season-%d-%d"%[m,dim.x])
		for hr in [7.0,12.5,20.0,23.5]:
			h.set_test_clock(hr);h.player.position=Vector2(310,321);h.camera=h.player.position-Vector2(0,80);h.layout();await shot("south-window-%s-%d"%[str(hr).replace(".","_"),dim.x])
		h.navigation();await shot("navigation-%d"%dim.x);h.close_modal()
		vp.queue_free();await process_frame
	print("CAPTURE SUITE DONE");quit()
