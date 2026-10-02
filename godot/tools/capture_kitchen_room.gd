extends SceneTree
var m
func _initialize() -> void:
    m = load("res://main.tscn").instantiate()
    root.add_child(m)
    call_deferred("run")
func run() -> void:
    for i in 600:
        if m.state == "title": break
        await process_frame
    m.cloud.fake_no_news = true
    m.nickname = "后厨试玩"
    await m._enter_banquet()
    for i in 5: await process_frame
    await m._switch_canvas("backhall")
    m.dialog.visible = false
    m.hint.visible = false
    m.backhall.reset_to(Vector2(1272,450))
    m.backhall.face = "up"
    for i in 60: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../验收记录/厨房场景运行.png"))
    print("CAPTURE OK")
    m.queue_free()
    for i in 2: await process_frame
    quit()
