extends SceneTree
const World=preload("res://ayu_home/v2/world.gd")
const Actor=preload("res://ayu_home/v2/actor.gd")
var out:="res://ayu_home/v2/evidence/restoration/"
func _initialize() -> void:call_deferred("run")
func capture(vp:SubViewport,path:String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var im:=vp.get_texture().get_image()
	im.convert(Image.FORMAT_RGB8)
	im.save_png(out+path+".png")
func run() -> void:
	for room in ["exterior","living","dining"]:
		var vp:=SubViewport.new();vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(vp)
		var w:=World.new();w.effects_enabled=false;vp.add_child(w);w.load_room(room);vp.size=Vector2i(w.cfg.size[0],w.cfg.size[1]);w.set_process(false)
		await capture(vp,room+"-godot")
		# Capture genuine same-location occlusion, once normally sorted and once
		# forced above furniture. Their difference measures the pixels hidden.
		var a:=Actor.new();w.actors.add_child(a);a.setup("ayu");a.freeze=true;a.face="down"
		a.position={"exterior":Vector2(468,596),"living":Vector2(187,187),"dining":Vector2(162,169)}[room]
		assert(w.walkable(a.position),"occlusion probe must stand on a reachable floor position")
		await capture(vp,room+"-occluded")
		a.z_index=10;await capture(vp,room+"-above-prop")
		vp.queue_free();await process_frame
	print("ORIGINAL RENDER CAPTURE DONE");quit()
