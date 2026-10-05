extends SceneTree
## 第 69 版收尾地图截图（03，10/4）：在指定块打开全景地图，看「你」的金圈压不压名字。要窗口：
## Godot --path . --resolution 540x960 --script res://tools/shot_map69b.gd -- --dir=目录 --tag=540 --ids="backgate,backhall,kids"
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"dir": "", "tag": "p", "ids": "court"}

func _initialize() -> void:
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--") and "=" in a:
            var kv := a.substr(2).split("=", true, 1)
            opt[kv[0]] = kv[1]
    m = Main.new()
    m.fast = true
    get_root().add_child(m)

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func frames(n: int) -> void:
    for i in n:
        await process_frame

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://shot_map69b_court.json"
    m.court_save.signed_in = true
    m.court_save.map_used = true
    await m._enter_court()
    m.dialog.visible = false
    var n := 0
    for id in str(opt["ids"]).split(","):
        if m.state != id:
            m.teleport_to(id, Vector2.ZERO)
            for i in 500:
                await process_frame
                if m.state == id and not m.switching:
                    break
        await frames(30)
        m.dialog.visible = false
        m.note_box.visible = false
        m.cv.walking_enabled = true
        m.estate_map.open()
        await frames(20)
        await RenderingServer.frame_post_draw
        get_root().get_texture().get_image().save_png("%s/%s-%s.png" % [opt["dir"], opt["tag"], id])
        m.estate_map.close_map()
        n += 1
    print("SHOT DONE ", n)
    quit(0)
