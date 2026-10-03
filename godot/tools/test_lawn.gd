extends SceneTree
## 验收：罗曼山庄草坪（蓝图 3.4，灰盒，01 9/19 派任务 8）。无界面跑整个 main.gd，云函数走 cloud.gd 的电脑假数据。
## 布局：四个交互点和蓝图一字不差、球 (1100,800)、喜多 (1040,760)（展位 10/3 从西边挪到竖路东边）、孩童区秋千滑梯四个小孩、西北草坪婚礼仪式区（展位，没交互）、四周的树。
## 进出（10/4 方案 C）：喷泉广场西口 ↔ 草坪东边南头的口、后厅厨房后门 ↔ 草坪东边北头的口，到了站的点离出口至少 1 米、不来回弹；草坪北口 ↔ 果园南口。
## 小孩：第一次踢完球、喜多把球放回脚边时喊一句「再踢一个」，每回到草坪喊一次（01 9/20 定）。踢球（只在本机）：第一次走近喜多叼着球跑过来；走到球旁出「踢一脚」；
## 朝人面朝的方向滚 1 秒停住（左右 4 米 192 像素、前后 4 米 128 像素）；滚不出草坪；滚进东西弹回上一格；停了喜多叼回人脚边，
## 喜多被挡住直接出现在球旁；在滚、在叼的时候不出按钮；踢几次都行；不调云函数；离开草坪球和喜多回起始点
## 用法：Godot --headless --path . --script res://tools/test_lawn.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const CourtCopy = preload("res://scripts/court_copy.gd")
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

func tick(n: int) -> void:
    for i in n:
        m.cv._process(DT)
        m._process(DT)

func walk_to(target: Vector2, secs := 20.0) -> void:
    m.cv.go_to(target)
    for i in int(secs / DT):
        tick(1)
        if m.cv.path.is_empty():
            break

## 摆好：球停在 ball_at，人站在 player_at 面朝 face，喜多待在远处，这次来已经迎过（不打岔）
func place(l, ball_at: Vector2, player_at: Vector2, face: String) -> void:
    l.ball_pos = ball_at
    l.ball_state = "rest"
    l.dog_state = "idle"
    l.dog_path.clear()
    l.dog_pos = Vector2(1000, 800)
    l.greeted = true
    l.reset_to(player_at)
    l.face = face
    tick(1)

## 一直推到喜多把球放下、待着（最多 secs 秒）
func until_idle(l, secs := 8.0) -> void:
    for i in int(secs / DT):
        tick(1)
        if l.ball_state == "rest" and l.dog_state == "idle":
            return

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    # 后厅、草坪、湖边、果园开场不搭、第一次进去才搭（main.ensure_canvas，02 10/3）：这里要直接看它们，先搭好
    for cn in ["backhall", "lawn", "lake", "orchard"]:
        m.ensure_canvas(cn)
    await process_frame
    var l = m.lawn
    m.games_save.local_path = "user://test_lawn_games.json"
    m.court_save.local_path = "user://test_lawn_court.json"

    # 1. 布局对蓝图 3.4
    print("1 布局对蓝图 3.4")
    # 10/4 连图（02 E 改）：加了去西餐厨房、南边去儿童乐园、北边去果园 B 三个口；
    # 10/4 方案 C：去后厅、西餐厨房、喷泉广场的口挪到东边北段空当（y 450 往南全是树冠），去果园 B 挪到北边西头
    var want := {"kids": [1300, 520, 70], "to_plaza": [1496, 430, 44], "to_backhall": [1496, 230, 44], "to_orchard": [768, 160, 60],
        "to_wkitchen": [1496, 330, 44], "to_kids": [760, 1000, 44], "to_orchard_b": [140, 172, 50]}
    var same: bool = l.points.size() == 7
    for id in want:
        same = same and l.points.has(id) and l.points[id]["pos"] == Vector2(want[id][0], want[id][1]) and is_equal_approx(float(l.points[id]["r"]), float(want[id][2]))
    check("七个交互点和蓝图一字不差（球那个点跟着球走，半径 %.0f）" % l.BALL_NEAR, same and is_equal_approx(l.BALL_NEAR, 60.0))
    check("球从 (1100,800)、喜多从 (1040,760) 起（展位 10/3：挪到竖路东边空草地，别往椅子里滚）", l.BALL_START == Vector2(1100, 800) and l.DOG_START == Vector2(1040, 760)
        and l.ball_pos == l.BALL_START and l.dog_pos == l.DOG_START)
    var kids_in := 0
    for id in l.npc_nodes:
        var p: Vector2 = (l.npc_nodes[id] as Sprite2D).position
        if str(id).begins_with("kid") and p.x >= 1100 and p.x <= 1500 and p.y >= 250 and p.y <= 620:
            kids_in += 1
    check("孩童区（x 1100～1500，y 250～620）四个小孩（%d；展位 01 E 10/3：LM-KID-01～04）" % kids_in, kids_in == 4)
    # 9/24 起草坪铺了占位底图，秋千、拱门、椅子、树画在图里、不再单独画；这里查布局里有没有它们（它们还在布局里算挡人）
    var ids := {}
    for it in l.cfg.get("items", []):
        ids[str(it.get("id", ""))] = it
    check("秋千、滑梯都在孩童区", ids.has("swing_bar") and ids.has("swing_seat") and ids.has("slide_tower") and ids.has("slide_chute"))
    # 展位（01 E 10/3）：西北是西式草坪婚礼仪式区——大树、圆台（LW-P01）、通道两边矮花丛（LW-P04）、两边各 5 排 × 4 把白椅子（LW-P03）；
    # 花拱门（LW-P02）先不摆，跟仪式台二选一等阿鱼看目录
    var wed_ok: bool = ids.has("wed_tree") and ids.has("wed_stage") and not ids.has("arch_top")
    var chairs := 0
    var hedges := 0
    for id in ids:
        if str(id).begins_with("chair_"):
            chairs += 1
        if str(id).begins_with("hedge_"):
            hedges += 1
    var far_from_points := true
    for id in l.points:
        far_from_points = far_from_points and (l.points[id]["pos"] as Vector2).distance_to(Vector2(420, 412)) > 150.0
    check("西北仪式区：大树圆台、%d 把白椅子、%d 丛矮花，附近没有交互点（只摆位置）" % [chairs, hedges], wed_ok and chairs == 48 and hedges == 10 and far_from_points)
    var trees := 0
    for id in ids:
        if str(id).begins_with("tree_"):
            trees += 1
    check("四周有树（%d 棵）" % trees, trees >= 20)
    for id in l.points:
        var pt: Vector2 = l.points[id]["pos"]
        var path: Array = l.find_path(l.SPAWN, pt)
        var end: Vector2 = path[path.size() - 1] if not path.is_empty() else l.SPAWN
        check("%s 走得到（离点 %.1f，半径 %.0f）" % [id, end.distance_to(pt), l.points[id]["r"]], end.distance_to(pt) < float(l.points[id]["r"]))
    for pair in [[l.arrival_at("to_plaza"), "to_plaza"], [l.arrival_at("to_backhall"), "to_backhall"]]:
        var at: Vector2 = pair[0]
        var gap: float = at.distance_to(l.points[pair[1]]["pos"])
        check("到了站在 %s 离 %s %.0f 像素（至少 48），能站" % [at, pair[1], gap], gap >= 48.0 and l._free(at))

    # 2. 进出：喷泉广场西口 ↔ 草坪西南口（10/4 新总图）；草坪西北口 ↔ 后厅厨房后门；草坪北口 ↔ 果园南口
    print("2 进出")
    m.nickname = "阿花"
    await m._enter_court()
    m.dialog.visible = false
    var c = m.court
    # 10/4 连图起落点照布局算（口往里 70 像素），不再写死
    walk_to(c.spot_pos("to_plaza"))
    var pz = m.plaza
    walk_to(pz.arrival_at("to_lawn"))
    walk_to(pz.spot_pos("to_lawn"))
    check("广场西口进了草坪 state=%s" % m.state, m.state == "lawn" and m.cv == l and l.visible and not pz.visible)
    check("站在东边南头那个口边 %s，朝向没变 %s" % [l.pos, l.face], l.pos == l.arrival_at("to_plaza") and l.face == "left")
    tick(60)
    check("站着 60 帧不弹回广场", m.state == "lawn")
    walk_to(l.spot_pos("to_plaza"))
    check("东边口回到广场，站在西口里边 %s" % pz.pos, m.state == "plaza" and pz.pos == pz.arrival_at("to_lawn"))
    tick(60)
    check("站着 60 帧不弹回草坪", m.state == "plaza")
    walk_to(pz.spot_pos("to_lawn"))
    walk_to(l.arrival_at("to_backhall"))
    walk_to(l.spot_pos("to_backhall"))
    check("东边北头那个口去了后厅，站在厨房后门边 %s" % m.backhall.pos, m.state == "backhall" and m.backhall.pos == m.backhall.arrival_at("to_lawn"))
    tick(60)
    check("站着 60 帧不弹回草坪", m.state == "backhall")
    walk_to(m.backhall.spot_pos("to_lawn"))
    check("厨房后门回到草坪，站在东边北头那个口边 %s" % l.pos, m.state == "lawn" and l.pos == l.arrival_at("to_backhall"))
    tick(60)
    check("站着 60 帧不弹回后厅", m.state == "lawn")
    walk_to(Vector2(768, 330))
    walk_to(l.spot_pos("to_orchard"))
    check("北口去了果园 A，站在 A 南口边 %s" % m.orchard.pos, m.state == "orchard" and m.orchard.pos == m.orchard.arrival_at("to_lawn"))   # 10/4 果园切成 A、B
    tick(60)
    check("站着 60 帧不弹回草坪", m.state == "orchard")
    walk_to(m.orchard.spot_pos("to_lawn"))
    check("南口回到草坪，站在北口边 %s" % l.pos, m.state == "lawn" and l.pos == l.arrival_at("to_orchard"))
    tick(60)
    check("站着 60 帧不弹回果园", m.state == "lawn")

    # 3. 走进孩童区不单独说话（01 9/20 改：小孩那句挪到「踢完球、喜多把球放回脚边」那一刻，见第 4b 条）
    print("3 走进孩童区")
    m.dialog.visible = false
    walk_to(Vector2(1180, 560))
    walk_to(l.spot_pos("kids"))
    check("走进孩童区不说话", not m.dialog.visible)

    # 4. 第一次走近：喜多叼着球跑过来放在脚边，出「踢一脚」
    print("4 喜多迎")
    var ui = m.lawn_ui
    l.reset_ball()   # 前面走来走去可能已经路过球旁；这里从头来：人在孩童区，离球远
    check("人离球远（%.0f 像素），喜多还没迎" % l.pos.distance_to(l.ball_pos), l.pos.distance_to(l.ball_pos) > l.GREET_R and not l.greeted)
    m.cv.go_to(Vector2(1000, 760))
    var saw_held := false
    for i in int(20.0 / DT):
        tick(1)
        if l.ball_state == "held":
            saw_held = true
        if l.path.is_empty() and l.greeted and l.ball_state == "rest" and l.dog_state == "idle":
            break
    check("喜多叼着球跑过来（中途叼着）", l.greeted and saw_held)
    check("球放在脚边（离人 %.0f 像素）" % l.ball_pos.distance_to(l.pos), l.ball_pos.distance_to(l.pos) < l.BALL_NEAR and l.ball_state == "rest")
    check("出「踢一脚」", ui.act_btn.visible and ui.act_btn.text == "踢一脚")

    # 4b. 小孩那句（蓝图 3.4 用户故事的顺序，01 9/20 定）：第一次踢完、喜多把球放回脚边那一刻喊；
    #     再踢不重复；出草坪再回来又能喊一次
    print("4b 踢完球小孩喊")
    m.dialog.visible = false
    var tok: int = m.say_token
    check("喜多迎完（没踢球）不喊", not m.dialog.visible and m.say_token == tok)
    place(l, Vector2(1000, 760), Vector2(970, 760), "right")
    l.kick()
    until_idle(l)
    check("%s：%s" % [m.dialog_who.text, m.dialog_text.text],
        m.dialog.visible and m.dialog_who.text == "小孩" and m.dialog_text.text == "再踢一个" and m.say_token > tok)
    tok = m.say_token
    place(l, Vector2(1000, 760), Vector2(970, 760), "right")
    l.kick()
    until_idle(l)
    check("再踢不重复喊", m.say_token == tok)
    walk_to(l.spot_pos("to_plaza"))
    check("先回广场", m.state == "plaza")
    walk_to(pz.spot_pos("to_lawn"))
    check("又进草坪", m.state == "lawn")
    m.dialog.visible = false
    tok = m.say_token
    place(l, Vector2(1000, 760), Vector2(970, 760), "right")
    l.kick()
    until_idle(l)
    check("这回来又喊一次：%s" % m.dialog_text.text, m.dialog.visible and m.dialog_text.text == "再踢一个" and m.say_token > tok)

    # 5. 朝人面朝的方向滚 1 秒停住：左右 4 米（192 像素）、前后 4 米（128 像素）；在滚、在叼的时候不出按钮；叼回脚边又出
    print("5 四个方向")
    var dirs := {"right": Vector2(192, 0), "down": Vector2(0, 128), "left": Vector2(-192, 0), "up": Vector2(0, -128)}
    for f in dirs:
        var start := Vector2(1000, 700)   # 展位（10/3）西边摆了观礼椅子，往左 4 米会撞上，挪到中间空草地上踢
        place(l, start, start - (dirs[f] as Vector2).normalized() * 30.0, f)
        check("%s：能踢、按钮出着" % f, l.can_kick() and ui.act_btn.visible)
        ui._on_act()
        tick(1)
        check("%s：滚起来按钮就收" % f, l.ball_state == "roll" and not ui.act_btn.visible)
        tick(int(0.9 / DT))
        check("%s：0.9 秒还在滚" % f, l.ball_state == "roll")
        tick(int(0.15 / DT))
        var moved: Vector2 = l.ball_pos - start
        check("%s：1 秒停住，滚了 %s（要 %s）" % [f, moved, dirs[f]], l.ball_state != "roll" and moved.distance_to(dirs[f]) < 3.0 and not l.bounced)
        check("%s：喜多去叼了" % f, l.dog_state != "idle")
        var held_once := false
        for i in int(8.0 / DT):
            tick(1)
            if l.ball_state == "held":
                held_once = true
                if ui.act_btn.visible:
                    break
            if l.ball_state == "rest" and l.dog_state == "idle":
                break
        check("%s：叼回来放在脚边（离人 %.0f 像素），按钮又出" % [f, l.ball_pos.distance_to(l.pos)],
            held_once and l.ball_state == "rest" and l.dog_state == "idle" and l.ball_pos.distance_to(l.pos) < l.BALL_NEAR and ui.act_btn.visible)

    # 6. 滚不出草坪：靠南边、西边往外踢，停在草坪里
    print("6 滚不出草坪")
    place(l, Vector2(570, 972), Vector2(570, 944), "down")
    l.kick()
    tick(int(1.1 / DT))
    check("往南踢：停在 %s，还在草坪里、能站" % l.ball_pos, l.ball_pos.y < 996.0 and l._free(l.ball_pos) and l.bounced)
    until_idle(l)
    place(l, Vector2(60, 640), Vector2(90, 640), "left")
    l.kick()
    tick(int(1.1 / DT))
    check("往西踢：停在 %s，还在草坪里、能站" % l.ball_pos, l.ball_pos.x > 16.0 and l._free(l.ball_pos) and l.bounced)
    until_idle(l)

    # 7. 滚进东西的占地弹回上一格：白椅子那一列下面往上踢（展位第二版：椅子在通道西边 x 300 那一列，最后一排脚在 y 696）
    print("7 弹回上一格")
    var under := Vector2(300, 780)
    place(l, under, under + Vector2(0, 28), "up")
    l.kick()
    tick(int(1.1 / DT))
    var cell: float = l.cell
    check("撞到白椅子停在 %s：这格能站、正好是格子中心、往上一格就挡住" % l.ball_pos,
        l.bounced and l._free(l.ball_pos) and l.ball_pos == l._cell_pos(l._cell_of(l.ball_pos)) and not l._free(l.ball_pos + Vector2(0, -cell))
        and l.ball_pos.y < under.y)
    until_idle(l)

    # 8. 喜多被挡住：去叼球的路不通，直接出现在球旁；回来的路不通，直接出现在人跟前；照样把球放回脚边
    print("8 喜多被挡")
    place(l, Vector2(980, 600), Vector2(980, 680), "up")   # 球离被围起来的喜多远一点（展位 10/3 起这几步都挪到竖路东边）
    l.dog_pos = Vector2(1000, 800)
    var ring := wall_around(l, Vector2(1000, 800))   # 把喜多围起来：去叼球的路不通
    var jumped0: int = l.dog_jumped
    l._fetch()
    check("去叼球走不过去：直接出现在球旁（离球 %.0f 像素），叼起来了" % l.dog_pos.distance_to(Vector2(980, 600)),
        l.dog_jumped == jumped0 + 1 and l.dog_pos.distance_to(Vector2(980, 600)) < 30.0 and l.ball_state == "held")
    unwall(l, ring)
    until_idle(l)
    check("跑回来放在脚边（离人 %.0f 像素）" % l.ball_pos.distance_to(l.pos), l.ball_state == "rest" and l.dog_state == "idle" and l.ball_pos.distance_to(l.pos) < l.BALL_NEAR)
    place(l, Vector2(1000, 760), Vector2(1140, 760), "right")
    l.dog_pos = Vector2(980, 760)
    ring = wall_around(l, Vector2(1140, 760), 6)       # 把人连同脚前那块围起来：回来的路不通
    jumped0 = l.dog_jumped
    l._fetch()
    until_idle(l)
    unwall(l, ring)
    check("回来的路不通：直接出现在人跟前放下（离人 %.0f 像素）" % l.ball_pos.distance_to(l.pos),
        l.dog_jumped >= jumped0 + 1 and l.ball_state == "rest" and l.ball_pos.distance_to(l.pos) < l.BALL_NEAR)

    # 9. 踢几次都行，只在本机：连踢 6 脚，一次云函数都不调
    print("9 连踢、不上服务器")
    var calls := []
    var real_cloud = m.cloud
    var spy := SpyCloud.new()
    spy.calls = calls
    m.cloud = spy
    place(l, Vector2(1000, 760), Vector2(970, 760), "right")
    var k0: int = l.kicks
    var all_kicked := true
    for n in 6:
        if not l.can_kick():
            all_kicked = false
            break
        l.face = "right" if n % 2 == 0 else "left"
        l.kick()
        until_idle(l)
    m.cloud = real_cloud
    spy.free()
    check("连踢 6 脚都踢得出去（%d 脚）" % (l.kicks - k0), all_kicked and l.kicks - k0 == 6)
    check("一次云函数都没调 %s" % [calls], calls.is_empty())

    # 10. 离开草坪：球和喜多回起始点；回来又从起始点开始，喜多再迎一次
    print("10 离开回起始点")
    place(l, Vector2(1000, 760), Vector2(970, 760), "right")
    l.kick()
    tick(int(0.5 / DT))
    check("走的时候球在滚", l.ball_state == "roll")
    m._switch_canvas("court")
    check("回到迎宾院", m.state == "court")
    check("球回 (1100,800)、喜多回 (1040,760)、都停着", l.ball_pos == l.BALL_START and l.dog_pos == l.DOG_START
        and l.ball_state == "rest" and l.dog_state == "idle" and not l.greeted)
    walk_to(c.spot_pos("to_plaza"))
    walk_to(pz.spot_pos("to_lawn"))
    check("回来球还在起始点", m.state == "lawn" and l.ball_pos == l.BALL_START)

    DirAccess.remove_absolute("user://test_lawn_games.json")
    DirAccess.remove_absolute("user://test_lawn_court.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)

## 在某点四周围一圈走不通的格子（只挡寻路，不改能不能站），返回围上的格子好拆
func wall_around(l, at: Vector2, r := 3) -> Array[Vector2i]:
    var cc: Vector2i = l._cell_of(at)
    var ring: Array[Vector2i] = []
    for dj in range(-r, r + 1):
        for di in range(-r, r + 1):
            if maxi(absi(di), absi(dj)) == r:
                var q := cc + Vector2i(di, dj)
                if l.nav.is_in_boundsv(q) and not l.nav.is_point_solid(q):
                    ring.append(q)
                    l.nav.set_point_solid(q, true)
    return ring

func unwall(l, ring: Array[Vector2i]) -> void:
    for q in ring:
        l.nav.set_point_solid(q, false)

## 只记下调了哪个云函数、不回话
class SpyCloud extends Node:
    var calls: Array
    func call_fn(name: String, _data: Dictionary, _cb: Callable, _timeout := 12.0) -> void:
        calls.append(name)
    func openid() -> String:
        return "fake_me"
