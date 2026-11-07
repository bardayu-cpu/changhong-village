extends SceneTree
const Checkpoint := preload("res://hongyuan/checkpoint.gd")
var failures := 0
var out := ""

func _initialize() -> void:
    out = OS.get_cmdline_user_args()[0]
    DirAccess.make_dir_recursive_absolute(out)
    if not OS.get_user_data_dir().contains("world-bridge-tests"):
        push_error("This test requires isolated world-bridge-tests userdata.")
        quit(2)
        return
    root.size = Vector2i(360, 640)
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    print(("PASS " if ok else "FAIL ") + label)
    if not ok:
        failures += 1

func wait_ready() -> Node:
    var deadline := Time.get_ticks_msec() + 60000
    while Time.get_ticks_msec() < deadline:
        await process_frame
        if current_scene != null and current_scene.get("busy") == false:
            return current_scene
    check(false, "Destination becomes playable")
    quit(1)
    return null

func shot(label: String) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    var img := root.get_texture().get_image()
    check(img.get_size() == Vector2i(360, 640), "360x640 " + label)
    img.save_png(out.path_join(label + ".png"))

func run() -> void:
    var player = load("res://hongyuan/player.tscn").instantiate()
    root.add_child(player)
    current_scene = player
    await process_frame
    player._enter_step(player.step_indices["finale/finale"])
    var runner = player.runner
    var choice := -1
    for i in runner.beats.size():
        if runner.beats[i].has("choice"):
            choice = i
    check(choice >= 0, "Finale retains both destination choices")
    runner.begin(choice)
    runner.result = {"name": "联调宾客", "look": "08"}
    runner.t = 1.0
    var at: Vector2 = runner.get_global_transform() * runner._choice_rect(0).get_center()
    for pressed in [true, false]:
        var e := InputEventScreenTouch.new()
        e.index = 0
        e.position = at
        e.pressed = pressed
        root.push_input(e, true)
    var entry := await wait_ready()
    if entry == null: return
    check(entry.destination == "wedding", "Actual finale tap enters the original estate")
    check(entry.profile.nick == "联调宾客" and entry.profile.avatar == 7, "Invitation name and look reach estate")
    check(entry.game.hall != null and entry.game.court != null, "Original estate and courtyard are instantiated")
    await shot("01-estate-entry")
    await entry.game.enter_banquet()
    check(entry.game.state == "banquet", "Direct seating enters the original banquet hall")
    await shot("02-original-banquet")
    await entry.travel("village")
    check(entry.game.bootstrapped and entry.game.profile.nick == "联调宾客" and entry.game.player_preset == 7, "Village is playable with the same guest")
    await shot("03-village")
    entry.game.life.data.notes.append("world-bridge-keep")
    entry.save_world()
    var village_id: String = entry.game.profile.id
    await entry.travel("wedding")
    check(entry.game.nickname == "联调宾客" and entry.game.preset == 7, "Return to estate preserves identity")
    check(entry.game.state == "banquet", "Return resumes the banquet location")
    await entry.travel("village")
    check(entry.game.profile.id == village_id and "world-bridge-keep" in entry.game.life.data.notes, "Village progress survives an estate round trip")
    entry.save_world()
    change_scene_to_file("res://hongyuan/boot.tscn")
    entry = await wait_ready()
    check(entry.destination == "village" and entry.profile.id == village_id, "Normal boot resumes the selected world and identity")
    await shot("04-resumed-village")
    var second = load("res://hongyuan/player.tscn").instantiate()
    entry.queue_free()
    await process_frame
    root.add_child(second)
    current_scene = second
    second._enter_step(second.step_indices["finale/finale"])
    runner = second.runner
    runner.begin(choice)
    runner.result = {"name": "联调宾客", "look": "08"}
    runner.t = 1.0
    at = runner.get_global_transform() * runner._choice_rect(1).get_center()
    for pressed in [true, false]:
        var e := InputEventScreenTouch.new()
        e.index = 0
        e.position = at
        e.pressed = pressed
        root.push_input(e, true)
    entry = await wait_ready()
    check(entry != null and entry.destination == "village", "Actual second finale choice enters the village")
    print("WORLD_BRIDGE_FAILURES ", failures)
    current_scene.queue_free()
    current_scene = null
    for i in 4:
        await process_frame
    quit(failures)
