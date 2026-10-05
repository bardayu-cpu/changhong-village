extends SceneTree
## 罗-12 话泡躲禁区的截图 + 逐张核（庄Z2 10/5）：每块画布让人站到最上一排、最左、最右，各顶一下「走到头」（那句冒在人头顶，哪块都有），
## 拍一张，量那句话泡在屏幕上落在哪、在不在禁区外（顶栏下沿 + 8、四边 16、微信里的胶囊）。另拍后厅化妆间人冒泡的改前 / 改后（safe_on 关 / 开）。
## 要窗口：Godot --path . --resolution 540x960 --script res://tools/shot_safe_zone.gd -- --dir=目录 [--tag=手机]
## 出 <dir>/<tag>-<画布>-<方向>.png、<tag>-化妆间冒泡-改前/改后.png、<tag>-核.json；出完打「SHOT DONE n 不对 m」
const Main = preload("res://scripts/main.gd")
const DSkin = preload("res://scripts/ui/dialog_skin.gd")
var m
var started := false
var opt := {"dir": "", "tag": "手机"}
var report: Array = []

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

func snap(name: String) -> void:
    await RenderingServer.frame_post_draw
    get_root().get_texture().get_image().save_png("%s/%s-%s.png" % [opt["dir"], opt["tag"], name])

func box_rect(b: Node2D) -> Rect2:
    for c in b.get_children():
        if c is Control:
            var xf := b.get_global_transform_with_canvas()
            return Rect2(xf * (c as Control).position, (c as Control).size * xf.get_scale())
    return Rect2()

func safe(r: Rect2) -> bool:
    var vs := get_root().get_visible_rect().size
    return r.position.x >= 15.5 and r.end.x <= vs.x - 15.5 and r.position.y >= DSkin.safe_top - 0.5 and r.end.y <= vs.y - 15.5 \
        and not (DSkin.capsule.size.x > 0.0 and r.intersects(DSkin.capsule))

## 能站的点里最上 / 最左 / 最右那个（12 像素一格扫）
func extremes(c) -> Dictionary:
    var sz: Vector2 = Vector2(c.cfg["size"][0], c.cfg["size"][1])
    var best := {"up": null, "left": null, "right": null}
    var y := 6.0
    while y < sz.y:
        var x := 6.0
        while x < sz.x:
            var p := Vector2(x, y)
            if c._free(p):
                if best["up"] == null or p.y < (best["up"] as Vector2).y or (p.y == (best["up"] as Vector2).y and absf(p.x - sz.x * 0.5) < absf((best["up"] as Vector2).x - sz.x * 0.5)):
                    best["up"] = p
                if best["left"] == null or p.x < (best["left"] as Vector2).x:
                    best["left"] = p
                if best["right"] == null or p.x > (best["right"] as Vector2).x:
                    best["right"] = p
            x += 12.0
        y += 12.0
    return best

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://shot_safe_zone_court.json"
    var n := 0
    var bad := 0
    var keys: Array = ["court", "banquet", "backhall", "lawn", "lake", "orchard", "parking", "plaza"] + m.AREA_IDS
    for k in keys:
        if k != "court" and k != "banquet":
            m.ensure_canvas(k)
        m._show_canvas(k)
        m._goto(k)
        m.dialog.visible = false
        var c = m.cv
        c.walking_enabled = false
        await frames(3)
        var ex := extremes(c)
        for dir in ["up", "left", "right"]:
            if ex[dir] == null:
                continue
            c.reset_to(ex[dir])
            if c.cam != null:
                c.cam.reset_smoothing()
            await frames(4)
            m._on_edge_bump(dir)
            await frames(4)
            var b: Node2D = c.get_node_or_null("edge_bubble")
            var r := box_rect(b) if b != null else Rect2()
            var md: String = str(b.get_node("safe_keep").mode) if b != null else "没冒"
            var good := b != null and safe(r)
            report.append({"画布": k, "方向": dir, "站": [ex[dir].x, ex[dir].y], "放在": md, "框": [r.position.x, r.position.y, r.size.x, r.size.y], "禁区外": good})
            if not good:
                bad += 1
            await snap("%s-%s" % [k, dir])
            n += 1
            if b != null:
                b.queue_free()
            await frames(1)
    # 化妆间人冒泡：改前 / 改后（后厅最北那间，镜头照人站在门口时的样子）
    m.ensure_canvas("backhall")
    m._show_canvas("backhall")
    m._goto("backhall")
    var bh = m.backhall
    var lf = null
    for l in bh.lives:
        if str(l.room) == "makeup":
            lf = l
    if lf != null:
        var who := ""
        var top_y := 99999.0
        for id in lf.people:
            if (lf.people[id]["head"] as Vector2).y < top_y:
                top_y = (lf.people[id]["head"] as Vector2).y
                who = str(id)
        bh.reset_to(bh.nearest_free(lf.approach_of(who) + Vector2(0, 160)))
        bh.cam.reset_smoothing()
        lf.frozen = true
        for on in [false, true]:
            DSkin.safe_on = on
            lf.show_bubble(who, "来了来了，等我把头冠戴好")
            var bb: Node2D = lf.bubbles[who]
            bb.scale = Vector2.ONE * lf._bubble_scale()
            await frames(5)
            var r2 := box_rect(bb)
            report.append({"画布": "化妆间冒泡", "方向": "改后" if on else "改前", "放在": str(bb.get_node("safe_keep").mode), "框": [r2.position.x, r2.position.y, r2.size.x, r2.size.y], "禁区外": safe(r2)})
            await snap("化妆间冒泡-%s" % ("改后" if on else "改前"))
            n += 1
        DSkin.safe_on = true
    # 阿鱼说话时「跟新娘聊聊」压住框第一行：改前（不藏）、改后（框开着，按钮、摇杆、路牌藏）、框关了（又出来）
    if lf != null:
        bh.reset_to(bh.nearest_free(lf.approach_of("bride")))
        bh.cam.reset_smoothing()
        bh.walking_enabled = true
        await frames(6)
        for step in [["改前-框开着", false, true], ["改后-框开着", true, true], ["改后-框关了", true, false]]:
            m.talk_hide_on = step[1]
            if step[2]:
                m._say("今天这天气真好，早上还有点凉，到中午就暖和了，等下开席有红烧肉。", 30.0)
            else:
                m.dialog.visible = false
            await frames(6)
            var tb: Button = m.lounge_ui.talk_btn
            report.append({"画布": "跟新娘聊聊", "方向": step[0], "按钮显示": tb.is_visible_in_tree(), "按钮透明度": tb.modulate.a, "能点": tb.mouse_filter != Control.MOUSE_FILTER_IGNORE})
            await snap("跟新娘聊聊-%s" % step[0])
            n += 1
        m.talk_hide_on = true
    var f := FileAccess.open("%s/%s-核.json" % [opt["dir"], opt["tag"]], FileAccess.WRITE)
    f.store_string(JSON.stringify(report, " "))
    f.close()
    print("SHOT DONE ", n, " 不对 ", bad, " 窗口 ", get_root().size, " 顶栏禁区到 ", DSkin.safe_top)
    quit(0)
