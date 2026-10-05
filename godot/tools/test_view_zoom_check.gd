extends SceneTree
## 化妆间 1.25 倍（makeup-125，庄Z2 做）改了公共的 layered_hall.gd：`_fit_zoom` 多认布局里的 view_h（一屏看多高，没写的照旧 1024）。
## 公共模块改了要把全部场景走一遍（版本号规矩）；03 / 庄Z3 自己重测（庄Z1 10/5 派，不改游戏代码）：
##   1 全部铺满画布的场景（宴会厅、迎宾院、后厅、草坪、湖边、果园、停车场、喷泉广场、小卖部、儿童乐园、休息厅 2、西餐厨房、后花园、前门、后门、化妆间）
##     手机 540×960、长屏 585×1266 各进一次：镜头缩放 == 我自己按老规矩算的值（一屏高 ÷ min(画布高, 1024)；铺了像素图的画布缩放落在 0.85～1 之间取整到 1），
##     只有化妆间按它布局写的 view_h（一屏高 ÷ view_h，铺了像素图同样取整）；别的场景一个都不能变
##   2 化妆间：布局写了 view_h；人在屏上多高（84 × 缩放）跟后厅比（手机屏要一样大、长屏记差多少）
##   3 化妆间 675 宽、屏只看 540 宽：人站在最左、中间、最右，人都在屏里、镜头看到的世界不超出画布（左边露到画布左沿、右边露到右沿），镜头跟着人走
## 用法：Godot --headless --path . --script res://tools/test_view_zoom_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const VIEW_H_OLD := 1024.0

var m
var started := false
var ok := true

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(240.0).timeout.connect(func():
        print("RESULT FAIL 240 秒没跑完")
        quit(1))

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func check(name: String, cond: bool) -> void:
    print(("  好 " if cond else "  不行 ") + name)
    ok = ok and cond

func frames(n: int) -> void:
    for i in n:
        await process_frame

func canvas_of(id: String):
    if id == "court":
        return m.court
    if id == "banquet":
        return m.hall
    if id == "makeup":
        return m.areas["makeup"]
    return m._canvas_by(id)

func go(id: String) -> void:
    m.switching = false
    if m.lounge_ui != null and m.lounge_ui.is_open():
        m.lounge_ui.hide_all()
    m.dialog.visible = false
    m._show_canvas(id)
    m._goto(id)
    await frames(3)

## 老规矩算出来该是多少（独立写一遍，不调游戏里的 _fit_zoom）
func expected_zoom(c, vh: float, view_h_override := -1.0) -> float:
    var h := VIEW_H_OLD if view_h_override < 0.0 else view_h_override
    var z := vh / minf(float(c.cfg["size"][1]), h)
    if c.cfg.has("pixel_art") and z > 0.85 and z < 1.0:
        z = 1.0
    return z

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://test_vzc_court.json"
    m.games_save.local_path = "user://test_vzc_games.json"
    m.court_save.signed_in = true
    var ids: Array = ["banquet", "court", "backhall", "lawn", "lake", "orchard", "parking", "plaza", "kids", "shop", "rest2", "wkitchen", "garden", "frontgate", "backgate", "makeup"]
    for id in ids:
        if id != "banquet" and id != "court":
            m.ensure_canvas(id)

    print("1 全部场景的镜头缩放（手机、长屏）")
    var bad: Array = []
    var rows: Array = []
    var zooms := {}   # id -> {尺寸: 缩放}
    for sz in [Vector2i(540, 960), Vector2i(585, 1266)]:
        get_root().size = sz
        await frames(4)
        for id in ids:
            await go(id)
            var c = canvas_of(id)
            c._fit_zoom()
            var vh := float(c.get_viewport().get_visible_rect().size.y)
            var vo := float(c.cfg.get("view_h", -1.0)) if id == "makeup" else -1.0
            var want: float = expected_zoom(c, vh, vo)
            var got: float = c.cam.zoom.x
            zooms[str(id) + str(sz)] = got
            rows.append("%s %.4f" % [id, got])
            if absf(got - want) > 0.0005:
                bad.append("%dx%d %s：镜头 %.4f，该是 %.4f（画布高 %s、屏高 %.0f%s）" % [sz.x, sz.y, id, got, want, str(c.cfg["size"][1]), vh, "、布局 view_h %s" % str(vo) if vo > 0.0 else ""])
            if id != "makeup" and c.cfg.has("view_h"):
                bad.append("%s 的布局居然写了 view_h（只有化妆间该写）" % id)
        print("    %dx%d 各块镜头：%s" % [sz.x, sz.y, str(rows)])
        rows = []
    for x in bad:
        print("    ", x)
    check("%d 个场景 × 2 种屏：镜头缩放都等于我按老规矩算的值，只有化妆间按 view_h 算、别的都没变（%d 处不对）" % [ids.size(), bad.size()], bad.is_empty())

    print("2 化妆间 view_h、人在屏上多高")
    var mk = canvas_of("makeup")
    var vh_mk := float(mk.cfg.get("view_h", -1.0))
    check("化妆间布局写了 view_h = %s（一屏看 960 高）" % str(vh_mk), absf(vh_mk - 960.0) < 0.5)
    var tall: Array = []
    for sz in [Vector2i(540, 960), Vector2i(585, 1266)]:
        var key := str(sz)
        var h_mk: float = 84.0 * float(zooms["makeup" + key])
        var h_bh: float = 84.0 * float(zooms["backhall" + key])
        tall.append("%dx%d：化妆间人高 %.1f、后厅人高 %.1f（差 %.1f%%）" % [sz.x, sz.y, h_mk, h_bh, (h_mk / h_bh - 1.0) * 100.0])
    print("    ", tall)
    var phone_same: bool = absf(float(zooms["makeup" + str(Vector2i(540, 960))]) - float(zooms["backhall" + str(Vector2i(540, 960))])) < 0.0005
    check("手机屏：化妆间的人跟后厅的人在屏上一样大（庄Z2 回执说「人跟别的屋子一样大」；长屏上化妆间大约大 %.0f%%，记一笔）" % ((float(zooms["makeup" + str(Vector2i(585, 1266))]) / float(zooms["backhall" + str(Vector2i(585, 1266))]) - 1.0) * 100.0), phone_same)

    print("3 化妆间 675 宽：最左、中间、最右镜头跟不跟")
    var follow_bad: Array = []
    var W := float(mk.cfg["size"][0])
    for sz in [Vector2i(540, 960), Vector2i(585, 1266)]:
        get_root().size = sz
        await frames(4)
        await go("makeup")
        mk._fit_zoom()
        var vsize: Vector2 = mk.get_viewport().get_visible_rect().size
        for pr in [["最左", Vector2(36, 600)], ["中间", Vector2(W * 0.5, 600)], ["最右", Vector2(W - 36, 600)]]:
            mk.reset_to(pr[1])
            mk.snap_cam()
            await frames(6)
            var z: float = mk.cam.zoom.x
            var cc: Vector2 = mk.cam.get_screen_center_position()
            var half_w: float = vsize.x * 0.5 / z
            var left_w: float = cc.x - half_w
            var right_w: float = cc.x + half_w
            var scr_x: float = (mk.pos.x - cc.x) * z + vsize.x * 0.5
            var tag := "%dx%d %s" % [sz.x, sz.y, pr[0]]
            if scr_x < 12.0 or scr_x > vsize.x - 12.0:
                follow_bad.append("%s：人在屏上 x=%.0f（屏宽 %.0f），跑到屏外去了" % [tag, scr_x, vsize.x])
            if left_w < -1.0 or right_w > W + 1.0:
                follow_bad.append("%s：镜头看到的世界 %.0f～%.0f，超出画布 0～%.0f" % [tag, left_w, right_w, W])
            if pr[0] == "最左" and left_w > 1.0:
                follow_bad.append("%s：人站在最左，镜头只看到 %.0f 起，没跟到画布左沿" % [tag, left_w])
            if pr[0] == "最右" and right_w < W - 1.0:
                follow_bad.append("%s：人站在最右，镜头只看到 %.0f 为止，没跟到画布右沿" % [tag, right_w])
            if pr[0] == "中间" and absf(scr_x - vsize.x * 0.5) > 6.0:
                follow_bad.append("%s：人在中间，屏上 x=%.0f（该在屏中央）" % [tag, scr_x])
    for x in follow_bad:
        print("    ", x)
    get_root().size = Vector2i(540, 960)
    check("人站在最左 / 中间 / 最右（手机、长屏）：人都在屏里、镜头不超出画布、左右跟到画布边（%d 处不对）" % follow_bad.size(), follow_bad.is_empty())

    DirAccess.remove_absolute("user://test_vzc_court.json")
    DirAccess.remove_absolute("user://test_vzc_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
