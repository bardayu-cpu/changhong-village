extends SceneTree
## 验收：55 桌大厅（01 9/24 派，阿鱼 v11）。新场景，和 12 桌厅并存，开关切：
## 0 默认还是 12 桌厅；1 调试版切过去：55 张桌、桌号 T1、T2 离婚礼台最近；2 每把椅子都走得到；
## 3 镜头上下左右跟人、手指拖着看、拖到边上停；4 第一次进厅站大门口，以后站自己桌边；5 从后厅回来站东侧门里边；
## 6 婚礼台横幅两行字、LED 屏「现在 N 人在场」跟着人数变、在滚；7 假服务端回 55 张桌、换桌查桌号椅子号；8 切回 12 桌厅
## 用法：Godot --headless --path . --script res://tools/test_hall_big.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const LayeredHall = preload("res://scripts/layered_hall.gd")

var m
var started := false
var ok := true

func _initialize() -> void:
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Main.HALL55_FLAG))   # 别带着上回的开关
    m = Main.new()
    m.fast = true
    get_root().add_child(m)

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

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true

    print("0 默认还是 12 桌厅")
    check("assets/hall.json 默认关", not m.hall55_on())
    check("搭的是 12 桌厅：%d 张桌" % m.hall.cfg["tables"].size(), not m.hall.big and m.hall.cfg["tables"].size() == 12)

    print("1 切到 55 桌大厅")
    await m._enter_banquet()
    await create_timer(0.5).timeout
    await m._set_hall55(true)
    await create_timer(0.5).timeout
    var h = m.hall
    var tabs: Array = h.cfg["tables"]
    check("是 55 桌大厅：%d 张桌、画布 %s" % [tabs.size(), h.cfg["size"]], h.big and tabs.size() == 55 and int(h.cfg["size"][1]) > 2000)
    check("还在宴会厅", m.state == "banquet" and m.cv == h)
    var t1: Dictionary = h._table_cfg("T1")
    var t2: Dictionary = h._table_cfg("T2")
    var min_y := INF
    for t in tabs:
        min_y = minf(min_y, float(t["y"]))
    # 第一排中间两个位空着（婚礼台正前方），T1、T2 是第一排剩下的里离红毯最近的两张，一边一张
    check("T1 %s、T2 %s 在第一排、红毯一边一张、离红毯最近" % [Vector2(t1["x"], t1["y"]), Vector2(t2["x"], t2["y"])],
        float(t1["y"]) == min_y and float(t2["y"]) == min_y and (float(t1["x"]) - 748.0) * (float(t2["x"]) - 748.0) < 0.0
        and absf(float(t1["x"]) - 748.0) < 400.0 and absf(float(t2["x"]) - 748.0) < 400.0)
    check("NPC 宾客 %d 个（每桌 5～7）" % h.life.guests.size(), h.life.guests.size() >= 250 and h.life.guests.size() <= 385)
    check("服务员 %d 个" % h.life.waiters.size(), h.life.waiters.size() == 6)

    print("2 每把椅子都走得到")
    var bad: Array = []
    for t in tabs:
        for no in range(1, 11):
            var p: Vector2 = h.chair_world(t, no)
            var c: Vector2i = h._nearest_free(h._cell_of(p))
            var d: float = h._cell_pos(c).distance_to(p)
            if d > 80.0 or h.find_path(h.SPAWN, h._cell_pos(c)).is_empty():
                bad.append("%s:%d(%.0f)" % [t["id"], no, d])
    check("走不到的椅子（550 把里）%s" % [bad], bad.is_empty())
    check("东侧门走得到", not h.find_path(h.SPAWN, h.side_door + Vector2(-20, 0)).is_empty())

    print("3 镜头")
    h.reset_to(h.SPAWN)
    await frames(3)
    var vh: float = m.get_viewport().get_visible_rect().size.y / h.cam.zoom.y
    check("在大门口：镜头贴着厅底（中心 y %.0f）" % h.cam.position.y, h.cam.position.y > float(h.cfg["size"][1]) - vh * 0.5 - 30.0)
    h.reset_to(Vector2(385, 700))
    await frames(3)
    check("人在厅中间：镜头跟到 y %.0f" % h.cam.position.y, absf(h.cam.position.y - 700.0) < 5.0)
    h.pan_cam(Vector2(0, 400))     # 手指往下拖：看上面
    await frames(2)
    check("往下拖，镜头往上挪（偏 %.0f）" % h.cam_pan.y, h.cam_pan.y < -100.0)
    h.pan_cam(Vector2(0, 20000))
    await frames(2)
    check("拖到顶就停（镜头中心 y %.0f，不小于半屏 %.0f）" % [h.pos.y + h.cam_pan.y, vh * 0.5], h.pos.y + h.cam_pan.y >= vh * 0.5 - 1.0)
    h.pan_cam(Vector2(-20000, 0))
    var vw: float = m.get_viewport().get_visible_rect().size.x / h.cam.zoom.x
    check("左右拖也停在边上", h.pos.x + h.cam_pan.x <= float(h.cfg["size"][0]) - vw * 0.5 + 1.0)

    print("4 进厅站哪")
    m.cloud.fake_arrival_mode = "first"
    m.cloud.fake_no_news = false
    await m._enter_banquet()
    await create_timer(2.5).timeout
    check("第一次进厅：站大门口 %s" % h.pos, h.pos.distance_to(h.SPAWN) < 1.0)
    m.cloud.fake_arrival_mode = "card"
    m.cloud.fake_no_news = true
    await m._enter_banquet()
    await create_timer(2.5).timeout
    var chair: Vector2 = h._my_chair_pos()
    check("以后进厅：站到自己桌边 %s（椅子 %s，差 %.0f）" % [h.pos, chair, h.pos.distance_to(chair)],
        chair != Vector2.ZERO and h.pos.distance_to(chair) < 60.0 and h._free(h.pos))

    print("5 从后厅回来")
    await m._switch_canvas("backhall")
    await create_timer(1.5).timeout
    await m._switch_canvas("banquet")
    await create_timer(1.5).timeout
    check("站在东侧门里边 %s（门 %s）" % [h.pos, h.side_door], h.pos.distance_to(h.side_door) < 90.0 and h._free(h.pos))

    print("6 婚礼台上的字")
    check("有横幅和 LED 屏", h.signs != null and h.signs.banner != null and h.signs.led != null)
    var lines: Array = []
    for l in h.signs.banner.find_children("*", "Label", true, false):
        lines.append((l as Label).text)
    check("横幅两行：%s" % [lines], lines.has("开席时间：2025 年 06 月 15 日") and lines.has("爱女：阿鱼 & 贤婿：Toretto"))
    var seated: int = h.seat_taken.size() + h.bench_spots.size()
    check("LED：%s（服务端座位 %d）" % [h.signs.led_line(), seated], h.signs.led_line() == "现在 %d 人在场" % seated)
    var x0: float = h.signs.led_text.position.x
    await create_timer(0.5).timeout
    check("LED 在滚（%.0f → %.0f）" % [x0, h.signs.led_text.position.x], h.signs.led_text.position.x != x0)
    var br: Rect2 = Rect2(h.signs.banner.position, h.signs.banner.size)
    # 画布最上面 130 像素在手机上是微信胶囊和左上角牌子那一条，横幅要在它下面；也不能压到台沿的 LED 屏
    var lr: Rect2 = Rect2(h.signs.led.position, h.signs.led.size)
    check("横幅在喜字下面、手机上看得见、不压 LED 屏 %s（LED %s）" % [br, lr], br.position.y >= 130.0 and br.end.y <= lr.position.y and br.position.x > 500.0 and br.end.x < 1000.0)

    print("7 假服务端")
    var got := {}   # 回话塞进字典（匿名函数改不了外面的局部变量）
    m.cloud.call_fn("enterHall", {}, func(r): got["enter"] = r)
    m.cloud.call_fn("changeSeat", {"tableId": "T56", "chairNo": 1}, func(r): got["t56"] = r)
    m.cloud.call_fn("changeSeat", {"tableId": "T55", "chairNo": 11}, func(r): got["c11"] = r)
    await create_timer(1.0).timeout
    check("回 55 张桌", (got.get("enter", {}).get("data", {}).get("tables", []) as Array).size() == 55)
    var r1: Dictionary = got.get("t56", {})
    var r2: Dictionary = got.get("c11", {})
    check("T56、11 号椅都拒：%s %s" % [r1.get("reason", ""), r2.get("reason", "")], r1.get("reason", "") == "bad_request" and r2.get("reason", "") == "bad_request")

    print("8 切回 12 桌厅")
    await m._set_hall55(false)
    await create_timer(0.5).timeout
    check("回到 12 桌厅：%d 张桌" % m.hall.cfg["tables"].size(), not m.hall.big and m.hall.cfg["tables"].size() == 12 and m.hall.signs == null)
    check("假服务端也回 12 张", m.cloud.fake_tables == 12)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Main.HALL55_FLAG))

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
