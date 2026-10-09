extends SceneTree
const World=preload("res://ayu_home/v3/world.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var defs:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v3/assets/rooms.json")).rooms
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ayu_home/v3/evidence/native"))
	for id in defs:
		var vp:=SubViewport.new();vp.size=Vector2i(defs[id].size[0],defs[id].size[1]);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(vp)
		var w:=World.new();vp.add_child(w);w.effects_enabled=false;w.sharp=false;w.load_room(id);w.set_process(false)
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("res://ayu_home/v3/evidence/native/"+id+".png");print("NATIVE ",id);vp.queue_free();await process_frame
	print("NATIVE CAPTURE DONE");quit()
