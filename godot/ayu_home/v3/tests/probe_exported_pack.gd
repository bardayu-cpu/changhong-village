extends SceneTree
const Assets=preload("res://ayu_home/v2/assets.gd")
const World=preload("res://ayu_home/v3/world.gd")
const Store=preload("res://ayu_home/v3/cloud_assets.gd")
const Home=preload("res://ayu_home/v3/home.gd")
var out:="/private/tmp/ayu-v3-pack-probe/"
func _initialize() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v3/assets/manifest.json"))
	var store:=Store.new();root.add_child(store)
	var ready:=await store.ensure_all(null,{});assert(ready.ok and ready.downloaded==0);store.queue_free()
	var textures:=0
	for file in manifest.files:
		if file.ends_with(".png"):
			var tex:=Assets.texture("res://ayu_home/v3/assets/"+file);assert(tex!=null and tex.get_width()>0,file);textures+=1
	var defs:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v3/assets/rooms.json")).rooms
	for id in defs:
		var vp:=SubViewport.new();vp.size=Vector2i(defs[id].size[0],defs[id].size[1]);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(vp)
		var w:=World.new();w.effects_enabled=false;vp.add_child(w);w.load_room(id);w.set_process(false)
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out+id+".png");vp.queue_free();await process_frame
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp);var h:=Home.new();h.save_path=out+"save.json";vp.add_child(h);await process_frame
	assert(not h.test_panel_enabled,"Normal packaged startup must not expose the test panel")
	h.admitted=true;h.set_test_clock(12.25)
	for room in defs:h.enter_room(room,false);await process_frame;assert(h.area==room)
	h.stop_audio();vp.queue_free();await process_frame
	print("RESULT PASS EXPORTED V3 PACK textures=",textures," rooms=",defs.size()," normal_startup_test_panel_hidden=true");quit()
