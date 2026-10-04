extends SceneTree
## 第 68 版开车连拍（07 10/4）：按手机屏开一趟，停在几个时刻各截一张：进前门、刚进广场喷泉在正前方、喷泉跟前右拐、往右开向停车场、
## 进停车场、倒进车位、下车（顶部提示 + 金箭头指迎宾院）。要有窗口：
##   Godot --path . --resolution 540x960 --script res://tools/shot_drive68.gd -- --dir=目录 [--tag=540x960]
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"dir": "", "tag": "540x960"}
var n := 0

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

func frames(k: int) -> void:
    for i in k:
        await process_frame

func shot(name: String) -> void:
    await frames(6)
    await RenderingServer.frame_post_draw
    get_root().get_texture().get_image().save_png("%s/%s-%s.png" % [opt["dir"], opt["tag"], name])
    n += 1

## 等到 cond 成立（开车停在那一格）再截
func hold(cond: Callable, name: String) -> void:
    for i in 4000:
        await process_frame
        if cond.call():
            break
    m.drive.paused = true
    await frames(4)
    await shot(name)
    m.drive.paused = false

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://shot_drive68_court.json"
    m.court_save.drive_seen = false
    m.court_save.signed_in = false
    m.court_save.court_seen = false
    m.drive_in_fast = true
    m.dialog.visible = false
    m._start_play()
    var d = m.drive
    await hold(func(): return d.leg == "frontgate" and d.leg_t >= 0.6, "1-进前门往上开")
    await hold(func(): return d.leg == "plaza" and d.leg_t >= 0.05 and not m.switching, "2-刚进广场喷泉在正前方")
    await hold(func(): return d.leg == "plaza" and m.cv.pos.y <= 800.0, "3-喷泉跟前靠右右拐")
    await hold(func(): return d.leg == "plaza" and m.cv.pos.x >= 1150.0, "4-往右开向停车场")
    await hold(func(): return d.leg == "parking" and d.leg_t >= 0.5 and not m.switching, "5-进停车场")
    await hold(func(): return d.leg == "parking" and m.cv.pos.y >= 930.0, "6-倒进车位")
    for i in 2000:
        await process_frame
        if not m.driving and m.state == "parking" and not m.switching:
            break
    await frames(12)
    await shot("7-下车提示和金箭头")
    print("SHOT DONE ", n)
    quit()
