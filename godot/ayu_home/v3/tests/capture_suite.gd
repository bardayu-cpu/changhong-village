extends SceneTree
const Home=preload("res://ayu_home/v3/home.gd")
var h
var vp:SubViewport
var out:="res://ayu_home/v3/evidence/runtime/"
var dims:=[Vector2i(540,960),Vector2i(540,1168)]
func _initialize() -> void:call_deferred("run")
func shot(tag:String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var im:=vp.get_texture().get_image();im.save_png(out+tag+".png");print("SHOT ",tag)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for dim in dims:
		vp=SubViewport.new();vp.size=dim;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(vp)
		if dim.y==1168:vp.size=Vector2i(1170,2532);vp.size_2d_override=Vector2i(540,1168);vp.size_2d_override_stretch=true
		h=Home.new();h.test_panel_enabled=true;h.save_path="/private/tmp/ayu-v3-capture.json";vp.add_child(h);await process_frame;h.admitted=true;h.set_process(false);h.set_test_clock(12.25)
		for room in h.definitions:
			h.enter_room(room,false);h.cooldown=999;h.set_process(false);h._process(.016);await shot(room+"-"+str(dim.y))
		for group in ["一楼","二楼","屋外"]:h.navigation(group);await shot("map-"+group+"-"+str(dim.y));h.close_modal()
		h.enter_room("living",false);h.set_test_clock(20);h.talk("ayu");h.talk_chars=100;h._process(.1);await shot("dialogue-"+str(dim.y));h.close_modal()
		h.testing_panel();await shot("test-panel-"+str(dim.y));h.close_modal()
		for kind in ["fish","tv","pet","detail","stars"]:
			h.immersive.open(kind,{"hour":20.0,"pet":"tiantian","name":"天天"});await create_timer(.2).timeout;await shot("play-"+kind+"-"+str(dim.y))
			if kind=="fish":
				for n in 5:
					h.immersive.drop_food(Vector2(270,240))
					for tick in 160:h.immersive._process(.1)
			elif kind=="tv":h.immersive._process(22)
			elif kind=="pet":
				for n in 4:h.immersive.pet_touch()
			elif kind=="stars":
				for n in 7:h.immersive.star_touch()
			if kind!="detail":await shot("play-"+kind+"-finished-"+str(dim.y))
			h.immersive.close()
		for kind in ["guitar","puzzle","album"]:
			h.activities.open(kind,{"v2_art":true});await create_timer(.2).timeout;await shot("play-"+kind+"-"+str(dim.y));var a=h.activities
			if kind=="guitar":
				for n in a.melody:a.note_buttons[n].pressed.emit()
			elif kind=="puzzle":
				for i in 9:
					if a.order[i]!=i:
						var j:int=a.order.find(i);a.tiles[i].pressed.emit();a.tiles[j].pressed.emit()
			else:
				for tile in a.album_tray:tile.pressed.emit();a.album_slots[tile.index].pressed.emit()
			await shot("play-"+kind+"-finished-"+str(dim.y));h.activities.close()
		for hr in [6.5,12.25,18.5,23.0]:
			h.set_test_clock(hr);h.enter_room("living",false);h._process(.016);await shot("time-"+str(hr)+"-"+str(dim.y))
		for hr in [7.75,12.25,18.5]:
			h.set_test_clock(hr);h.enter_room("dining",false);h._process(.016);await shot("meal-"+str(hr)+"-"+str(dim.y))
		for hr in [9.5,10.5,14.5]:
			h.set_test_clock(hr);h.enter_room("study" if hr!=9.5 else "dining",false);h._process(.016);await shot("away-"+str(hr)+"-"+str(dim.y))
		h.set_test_clock(23.0);h.enter_room("cats",false);h._process(.016);await shot("three-cats-"+str(dim.y))
		h.set_test_clock(12.25);h.enter_room("living",false);h.player.position=h.world.nearest(Vector2(370,159));h.camera=h.player.position-Vector2(0,65);h.layout();h.interact("lamp");await shot("lamp-off-"+str(dim.y));h.interact("lamp");await shot("lamp-on-"+str(dim.y))
		for m in [3,7,10,1]:
			h.set_test_clock(12.25,m,"clear");h.enter_room("garden",false);h.player.position=Vector2(1010,430);h.camera=h.player.position-Vector2(0,100);h.layout();await shot("season-"+str(m)+"-"+str(dim.y))
		h.set_test_clock(12.25,10,"rain");h.enter_room("garden",false);await create_timer(.3).timeout;await shot("rain-"+str(dim.y))
		h.stop_audio();vp.queue_free();await process_frame
	print("CAPTURE SUITE DONE");quit()
