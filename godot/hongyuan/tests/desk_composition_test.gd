extends SceneTree
## Development-only rendering harness. Does not load or overwrite player saves.
const Runner := preload("res://hongyuan/scene_runner.gd")
var output := ""
var copy: Dictionary
func _initialize() -> void: call_deferred("run")
func capture(r, name: String) -> void:
	r.queue_redraw()
	await process_frame
	await process_frame
	var error := root.get_texture().get_image().save_png(output + "/" + name + ".png")
	assert(error == OK)
func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	copy = JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/copy.json"))
	for viewport in [Vector2i(360,640), Vector2i(390,844)]:
		root.size = viewport
		var height := roundi(viewport.y * 360.0 / viewport.x)
		root.content_scale_size = Vector2i(360,height)
		var r := Runner.new()
		r.position.y = (height - 640) * 0.5
		r.view_rect = Rect2(0, -r.position.y, 360, height)
		r.setup({"hideAyu": true, "beats": [{"game":"desk_intro", "copyId":"R1-B01-MOTIVE"}, {"material":"ink"}, {"game":"finale"}]}, copy, {})
		root.add_child(r)
		r.set_process(false)
		r.begin(0)
		var prefix := str(viewport.x) + "-"
		await capture(r,prefix+"opening")
		r.begin(1)
		var all := {}
		for id in ["pen","ink","paper","stamp","wax","envelope"]:
			all[id] = true
			r.materials = all.duplicate()
			r.material_id = id
			r.t = 3.0
			await capture(r,prefix+"material-"+id)
		r.begin(2)
		await capture(r,prefix+"recipient")
		r.game.name = "久别的朋友"
		r.game.phase = "write"
		r.game.typed = 12.0
		await capture(r,prefix+"writing")
		r.game.typed = r.game._letter().length() - 1
		await capture(r,prefix+"last-stroke")
		r.game.phase = "written"
		await capture(r,prefix+"written")
		r.game.phase = "welcome"
		r.game.look = 0
		await capture(r,prefix+"welcome")
		r.free()
	print("COMPOSITION CAPTURED 24 frames; visual review required")
	quit()
