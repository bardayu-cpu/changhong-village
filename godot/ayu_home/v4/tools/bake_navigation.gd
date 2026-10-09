extends SceneTree
const World=preload("res://ayu_home/v4/world.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var rooms:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/rooms.json")).rooms
	for id in rooms:
		if "--floor1" in OS.get_cmdline_user_args() and int(rooms[id].floor)!=1:continue
		var only:=""
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--rooms="):only=a.substr(8)
		if not only.is_empty() and not id in only.split(","):continue
		var w=World.new();w.use_baked_navigation=false;w.load_room(id);var bytes:=PackedByteArray();bytes.resize(w.grid.region.size.x*w.grid.region.size.y)
		for y in w.grid.region.size.y:
			for x in w.grid.region.size.x:bytes[y*w.grid.region.size.x+x]=1 if w.grid.is_point_solid(Vector2i(x,y)) else 0
		var f:=FileAccess.open("res://ayu_home/v4/assets/"+id+".nav",FileAccess.WRITE);f.store_buffer(bytes);f.close();w.free();print("BAKED ",id," ",bytes.size());await process_frame
	quit()
