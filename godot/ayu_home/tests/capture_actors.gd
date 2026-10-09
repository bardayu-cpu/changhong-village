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
	var actions := ["guitar", "eat", "mahjong", "cook", "clean", "work", "sleep", "record", "fish", "watering", "sniff", "walk"]
	var ids := ["ayu", "mother", "father", "mother", "father", "visitor", "ayu", "mother", "ayu", "mother", "qiuqiu", "xiduo"]
	for i in range(actions.size()):
		var actor = Actor.new()
		root.add_child(actor)
		actor.setup(ids[i])
		actor.set_activity(actions[i])
		actor.set_direction("left" if actions[i] in ["eat", "watering"] else ("right" if i % 2 else "down"))
		actor.set_walking(actions[i] == "walk")
		actor.position = Vector2(90 + (i % 3) * 175, 190 + (i / 3) * 220)
		if actions[i] == "sleep": actor.position.x += 42
		actor.scale = Vector2(1.7, 1.7)
		actors.append(actor)
		var text := Label.new()
		text.text = ids[i] + " / " + actions[i]
		text.position = actor.position + Vector2(-65, 13)
		text.add_theme_color_override("font_color", Color("654d39"))
		root.add_child(text)
	for frame in range(2):
		for actor in actors: actor.elapsed = 0.15 + frame * 0.45
		for i in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://ayu_home/evidence/actors_action_%d.png" % frame)
	quit()
