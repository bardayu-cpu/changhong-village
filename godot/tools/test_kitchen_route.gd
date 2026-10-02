extends SceneTree
## 厨房 v1 试接入（01 D 10/1）：两种宴会厅都走一遍——宴会厅东侧门 → 后厅 → 走到大锅点「穿上围裙 · 学做菜」→ 玩一局（交一道菜）
## → 金币进钱包（本机存档、电脑假服务端都记上）→ 关掉厨房、后厅能走 → 西口回宴会厅。
## 另记一条：开着厨房时来的干杯插图，关了厨房以后有没有接着放（宴会厅小游戏是放的）
## 用法：Godot --headless --path . --script res://tools/test_kitchen_route.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 60.0
const KITCHEN_SAVE := "user://suqi_kitchen.json"

var m
var started := false
var ok := true
var had_kitchen_save := false

func _initialize() -> void:
    had_kitchen_save = FileAccess.file_exists(KITCHEN_SAVE)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Main.HALL55_FLAG))
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

func tick(n: int) -> void:
    for i in n:
        m.cv._process(DT)
        m._process(DT)

func walk_to(target: Vector2, secs := 30.0) -> void:
    m.cv.go_to(target)
    for i in int(secs / DT):
        tick(1)
        if m.cv.path.is_empty():
            break

func click(p, text: String, last := false) -> bool:
    var children: Array = p.panel.get_children()
    if last:
        children.reverse()
    for c in children:
        if c is Button and c.text == text and not c.disabled:
            c.pressed.emit()
            await process_frame
            return true
    print("    找不到按钮 ", text)
    return false

## 一局：照 GPT 的 test_kitchen_buttons 那样点（第 1 关、跷脚牛肉、三样料、煮熟、盛出、交给服务员）
## 玩一局交一道菜。厨房 v3（GPT 10/2）界面全是图按钮，按钮上没字可找了：照 GPT 自己的测试那样走规则接口——
## 开第 1 关、给第一位服务员选第一道菜、照配料下锅、烧熟、盛出、交到他面前的盘子；钱从主工程的钱包走（看金币涨没涨）
func play_one(p) -> bool:
    p._start(1)
    await process_frame
    var g = p.rules
    if g.orders.is_empty():
        return false
    # 第 1 关的引导（04、03 10/2）：锅和原料之间一行大字，照该做的那一步说，做对一步换一句；点错了先说为什么
    var said: Array = []
    p._update_live_labels()
    said.append(p.guide.text if is_instance_valid(p.guide) else "")
    p._tap_ingredient(str(g.recipe_data(str(g.orders[0].dishes[0].recipe)).ingredients[0]))   # 先点原料（长辈最自然的那一下）
    said.append(p.guide.text if is_instance_valid(p.guide) else "")
    p.guide_flash_t = 0.0
    var good: bool = g.choose_order_dish(0, g.orders[0].id, 0)
    p._render()
    said.append(p.guide.text)
    var first: String = str(g.pots[0].required[0])
    for ing in g.pots[0].required:
        p._tap_ingredient(ing)
    said.append(p.guide.text)
    g.tick(8)
    p._update_live_labels()
    said.append(p.guide.text)
    good = good and g.serve_pot(0)
    p._render()
    said.append(p.guide.text)
    good = good and not g.plates.is_empty() and g.deliver(g.plates[0].id, g.orders[0].id)
    p._render()
    await process_frame
    check("第 1 关引导一步一句：%s" % [said], said[0] == "点服务员头上要的那道菜" and said[1].begins_with("先点服务员头上要的菜")
        and said[2] == "点原料：%s" % first and said[3] == "正在烧，熟了点锅盛出" and said[4].begins_with("熟了") and said[5].contains("交菜"))
    var gfs: int = p.guide.get_theme_font_size("font_size") if is_instance_valid(p.guide) else 0
    var gy: float = p.guide.position.y if is_instance_valid(p.guide) else 0.0
    check("引导字 %d（乘 540/941 约 %.0f 像素，≥24）、放在锅和原料之间（y %.0f，锅牌下沿 1170、原料格上沿 1210）" % [gfs, gfs * 540.0 / 941.0, gy],
        gfs * 540.0 / 941.0 >= 24.0 and gy >= 1150.0 and gy <= 1210.0)
    return good

## 三人三锅局：第 4 关（三位服务员、三口锅）用规则接口一直做到过关——空锅就接一道还没做的菜、照配料下锅，
## 熟了盛出、自动交给要它的那位；每步走 0.5 秒。回 [过没过关, 交了几道, 同屏最多几位服务员, 用了几口锅]
func play_three(p) -> Array:
    p._start(4)
    await process_frame
    var g = p.rules
    var most_orders := 0
    var pots_used := {}
    for k in 120:   # 先等三位服务员都来了再动手（不然做得快，同屏凑不齐三位）
        if g.orders.size() >= 3:
            break
        g.tick(0.5)
    for step in 1200:
        if not g.active:
            break
        most_orders = maxi(most_orders, g.orders.size())
        for i in g.pots.size():
            var pot: Dictionary = g.pots[i]
            if pot.state == "empty":
                var taken := {}
                for q in g.pots:
                    if q.state != "empty":
                        taken["%s:%s" % [q.get("order_id", -1), q.get("dish_index", -1)]] = true
                for pl in g.plates:
                    taken["%s:%s" % [pl.get("order_id", -1), pl.get("dish_index", -1)]] = true
                var picked := false
                for o in g.orders:
                    if picked:
                        break
                    for d in o.dishes.size():
                        if not o.dishes[d].done and not taken.has("%s:%s" % [o.id, d]) and g.choose_order_dish(i, o.id, d):
                            for ing in g.pots[i].required:
                                g.add_ingredient(i, ing)
                            pots_used[i] = true
                            picked = true
                            break
            elif pot.state == "ready":
                if g.serve_pot(i):
                    g.deliver_auto()
            elif pot.state in ["burnt", "invalid"]:
                g.clear_pot(i)
        while not g.plates.is_empty() and g.deliver_auto():
            pass
        g.tick(0.5)
    var guide_off: bool = not is_instance_valid(p.guide)
    p.departures.clear()
    p._process(0.01)
    await process_frame
    var card: Array = p.find_children("*", "Panel", true, false).filter(func(n): return n.get_meta("kitchen_result_card", false))
    check("第 4 关没有引导那行（%s）；过关出结算卡、垫着小游戏的卡片（%d 张）" % [guide_off, card.size()], guide_off and card.size() == 1)
    return [g.won, g.completed, most_orders, pots_used.size()]

func route(label: String) -> void:
    var h = m.hall
    var b = m.backhall
    print("== %s（%s 张桌）" % [label, h.cfg["tables"].size()])
    # 东侧门：55 桌厅的侧门在东墙下半截，从红毯走过去要很久，先站到门里边 90 像素再走进去
    m.hall_side_latched = false
    h.stand_up()
    h.reset_to(h.side_door + Vector2(-90, 0))
    tick(2)
    walk_to(h.side_door)
    for i in 120:
        if m.state == "backhall" and not m.switching:
            break
        await process_frame
    check("%s：东侧门进了后厅（state=%s）" % [label, m.state], m.state == "backhall" and m.cv == b)
    tick(2)
    b.snap_cam()   # 镜头别从上回的位置慢慢挪过来（看「厨房在不在屏幕里」要按刚进来那一眼）
    tick(1)
    # K8（04 挡路）：进后厅厨房在屏幕外，屏幕边有个金色小箭头指着它
    check("%s：进后厅屏幕边有箭头指着厨房（%s）" % [label, b.kitchen_arrow != null and b.kitchen_arrow.visible],
        b.kitchen_arrow != null and b.kitchen_arrow.visible and absf(wrapf(b.kitchen_arrow.rotation - (b.spot_pos("pot") - b.kitchen_arrow.position).angle(), -PI, PI)) < 0.01)
    walk_to(Vector2(1272, 790))
    walk_to(b.spot_pos("pot"))
    tick(1)
    check("%s：走到厨房门口箭头收了" % label, not b.kitchen_arrow.visible and not b.kitchen_hint)
    check("%s：后厅里没有找自己的圈和倒三角（只在宴会厅）" % label, not b.me_ring.visible and not b.me_mark.visible and m.hall.me_marks)
    check("%s：走到大锅出「%s」" % [label, m.backhall_ui.act_btn.text], m.backhall_ui.act_btn.visible and m.backhall_ui.act_btn.text == "穿上围裙 · 学做菜")
    m.backhall_ui._on_act()
    await process_frame
    var p = m.game_host
    check("%s：打开厨房，后厅停住不能走" % label, is_instance_valid(p) and p.has_method("_render") and not b.walking_enabled)
    var coins0: int = m.games_save.coins
    var played: bool = await play_one(p)
    await process_frame
    check("%s：玩一局交了一道菜（%s），金币 %d → %d" % [label, played, coins0, m.games_save.coins], played and p.rules.completed == 1 and m.games_save.coins == coins0 + 3)
    var coins1: int = m.games_save.coins
    var three: Array = await play_three(p)
    check("%s：三人三锅局（第 4 关）打到过关 %s，交了 %d 道，同屏最多 %d 位服务员、用了 %d 口锅，金币 %d → %d" % [label, three[0], three[1], three[2], three[3], coins1, m.games_save.coins],
        three[0] and three[2] == 3 and three[3] == 3 and m.games_save.coins > coins1)
    var local: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(m.games_save.local_path))
    check("%s：金币进了钱包——本机存档 %s、电脑假服务端 %s" % [label, local.get("coins"), m.cloud.fake_mine.get("coins")],
        int(local.get("coins", -1)) == m.games_save.coins and int(m.cloud.fake_mine.get("coins", -1)) == m.games_save.coins and not m.games_save.dirty)
    tick(2)
    check("%s：顶上金币显示「%s」" % [label, m.coins_chip.text], m.coins_chip.text == "%d 金" % m.games_save.coins)
    # 开着厨房来一张干杯插图：宴会厅小游戏是排队、关了接着放
    m.toast_queue.clear()
    m._play_toast(0, 1, "厨房里来的插图")
    await process_frame
    var queued: bool = not is_instance_valid(m.toast_scene) and m.toast_queue.size() >= 1
    p._close()
    await process_frame
    await process_frame
    var replayed: bool = is_instance_valid(m.toast_scene)
    print("    记一条：开着厨房来的插图 排队 %s、关了厨房接着放 %s（宴会厅小游戏两样都是 true）" % [queued, replayed])
    if is_instance_valid(m.toast_scene):
        m.toast_scene.queue_free()
        m.toast_scene = null
    m.toast_queue.clear()
    check("%s：关了厨房，后厅能走" % label, m.game_host == null and b.walking_enabled)
    walk_to(Vector2(200, 790))
    walk_to(b.spot_pos("to_hall"))
    for i in 120:
        if m.state == "banquet" and not m.switching:
            break
        await process_frame
    check("%s：西口回了宴会厅（state=%s）" % [label, m.state], m.state == "banquet" and m.cv == m.hall)

func run() -> void:
    root.size = Vector2i(540, 960)   # 手机竖屏：看「在不在屏幕里」要按手机那么宽算（无头跑默认窗口宽得多）
    m.cloud.fake_no_news = true
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await process_frame
    m.games_save.local_path = "user://test_kitchen_route_games.json"
    m.court_save.local_path = "user://test_kitchen_route_court.json"
    m.nickname = "小李"
    await m._set_hall55(false)   # 03 10/2：第一遍标「第 44 版厅」，第 52 版起默认 55 桌，得显式切过去
    await m._enter_banquet()
    await create_timer(0.3).timeout
    check("第一遍真是第 44 版厅（%d 张桌）" % m.hall.cfg["tables"].size(), not m.hall.big)
    await route("第 44 版厅")
    await m._set_hall55(true)
    await create_timer(0.5).timeout
    check("切到 55 桌厅", m.hall.big and m.state == "banquet")
    await route("55 桌厅")
    await m._set_hall55(false)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Main.HALL55_FLAG))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_kitchen_route_games.json"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_kitchen_route_court.json"))
    if not had_kitchen_save:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(KITCHEN_SAVE))   # 别给这台电脑留一份厨房存档
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
