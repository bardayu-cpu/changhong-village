extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var Actor = load("res://ayu_home/actor.gd")
	for id in ["ayu", "father", "mother", "visitor", "qiuqiu", "luoluo", "tiantian", "xiduo"]:
		var actor = Actor.new()
		root.add_child(actor)
		actor.setup(id)
		assert(actor.sheet != null and actor.frames.size() == 12)
		assert(actor.foreground.get_index() > actor.sprite.get_index())
		for dir in ["down", "left", "right", "up"]:
			actor.set_direction(dir)
			actor.set_walking(true)
			actor.elapsed = 0.01
			actor._update_sprite()
			var first: Rect2 = actor.sprite.texture.region
			var height: float = first.size.y * actor.sprite.scale.y
			if not actor.pet: assert(absf(height - 84.0) < 0.01)
			actor.elapsed = 0.3
			actor._update_sprite()
			if not actor.pet: assert(first != actor.sprite.texture.region)
		actor.set_walking(false)
		actor.set_activity("sleep")
		actor._update_sprite()
		if not actor.pet: assert(absf(actor.sprite.rotation + PI / 2.0) < 0.001)
		else: assert(actor.sprite.scale.y < actor.sprite.scale.x)
		actor.set_activity("record")
		actor.elapsed = 0.5
		actor._update_sprite()
		assert(actor.activity == "record" and absf(actor.sprite.rotation) < 0.1)
		print("ACTOR_MEASURE ", id, " target_px=", actor.target_height, " opaque_frames=", actor.frames)
		actor.queue_free()
	await process_frame
	print("ACTORS_PASS final sheets / exact 84px four-way / changing walk frames / foreground props / bed / record / visitor")
	quit()
