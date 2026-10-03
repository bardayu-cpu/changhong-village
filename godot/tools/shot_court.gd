extends SceneTree
## 截迎宾院：1:1、不放人、没界面、不写字（03，10/3；给 GPT 出迎宾院色块参考的「现状图」用，照 shot_canvas.gd 的做法，不改 main.gd）
## 要有窗口（headless 不出画面）：Godot --path . --resolution 540x960 --script res://tools/shot_court.gd -- --out=图.png [--rect=0,0,1536,1024] [--zoom=1] [--labels=0]
##   --labels=0 藏灰盒上「签到」「花墙」那些物件名（图上不写字）；1 留着
##   --world=0 连桌子、墙、大门、树这些物件整层都藏，只剩地面和路（量物件框时拿它跟带物件的那张做差）；1 留着
##   --canvas=plaza 截别的画布（喷泉广场等，10/4 02 E 加；默认 court 迎宾院）；--rect 不给就是整块
## 出完打一行「SHOT SAVED <路径> <宽>x<高>」；出错打「SHOT FAILED 原因」，退出码 1
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"rect": "", "zoom": "1", "out": "", "labels": "0", "world": "1", "canvas": "court"}

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

func fail(why: String) -> void:
    print("SHOT FAILED ", why)
    quit(1)

func frames(n: int) -> void:
    for i in n:
        await process_frame

func run() -> void:
    if str(opt["out"]) == "":
        fail("没给 --out=")
        return
    var zoom: float = float(opt["zoom"])
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    await m._enter_court()
    var cn := str(opt["canvas"])
    if cn != "court":
        m.ensure_canvas(cn)
        m._show_canvas(cn)
        m._goto(cn)
    await create_timer(1.0).timeout
    m.dialog.visible = false
    m.hint.visible = false
    var c = m.court if cn == "court" else m.get(cn)
    var sz: Array = c.cfg["size"]
    var r: PackedStringArray = (str(opt["rect"]) if str(opt["rect"]) != "" else "0,0,%d,%d" % [int(sz[0]), int(sz[1])]).split(",")
    if r.size() != 4:
        fail("--rect 要 x,y,w,h")
        return
    var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
    # 藏人：玩家、新人、新娘妈妈等站桩的、走动的客人、摄影师；藏记号和字
    for n in [c.player, c.tag_anchor, c.world.get_node_or_null("couple"), c.get("sign_mark"), c.get("sign_arrow"), c.get("me_ring"), c.get("me_mark")]:
        if n != null:
            n.visible = false
    for id in c.npc_nodes:
        (c.npc_nodes[id] as CanvasItem).visible = false
    if c.get("court_life") != null:
        c.court_life.set_process(false)
        for w in c.court_life.walkers:
            w.node.visible = false
        for g in c.court_life.greeters:
            if g.has("node") and g["node"] != null:
                (g["node"] as CanvasItem).visible = false
    for ch in c.world.get_children():
        if str(ch.name).begins_with("walker_"):
            (ch as CanvasItem).visible = false
    if str(opt["labels"]) == "0":
        c.labels.visible = false
    else:
        for l in c.labels.get_children():   # 游戏里离人远的牌子先不显示、贴屏幕边的往里收（_keep_tags_on_screen）；整块图全放回原位
            if l.has_meta("home"):
                l.position = l.get_meta("home")
            (l as CanvasItem).visible = true
    if str(opt["world"]) == "0":
        c.world.visible = false
    if c.exit_mark != null:
        c.exit_mark.visible = false
    for n in [m.hud, m.dialog, m.note_box]:
        if n != null:
            (n as CanvasItem).visible = false
    c.set_process(false)
    var out_size := Vector2i(int(round(rect.size.x * zoom)), int(round(rect.size.y * zoom)))
    var sv: SubViewport = m.view.get_child(0)
    m.view.stretch = false
    sv.size = out_size
    await frames(5)
    c.cam.limit_left = -100000
    c.cam.limit_top = -100000
    c.cam.limit_bottom = 100000
    c.cam.limit_right = 100000
    c.cam.zoom = Vector2(zoom, zoom)
    c.cam.position = rect.get_center()
    c.cam.reset_smoothing()
    await frames(10)
    await RenderingServer.frame_post_draw
    var img: Image = sv.get_texture().get_image()
    if img.save_png(str(opt["out"])) != OK:
        fail("存不下 %s" % opt["out"])
        return
    print("SHOT SAVED ", opt["out"], " ", img.get_width(), "x", img.get_height())
    quit(0)
