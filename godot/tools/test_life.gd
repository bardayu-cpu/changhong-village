extends SceneTree
## 验收：厅里的热闹（hall_life.gd，阿鱼 9/18）。无界面跑，只看逻辑：
## NPC 宾客给真人让座（9/18 晚起 NPC 的椅子也出「坐这儿」，坐下时 NPC 起身走掉）、点不开；
## 服务员一直走在能走的地方、端菜放上桌再回侧门；
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

    # 3. 走到 NPC 坐着的椅子旁：出「坐这儿」（坐下时 NPC 让座），但不出人名（NPC 点不开）
    var full_tables: Array = []
    for k in plan: full_tables.append({"id": k, "seats": []})
    hall.set_seats({"tables": full_tables, "me": {"table_id": "", "chair_no": 0}, "names": {}}, "me")
    var near_hits: Array = []
    var person_hits: Array = []
    hall.chair_near.connect(func(t, n): near_hits.append("%s:%d" % [t, n]))
    hall.person_near.connect(func(p): person_hits.append(p))
    var offered := 0
    for key in life.npc_taken.keys():
        var tc: Dictionary = hall._table_cfg(key.split(":")[0])
        var at: Vector2 = hall.chair_world(tc, int(key.split(":")[1]))
        hall.reset_to(at)
        if key in near_hits:
            offered += 1
    var real_people := person_hits.filter(func(p): return p != "")
    print("3 走遍 NPC 的椅子 ", life.npc_taken.size(), " 把：出坐这儿 ", offered, " 把，冒出人名 ", real_people.size(), " 次")
    ok = ok and offered == life.npc_taken.size() and real_people.is_empty()
    # 坐到一把 NPC 的椅子上：那个 NPC 起身走掉，走到大门就没了
    var take: String = life.npc_taken.keys()[0]
    var before: int = life.guests.size()
    hall.apply_change(take.split(":")[0], int(take.split(":")[1]), "me")
    var leavers: Array = life.waiters.filter(func(w): return w.kind == "leaver")
    print("  坐到 NPC 的椅子 ", take, "：NPC 少了 ", before - life.guests.size(), " 个，还算 NPC 的 ", life.npc_taken.has(take),
        "，起身往外走的 ", leavers.size(), " 个")
    ok = ok and before - life.guests.size() == 1 and not life.npc_taken.has(take) and leavers.size() == 1
    for i in 60 * 40:
        life._process(1.0 / 60.0)
    var still: Array = life.waiters.filter(func(w): return w.kind == "leaver")
    print("  40 秒后还在厅里的让座宾客 ", still.size(), " 个")
    ok = ok and still.is_empty()

    # 4. 服务员：推 4 分钟，每一步都站在能走的地方（在门里那会儿人不见了不算），端菜放上桌、空托盘回侧门
    var off := 0
    var served := 0
    var away := 0
    var dish_max := 0
    var was: Dictionary = {}
    var toasted_tables: Dictionary = {}
    for step in 60 * 240:
        life._process(1.0 / 60.0)
        for k in plan:
            if life.toast_left.get(k, 0.0) > 0.0: toasted_tables[k] = true
        dish_max = maxi(dish_max, life.dishes.size())
        for w in life.waiters:
            if w.node.visible and not hall._free(w.pos):
                off += 1
            var st: String = w.state
            if was.get(w, "") != st:
                if st == "serve": served += 1
                if st == "away": away += 1
                was[w] = st
    var has_dish_art := ResourceLoader.exists("res://assets/ambience/amb_dish_1.png")
    print("4 服务员 ", life.waiters.size(), " 个，4 分钟：踩出能走的地方 ", off, " 次，放菜 ", served, " 次，回侧门 ", away,
        " 次，桌上同时最多 ", dish_max, " 盘新菜（菜的图在 ", has_dish_art, "）")
    ok = ok and life.waiters.size() == int(life.conf["waiters"]["count"]) and off == 0 and served >= 6 and away >= 3
    if has_dish_art:
        ok = ok and dish_max > 0

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
    # 乐队 9/21 换成 GPT 交的图了（band/），老的色块乐手（pianist/cellist/…）只在图缺了时才有
    var band_art := ResourceLoader.exists("res://assets/ambience/band/piano_player.png")
    var band_names := ["piano_player", "violin_player_a", "cello_player", "violin_player_b", "stage_rug", "light"]
    var old_band := ["pianist", "cellist", "violin1", "violin2"]
    print("6 占位图在 ", has_art, "：贺礼 ", "gifts" in names, " 彩带彩纸 ", decals, " 灯笼光 ", glows,
        "；乐队用图 ", band_art)
    ok = ok and glows == life.conf["glows"].size()   # 数的是灯笼光那些节点，乐队的灯光不在这堆里
    if band_art:
        var got := band_names.all(func(x): return x in names)
        print("  乐队那批图都摆上了 ", got, "；老的色块乐手不该再出现 ", not old_band.any(func(x): return x in names))
        ok = ok and got and not old_band.any(func(x): return x in names)
        # 灯光走会闪那一队（单独的动效层，不画死在乐手身上）
        print("  会闪的一共 ", life.glows.size(), " 个 = 灯笼 ", life.conf["glows"].size(), " + 乐队的灯光 1")
        ok = ok and life.glows.size() == life.conf["glows"].size() + 1
        # 音符是单独的动效层：不摆成死图，只记飘起来的点，交给 _step_notes
        print("  音符 ", life.band_notes.size(), " 种，从 ", life.heads.size(), " 个点往上飘；盘面上没有写死的音符 ",
            not ("note_a" in names))
        ok = ok and life.band_notes.size() == 3 and life.heads.size() == 3 and not ("note_a" in names)
        # 真推一段时间，音符得飘起来又淡掉
        life.notes.clear()
        for i in 400:
            life._step_notes(0.05)
        print("  推 20 秒：同时飘着的音符 ", life.notes.size(), " 个")
        ok = ok and life.notes.size() > 0
    else:
        ok = ok and old_band.all(func(x): return x in names)
    if has_art:
        ok = ok and "gifts" in names and decals == life.conf["decals"].size()

    # 7. 乐队和贺礼摆在能走的范围外（不挡路）
    var blockers := 0
    if band_art:
        for pl in JSON.parse_string(FileAccess.get_file_as_string("res://assets/ambience/band/band.json"))["place"]:
            if hall._free(life._vec(pl["at"])): blockers += 1
    else:
        for key in ["piano", "bench", "cello", "violin1", "violin2"]:
            if hall._free(life._vec(life.conf["band"][key])): blockers += 1
    if hall._free(life._vec(life.conf["gifts"])): blockers += 1
    print("7 乐队、贺礼落在能走的地方 ", blockers, " 处")
    ok = ok and blockers == 0

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
