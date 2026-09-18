extends SceneTree
## 验收：厅里的热闹（hall_life.gd，阿鱼 9/18）。无界面跑，只看逻辑：
## NPC 宾客给真人让座、NPC 的椅子不出「坐这儿」也点不开；服务员一直走在能走的地方、会上菜也会出门再进来；
## 乐队、贺礼、彩带、灯笼光都摆出来了；整桌会举杯
## 用法：Godot --headless --path . --script res://tools/test_life.gd

var hall
var started := false

func _initialize() -> void:
    hall = load("res://scripts/layered_hall.gd").new()
    get_root().add_child(hall)

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    hall.build(2, "测试", SystemFont.new())
    run()
    return false

func run() -> void:
    var ok := true
    var life = hall.life
    life.set_process(false)   # 下面手动推时间，别让引擎再多推一遍
    var plan: Dictionary = life.conf["npc_tables"]

    # 1. 没有真人时，NPC 数 = 计划的总数
    var want := 0
    for k in plan: want += int(plan[k])
    hall.set_seats({"tables": [], "me": {"table_id": "", "chair_no": 0}, "names": {}}, "me")
    print("1 NPC 宾客：计划 ", want, " 个，摆了 ", life.guests.size(), " 个，占椅 ", life.npc_taken.size())
    ok = ok and life.guests.size() == want and life.npc_taken.size() == want

    # 2. 真人坐到 NPC 的椅子上：那把的 NPC 不画、也不算 NPC 占着
    var some_key: String = life.npc_taken.keys()[0]
    var tid := some_key.split(":")[0]
    var no := int(some_key.split(":")[1])
    var data := {"tables": [{"id": tid, "seats": [{"openid": "wang", "chair_no": no, "sat_at": 1}]}],
        "me": {"table_id": "", "chair_no": 0}, "names": {"wang": {"nick": "老王", "avatar": 1}}}
    hall.set_seats(data, "me")
    print("2 老王坐 ", some_key, "：NPC 还剩 ", life.guests.size(), " 个，这把还算 NPC 的 ", life.npc_taken.has(some_key))
    ok = ok and life.guests.size() == want - 1 and not life.npc_taken.has(some_key)

    # 3. 走到 NPC 坐着的椅子旁：不出「坐这儿」，也不出人名（点不开）
    var full_tables: Array = []
    for k in plan: full_tables.append({"id": k, "seats": []})
    hall.set_seats({"tables": full_tables, "me": {"table_id": "", "chair_no": 0}, "names": {}}, "me")
    var near_hits: Array = []
    var person_hits: Array = []
    hall.chair_near.connect(func(t, n): near_hits.append("%s:%d" % [t, n]))
    hall.person_near.connect(func(p): person_hits.append(p))
    var bad := 0
    for key in life.npc_taken.keys():
        var tc: Dictionary = hall._table_cfg(key.split(":")[0])
        var at: Vector2 = hall.chair_world(tc, int(key.split(":")[1]))
        hall.reset_to(at)
        if key in near_hits:
            bad += 1
    var real_people := person_hits.filter(func(p): return p != "")
    print("3 走遍 NPC 的椅子：冒出坐这儿 ", bad, " 次，冒出人名 ", real_people.size(), " 次")
    ok = ok and bad == 0 and real_people.is_empty()
    # NPC 桌上的空椅子照样能坐
    var free_key := ""
    for c in hall.chairs:
        var key: String = "%s:%d" % [c["table_id"], c["chair_no"]]
        if plan.has(c["table_id"]) and not life.npc_taken.has(key):
            free_key = key
            hall.reset_to(c["pos"])
            break
    print("  NPC 桌上的空椅子 ", free_key, "：冒出坐这儿 ", free_key in near_hits)
    ok = ok and free_key != "" and free_key in near_hits

    # 4. 服务员：推 4 分钟，每一步都站在能走的地方（出门那会儿人不见了不算），上过菜、出过门
    var off := 0
    var served := 0
    var away := 0
    var was: Dictionary = {}
    var toasted_tables: Dictionary = {}
    for step in 60 * 240:
        life._process(1.0 / 60.0)
        for k in plan:
            if life.toast_left.get(k, 0.0) > 0.0: toasted_tables[k] = true
        for w in life.waiters:
            if w.node.visible and not hall._free(w.pos):
                off += 1
            var st: String = w.state
            if was.get(w, "") != st:
                if st == "serve": served += 1
                if st == "away": away += 1
                was[w] = st
    print("4 服务员 ", life.waiters.size(), " 个，4 分钟：踩出能走的地方 ", off, " 次，上菜 ", served, " 次，出门 ", away, " 次")
    ok = ok and life.waiters.size() == 3 and off == 0 and served >= 6 and away >= 1

    # 5. 整桌举杯：推的这 4 分钟里每桌都举过
    print("5 4 分钟里举过杯的桌 ", toasted_tables.size(), " / ", plan.size())
    ok = ok and toasted_tables.size() == plan.size()

    # 6. 摆设：乐队、贺礼、彩带、灯笼光（占位图在才摆）
    var names: Array = []
    for n in hall.world.get_children(): names.append(str(n.name))
    var decals := 0
    var glows := 0
    for n in life.get_children():
        if str(n.name).begins_with("decal"): decals += 1
        if str(n.name).begins_with("glow"): glows += 1
    var has_art := ResourceLoader.exists("res://assets/ambience/amb_piano.png")
    print("6 占位图在 ", has_art, "：钢琴 ", "piano" in names, " 贺礼 ", "gifts" in names, " 乐手 ",
        ["pianist", "cellist", "violin1", "violin2"].all(func(x): return x in names),
        " 彩带彩纸 ", decals, " 灯笼光 ", glows)
    ok = ok and glows == life.conf["glows"].size()
    ok = ok and ["pianist", "cellist", "violin1", "violin2"].all(func(x): return x in names)
    if has_art:
        ok = ok and "piano" in names and "gifts" in names and decals == life.conf["decals"].size()

    # 7. 乐队和贺礼摆在能走的范围外（不挡路）
    var blockers := 0
    for key in ["piano", "bench", "cello", "violin1", "violin2"]:
        if hall._free(life._vec(life.conf["band"][key])): blockers += 1
    if hall._free(life._vec(life.conf["gifts"])): blockers += 1
    print("7 乐队、贺礼落在能走的地方 ", blockers, " 处")
    ok = ok and blockers == 0

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
