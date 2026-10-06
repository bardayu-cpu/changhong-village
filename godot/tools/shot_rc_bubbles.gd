extends SceneTree
## rc-makeup 话泡位置截图（庄Z2 10/6；回执 godot/回执/rc-makeup-修.md）：后厅麻将室、休息间、化妆间各让几个人同时冒泡，看泡叠不叠、出不出禁区。要窗口：
## Godot --path . --resolution 540x960 --script res://tools/shot_rc_bubbles.gd -- --dir=目录 [--tag=手机]
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"dir": "", "tag": "手机"}

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
    await frames(8)
    await RenderingServer.frame_post_draw
    get_root().get_texture().get_image().save_png("%s/%s-%s.png" % [opt["dir"], opt["tag"], name])
    print("SHOT ", name)

func quiet(c) -> void:
    for lf in c.lives:
        lf.frozen = true
        for id in lf.bubbles.keys():
            lf._hide_bubble(id)

func life_by(c, room: String):
    for lf in c.lives:
        if lf.room == room:
            return lf
    return null

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://shot_rcb_court.json"
    m.ensure_canvas("backhall")
    m._show_canvas("backhall")
    m._goto("backhall")
    await frames(3)
    var b = m.backhall
    m.dialog.visible = false
    m.hint.visible = false
    b.walking_enabled = true
    await create_timer(0.6).timeout
    # 1 麻将室：四组同时冒
    var mj = life_by(b, "mahjong")
    quiet(b)
    b.reset_to(Vector2(700, 640))
    b.face = "up"
    b.cam.reset_smoothing()
    await frames(20)
    mj.show_bubble("elder_n", "我听牌了哦")
    mj.show_bubble("card_e", "再来一把")
    mj.show_bubble("mj3_e", "这把稳了")
    mj.show_bubble("elder_6", "眼睛花了，看不清")
    await shot("1-后厅麻将室")
    # 2 休息间：两组同时冒
    quiet(b)
    b.reset_to(Vector2(1032, 560))
    b.face = "up"
    b.cam.reset_smoothing()
    await frames(20)
    b.lounge.show_bubble("lounge_10", "一会儿多吃两碗")
    b.lounge.show_bubble("lounge_05", "跷脚牛肉上了没")
    await shot("2-后厅休息间")
    # 3 化妆间（单独一间屋）：化妆师、助理同时冒
    quiet(b)
    m.ensure_canvas("makeup")
    var r = m.areas["makeup"]
    m._show_canvas("makeup")
    m._goto("makeup")
    await frames(6)
    r.walking_enabled = true
    var mk = life_by(r, "makeup")
    quiet(r)
    var near: Vector2 = mk.people["makeup_1"]["foot"]
    r.reset_to(r.nearest_free(near + Vector2(0, 120)))
    r.cam.reset_smoothing()
    await frames(20)
    var said := 0
    for id in mk.people.keys():
        if str(id) == "bride" or said >= 3:
            continue
        mk.show_bubble(str(id), ["头抬高一点", "耳环拿来了", "新娘子真好看"][said])
        said += 1
    await shot("3-化妆间")
    print("SHOT DONE 窗口 ", get_root().size)
    quit(0)
