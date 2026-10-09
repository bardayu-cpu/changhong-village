extends SceneTree
const Assets=preload("res://ayu_home/v2/assets.gd")
const World=preload("res://ayu_home/v4/world.gd")
const Store=preload("res://ayu_home/v4/cloud_assets.gd")
const Home=preload("res://ayu_home/v4/home.gd")
var out:="/private/tmp/ayu-v4-pack-probe/"
func label_copy(n:Node) -> String:
	var copy:String=n.text if n is Label else ""
	for child in n.get_children():copy+="\n"+label_copy(child)
	return copy
func _initialize() -> void:
	create_timer(180).timeout.connect(func():push_error("Exported pack probe exceeded 180 seconds");quit(1))
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/manifest.json"))
	var store:=Store.new();root.add_child(store)
	var ready:=await store.ensure_all(null,{});assert(ready.ok and ready.downloaded==0);store.queue_free()
	var textures:=0
	for file in manifest.files:
		if file.ends_with(".png"):
			var tex:=Assets.texture("res://ayu_home/v4/assets/"+file);assert(tex!=null and tex.get_width()>0,file);textures+=1
	var defs:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/rooms.json")).rooms
	for id in defs:
		var vp:=SubViewport.new();vp.size=Vector2i(defs[id].size[0],defs[id].size[1]);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(vp)
		var w:=World.new();w.effects_enabled=false;vp.add_child(w);w.load_room(id);w.set_process(false)
		await process_frame;await process_frame;await process_frame;RenderingServer.force_draw(false)
		vp.get_texture().get_image().save_png(out+id+".png");vp.queue_free();await process_frame
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp);var h:=Home.new();h.save_path=out+"save.json";vp.add_child(h);await process_frame
	assert(not h.test_panel_enabled,"Normal packaged startup must not expose the test panel")
	assert(h.games.has_method("draw_planted_tree"),"Pack must include the final mature-tree visual fix")
	assert(h.life.stage({"crop":"apple","watered":true,"planted":h.life.now(),"grown":true})=="等下一批果子")
	var previous_photos:Array=h.life.data.photos.duplicate(true)
	h.life.data.photos=[{"area":"dining"}];h.life_book()
	assert(label_copy(h.modal).contains("1 张合影"),"Pack must include the final photo diary fix")
	h.life.data.photos=previous_photos;h.close_modal()
	h.admitted=true;h.set_test_clock(12.25)
	for room in defs:h.enter_room(room,false);await process_frame;assert(h.area==room)
	h.stop_audio();vp.queue_free();await process_frame
	print("RESULT PASS EXPORTED V4 PACK textures=",textures," rooms=",defs.size()," normal_startup_test_panel_hidden=true");quit()
