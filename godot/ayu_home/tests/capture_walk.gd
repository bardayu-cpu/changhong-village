extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(540, 960)
	var bg := ColorRect.new()
	bg.color = Color("f2e7d1")
	bg.size = Vector2(540, 960)
	root.add_child(bg)
	var Actor = load("res://ayu_home/actor.gd")
	var actors: Array = []
	for row in range(4):
		for col in range(3):
			var actor = Actor.new()
			root.add_child(actor)
			actor.setup(["ayu", "father", "mother"][col])
			actor.position = Vector2(90 + col * 175, 190 + row * 220)
			actor.scale = Vector2(1.7, 1.7)
			actor.set_direction(["down", "left", "right", "up"][row])
			actor.set_walking(true)
			actors.append(actor)
			var label := Label.new()
			label.text = actor.actor_id + " / " + actor.direction
			label.position = actor.position + Vector2(-65, 13)
			label.add_theme_color_override("font_color", Color("654d39"))
			root.add_child(label)
	for frame in range(2):
		for actor in actors: actor.elapsed = 0.01 + frame * 0.13
		for i in range(2): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://ayu_home/evidence/actors_walk_%d.png" % frame)
	quit()
