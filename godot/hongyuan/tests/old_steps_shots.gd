extends SceneTree
## 截老步骤（序章、上海、成都）每一步的画面，用来核对对话框、比例和衔接。

class Harness extends "res://hongyuan/player.gd":
	func _save() -> void:
		pass

var out := "user://old"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(540, 960)
	call_deferred("run")


func run() -> void:
	var p = Harness.new()
	p.size = Vector2(540, 960)
	root.add_child(p)
	for i in range(3):
		await process_frame
	var n := 0
	for chapter in ["prologue", "shanghai", "chengdu"]:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/chapters/%s.json" % chapter))
		for step: Dictionary in d.steps:
			var sid: String = chapter + "/" + str(step.id)
			if not p.step_indices.has(sid) or step.type == "scene":
				continue
			p.shot = {}  # 跳过换场淡出，测试里同步进场
			p._enter_step(p.step_indices[sid])
			for i in range(40):
				await process_frame
			n += 1
			root.get_texture().get_image().save_png("%s/%02d_%s_%s.png" % [out, n, chapter, step.id])
	print("OLD SHOTS ", n)
	quit(0)
