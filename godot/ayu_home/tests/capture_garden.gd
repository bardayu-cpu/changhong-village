extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(540, 960)
	var Activities = load("res://ayu_home/activities.gd")
	var panel = Activities.new()
	root.add_child(panel)
	for season in range(4):
		panel.open("garden", {"season_index": season})
		var garden = panel.garden_panel
		garden.now_override = 1000.0
		for i in range(3): garden.plant(i, garden.Data.CROPS[season][i])
		garden.water_all()
		garden.now_override = 1061.0
		garden._refresh()
		for i in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://ayu_home/evidence/garden_season_%d.png" % season)
		panel.close()
	panel.queue_free()
	await process_frame
	quit()
