extends SceneTree
## Native check of exported PCKs. It does not simulate the WeChat JS or phone audio.
## Run with an isolated HOME, --main-pack /.../love.bin, and -- <project-dir> <cloud-dir>.
var build_dir: String
var cloud_dir: String
var manifest: Dictionary
var failures := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not OS.get_user_data_dir().contains("hongyuan-wechat-smoke"):
		push_error("Pass a candidate, cloud directory and isolated hongyuan-wechat-smoke HOME.")
		quit(2)
		return
	build_dir = args[0]
	cloud_dir = args[1]
	root.size = Vector2i(360, 640)
	manifest = JSON.parse_string(FileAccess.get_file_as_string(cloud_dir.path_join("manifest.json")))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func mount(group: String) -> void:
	if manifest.local.has(group):
		var entry: Dictionary = manifest.local[group]
		check(ProjectSettings.load_resource_pack(build_dir.path_join(entry.path), false), "mount " + group)
	for item: Dictionary in manifest.remote.get(group, []):
		var path := cloud_dir.path_join(str(item.file))
		check(FileAccess.get_sha256(path) == item.sha256 and ProjectSettings.load_resource_pack(path, false),
			"verify and mount " + str(item.file))

func world_ready() -> Node:
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene and current_scene.get("busy") == false:
			return current_scene
	check(false, "world ready within 45 seconds")
	quit(1)
	return null

func run() -> void:
	check(root.get_node_or_null("DialogueManager") != null, "main package dialogue autoload")
	check(not ResourceLoader.exists("res://ayu_home/v4/home.tscn"), "village absent from main")
	check(not ResourceLoader.exists("res://hongyuan/wedding.gd"), "estate absent from main")
	mount("love-media")
	mount("prologue")
	change_scene_to_file("res://hongyuan/boot.tscn")
	for i in range(8):
		await process_frame
	var player := current_scene
	if player == null or not player.get("shot") is Dictionary:
		check(false, "normal boot starts the story")
		quit(1)
		return
	check(player.shot.chapterId == "prologue", "normal boot starts the prologue")
	for chapter in ["prologue", "shanghai", "chengdu", "call", "shizuoka", "hainan", "hongkong", "finale"]:
		if chapter != "prologue":
			mount(chapter)
		for shot: Dictionary in player.playlist:
			if shot.chapterId != chapter:
				continue
			player.shot = {}  # 跳过换场淡出，测试里同步进场
			player._enter_step(int(player.step_indices[shot.fullId]))
			check(player.bgm.playing and player.bgm_id == chapter, "BGM stream starts: " + chapter)
			break
	mount("world")
	mount("world-media")
	mount("estate")
	var wedding = load("res://hongyuan/wedding.gd")
	check(wedding != null and wedding.can_instantiate(), "estate script resolves its packaged dependencies")
	if not wedding or not wedding.can_instantiate():
		quit(1)
		return
	var runner = player.runner
	var choice := -1
	for i in runner.beats.size():
		if runner.beats[i].has("choice"):
			choice = i
			break
	check(choice >= 0, "finale has a destination choice")
	if choice < 0:
		quit(1)
		return
	runner.begin(choice)
	runner.result = {"name": "微信包测试", "look": "08"}
	runner.t = 1.0
	var at: Vector2 = runner.get_global_transform() * runner._choice_rect(0).get_center()
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = at
		event.pressed = pressed
		root.push_input(event, true)
	var entry := await world_ready()
	if not entry:
		return
	check(entry.destination == "wedding" and entry.profile.nick == "微信包测试", "finale touch enters estate with the same guest")
	await entry.game.enter_banquet()
	check(entry.game.state == "banquet", "estate enters the original banquet hall")
	mount("village")
	mount("village-media")
	await entry.travel("village")
	check(entry.game.bootstrapped and entry.game.profile.nick == "微信包测试", "village boots with the same guest")
	# Let the welcome letter finish its deferred setup before simulating a restart.
	for i in range(3):
		await process_frame
	entry.save_world()
	change_scene_to_file("res://hongyuan/boot.tscn")
	entry = await world_ready()
	if not entry:
		return
	check(entry.destination == "village" and entry.profile.nick == "微信包测试", "normal boot resumes village and guest")
	print("WECHAT_PACK_FAILURES ", failures)
	quit(failures)
