extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var Activities = load("res://ayu_home/activities.gd")
	var panel = Activities.new()
	root.add_child(panel)
	for dim in [Vector2i(540, 960), Vector2i(1170, 2532)]:
		root.size = dim
		for kind in ["guitar", "puzzle", "album", "fish", "garden"]:
			panel.open(kind)
			for i in range(5): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://ayu_home/evidence/activities_%s_%d.png" % [kind, dim.x])
			panel.close()
	panel.queue_free()
	await process_frame
	quit()
