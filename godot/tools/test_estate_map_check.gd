extends SceneTree
## 第 69 版全景地图（07 做，阿鱼：左上角罗曼山庄名字牌里加传送门图标，点开整座山庄、点一块传过去），03 自己重测（01 H 10/4 派，不改游戏代码；不看 07 的 test_estate_map，另起量法）：
##   1 入口：签到前名字牌里没有图标、真点名字牌地图不开；签到后图标出来、图标整个在名字牌的框里、真点名字牌地图开；
##     地图开着，人不能走（下命令走、推摇杆都不挪）；关上以后又能走；「关上」键、点背景都收得对
##   2 打不开：开车、说话框开着、写悄悄话、翻册子、看身份卡、后厅聊天开着、厨房小游戏、没签到——每种都真点名字牌，地图不开；放开后能开
##   3 点块：十五块每块中心点下去 block_at 认出的是它自己（没被别块盖住）；点空地不问；点自己那块（十五块各试一次）「你就在这里」、不问、不传
##   4 传送：两趟链子，正着一趟、反着一趟，每一站的出发块不一样（每块都当过目的地两次、从不同的块来）；到了：站在那块、地上能站（走路范围里、不在障碍里）、
##     没被弹回去（再过 2 秒还在）、地图收了、四个方向推摇杆至少有一个方向真能挪 20 像素以上（没卡死）、人能走；
##     点「不去」不传；点背景收确认框
## 用法：Godot --headless --path . --script res://tools/test_estate_map_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 60.0
const SAVE := "user://test_emc_court.json"
const ALL := ["court", "banquet", "backhall", "lawn", "lake", "orchard", "parking", "plaza", "kids", "shop", "rest2", "wkitchen", "garden", "frontgate", "backgate"]

var m
var started := false
var ok := true
var em

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(280.0).timeout.connect(func():
        print("RESULT FAIL 280 秒没跑完")
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

func tick(n: int) -> void:
    for i in n:
        m.cv._process(DT)
        m._process(DT)

func press(at: Vector2) -> InputEventMouseButton:
    var e := InputEventMouseButton.new()
    e.button_index = MOUSE_BUTTON_LEFT
    e.pressed = true
    e.position = at
    return e

## 真点名字牌（跟玩家点一样：事件发到名字牌的 gui_input）
func tap_chip() -> void:
    em.chip.gui_input.emit(press(Vector2(30, 20)))
    await frames(2)

func click_block(id: String) -> void:
    var r: Rect2 = em.view.rect_of(em.block(id))
    em.view._gui_input(press(r.get_center()))
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

## 地上能站：画布自己的 _free + 我自己对走路范围多边形认一遍（宴会厅不是多边形走路范围，只认 _free）
func on_ground(c, p: Vector2) -> bool:
    if not c._free(p):
        return false
    if c.cfg is Dictionary and c.cfg.has("walk") and c.cfg["walk"] is Array and not (c.cfg["walk"] as Array).is_empty() and (c.cfg["walk"][0] is Array):
        var inside := false
        for poly in c.cfg["walk"]:
            var pts := PackedVector2Array()
            for v in poly:
                pts.append(Vector2(float(v[0]), float(v[1])))
            if Geometry2D.is_point_in_polygon(p, pts):
                inside = true
        return inside
    return true

## 站稳以后推摇杆看挪不挪得动：先往离最近的口最远的方向推（不走进口里去触发换场），挪不动再试别的方向；谁挪到 20 像素以上就算活的
func push_test(c) -> float:
    var nearest := Vector2.ZERO
    var nd := INF
    var pts = c.get("points")   # 宴会厅没有 points（它的门在 exits 里）
    if pts is Dictionary:
        for id in pts:
            if str(pts[id]["to"]) != "":
                var dd: float = c.pos.distance_to(pts[id]["pos"])
                if dd < nd:
                    nd = dd
                    nearest = pts[id]["pos"]
    elif c.get("exits") is Array:
        for e in c.exits:
            var ep: Vector2 = e["arrive"] if e.has("arrive") else Vector2.ZERO
            if ep != Vector2.ZERO and c.pos.distance_to(ep) < nd:
                nd = c.pos.distance_to(ep)
                nearest = ep
    var away: Vector2 = (c.pos - nearest).normalized() if nearest != Vector2.ZERO else Vector2(0, 1)
    var dirs: Array = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
    dirs.sort_custom(func(a, b): return a.dot(away) > b.dot(away))
    var best := 0.0
    var p0: Vector2 = c.pos
    for d in dirs:
        c.walking_enabled = true
        c.stick = d
        for i in 40:
            tick(1)
            if c.pos.distance_to(p0) >= 24.0:
                break
        c.stick = Vector2.ZERO
        tick(2)
        best = maxf(best, c.pos.distance_to(p0))
        c.reset_to(p0)
        tick(1)
        if best >= 20.0:
            break
    return best

func teleport_via_map(id: String) -> Dictionary:
    var res := {"issues": [], "at": Vector2.ZERO}
    if not em.can_open():
        res["issues"].append("在 %s 打不开地图" % m.state)
        return res
    await tap_chip()
    if not em.is_open():
        res["issues"].append("真点名字牌没开")
        return res
    await click_block(id)
    if not em.confirm.visible or em.picked != id:
        res["issues"].append("点了没问（picked %s）" % em.picked)
        em.close_map()
        return res
    if em.confirm_label.text.find(str(em.block(id)["name"])) < 0:
        res["issues"].append("问的话「%s」没带地名" % em.confirm_label.text)
    (em.confirm.find_child("map_yes", true, false) as Button).pressed.emit()
    for i in 500:
        await process_frame
        if m.state == id and not m.switching:
            break
    await frames(30)
    var c = m.cv
    var at: Vector2 = c.pos
    res["at"] = at
    if m.state != id:
        res["issues"].append("没到（在 %s）" % m.state)
        return res
    if not on_ground(c, at):
        res["issues"].append("站的地方 %s 不在走路范围里 / 在障碍里" % str(at))
    if em.is_open():
        res["issues"].append("地图没收")
    m.dialog.visible = false
    await frames(120)
    if m.state != id:
        res["issues"].append("2 秒后被弹到 %s" % m.state)
        return res
    if c.pos.distance_to(at) > 4.0 and c.path.is_empty():
        res["issues"].append("没碰就自己挪了 %s → %s" % [str(at), str(c.pos)])
    var far := push_test(c)
    if far < 20.0:
        res["issues"].append("四个方向都推不动（最远 %.1f 像素；说话框 %s、能走 %s、坐着 %s、在切 %s、状态 %s、站 %s）" % [far, str(m.dialog.visible), str(c.walking_enabled), str(c.get("seated")), str(m.switching), m.state, str(c.pos)])
    if not c.walking_enabled:
        res["issues"].append("到了不能走")
    return res

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = SAVE
    m.games_save.local_path = "user://test_emc_games.json"
    m.court_save.signed_in = false
    em = m.estate_map

    print("1 入口")
    m._enter_court()
    for i in 300:
        await process_frame
        if m.state == "court" and not m.switching:
            break
    m.dialog.visible = false
    m.court.walking_enabled = true
    await frames(4)
    var no_icon: bool = not em.icon.visible
    await tap_chip()
    check("签到前：名字牌里没有传送门图标（%s）、真点名字牌地图不开（开了 %s）" % [str(no_icon), str(em.is_open())], no_icon and not em.is_open() and m.court.walking_enabled)
    m.court_save.signed_in = true
    await frames(4)
    var chip_r: Rect2 = em.chip.get_global_rect()
    var icon_r: Rect2 = em.icon.get_global_rect()
    check("签到后：图标出来、有大小（%s）、整个在名字牌框里（图标 %s 名字牌 %s）" % [str(em.icon.size), str(icon_r), str(chip_r)], em.icon.visible and em.icon.size.x >= 16.0 and em.icon.size.y >= 16.0 and chip_r.encloses(icon_r))
    await tap_chip()
    check("真点名字牌：地图开了、标着你在迎宾院", em.is_open() and em.view.here == "court")
    var p0: Vector2 = m.court.pos
    m.court.tap(m.court.get_viewport().get_canvas_transform() * (p0 + Vector2(120, 0)))   # 真点地面（走路的入口 tap；地图的遮罩正常会先吃掉这一下）
    m.court.stick = Vector2(0, 1)
    tick(60)
    check("地图开着人不能走（点地面 + 推摇杆，挪了 %.1f 像素）" % m.court.pos.distance_to(p0), m.court.pos.distance_to(p0) < 2.0 and not m.court.walking_enabled)
    (em.overlay.find_child("map_close", true, false) as Button).pressed.emit()
    await frames(2)
    check("点「关上」：地图收了、又能走", not em.is_open() and m.court.walking_enabled)
    m.court.stick = Vector2.ZERO
    m.court.path.clear()

    print("2 打不开")
    var blockers := {}
    # 开车
    m.driving = true
    await tap_chip()
    blockers["开车"] = em.is_open()
    em.close_map()
    m.driving = false
    # 说话框
    m.dialog.visible = true
    await tap_chip()
    blockers["说话框"] = em.is_open()
    em.close_map()
    m.dialog.visible = false
    # 悄悄话
    m.whisper_box.visible = true
    await tap_chip()
    blockers["写悄悄话"] = em.is_open()
    em.close_map()
    m.whisper_box.visible = false
    # 册子、身份卡
    m.book_open = true
    await tap_chip()
    blockers["回忆册"] = em.is_open()
    em.close_map()
    m.book_open = false
    m.card_open = true
    await tap_chip()
    blockers["身份卡"] = em.is_open()
    em.close_map()
    m.card_open = false
    # 厨房小游戏（state 不在场景里）
    var st: String = m.state
    m.state = "kitchen"
    await tap_chip()
    blockers["厨房小游戏"] = em.is_open()
    em.close_map()
    m.state = st
    # 没签到
    m.court_save.signed_in = false
    await tap_chip()
    blockers["没签到"] = em.is_open()
    em.close_map()
    m.court_save.signed_in = true
    # 切画布中
    m.switching = true
    await tap_chip()
    blockers["切画布中"] = em.is_open()
    em.close_map()
    m.switching = false
    # 画布不能走（签到面板那类）
    m.court.walking_enabled = false
    await tap_chip()
    blockers["画布不能走"] = em.is_open()
    em.close_map()
    m.court.walking_enabled = true
    var opened: Array = []
    for k in blockers:
        if blockers[k]:
            opened.append(k)
    await frames(2)
    check("九种情况真点名字牌都不开（开了的 %s）" % str(opened), opened.is_empty())
    await tap_chip()
    check("都放开以后点得开", em.is_open())
    em.close_map()
    # 后厅聊天
    await enter("backhall")
    m.lounge_ui.attach(m.backhall.lounge)
    m.backhall.reset_to(m.backhall.lounge.approach_of("lounge_10"))
    m.backhall.lounge.request_talk("lounge_10")
    for i in 300:
        await process_frame
        if m.lounge_ui.talk_box.visible:
            break
    var talk_on: bool = m.lounge_ui.talk_box.visible
    await tap_chip()
    check("后厅跟爷爷说着话（对话框开着 %s）：真点名字牌不开（开了 %s）" % [str(talk_on), str(em.is_open())], talk_on and not em.is_open())
    em.close_map()
    m.lounge_ui.close_talk()
    await frames(4)
    m.dialog.visible = false

    print("3 点块")
    await enter("court")
    await tap_chip()
    var hit_bad: Array = []
    for id in ALL:
        var r: Rect2 = em.view.rect_of(em.block(id))
        var got: String = em.view.block_at(r.get_center())
        if got != id:
            hit_bad.append("%s（中心点出来是 %s）" % [id, got])
    check("十五块每块中心点下去认出的是它自己（不对的 %s）" % str(hit_bad), hit_bad.is_empty())
    var map_r: Rect2 = em.view.get_global_rect()
    var empty_hit := ""
    for corner in [Vector2(1, 1), Vector2(em.view.size.x - 2, 1), Vector2(1, em.view.size.y - 2)]:
        var g: String = em.view.block_at(corner)
        if g != "":
            empty_hit += "%s→%s " % [str(corner), g]
    check("地图边角空地点下去不认成哪一块（%s）" % empty_hit, empty_hit == "")
    em.close_map()
    var here_bad: Array = []
    for id in ALL:
        await enter(id)
        var st0: String = m.state
        var at0: Vector2 = m.cv.pos
        if not em.can_open():
            here_bad.append("%s：打不开" % id)
            continue
        await tap_chip()
        await click_block(id)
        var said: String = em.hint.text
        if said != em._t("here") or em.confirm.visible or em.picked != "":
            here_bad.append("%s：点自己说「%s」、确认框 %s" % [id, said, str(em.confirm.visible)])
        await frames(30)
        if m.state != st0 or m.cv.pos.distance_to(at0) > 1.0:
            here_bad.append("%s：点自己居然挪了（%s %s）" % [id, m.state, str(m.cv.pos)])
        em.close_map()
    check("十五块各在自己那块点自己：说「你就在这里」、不问、不传（%d 处不对 %s）" % [here_bad.size(), str(here_bad)], here_bad.is_empty())

    print("4 传送")
    await enter("court")
    # 点「不去」、点背景
    await tap_chip()
    await click_block("lake")
    var asked: bool = em.confirm.visible
    (em.confirm.find_child("map_no", true, false) as Button).pressed.emit()
    await frames(2)
    var no_ok: bool = asked and not em.confirm.visible and m.state == "court" and em.is_open()
    await click_block("orchard")
    var asked2: bool = em.confirm.visible
    var dim: Control = em.overlay.get_child(0)
    dim.gui_input.emit(press(Vector2(10, 900)))
    await frames(2)
    check("点「不去」、点背景：确认框收了、人还在迎宾院、地图还开着（问 %s %s）" % [str(asked), str(asked2)], no_ok and asked2 and not em.confirm.visible and m.state == "court" and em.is_open() and em.picked == "")
    em.close_map()
    var forward: Array = ["lawn", "banquet", "lake", "kids", "orchard", "shop", "backgate", "rest2", "parking", "wkitchen", "plaza", "garden", "frontgate", "backhall", "court"]
    var backward: Array = forward.duplicate()
    backward.reverse()
    var bad: Array = []
    var sources := {}
    var n_tp := 0
    for chain in [forward, backward]:
        for id in chain:
            var from: String = m.state
            if from == id:
                continue
            var res: Dictionary = await teleport_via_map(id)
            n_tp += 1
            if not sources.has(id):
                sources[id] = []
            (sources[id] as Array).append(from)
            var iss: Array = res["issues"]
            print("    %s → %s：站 %s %s" % [from, id, str(res["at"]), "" if iss.is_empty() else str(iss)])
            if not iss.is_empty():
                bad.append("%s→%s：%s" % [from, id, str(iss)])
                await enter(id)
    var two_src := 0
    for id in sources:
        if (sources[id] as Array).size() >= 2 and (sources[id][0] != sources[id][1]):
            two_src += 1
    check("两趟链子共传了 %d 次（%d 处不对 %s）；十五块里 %d 块当过两次目的地且两次从不同的块来；每次到了站得住、没弹回去、地图收了、四个方向能挪" % [n_tp, bad.size(), str(bad), two_src], bad.is_empty() and n_tp >= 28 and two_src >= 13)

    DirAccess.remove_absolute(SAVE)
    DirAccess.remove_absolute("user://test_emc_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
