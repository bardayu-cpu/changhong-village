extends SceneTree
## 第 69 版收尾（07 做，04 看第 69 版的几条），03 自己重测（01 H 10/4 派，不改游戏代码；不看 07 的 test_estate_map 第五节，另起量法）：
##   1 传到了弹提示：每传一次，到了以后顶部提示条出来、字是「到了 + 那块的正式名字」（不是地图上的短叫法）、不带引号、站稳以后约 2.5 秒收；没传成不弹
##   2 传送门图标闪：存档里没点开过地图的，图标每回出来（离开场景再回来也算）闪 4 秒（亮暗来回，最暗 < 0.5、最亮 > 0.9），闪完停在全亮；点开过一次地图：
##     存档记 map_used、真写进文件、以后图标再出来也不闪（一直全亮）；老存档没这个字段读成没点开过；没签到不出
##   3 地图上的字：十五块名字都写得下一行（正式名字、短叫法各列出来）；「你」的标记画在块上沿，金圈不压块里的名字墨迹（十五块各当一回「你在这」、5 个站位）
##   4 迎宾院「大门」那块牌合进「去停车场 ↓」：迎宾院里不剩单独的「大门」牌，通停车场的牌只有一块、箭头朝下
##   5 北口落点不挡门牌：小卖部、休息厅 2、西餐厨房从喷泉广场走口进来、从地图传送过来，人站的位置（40×90 的身子）都不压在门口名字牌上
## 用法：Godot --headless --path . --script res://tools/test_map69b_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 60.0
const SAVE := "user://test_m69b_court.json"
const ALL := ["court", "banquet", "backhall", "lawn", "lake", "orchard", "parking", "plaza", "kids", "shop", "rest2", "wkitchen", "garden", "frontgate", "backgate"]

var m
var started := false
var ok := true
var em

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(250.0).timeout.connect(func():
        print("RESULT FAIL 250 秒没跑完")
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

func press(at: Vector2) -> InputEventMouseButton:
    var e := InputEventMouseButton.new()
    e.button_index = MOUSE_BUTTON_LEFT
    e.pressed = true
    e.position = at
    return e

func tap_chip() -> void:
    em.chip.gui_input.emit(press(Vector2(30, 20)))
    await frames(2)

func enter(id: String) -> void:
    m.dialog.visible = false
    m.say_token += 1
    m.cv.walking_enabled = true
    if m.state == id:
        return
    m.teleport_to(id, Vector2.ZERO)
    for i in 500:
        await process_frame
        if m.state == id and not m.switching:
            break
    await frames(4)
    m.dialog.visible = false
    m.cv.walking_enabled = true

func map_go(id: String) -> void:
    await tap_chip()
    var r: Rect2 = em.view.rect_of(em.block(id))
    em.view._gui_input(press(r.get_center()))
    await frames(2)
    (em.confirm.find_child("map_yes", true, false) as Button).pressed.emit()
    for i in 500:
        await process_frame
        if m.state == id and not m.switching:
            break

func set_save(d: Dictionary) -> void:
    var f := FileAccess.open(SAVE, FileAccess.WRITE)
    f.store_string(JSON.stringify(d))
    f.close()
    m.court_save.local_path = SAVE
    m.court_save.load_local()

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.games_save.local_path = "user://test_m69b_games.json"
    set_save({"welcomed": true, "signed_in": true, "court_seen": true, "map_used": true})
    em = m.estate_map
    m._enter_court()
    for i in 300:
        await process_frame
        if m.state == "court" and not m.switching:
            break
    m.dialog.visible = false
    await frames(4)

    print("1 传到了弹提示")
    var bad: Array = []
    var n := 0
    for id in ["lake", "kids", "shop", "wkitchen", "garden", "banquet", "backgate", "rest2", "plaza", "orchard"]:
        if id == m.state:
            continue
        m.note_box.visible = false
        await map_go(id)
        await frames(20)
        var want: String = em._t("arrive_fmt") % str(em.block(id)["name"])
        var got: String = m.note.text
        var shown: bool = m.note_box.visible
        var short_name: String = str(em.block(id).get("short", ""))
        n += 1
        var issues: Array = []
        if not shown or got != want:
            issues.append("提示 %s「%s」，该是「%s」" % [str(shown), got, want])
        if got.contains("“") or got.contains("”"):
            issues.append("提示带了引号")
        if short_name != "" and short_name != str(em.block(id)["name"]) and got.contains("到了" + short_name) and not got.contains(str(em.block(id)["name"])):
            issues.append("提示用了短叫法")
        await create_timer(3.2).timeout   # 提示停 2.5 秒（真时间），多等一点
        if m.note_box.visible:
            issues.append("3.2 秒后提示还不收")
        if not issues.is_empty():
            bad.append("%s：%s" % [id, str(issues)])
        m.dialog.visible = false
    for x in bad:
        print("    ", x)
    check("传了 %d 次：每次到了弹「到了 + 正式名字」、不带引号、3.2 秒后收了（%d 处不对）" % [n, bad.size()], bad.is_empty() and n >= 9)
    # 点「不去」不弹
    await enter("court")
    m.note_box.visible = false
    await tap_chip()
    var r2: Rect2 = em.view.rect_of(em.block("lake"))
    em.view._gui_input(press(r2.get_center()))
    await frames(2)
    (em.confirm.find_child("map_no", true, false) as Button).pressed.emit()
    await frames(30)
    em.close_map()
    check("点「不去」：不弹提示（提示条 %s）" % str(m.note_box.visible), not m.note_box.visible)

    print("2 传送门图标闪")
    set_save({"welcomed": true, "signed_in": true, "court_seen": true})
    await enter("lawn")
    await enter("court")
    # 图标刚出来：采样 4.4 秒（用真实帧，sync 用的是 get_process_delta_time）
    m.court_save.signed_in = false
    await frames(3)
    check("没签到：图标不出（%s）" % str(em.icon.visible), not em.icon.visible)
    m.court_save.signed_in = true
    var lo := 1.0
    var hi := 0.0
    var t_end := Time.get_ticks_msec() + 4400
    var samples := 0
    var flips := 0
    var last_hi := true
    while Time.get_ticks_msec() < t_end:
        await process_frame
        samples += 1
        var a: float = em.icon.modulate.a
        lo = minf(lo, a)
        hi = maxf(hi, a)
        var now_hi: bool = a > 0.65
        if now_hi != last_hi:
            flips += 1
            last_hi = now_hi
    await frames(30)
    var a_end: float = em.icon.modulate.a
    check("没点开过：图标 4 秒里亮暗来回（最暗 %.2f、最亮 %.2f、%d 次亮暗切换、%d 帧），闪完停在全亮（%.2f）" % [lo, hi, flips, samples, a_end], lo < 0.5 and hi > 0.9 and flips >= 4 and absf(a_end - 1.0) < 0.01)
    # 每回出来都闪：图标每回「出来」（离开场景再回来，比如进了厨房小游戏）都闪；在场景里换画布不算出来
    var st_keep: String = m.state
    m.state = "kitchen"
    await frames(3)
    check("不在场景里（厨房小游戏）：图标收起来（%s）" % str(em.icon.visible), not em.icon.visible)
    m.state = st_keep
    var lo2 := 1.0
    var t2_end := Time.get_ticks_msec() + 1500
    while Time.get_ticks_msec() < t2_end:
        await process_frame
        lo2 = minf(lo2, em.icon.modulate.a)
    check("没点开过：回到场景图标又闪（最暗 %.2f）" % lo2, lo2 < 0.5 and em.icon.visible)
    await enter("lawn")
    await enter("court")
    var lo2b := 1.0
    var t2b_end := Time.get_ticks_msec() + 4800
    while Time.get_ticks_msec() < t2b_end:
        await process_frame
        lo2b = minf(lo2b, em.icon.modulate.a)
    await frames(30)
    check("闪完以后（等了 4.8 秒）：停在全亮（%.2f）" % em.icon.modulate.a, absf(em.icon.modulate.a - 1.0) < 0.01)
    # 点开一次
    m.court_save.map_used = false
    await tap_chip()
    var saved := {}
    if FileAccess.file_exists(SAVE):
        var raw = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
        if raw is Dictionary:
            saved = raw
    check("点开过一次地图：记进存档（内存 %s、文件里 %s）" % [str(m.court_save.map_used), str(saved.get("map_used", "没有"))], em.is_open() and m.court_save.map_used and saved.get("map_used", false) == true)
    em.close_map()
    m.state = "kitchen"
    await frames(3)
    m.state = st_keep
    var lo3 := 1.0
    var t3_end := Time.get_ticks_msec() + 1500
    while Time.get_ticks_msec() < t3_end:
        await process_frame
        lo3 = minf(lo3, em.icon.modulate.a)
    check("点开过以后：离开场景再回来图标一直全亮不闪（最暗 %.2f）" % lo3, lo3 > 0.99 and em.icon.visible)
    # 重新读存档（老存档没有这个字段 → 当没点开过，闪）
    set_save({"welcomed": true, "signed_in": true, "court_seen": true})
    check("老存档没有 map_used 这个字段：读成没点开过（%s）" % str(m.court_save.map_used), not m.court_save.map_used)
    set_save({"welcomed": true, "signed_in": true, "court_seen": true, "map_used": true})
    check("存档里 map_used 真读回来（%s）" % str(m.court_save.map_used), m.court_save.map_used)

    print("3 地图上的字")
    var nofit: Array = []
    var listed: Array = []
    for b in em.data["blocks"]:
        var nm: String = str(b["name"])
        var sh: String = str(b.get("short", nm))
        listed.append("%s%s" % [nm, "" if sh == nm else "→" + sh])
        if not em.view.name_fits(b):
            nofit.append(nm)
    print("    ", listed)
    check("十五块名字都写得下一行（写不下的 %s）" % str(nofit), nofit.is_empty() and listed.size() == 15)
    # 「你」标记离名字有多远：金圈在块上沿、半径 ≤ 8 + 2；名字一行 18 号，按块中心排
    var close_ones: Array = []
    var fnt: Font = m.font
    for b in em.data["blocks"]:
        var r: Rect2 = em.view.rect_of(b)
        var sh2: String = str(b.get("short", b["name"]))
        var sz: Array = b["size"]
        var wname: float = fnt.get_string_size(sh2, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
        var hname: float = fnt.get_height(18)
        hname = 14.0   # 像素字 18 号一行 24 高，墨迹只占中间 14 左右（上下是留白）：按墨迹量
        var name_r := Rect2(r.get_center() - Vector2(wname, hname) * 0.5, Vector2(wname, hname))
        for fx in [0.0, 0.25, 0.5, 0.75, 1.0]:
            var cx: float = clampf(fx, 0.1, 0.9)
            var p := Vector2(r.position.x + r.size.x * cx, r.position.y)
            var circle := Rect2(p - Vector2(10, 10), Vector2(20, 20))
            var gap := maxf(name_r.position.y - circle.end.y, 0.0) if name_r.position.y > circle.end.y else -1.0
            if gap < 0.0:
                close_ones.append("%s（站 %.2f 处）金圈到名字只隔 %.1f" % [str(b["name"]), fx, gap])
    for x in close_ones:
        print("    ", x)
    check("十五块各当一回「你在这」、站在 5 个位置：金圈（半径 10）不压块里的名字（按墨迹高 14 量）（不够的 %d 处）" % close_ones.size(), close_ones.is_empty())

    print("4 迎宾院「大门」牌合进「去停车场」")
    await enter("court")
    var texts: Array = []
    for lb in m.court.labels.get_children():
        if lb is Label:
            texts.append(str((lb as Label).text))
    var gate_only: Array = texts.filter(func(t): return t.replace("↓", "").replace("↑", "").replace("←", "").replace("→", "").strip_edges() == "大门")
    var park: Array = texts.filter(func(t): return t.contains("停车场"))
    check("迎宾院的牌 %s：没有单独的「大门」（%d 块）、通停车场的牌 %d 块、箭头朝下 %s" % [str(texts), gate_only.size(), park.size(), str(park)], gate_only.is_empty() and park.size() == 1 and (park[0] as String).contains("↓"))

    print("5 北口落点不挡门牌")
    var cover: Array = []
    for id in ["shop", "rest2", "wkitchen"]:
        # 走口进来
        await enter("plaza")
        m.teleport_to(id, Vector2.ZERO)
        for i in 500:
            await process_frame
            if m.state == id and not m.switching:
                break
        await frames(10)
        var c = m.cv
        var body_a := Rect2(c.pos.x - 20.0, c.pos.y - 90.0, 40.0, 90.0)
        for hs in c.room_signs:
            var rl = (hs as Node2D).get_child(0)
            if rl is Label and body_a.intersects(Rect2((hs as Node2D).position + (rl as Label).position, (rl as Label).size)):
                cover.append("%s 默认落点 %s 压「%s」" % [id, str(c.pos), (rl as Label).text])
        # 从喷泉广场走口进来的真落点
        var via: Vector2 = c.arrival_from("plaza")
        var body_b := Rect2(via.x - 20.0, via.y - 90.0, 40.0, 90.0)
        for hs in c.room_signs:
            var rl2 = (hs as Node2D).get_child(0)
            if rl2 is Label and body_b.intersects(Rect2((hs as Node2D).position + (rl2 as Label).position, (rl2 as Label).size)):
                cover.append("%s 从广场走口进来落点 %s 压「%s」" % [id, str(via), (rl2 as Label).text])
        # 从地图传送过来
        await enter("court")
        await map_go(id)
        await frames(10)
        var c2 = m.cv
        var body_c := Rect2(c2.pos.x - 20.0, c2.pos.y - 90.0, 40.0, 90.0)
        for hs in c2.room_signs:
            var rl3 = (hs as Node2D).get_child(0)
            if rl3 is Label and body_c.intersects(Rect2((hs as Node2D).position + (rl3 as Label).position, (rl3 as Label).size)):
                cover.append("%s 地图传送落点 %s 压「%s」" % [id, str(c2.pos), (rl3 as Label).text])
        if not c2._free(c2.pos):
            cover.append("%s 地图传送落点 %s 站不了" % [id, str(c2.pos)])
    for x in cover:
        print("    ", x)
    check("小卖部、休息厅 2、西餐厨房：三种进法（teleport 默认、走口 arrival_from、地图传送）人的身子都不压门牌（%d 处）" % cover.size(), cover.is_empty())

    DirAccess.remove_absolute(SAVE)
    DirAccess.remove_absolute("user://test_m69b_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
