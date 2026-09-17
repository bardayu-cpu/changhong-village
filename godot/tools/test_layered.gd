extends SceneTree
## 验收：分层宴会厅（layered_hall.gd）的寻路、摇杆、两个交互点、遮挡前后。无界面跑，只看逻辑。
## 用法：Godot --headless --path . --script res://tools/test_layered.gd

var hall
var hits: Array = []
var started := false

func step(frames: int, stop_on := "") -> void:
    for i in frames:
        hall._process(1.0 / 60.0)
        if stop_on != "" and stop_on in hits:
            return

func _initialize() -> void:
    hall = load("res://scripts/layered_hall.gd").new()
    get_root().add_child(hall)

## 等场景挂进场景树以后（第一帧）再搭、再测
func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    hall.build(2, "测试", SystemFont.new())
    run()
    return false

func run() -> void:
    hall.reached.connect(func(w): hits.append(w))
    var ok := true
    var w: float = hall.cfg["size"][0]
    var h: float = hall.cfg["size"][1]

    # 0. 进场点、新人桌前、门口都能站
    print("0 进场点能站：", hall._free(hall.SPAWN), "  新人 ", hall.COUPLE_SPOT, "  门口 ", hall.door)
    ok = ok and hall._free(hall.SPAWN)

    # 1. 从门口点到新人桌前，应该走到并触发 couple
    hall.reset_to(hall.SPAWN)
    hall.go_to(hall.COUPLE_SPOT)
    print("1 去新人桌：路径 ", hall.path.size(), " 段")
    step(3000, "couple")
    var r1: bool = "couple" in hits
    print("  触发 couple：", r1, "  停在 ", hall.pos)
    ok = ok and r1

    # 2. 出口：arm 之后点门口，应该触发 exit
    hall.arm_exit()
    hall.go_to(hall.door)
    print("2 去门口：路径 ", hall.path.size(), " 段")
    step(3000, "exit")
    var r2: bool = "exit" in hits
    print("  触发 exit：", r2, "  停在 ", hall.pos)
    ok = ok and r2

    # 3. 随机点 60 个地方：能站的都要走到，且一步都不踩进不能走的格子
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var reach := 0
    var tried := 0
    var inside := 0
    for i in 60:
        hall.couple_armed = false
        hall.exit_armed = false
        hall.reset_to(hall.SPAWN)
        var target := Vector2(rng.randf_range(0.0, w), rng.randf_range(0.0, h))
        if not hall._free(target):
            continue
        tried += 1
        hall.go_to(target)
        for f in 2400:
            hall._process(1.0 / 60.0)
            if not hall._free(hall.pos):
                inside += 1
                break
            if hall.path.is_empty():
                break
        if hall.pos.distance_to(target) < 6.0:
            reach += 1
        else:
            print("  没走到 ", target, " 停在 ", hall.pos)
    print("3 随机点：试 ", tried, " 个，走到 ", reach, " 个，走进障碍 ", inside, " 次")
    ok = ok and inside == 0 and reach == tried

    # 4. 摇杆：从门口一直往前推 4 秒，应该沿红毯往里走
    hall.reset_to(hall.SPAWN)
    hall.stick = Vector2(0.0, -1.0)
    step(240)
    hall.stick = Vector2.ZERO
    print("4 摇杆往前 4 秒：从 y=", hall.SPAWN.y, " 走到 y=", snappedf(hall.pos.y, 0.1))
    ok = ok and hall.pos.y < hall.SPAWN.y - 250.0 and hall._free(hall.pos)

    # 5. 摇杆斜推撞桌子：应该贴着桌边滑，不会进桌子
    hall.reset_to(Vector2(600, 700))
    print("  起点在空地上：", hall._free(hall.pos))
    hall.stick = Vector2(-1.0, 0.4).normalized()
    step(180)
    hall.stick = Vector2.ZERO
    print("5 摇杆斜推：停在 ", hall.pos, "  在空地上：", hall._free(hall.pos))
    ok = ok and hall._free(hall.pos)

    # 6. 前后：人站在桌子后面（脚在桌子着地线以上）时，桌子要画在人前面；站到桌子前面，人在前
    var t4: Dictionary = {}
    for o in hall.cfg["occluders"]:
        if String(o["id"]).begins_with("blk_table") or o["id"] == "table_4":
            t4 = o
            break
    if t4.is_empty():
        print("6 场景里没有桌子遮挡块，跳过")
    var foot: float = t4.get("foot", 0.0)
    if not t4.is_empty():
        var tx: float = hall.cfg["size"][0] * 0.29   # 桌子附近的 x（第一张桌在左侧）
        hall.reset_to(Vector2(tx, foot - 150.0))
        hall._process(0.0)
        var behind: bool = hall.player.position.y < foot
        hall.reset_to(Vector2(tx, foot + 30.0))
        hall._process(0.0)
        var front: bool = hall.player.position.y > foot
        print("6 桌子前后：站桌后被挡 ", behind, "  站桌前挡桌 ", front)
        ok = ok and behind and front

    # 7. 人的大小：越往里越小
    var near_h: float = hall._px_h(900.0)
    var far_h: float = hall._px_h(330.0)
    print("7 人高：靠门口 ", snappedf(near_h, 0.1), " 像素，新人桌前 ", snappedf(far_h, 0.1), " 像素")
    if String(hall.cfg.get("mode", "")) == "blocks":
        ok = ok and absf(near_h - far_h) < 0.5   # 斜俯视正交：固定 84，不随远近缩
    else:
        ok = ok and near_h > far_h

    # 8. 席位：拿 enterHall 那个形状的数据画席位，金标要在自己那把椅子上，
    #    走到空椅子旁要冒出「坐这儿」，走到别人坐着的椅子旁不冒
    var data := {
        "me": {"table_id": "T1", "chair_no": 2},
        "tables": [
            {"id": "T1", "seats": [{"openid": "wang", "chair_no": 1}, {"openid": "me", "chair_no": 2}]},
            {"id": "T2", "seats": [{"openid": "li", "chair_no": 4}]},
        ],
        "names": {"wang": {"nick": "老王", "avatar": 1}, "li": {"nick": "小李", "avatar": 5}},
    }
    hall.set_seats(data, "me")
    var tables: Array = hall.cfg.get("tables", [])
    print("8 席位：桌 ", tables.size(), " 张，椅子 ", hall.chairs.size(), " 把，坐了人的 ", hall.seat_taken.size(),
        "，桌牌 ", hall.table_names)
    ok = ok and hall.chairs.size() == tables.size() * 10 and hall.seat_taken.size() == 3
    var mark: Vector2 = hall._my_chair_pos()
    print("  金标位置 ", mark, " 画出来了 ", hall.seat_marker != null)
    ok = ok and mark != Vector2.ZERO and hall.seat_marker != null and hall.seat_marker.position == mark

    var near: Array = []
    hall.chair_near.connect(func(tid, no): near.append([tid, no]))
    # 站到一把空椅子旁边
    var empty_chair: Dictionary = {}
    for c in hall.chairs:
        if not hall.seat_taken.has("%s:%d" % [c["table_id"], c["chair_no"]]):
            empty_chair = c
            break
    hall.near_key = ""
    hall.seat_scan = 1.0
    hall.reset_to(empty_chair["pos"])
    hall._scan_chairs(1.0)
    var offered: bool = near.size() > 0 and near[-1][1] == int(empty_chair["chair_no"])
    print("  走到空椅子 ", empty_chair["table_id"], empty_chair["chair_no"], " 旁：冒出坐这儿 ", offered)
    ok = ok and offered
    # 走远：要收回
    near.clear()
    hall.seat_scan = 1.0
    hall.reset_to(hall.SPAWN)
    hall._scan_chairs(1.0)
    var withdrawn: bool = near.size() > 0 and near[-1][1] == 0
    print("  走开以后收回 ", withdrawn)
    ok = ok and withdrawn
    # 换桌以后金标跟着挪，人也要坐到那把椅子上
    hall.reset_to(hall.SPAWN)
    hall.apply_change("T2", 7, "me")
    print("  换到 T2 第 7 把：金标 ", hall.seat_marker.position, " 该是 ", hall._my_chair_pos())
    ok = ok and hall.seat_marker != null and hall.seat_marker.position == hall._my_chair_pos()
    ok = ok and hall.seat_taken.get("T2:7", "") == "me" and not hall.seat_taken.has("T1:2")

    # 9. 坐下的表现：人吸附到椅位、面朝桌心、停着不动
    var t2: Dictionary = hall._table_cfg("T2")
    var seat_pos: Vector2 = hall.chair_world(t2, 7)
    var center := Vector2(float(t2["x"]), float(t2["y"]))
    print("9 坐下：人在 ", hall.pos, " 椅位 ", seat_pos, " 坐着 ", hall.seated, " 朝向 ", hall.face,
        " 该朝 ", hall._face_for(center - seat_pos))
    ok = ok and hall.seated and hall.pos == seat_pos and hall.face == hall._face_for(center - seat_pos)
    hall.path.clear()
    hall.stick = Vector2.ZERO
    hall._process(1.0 / 60.0)
    print("  站着不动：还在 ", hall.pos, " 还坐着 ", hall.seated)
    ok = ok and hall.seated and hall.pos == seat_pos

    # 10. 推摇杆要站起来，而且落脚点不能在桌子占地里
    hall.stick = Vector2(0.0, 1.0)
    hall._process(1.0 / 60.0)
    hall.stick = Vector2.ZERO
    print("10 推摇杆：起身 ", not hall.seated, " 停在 ", hall.pos, " 在能走的地方 ", hall._free(hall.pos),
        " 起身点 ", hall.seat_stand_spot)
    ok = ok and not hall.seated and hall._free(hall.pos)

    # 11. 坐着时点地面也要站起来，而且走得到目标
    hall.apply_change("T2", 3, "me")
    print("11 再坐下 ", hall.seated, " 在 ", hall.pos)
    ok = ok and hall.seated
    hall.go_to(hall.SPAWN)
    print("  点门口：起身 ", not hall.seated, " 起身后在能走的地方 ", hall._free(hall.pos), " 路 ", hall.path.size(), " 段")
    ok = ok and not hall.seated and hall._free(hall.pos) and not hall.path.is_empty()
    step(3000)
    print("  走到 ", hall.pos, " 目标 ", hall.SPAWN)
    ok = ok and hall.pos.distance_to(hall.SPAWN) < 6.0

    # 12. 坐着时不提「坐这儿」（刚坐下又冒一个按钮，看着像没坐成）；
    #     站起来走近空椅子照旧弹
    near.clear()
    hall.apply_change("T1", 5, "me")
    hall.seat_scan = 1.0
    hall._scan_chairs(1.0)
    print("12 坐着时：坐着 ", hall.seated, " 按钮广播 ", near)
    ok = ok and hall.seated and (near.is_empty() or near[-1][1] == 0)
    var free_chair: Dictionary = {}
    for c in hall.chairs:
        if not hall.seat_taken.has("%s:%d" % [c["table_id"], c["chair_no"]]):
            free_chair = c
            break
    hall.go_to(free_chair["pos"])   # 点地面：起身走过去
    step(3000)
    near.clear()
    hall.seat_scan = 1.0
    hall.near_key = ""
    hall._scan_chairs(1.0)
    print("  起身走到空椅子 ", free_chair["table_id"], free_chair["chair_no"], " 旁：", near)
    ok = ok and not hall.seated and near.size() > 0 and near[-1][1] != 0

    # 13. 看人：走到有人坐的椅子旁边发出对方 openid；走远发 ""；自己那把椅子不算（第 22 版，蓝图 3.2）
    var data13 := {
        "me": {"table_id": "T1", "chair_no": 2},
        "tables": [
            {"id": "T1", "seats": [{"openid": "wang", "chair_no": 1}, {"openid": "me", "chair_no": 2}]},
            {"id": "T2", "seats": [{"openid": "li", "chair_no": 4}]},
        ],
        "names": {"wang": {"nick": "老王", "avatar": 1}, "li": {"nick": "小李", "avatar": 5}},
    }
    hall.set_seats(data13, "me")
    var t1cfg: Dictionary = hall._table_cfg("T1")
    var wang_pos: Vector2 = hall.chair_world(t1cfg, 1)
    var my_pos13: Vector2 = hall.chair_world(t1cfg, 2)
    var seen: Array = []
    hall.person_near.connect(func(oid): seen.append(oid))
    # 先归位到远离所有椅子的地方，把 person_near_key 收成已知的 ""（set_seats、上一条测试
    # 留下的位置都可能凑巧已经在谁旁边，不清空基线，下一步「变了才发」会误判成没变）
    hall.reset_to(hall.SPAWN)
    seen.clear()
    hall.reset_to(wang_pos)
    hall._scan_chairs(1.0)
    print("13 走到老王旁边：person_near 发出 ", seen)
    ok = ok and seen.size() > 0 and seen[-1] == "wang"
    seen.clear()
    hall.reset_to(hall.SPAWN)
    hall._scan_chairs(1.0)
    print("  走远：person_near 发出 ", seen)
    ok = ok and seen.size() > 0 and seen[-1] == ""
    seen.clear()
    hall.reset_to(my_pos13)
    hall._scan_chairs(1.0)
    var self_ok := true
    for oid in seen:
        if oid == "me":
            self_ok = false
    print("  走到自己座位旁：person_near 发出 ", seen, "（不该有 me）")
    ok = ok and self_ok

    # 14. 坐在自己椅子上、邻座有人：能发出邻座 openid，同时「坐这儿」不发（第 22 版规则 6）
    var data14 := {
        "me": {"table_id": "T2", "chair_no": 3},
        "tables": [
            {"id": "T2", "seats": [{"openid": "li", "chair_no": 4}, {"openid": "me", "chair_no": 3}]},
        ],
        "names": {"li": {"nick": "小李", "avatar": 5}},
    }
    hall.set_seats(data14, "me")
    hall.apply_change("T2", 3, "me")   # 坐到自己那把椅子上，4 号邻座是小李
    var offers: Array = []
    hall.chair_near.connect(func(tid, no): offers.append(no))
    seen.clear()
    hall.seat_scan = 1.0
    hall._scan_chairs(1.0)
    print("14 坐着、邻座有人：坐着 ", hall.seated, " person_near 发出 ", seen, " 坐这儿广播 ", offers)
    ok = ok and hall.seated and seen.size() > 0 and seen[-1] == "li" and offers.is_empty()

    print("RESULT ", "PASS" if ok else "FAIL")
    quit()
