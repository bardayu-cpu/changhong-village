extends SceneTree
## 验收：宴会厅的席面菜单 + 添一道菜（阿鱼 9/20 定的两样，01 转的先后里排第一）。
## 无界面跑整个 main.gd，云函数走 cloud.gd 的电脑假数据。
## 菜单：两套都是婚礼当天真实的菜（正席 19 道、晚宴 18 道，阿鱼 9/20 认过的定稿，代码里一个字都不许改）；
##       按手机真实时间切，点一道菜简介当场展开、不切场景；简介底下「学做这道」等厨房做完再接。
## 添菜：坐在自己桌上才有，40 金一道，服务员真端过来，摆到离开宴会厅为止，不累计、不进存档；
##       一开始就有三道能添（不打连连看也添得了——03 在《添菜50金-核算》第四节点的那个漏）；没有任何买金币的口子。
## 拨时间：menu.fake_hour 设成 0～23 当成那个点（不用真等到晚上）
## 用法：Godot --headless --path . --script res://tools/test_banquet_menu.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const Menu = preload("res://scripts/banquet_menu.gd")
const DT := 1.0 / 60.0

var m
var started := false
var ok := true

func _initialize() -> void:
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

## 手动推厅里那层的时间（别让引擎再多推一遍）
func life_secs(life, secs: float, step := 0.05) -> void:
    for i in int(secs / step):
        life._process(step)

func enter() -> void:
    await m._enter_banquet()
    await frames(3)

## 坐到某张桌的某把椅子上
func sit(h, tid: String, no: int) -> void:
    var t: Dictionary = h._table_cfg(tid)
    var c: Vector2 = h.chair_world(t, no)
    h.reset_to(h._stand_spot(c, h._seat_center(t)))
    await frames(1)
    m.near_seat_info = {"table_id": tid, "chair_no": no}
    m.sit_target = {"table_id": tid, "chair_no": no}
    m.sit_confirming = true
    m._on_sit_pressed()
    await frames(2)

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.games_save.local_path = "user://test_banquet_menu_games.json"
    var bu = m.banquet_ui
    var menu = bu.menu

    # ---------- 1. 两套菜名：阿鱼认过的定稿，一字不差 ----------
    print("1 两套菜单就是单子上的菜")
    var mid: Array = menu.dishes("midday")
    var eve: Array = menu.dishes("evening")
    check("正席 19 道（手写单 A-0006799）", mid.size() == 19)
    check("晚宴 18 道（印刷单 10 人 18 道）", eve.size() == 18)
    check("正席第 1 道韭香蹄花、第 19 道水果", str(mid[0]) == "韭香蹄花" and str(mid[18]) == "水果")
    check("正席第 8 道养生鲍鱼盅（位上）", str(mid[7]) == "养生鲍鱼盅（位上）")
    check("正席第 11 道天赐良缘网红参", str(mid[10]) == "天赐良缘网红参")
    check("晚宴第 1 道白宰鸡、末道特级冬菜海鲜汤在里面", str(eve[0]) == "白宰鸡" and eve.has("特级冬菜海鲜汤"))
    var uniq: Array = []
    for n in mid + eve:
        if not uniq.has(str(n)):
            uniq.append(str(n))
    check("两套去重一共 33 道（白宰鸡、炝拌鹿茸菌、一品香碗、水果各重一次）", uniq.size() == 33)
    var dup := 0
    for n in ["白宰鸡", "炝拌鹿茸菌", "一品香碗", "水果"]:
        if mid.has(n) and eve.has(n):
            dup += 1
    check("重样的就是那 4 道", dup == 4)
    var shown_text := ""
    for n in mid + eve:
        shown_text += str(n) + menu.intro(str(n))
    check("单子上的人数、价格、单号没进游戏（阿鱼 9/20 定；json 里 source 那几行是出处，不显示）",
        not shown_text.contains("886") and not shown_text.contains("768") and not shown_text.contains("0006799") and not shown_text.contains("10 人"))

    # ---------- 2. 按真实时间切 ----------
    print("2 中午正席、晚上晚宴")
    var want := {12: "midday", 13: "midday", 17: "midday", 18: "evening", 20: "evening", 23: "evening", 0: "evening", 5: "evening", 11: "evening"}
    var switched := true
    for h in want:
        menu.fake_hour = h
        if menu.menu_key() != want[h]:
            switched = false
            print("    %d 点该是 %s，实际 %s" % [h, want[h], menu.menu_key()])
    check("九个钟点都切对了（阿鱼 9/20 定：12:00～18:00 正席，其余晚宴，中间不留空当）", switched)
    menu.fake_hour = 12
    check("12 点面板头上写「中午 · 正席」", menu.line("head_midday") == "中午 · 正席" and menu.title() == "正席")
    menu.fake_hour = 20
    check("20 点是「晚上 · 晚宴」", menu.title() == "晚宴")

    # 2b. 固定 UTC+8，不跟设备时区走（阿鱼 9/20 定）。
    # 用真实纪元的量级拨时间（小数字往回拨会成负数，钟点全乱）
    print("2b 固定 UTC+8，设备时区改了也不变")
    menu.fake_hour = -1
    check("配置里写着 UTC+8", menu.tz_offset_hours() == 8)
    # 2026-09-20 04:00:00 UTC = UTC+8 的 12:00:00 整
    var noon8 := 1789876799.0    # UTC+8 的 2026-09-20 11:59:59（真实纪元量级）
    var cases := {
        noon8: ["evening", 11],          # 11:59:59 还是晚宴
        noon8 + 1.0: ["midday", 12],     # 12:00:00 切正席
        noon8 + 6.0 * 3600.0: ["midday", 17],       # 17:59:59 还是正席
        noon8 + 6.0 * 3600.0 + 1.0: ["evening", 18] # 18:00:00 切晚宴
    }
    var edges := true
    for t in cases:
        menu.fake_now = t
        var want_key: String = str(cases[t][0])
        var want_h: int = int(cases[t][1])
        if menu.hour_now() != want_h or menu.menu_key() != want_key:
            edges = false
            print("    %d 该是 %d 点 %s，实际 %d 点 %s" % [int(t), want_h, want_key, menu.hour_now(), menu.menu_key()])
    check("四个边界都准（11:59:59 / 12:00:00 / 17:59:59 / 18:00:00）", edges)
    # 同一个真实瞬间，设备时区是什么都算出同一个钟点：钟点只由纪元秒 + 8 小时决定，
    # 不经过任何读设备时区的接口（这份源码里不许出现 get_datetime_dict_from_system）
    var src8 := FileAccess.get_file_as_string("res://scripts/banquet_menu.gd")
    check("源码不读设备时区（没有 get_datetime_dict_from_system）", not src8.contains("get_datetime_dict_from_system"))
    var h_utc: int = int(Time.get_datetime_dict_from_unix_time(int(noon8 + 1.0) + 8 * 3600)["hour"])
    menu.fake_now = noon8 + 1.0
    check("自己按 UTC 加 8 小时算，和代码一个结果（%d 点）" % h_utc, menu.hour_now() == h_utc and h_utc == 12)
    menu.fake_now = -1.0

    # ---------- 3. 简介：有把握的写了，酒店自己起名的留「【待补】」 ----------
    print("3 简介")
    check("咸烧白有话", menu.intro("咸烧白") != "")
    check("金牌玉女瓜没瞎猜，是空的（界面显示【待补】）", menu.intro("金牌玉女瓜") == "")
    check("天赐良缘网红参同上", menu.intro("天赐良缘网红参") == "")
    var todo := 0
    for n in uniq:
        if menu.intro(str(n)) == "":
            todo += 1
    check("33 道里只有那 2 道没写（%d 道）" % todo, todo == 2)
    check("【待补】那句在 json 里", menu.line("intro_todo") == "【待补】")

    # ---------- 4. 进厅：右上角那块牌子 ----------
    print("4 席面菜单那块牌子")
    m.nickname = "阿花"
    await enter()
    await frames(2)
    m._process(DT)
    check("在宴会厅里牌子露出来", bu.chip.visible)
    check("牌子上写「席面菜单」", bu.chip.text == "席面菜单")
    menu.fake_hour = 12
    bu.open_menu()
    check("点开面板", bu.panel_open())
    check("面板开着人走不了", not m.hall.walking_enabled)
    m._process(DT)
    check("面板开着牌子让开", not bu.chip.visible)
    check("头上是中午那套、19 道", bu.head.text == "中午 · 正席" and bu.sub.text == "今天席上的 19 道菜")
    var rows: int = bu.list_box.get_child_count()
    check("列表 19 行（还没点开哪道）", rows == 19)

    # ---------- 5. 点一道菜：简介当场展开，不切场景 ----------
    print("5 点菜看简介")
    var where: String = m.state
    bu._tap_dish("咸烧白")
    check("展开了简介和「学做这道」（19 + 2 行）", bu.list_box.get_child_count() == 21)
    check("没切场景，人还在宴会厅", m.state == where and where == "banquet")
    bu._tap_dish("咸烧白")
    check("再点一下收起来", bu.list_box.get_child_count() == 19)
    bu._tap_dish("金牌玉女瓜")
    var shown := ""
    for c in bu.list_box.get_children():
        if c is Label and str((c as Label).text).contains("待补"):
            shown = (c as Label).text
    check("没写简介的那道显示【待补】：%s" % shown, shown != "")
    bu._learn("咸烧白")
    check("「学做这道」：厨房还没做，顶一句话", m.note.text == "厨房还没开火 等等再来")
    check("点完面板收起来", not bu.panel_open())
    check("人又能走了", m.hall.walking_enabled)

    # ---------- 6. 添一道菜：没坐着 ----------
    print("6 添一道菜：先坐下")
    m.games_save.coins = 200
    m._refresh_seat_buttons()
    check("没坐着时底下没有「添一道菜」", not m.add_dish_btn.visible)
    bu.open_add()
    check("面板上「添一道菜（40 金一道）」", bu.head.text == "添一道菜（40 金一道）")
    bu._tap_add("豆腐脑")
    check("没坐着点了：先坐下 再添菜", m.note.text == "先坐下 再添菜")
    check("钱没扣", m.games_save.coins == 200)

    # ---------- 7. 一开始就有三道能添（不打连连看也添得了） ----------
    print("7 能添哪几道")
    m.games_save.dishes = []
    var can0: Array = menu.addable(load("res://scripts/games/game_config.gd").dishes(), m.games_save.dishes)
    check("一关没打也有 3 道：%s" % [can0], can0 == ["豆腐脑", "叶儿粑", "冰粉"])
    m.games_save.dishes = [0, 1]   # 连连看解了跷脚牛肉、甜皮鸭
    var can2: Array = menu.addable(load("res://scripts/games/game_config.gd").dishes(), m.games_save.dishes)
    check("解锁两道以后有 5 道：%s" % [can2], can2.size() == 5 and can2.has("跷脚牛肉") and can2.has("甜皮鸭"))
    check("解锁过的不重复进表", can2.count("豆腐脑") == 1)
    m.games_save.dishes = [3]      # 3 号就是豆腐脑，本来就在 always 里
    var can3: Array = menu.addable(load("res://scripts/games/game_config.gd").dishes(), m.games_save.dishes)
    check("解锁到本来就有的那道，不会多一行：%s" % [can3], can3.size() == 3)
    m.games_save.dishes = []

    # ---------- 8. 坐下添菜：扣钱、服务员端过来 ----------
    print("8 坐下添一道菜")
    var h = m.hall
    var life = h.life
    life.set_process(false)
    await sit(h, "T3", 5)
    check("坐在 T3 5 号", str(h.my_seat.get("table_id", "")) == "T3" and h.seated)
    m.near_table_id = "T3"
    m._refresh_seat_buttons()
    check("底下出「添一道菜」", m.add_dish_btn.visible and m.add_dish_btn.text == "添一道菜")
    var slots: Array = []
    for b in [m.person_btn, m.book_btn, m.play_btn, m.add_dish_btn, m.sit_btn]:
        if b.visible:
            slots.append(b)
    var overlap := false
    for i in range(1, slots.size()):
        if slots[i].offset_left < slots[i - 1].offset_right:
            overlap = true
    var in_screen := true
    for b in slots:
        in_screen = in_screen and b.offset_left >= -270.0 and b.offset_right <= 270.0
    check("底下 %d 个按钮不重叠、没出屏幕" % slots.size(), not overlap and in_screen)
    m.games_save.coins = 100
    bu.open_add()
    bu._tap_add("豆腐脑")
    check("扣了 40，手上剩 60", m.games_save.coins == 60)
    check("顶部：%s" % m.note.text, m.note.text == "添了一道豆腐脑 马上端来")
    check("这一单记下了（服务员当场调过来了）", life.ordered_total("T3") == 1 and life.ordered_count("T3") == 0)
    # 门里待着的服务员是藏起来的，被调出来接单必须先现身，不然一路隐身走过去、
    # 菜像凭空出现在桌上（03 9/20 报的）
    var carriers := 0
    var hidden := 0
    for w in life.waiters:
        if w.order != "":
            carriers += 1
            if not w.node.visible:
                hidden += 1
            if w.pos.distance_to(life.door) > 4.0 and w.path.is_empty():
                hidden += 1   # 既不在门口又没路可走：这趟没真派出去
    check("接单的服务员看得见、有路可走（%d 个在端，%d 个不对劲）" % [carriers, hidden], hidden == 0)
    life_secs(life, 5.0)
    check("5 秒内菜就端到了", life.ordered_count("T3") == 1)
    var mine: Dictionary = {}
    for dd in life.dishes:
        if bool(dd.get("keep", false)):
            mine = dd
    check("是添的那道、放在 T3、菜名挂出来了", str(mine.get("table", "")) == "T3" and mine.get("tag") != null)
    check("菜名写的是豆腐脑", mine.get("tag") != null and (mine["tag"] as Label).text == "豆腐脑")
    life_secs(life, 8.0)
    check("菜名显示几秒就收（盘子还在）", mine.get("tag") == null and life.ordered_count("T3") == 1)

    # ---------- 9. 添的菜不淡出；服务员自己上的菜会撤 ----------
    print("9 添的菜摆着不撤")
    var before: int = life.dishes.size()
    life._place_dish("T3", Vector2(h._table_cfg("T3")["x"], h._table_cfg("T3")["y"]) + Vector2(40, 0))
    check("服务员另上了一盘", life.dishes.size() == before + 1)
    var served: Dictionary = life.dishes[-1]
    var served_spr: Sprite2D = served["spr"]
    life_secs(life, 60.0)
    check("那一盘 60 秒后撤了", not is_instance_valid(served_spr) or not life.dishes.has(served))
    check("我添的那道还在", life.ordered_count("T3") == 1)

    # ---------- 10. 钱不够、桌上满了 ----------
    print("10 两种添不了的情况")
    m.games_save.coins = 25
    bu.open_add()
    bu._tap_add("叶儿粑")
    check("钱不够：%s" % m.note.text, m.note.text == "还差 15 金 去玩两把挣点")
    check("钱一分没扣", m.games_save.coins == 25)
    m.games_save.coins = 1000
    for i in 3:
        bu.open_add()
        bu._tap_add("冰粉")
        life_secs(life, 15.0)
    check("桌上满 4 道", life.ordered_count("T3") == 4)
    var coins_before: int = m.games_save.coins
    bu.open_add()
    bu._tap_add("冰粉")
    check("第 5 道：%s" % m.note.text, m.note.text == "桌上摆满了 先吃")
    check("没扣钱", m.games_save.coins == coins_before)

    # 连点绕不过上限（03 9/20 测出来的：服务员走过去那几秒里一直点，上了 6 道）。
    # 判满要连「还在路上的」一起数，不然只数桌上的就漏了
    print("10b 连点 6 次也只上得了 4 道")
    life.clear_orders()
    m.games_save.coins = 1000
    var paid_before: int = m.games_save.coins
    var got := 0
    for i in 6:
        bu.open_add()
        bu._tap_add("冰粉")
        life_secs(life, 1.0)   # 每次只隔 1 秒，服务员还在路上
    check("六次只成了 4 次（扣 160 金）", paid_before - m.games_save.coins == 160)
    check("最后一次报的是：%s" % m.note.text, m.note.text == "桌上摆满了 先吃")
    check("摆上的 + 在路上的一共 4 道", life.ordered_total("T3") == 4)
    life_secs(life, 40.0)
    check("等服务员都走到，桌上正好 4 道", life.ordered_count("T3") == 4 and life.ordered_total("T3") == 4)

    # ---------- 11. 没服务员也得把菜端上（钱不能白花） ----------
    print("11 兜底")
    life.clear_orders()
    var keep_waiters: Array = life.waiters.duplicate()
    life.waiters.clear()
    m.games_save.coins = 100
    bu.open_add()
    bu._tap_add("豆腐脑")
    check("扣了钱", m.games_save.coins == 60)
    life_secs(life, 3.0)
    check("3 秒还没到（服务员都不在）", life.ordered_count("T3") == 0)
    life_secs(life, 11.0)
    check("等到头自己摆上桌了", life.ordered_count("T3") == 1)
    life.waiters = keep_waiters

    # ---------- 12. 离开宴会厅：添的菜清掉 ----------
    print("12 出厅")
    m._goto("court")
    await frames(2)
    check("添的菜清掉了", life.ordered_count("T3") == 0 and life.orders.is_empty())
    check("牌子、面板都收了", not bu.chip.visible and not bu.panel_open())
    check("底下的按钮也收了", not m.add_dish_btn.visible)
    check("金币不退、也不累计（花掉就是花掉）", m.games_save.coins == 60)

    # ---------- 13. 没有买金币、加速的口子（照第 28 版验收清单第 15 条） ----------
    print("13 没有买金币的口子")
    var src := ""
    for f in ["res://scripts/banquet_ui.gd", "res://scripts/banquet_menu.gd", "res://assets/banquet/menu.json"]:
        src += FileAccess.get_file_as_string(f)
    var bad := ""
    for w in ["充值", "内购", "买金币", "purchase", "recharge", "iap", "add_coins", "give_coins", "free_coins"]:
        if src.to_lower().contains(w.to_lower()):
            bad += w + " "
    check("源码里没有买币、充值的字眼（%s）" % ("没有" if bad == "" else bad), bad == "")
    check("加钱只有一处：端不过去时原样退回", src.count("games_save.earn") == 1)

    print("RESULT ", "PASS" if ok else "FAIL")
    quit()
