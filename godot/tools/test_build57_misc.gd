extends SceneTree
## 第 57 版（build57 bd139d9）的两处细节（01 F 10/3 派，03 写）。不改游戏代码。
##   1 后厅门口名字牌（化妆间、休息间、麻将室、后厨）：量游戏里牌子真占的框，跟门洞（前沿矮墙留的口）、麻将室门里两盏宫灯（mj_lamp_w / mj_lamp_e）、化妆间休息间门口的家具比，看压不压
##   2 草坪 24 位坐着的观礼替身跟椅背：每位的脚点、座椅图的着地线、椅背图的着地线排得对不对（座椅 < 人 < 椅背）；人在椅子正中；椅背遮住人多少（人露出来的不透明像素占几成）
## 用法：Godot --headless --path . --script res://tools/test_build57_misc.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")

var m
var started := false
var ok := true

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(120.0).timeout.connect(func():
        print("RESULT FAIL 120 秒没跑完")
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

func img_of(tex: Texture2D) -> Image:
    var img := tex.get_image()
    if img.is_compressed():
        img.decompress()
    img.convert(Image.FORMAT_RGBA8)
    return img

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.ensure_canvas("backhall")
    m.ensure_canvas("lawn")
    m._show_canvas("backhall")
    m._goto("backhall")
    await process_frame
    await process_frame
    var b = m.backhall

    print("1 后厅门口名字牌")
    var rects := {}
    for h in b.room_signs:
        var l: Label = (h as Node2D).get_child(0)
        var tl: Vector2 = (h as Node2D).position + l.position
        rects[str(l.text)] = Rect2(tl, l.size)
        print("    牌子「%s」占 %s（下沿 y %.0f，排前后的线 y %.0f）" % [l.text, str(Rect2(tl, l.size)), tl.y + l.size.y, (h as Node2D).position.y])
    check("四块牌子都挂了（化妆间、休息间、麻将室、后厨）", rects.size() == 4)
    var gaps := [Rect2(128, 684, 80, 12), Rect2(656, 684, 80, 12), Rect2(992, 684, 80, 12), Rect2(1323, 684, 80, 12)]   # 前沿矮墙留的四个门洞（10/4 方案 C 平移后）
    var lamps := {"mj_lamp_w": null, "mj_lamp_e": null}
    var boxes: Dictionary = {}
    var f := FileAccess.open("res://回执/零件规格/后厅/后厅-框.json", FileAccess.READ)
    if f != null:
        for it in (JSON.parse_string(f.get_as_text()) as Dictionary)["items"]:
            boxes[str(it["id"])] = it["box"]
    for k in lamps:
        if boxes.has(k):
            var bx: Array = boxes[k]
            lamps[k] = Rect2(float(bx[0]), float(bx[1]), float(bx[2]) - float(bx[0]), float(bx[3]) - float(bx[1]))
    check("两盏宫灯的框读到了", lamps["mj_lamp_w"] != null and lamps["mj_lamp_e"] != null)
    for t in rects:
        var r: Rect2 = rects[t]
        var hit_gap := false
        for g in gaps:
            if r.intersects(g):
                hit_gap = true
        check("「%s」牌不压门洞（%s）" % [t, str(r)], not hit_gap)
        for k in lamps:
            if lamps[k] != null:
                check("「%s」牌不压 %s（%s）" % [t, k, str(lamps[k])], not r.intersects(lamps[k]))
    # 牌子跟所有挡人家具的画出来的框
    var over: Array = []
    for t in rects:
        var r: Rect2 = rects[t]
        for id in boxes:
            var bx: Array = boxes[id]
            var rb := Rect2(float(bx[0]), float(bx[1]), float(bx[2]) - float(bx[0]), float(bx[3]) - float(bx[1]))
            if r.intersects(rb) and not str(id).begins_with("front_") and not str(id).begins_with("wall_"):
                over.append("%s×%s" % [t, id])
    print("    牌子压到的家具（除前沿矮墙、隔墙）：%s" % str(over))
    check("牌子不压任何家具的画出来的框", over.is_empty())
    # 牌子在前沿矮墙上、走廊里的人在牌子前面
    for h in b.room_signs:
        check("牌子排前后的线 %.0f ≥ 前沿矮墙脚 696（走廊里的人在牌子前面）" % (h as Node2D).position.y, (h as Node2D).position.y >= 696.0)

    print("2 草坪 24 位坐着的观礼替身")
    m._show_canvas("lawn")
    m._goto("lawn")
    await process_frame
    var lw = m.lawn
    var n_ok := 0
    var bad: Array = []
    var vis_pcts: Array = []
    for n in lw.cfg["npcs"]:
        var id := str(n["id"])
        if not id.begins_with("wed_guest_"):
            continue
        var gx := float(n["x"])
        var gy := float(n["y"])
        # 找椅子：x 一样、椅子下沿比人脚点高 0～8
        var chair_id := ""
        for it in lw.cfg["items"]:
            if str(it["id"]).begins_with("chair_") and it.has("rect"):
                var r: Array = it["rect"]
                if absf((float(r[0]) + float(r[2])) * 0.5 - gx) <= 3.0 and gy - float(r[3]) >= 0.0 and gy - float(r[3]) <= 8.0:
                    chair_id = str(it["id"])
        var guest: Sprite2D = lw.npc_nodes.get(id)
        var seat: Sprite2D = lw.world.get_node_or_null(NodePath("px_%s" % chair_id))
        var back: Sprite2D = lw.world.get_node_or_null(NodePath("px_back_%s" % chair_id))
        if chair_id == "" or guest == null or seat == null or back == null:
            bad.append("%s 找不到椅子或图（椅子 %s 座 %s 背 %s）" % [id, chair_id, seat != null, back != null])
            continue
        var order_ok: bool = seat.position.y < guest.position.y and guest.position.y < back.position.y
        var seat_tl: Vector2 = seat.position + seat.offset
        var cx: float = seat_tl.x + seat.texture.get_size().x * 0.5
        var centered: bool = absf(guest.position.x - cx) <= 3.0
        # 椅背遮住人多少：人这张图（只留上半身那块）里不透明的像素，有几个被椅背图的不透明像素盖着
        var gtex := img_of(guest.texture)
        var rr: Rect2i = Rect2i(guest.region_rect)
        var gtl: Vector2 = guest.position + guest.offset
        var btl: Vector2 = back.position + back.offset
        var bimg := img_of(back.texture)
        var total := 0
        var covered := 0
        for yy in rr.size.y:
            for xx in rr.size.x:
                var c := gtex.get_pixel(rr.position.x + xx, rr.position.y + yy)
                if c.a8 == 0:
                    continue
                total += 1
                var wx := int(gtl.x) + xx
                var wy := int(gtl.y) + yy
                var bx2 := wx - int(btl.x)
                var by2 := wy - int(btl.y)
                if bx2 >= 0 and by2 >= 0 and bx2 < bimg.get_width() and by2 < bimg.get_height() and bimg.get_pixel(bx2, by2).a8 > 0:
                    covered += 1
        var vis := 100.0 * float(total - covered) / maxf(float(total), 1.0)
        vis_pcts.append(vis)
        if order_ok and centered and vis > 30.0:
            n_ok += 1
        else:
            bad.append("%s 椅子 %s：座 y %.0f、人 y %.0f、背 y %.0f，排对 %s，居中 %s（差 %.0f），露出 %.0f%%" % [id, chair_id, seat.position.y, guest.position.y, back.position.y, order_ok, centered, guest.position.x - cx, vis])
    print("    24 位里排对、居中、露出 >30%% 的 %d 位；露出比例最少 %.0f%%、最多 %.0f%%" % [n_ok, (vis_pcts.min() if vis_pcts.size() > 0 else 0.0), (vis_pcts.max() if vis_pcts.size() > 0 else 0.0)])
    for s in bad.slice(0, 8):
        print("    ", s)
    check("24 位替身：座椅 < 人 < 椅背，人在椅子正中，椅背没把人盖没（%d 位对）" % n_ok, n_ok == 24 and bad.is_empty())
    print("RESULT " + ("PASS" if ok else "FAIL"))
    quit(0 if ok else 1)
