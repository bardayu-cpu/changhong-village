extends SceneTree
## 第 28 版数据测试用：六个小游戏在第 1/5/10 关，各跑 20 次，记通关率和用了多久/多少步。
## 玩法照抄各自 tools/test_game_<id>.gd 里已经有的自动玩法（连连看找能连的对子；三消找能凑成的换法；
## 2048 循环四个方向；打地鼠/接物每帧点开着的/接最近的一颗；翻牌配对另外跑了两种：作弊读牌面、纯随机猜）。
## 不碰正式游戏代码，只读 Cfg 和各游戏类。跑完直接打印表格，报表里的数字是从这份输出摘的。
## 用法：Godot --headless --path . --script res://tools/sim_clear_rate.gd
## 阿鱼确认后：可以留着给下一次数据测试复用（改改 LEVELS/RUNS 就能跑），也可以删——报告里说了

const Cfg = preload("res://scripts/games/game_config.gd")
const LLK = preload("res://scripts/games/lianliankan.gd")
const Match3 = preload("res://scripts/games/match3.gd")
const G2048 = preload("res://scripts/games/g2048.gd")
const Memory = preload("res://scripts/games/memory.gd")
const Whack = preload("res://scripts/games/whack.gd")
const Catch = preload("res://scripts/games/catch.gd")

const LEVELS := [1, 5, 10]
const RUNS := 20
const DT := 0.05

var started := false
var font: Font

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    font = SystemFont.new()
    run()
    return false

func _new_inst(cls, level: int, params: Dictionary, seed_v: int, sz: Vector2):
    var inst = cls.new()
    inst.setup(level, params, font, seed_v)
    inst.size = sz
    get_root().add_child(inst)
    inst.start()
    return inst

## 立刻销毁，不用 queue_free()：这个脚本一帧里连着跑几百局，deferred 删除攒着不清，
## 树里堆的 Control 越多，布局重算就越吃力，跑到后面会内存爆掉甚至卡死（试跑时在第 350 局左右崩过一次）
func _kill(inst) -> void:
    if inst != null and is_instance_valid(inst):
        if inst.get_parent() != null:
            inst.get_parent().remove_child(inst)
        inst.free()

# ---------- 连连看：找一对能连的就消，一直到清空（照 test_game_lianliankan.gd 的 _find_pair） ----------
func _find_pair(board: Array) -> Array:
    var by_val := {}
    for y in board.size():
        var row: Array = board[y]
        for x in row.size():
            var v := int(row[x])
            if v == 0:
                continue
            if not by_val.has(v):
                by_val[v] = []
            (by_val[v] as Array).append(Vector2i(x, y))
    for v in by_val:
        var pts: Array = by_val[v]
        for i in range(pts.size()):
            for j in range(i + 1, pts.size()):
                if not LLK.can_link(board, pts[i], pts[j]).is_empty():
                    return [pts[i], pts[j]]
    return []

func sim_lianliankan(level: int, seed_v: int) -> Dictionary:
    var g := Cfg.game("lianliankan")
    var params := Cfg.params(g, level, 1.0)
    var inst = _new_inst(LLK, level, params, seed_v, Vector2(540, 960))
    var total_pairs := 0
    for row in inst.board:
        for v in row:
            if int(v) != 0:
                total_pairs += 1
    total_pairs /= 2
    var rounds := 0
    var stuck := false
    while true:
        var pair := _find_pair(inst.board)
        if pair.is_empty():
            stuck = not inst._all_cleared()
            break
        inst.tap(pair[0])
        inst.tap(pair[1])
        rounds += 1
        if rounds > 2000:
            stuck = true
            break
    _kill(inst)
    await process_frame
    return {"win": not stuck, "rounds": rounds, "pairs": total_pairs, "time_param": params.get("time", 0.0)}

# ---------- 三消：一直找一个能凑成的换法（照 test_game_match3.gd 第 5 条） ----------
func sim_match3(level: int, seed_v: int) -> Dictionary:
    var g := Cfg.game("match3")
    var params := Cfg.params(g, level, 1.0)
    var inst = _new_inst(Match3, level, params, seed_v, Vector2(500, 700))
    var win_result := [null]
    inst.finished.connect(func(w, _why): win_result[0] = w)
    var steps := 0
    while win_result[0] == null and steps < 4000:
        var mv: Array = Match3.find_a_move(inst.board)
        if mv.is_empty():
            break
        inst.play(mv[0], mv[1])
        steps += 1
    var ok: bool = win_result[0] == true
    var score: int = inst.score
    var moves_param: int = int(params.get("moves", 0))
    _kill(inst)
    await process_frame
    return {"win": ok, "steps": steps, "score": score, "moves_param": moves_param}

# ---------- 2048：循环右下左上四个方向（照 test_games.gd 第 5 条） ----------
func sim_g2048(level: int, seed_v: int) -> Dictionary:
    var g := Cfg.game("g2048")
    var params := Cfg.params(g, level, 1.0)
    var inst = _new_inst(G2048, level, params, seed_v, Vector2(540, 960))
    var win_result := [null]
    inst.finished.connect(func(w, _why): win_result[0] = w)
    var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
    var attempts := 0
    var moved := 0
    while win_result[0] == null and attempts < 8000:
        if inst.play(dirs[attempts % 4]):
            moved += 1
        attempts += 1
    var ok: bool = win_result[0] == true
    _kill(inst)
    await process_frame
    return {"win": ok, "moves": moved, "attempts": attempts}

# ---------- 翻牌配对：两种玩法都跑 ----------
## a) 作弊：直接读 deck 数组配对（照 test_game_memory.gd 第 2 条），上限——真人不可能这样
func sim_memory_cheat(level: int, seed_v: int) -> Dictionary:
    var g := Cfg.game("memory")
    var params := Cfg.params(g, level, 1.0)
    var inst = _new_inst(Memory, level, params, seed_v, Vector2(540, 960))
    inst._game_tick(float(params.get("preview", 0.0)) + 0.05)   # 跳过预览（时间到了自动翻回去）
    var win_result := [null]
    inst.finished.connect(func(w, _why): win_result[0] = w)
    var by_kind := {}
    for i in inst.deck.size():
        var k = inst.deck[i]
        if not by_kind.has(k):
            by_kind[k] = []
        (by_kind[k] as Array).append(i)
    for k in by_kind:
        if win_result[0] != null:
            break
        var idxs: Array = by_kind[k]
        inst.tap(idxs[0])
        inst.tap(idxs[1])
    var ok: bool = win_result[0] == true
    var misses: int = inst.misses
    _kill(inst)
    await process_frame
    return {"win": ok, "misses": misses, "misses_max": int(params.get("misses", 0))}

## b) 纯随机：不作弊、也不记事——每次从没配上的牌里随机翻两张，当「什么都不记得」的下限参照
func sim_memory_random(level: int, seed_v: int) -> Dictionary:
    var g := Cfg.game("memory")
    var params := Cfg.params(g, level, 1.0)
    var inst = _new_inst(Memory, level, params, seed_v, Vector2(540, 960))
    inst._game_tick(float(params.get("preview", 0.0)) + 0.05)
    var win_result := [null]
    inst.finished.connect(func(w, _why): win_result[0] = w)
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_v ^ 0x5eed
    var guard := 0
    while win_result[0] == null and guard < 500:
        guard += 1
        var open: Array = []
        for i in inst.total:
            if not inst.matched[i]:
                open.append(i)
        if open.size() < 2:
            break
        var a: int = open[rng.randi_range(0, open.size() - 1)]
        inst.tap(a)
        var open2: Array = []
        for i in inst.total:
            if not inst.matched[i] and i != a and not inst.revealed[i]:
                open2.append(i)
        if open2.is_empty():
            break
        var b: int = open2[rng.randi_range(0, open2.size() - 1)]
        inst.tap(b)
    var ok: bool = win_result[0] == true
    var misses: int = inst.misses
    _kill(inst)
    await process_frame
    return {"win": ok, "misses": misses, "misses_max": int(params.get("misses", 0)), "guard": guard}

# ---------- 打地鼠：每帧把冒出来的都点掉（照 test_game_whack.gd 第 2 条） ----------
func sim_whack(level: int, seed_v: int) -> Dictionary:
    var g := Cfg.game("whack")
    var params := Cfg.params(g, level, 1.0)
    var inst = _new_inst(Whack, level, params, seed_v, Vector2(540, 960))
    var result := [null]
    var why := [""]
    inst.finished.connect(func(won, r): result[0] = won; why[0] = r)
    var duration: float = float(params.get("duration", 30.0))
    var guard := 0
    var guard_max := int(duration / DT) + 200
    while result[0] == null and guard < guard_max:
        inst._game_tick(DT)
        for i in inst.holes_state.size():
            if result[0] != null:
                break
            if inst.holes_state[i]["up"]:
                inst.hit(i)
        guard += 1
    var time_used: float = duration - inst.time_left
    var ok: bool = result[0] == true
    var score: int = inst.score
    _kill(inst)
    await process_frame
    return {"win": ok, "time_used": time_used, "score": score, "why": why[0]}

## 打地鼠·会躲辣椒：跟 sim_whack 一样逐帧点，但看得到 holes_state[i]["bad"]（跟看得到牌面颜色一样，不算作弊）
## 空盘子冒出来的是辣椒就不点，等它自己缩回去——比原 test 的「冒出来就点」更接近真人
func sim_whack_smart(level: int, seed_v: int) -> Dictionary:
    var g := Cfg.game("whack")
    var params := Cfg.params(g, level, 1.0)
    var inst = _new_inst(Whack, level, params, seed_v, Vector2(540, 960))
    var result := [null]
    var why := [""]
    inst.finished.connect(func(won, r): result[0] = won; why[0] = r)
    var duration: float = float(params.get("duration", 30.0))
    var guard := 0
    var guard_max := int(duration / DT) + 200
    while result[0] == null and guard < guard_max:
        inst._game_tick(DT)
        for i in inst.holes_state.size():
            if result[0] != null:
                break
            var st: Dictionary = inst.holes_state[i]
            if st["up"] and not st["bad"]:
                inst.hit(i)
        guard += 1
    var time_used: float = duration - inst.time_left
    var ok: bool = result[0] == true
    var score: int = inst.score
    _kill(inst)
    await process_frame
    return {"win": ok, "time_used": time_used, "score": score, "why": why[0]}

# ---------- 接物：每帧把篮子挪到最靠下那一颗下面（照 test_game_catch.gd 第 2 条） ----------
func sim_catch(level: int, seed_v: int) -> Dictionary:
    var g := Cfg.game("catch")
    var params := Cfg.params(g, level, 1.0)
    var inst = _new_inst(Catch, level, params, seed_v, Vector2(540, 960))
    var result := [null]
    var why := [""]
    inst.finished.connect(func(won, r): result[0] = won; why[0] = r)
    var duration: float = float(params.get("duration", 30.0))
    var guard := 0
    var guard_max := int(duration / DT) + 200
    while result[0] == null and guard < guard_max:
        var best := -1
        var best_y := -INF
        for i in inst.drops.size():
            var d: Dictionary = inst.drops[i]
            if d["y"] > best_y:
                best_y = d["y"]
                best = i
        if best >= 0:
            inst.basket_x = clampf(inst.drops[best]["x"], inst.basket_w * 0.5, inst.size.x - inst.basket_w * 0.5)
            inst._layout_basket()
        inst._game_tick(DT)
        guard += 1
    var time_used: float = duration - inst.time_left
    var ok: bool = result[0] == true
    var caught: int = inst.caught
    _kill(inst)
    await process_frame
    return {"win": ok, "time_used": time_used, "caught": caught, "why": why[0]}

## 接物·会躲鞭炮：只追最靠下那颗「不是鞭炮」的；没有喜糖在掉就不动——比原 test 的「不管好坏都追最下面」更接近真人
func sim_catch_smart(level: int, seed_v: int) -> Dictionary:
    var g := Cfg.game("catch")
    var params := Cfg.params(g, level, 1.0)
    var inst = _new_inst(Catch, level, params, seed_v, Vector2(540, 960))
    var result := [null]
    var why := [""]
    inst.finished.connect(func(won, r): result[0] = won; why[0] = r)
    var duration: float = float(params.get("duration", 30.0))
    var guard := 0
    var guard_max := int(duration / DT) + 200
    while result[0] == null and guard < guard_max:
        var best := -1
        var best_y := -INF
        for i in inst.drops.size():
            var d: Dictionary = inst.drops[i]
            if not d["bad"] and d["y"] > best_y:
                best_y = d["y"]
                best = i
        if best >= 0:
            inst.basket_x = clampf(inst.drops[best]["x"], inst.basket_w * 0.5, inst.size.x - inst.basket_w * 0.5)
            inst._layout_basket()
        inst._game_tick(DT)
        guard += 1
    var time_used: float = duration - inst.time_left
    var ok: bool = result[0] == true
    var caught: int = inst.caught
    _kill(inst)
    await process_frame
    return {"win": ok, "time_used": time_used, "caught": caught, "why": why[0]}

# ---------- 跑一遍、汇总 ----------
func _summ(rows: Array, key: String) -> String:
    var wins := 0
    var vals: Array = []
    for r in rows:
        if r["win"]:
            wins += 1
            if r.has(key):
                vals.append(float(r[key]))
    var avg := 0.0
    for v in vals:
        avg += v
    if vals.size() > 0:
        avg /= vals.size()
    return "通关 %d/%d，赢的里面 %s 平均 %.2f" % [wins, rows.size(), key, avg]

func run() -> void:
    print("=== 连连看 lianliankan（找得到的对子马上消，不模拟人眼扫版和手速；时间参数没用上，见报告） ===")
    for level in LEVELS:
        var rows: Array = []
        for i in RUNS:
            rows.append(await sim_lianliankan(level, level * 100000 + i))
        print("第 %d 关：%s" % [level, _summ(rows, "rounds")])

    print("=== 三消 match3（每步都找一个当下能凑成的换法，不是全局最优） ===")
    for level in LEVELS:
        var rows: Array = []
        for i in RUNS:
            rows.append(await sim_match3(level, level * 100000 + i))
        print("第 %d 关：%s" % [level, _summ(rows, "steps")])

    print("=== 2048 g2048（固定循环右下左上四个方向，不是聪明的角落堆叠策略） ===")
    for level in LEVELS:
        var rows: Array = []
        for i in RUNS:
            rows.append(await sim_g2048(level, level * 100000 + i))
        print("第 %d 关：%s" % [level, _summ(rows, "moves")])

    print("=== 记菜名 memory——a) 作弊读牌面（上限，真人做不到） ===")
    for level in LEVELS:
        var rows: Array = []
        for i in RUNS:
            rows.append(await sim_memory_cheat(level, level * 100000 + i))
        print("第 %d 关：%s" % [level, _summ(rows, "misses")])

    print("=== 记菜名 memory——b) 纯随机翻、不作弊也不记（下限参照） ===")
    for level in LEVELS:
        var rows: Array = []
        for i in RUNS:
            rows.append(await sim_memory_random(level, level * 100000 + i))
        print("第 %d 关：%s" % [level, _summ(rows, "misses")])

    print("=== 打地鼠 whack（冒出来就点，反应时间当成 0） ===")
    for level in LEVELS:
        var rows: Array = []
        for i in RUNS:
            rows.append(await sim_whack(level, level * 100000 + i))
        var loses: Array = []
        for r in rows:
            if not r["win"]:
                loses.append(str(r["why"]))
        print("第 %d 关：%s；输的原因 %s" % [level, _summ(rows, "time_used"), loses])

    print("=== 打地鼠 whack·会躲辣椒（辣椒冒出来不点，等它缩回去；更像真人） ===")
    for level in LEVELS:
        var rows: Array = []
        for i in RUNS:
            rows.append(await sim_whack_smart(level, level * 100000 + i))
        var loses: Array = []
        for r in rows:
            if not r["win"]:
                loses.append(str(r["why"]))
        print("第 %d 关：%s；输的原因 %s" % [level, _summ(rows, "time_used"), loses])

    print("=== 接物 catch（篮子瞬移到最下面那颗下面，反应时间当成 0；不躲鞭炮） ===")
    for level in LEVELS:
        var rows: Array = []
        for i in RUNS:
            rows.append(await sim_catch(level, level * 100000 + i))
        var loses: Array = []
        for r in rows:
            if not r["win"]:
                loses.append(str(r["why"]))
        print("第 %d 关：%s；输的原因 %s" % [level, _summ(rows, "time_used"), loses])

    print("=== 接物 catch·会躲鞭炮（只追不是鞭炮的那颗；更像真人） ===")
    for level in LEVELS:
        var rows: Array = []
        for i in RUNS:
            rows.append(await sim_catch_smart(level, level * 100000 + i))
        var loses: Array = []
        for r in rows:
            if not r["win"]:
                loses.append(str(r["why"]))
        print("第 %d 关：%s；输的原因 %s" % [level, _summ(rows, "time_used"), loses])

    print("ALL DONE")
    quit(0)
