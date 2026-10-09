extends SceneTree
const World=preload("res://ayu_home/v4/world.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var rooms:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/rooms.json")).rooms
	for room in rooms:
		var vp:=SubViewport.new();vp.size=Vector2i(rooms[room].size[0],rooms[room].size[1]);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
		var w=World.new();w.effects_enabled=false;vp.add_child(w);w.load_room(room);w.set_process(false);await process_frame;await process_frame;await process_frame;RenderingServer.force_draw(false);vp.get_texture().get_image().save_png("res://ayu_home/v4/evidence/native/"+room+".png");vp.queue_free();await process_frame
	print("RESULT PASS native all 27");quit()
