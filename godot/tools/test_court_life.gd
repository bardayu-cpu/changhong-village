extends SceneTree
## 验收：迎宾院里的人动起来（01 E 10/2「院子里的人走起来」，04 基线第六节第 2 条）
## 1 走动的客人 6～8 个，用罗曼山庄宾客的图（有图用图），长相不撞、不跟玩家撞
## 2 从大门进来、去签到桌边和花墙前、往楼门走进去；进去一个，大门再进来一个
## 3 四块不许站不许走过：快进 3 分钟，每一帧每个客人的脚都不在红毯中间、签到桌前、合影站位、回忆册前
## 4 让玩家：玩家走到站着的客人跟前，客人挪开；客人不算挡路，玩家走路的格子跟没客人时一样（卡不住）
## 5 玩家站签到桌前、合影站位：快进一阵，跟前没有客人
## 6 新娘爸妈有小动作（互相看、欠身），玩家走近签到桌就看着玩家；摄影师一会儿看相机一会儿招呼人，玩家在合影站位就对着相机
## 7 别的画布（后厅）没有走动的客人
## 用法：Godot --headless --path . --script res://tools/test_court_life.gd ；最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const CourtLife = preload("res://scripts/court_life.gd")
const LMPeople = preload("res://scripts/lm_people.gd")
const Spr = preload("res://scripts/sprites.gd")

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

func present(life) -> Array:
    return life.walkers.filter(func(w): return w.state != "gone")

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.court_save.local_path = "user://test_court_life_court.json"
    m.games_save.local_path = "user://test_court_life_games.json"
    m.court_save.welcomed = true
    m.court_save.signed_in = false
    m.nickname = "小李"
    await m._enter_court()
    m.dialog.visible = false
    var c = m.court
    var life = c.court_life
    check("迎宾院搭了走动的客人", life != null)
    if life == null:
        print("RESULT FAIL")
        quit(1)
        return
    life.set_process(false)   # 下面全用 step 快进，每回一样
    c.walking_enabled = false
    c.reset_to(Vector2(200, 300))   # 玩家先站到西北角，别挡着客人
    life.reseed(7)

    print("1 人和长相")
    var n_lm := 0
    for w in present(life):
        if not w.lm.is_empty():
            n_lm += 1
    var codes: Array = present(life).map(func(w): return w.code)
    var uniq := {}
    for k in codes:
        uniq[k] = true
    check("一进院子已经有 %d 个站着，用罗曼山庄宾客图的 %d 个（%s）" % [codes.size(), n_lm, codes], codes.size() == CourtLife.WALKERS - 2 and n_lm == codes.size() and uniq.size() == codes.size())
    var most := 0
    var least := 99
    var enters := 0
    var leaves := 0
    var bad: Array = []
    var visited := {}
    var seen_ids := {}
    var twin := 0
    var player_tex = c.player.texture
    for f in 30 * 180:
        life.step(1.0 / 30.0)
        var ps := present(life)
        if f > 30 * 20:
            most = maxi(most, ps.size())
            least = mini(least, ps.size())
        for w in ps:
            if not seen_ids.has(w):
                seen_ids[w] = true
                if w.state == "enter":
                    enters += 1
            if CourtLife.in_no_go(w.pos) and bad.size() < 5:
                bad.append("%s 在 %s（%s）" % [w.code, w.pos, w.state])
            if w.state == "stay" and w.spot >= 0:
                visited[life.spots[w.spot]["what"]] = true
            if not w.lm.is_empty() and w.lm["tex"] == player_tex:
                twin += 1
        leaves = enters + (CourtLife.WALKERS - 2) - ps.size()
    check("快进 3 分钟（20 秒以后）院子里一直有 %d～%d 个人（要 6～8）" % [least, most], least >= 6 and most <= 8)
    check("一模一样的长相没撞玩家（%d 帧撞了）" % twin, twin == 0)

    print("2 进出")
    check("从大门进来了 %d 个、走进楼门 %d 个" % [enters, leaves], enters >= 4 and leaves >= 4)
    check("站过的地方：%s（要有签到桌边、花墙前）" % [visited.keys()], visited.has("签到桌西头排着") or visited.has("签到桌东头排着"))
    check("……也站过花墙前", visited.has("花墙前看"))

    print("3 不许站不许走过")
    check("3 分钟里没有客人踩进那四块（%s）" % [bad], bad.is_empty())
    var spots_ok: bool = life.spots.all(func(s): return not CourtLife.in_no_go(s["pos"], 8.0))
    check("客人去站的地方都不在那四块里", spots_ok)
    var carpet_mid := true
    for y in range(240, 860, 12):
        if life._wok(Vector2(768, y)) or life._wok(Vector2(720, y)) or life._wok(Vector2(816, y)):
            carpet_mid = false
    var arrow_ok := true
    for x in range(1000, 1036, 6):
        for y in range(600, 696, 6):
            if life._wok(Vector2(x, y)):
                arrow_ok = false
    check("进门金箭头 (1016, 610) 那块和它下面一个人高，客人站不上（04 第二件第 1 条）", arrow_ok)
    check("红毯中间那一条客人的格子里整条没有（大门口、楼门口两边能过）", carpet_mid and life._wok(Vector2(684, 600)) and life._wok(Vector2(852, 600)))

    print("4 让玩家")
    var w0 = null
    for w in present(life):
        if w.state == "stay" and w.pos.distance_to(Vector2(768, 500)) > 100:
            w0 = w
            break
    var gap := 0.0
    if w0 != null:
        c.reset_to(w0.pos + Vector2(20, 6))
        for f in 30 * 2:
            life.step(1.0 / 30.0)
        gap = w0.pos.distance_to(c.pos)
    check("玩家走到站着的客人跟前，客人挪开了（离玩家 %.0f，要 ≥ %.0f）" % [gap, CourtLife.YIELD_R], w0 != null and gap >= CourtLife.YIELD_R * 0.95)
    var solid_with := 0
    for j in c.rows:
        for i in c.cols:
            if c.nav.is_point_solid(Vector2i(i, j)):
                solid_with += 1
    var fresh := Entrance_solid_count()
    check("客人不算挡路：玩家走路的格子挡住的 %d 格，跟没有客人的一样（%d）" % [solid_with, fresh], solid_with == fresh)
    c.reset_to(Vector2(70, 220))   # 西北角
    for f in 30 * 20:
        life.step(1.0 / 30.0)
    var out_path: Array = c.find_path(c.pos, c.spot_pos("to_hall"))
    check("玩家在角落里站 20 秒，照样走得出去（到楼门 %d 段路）" % out_path.size(), not out_path.is_empty())

    print("5 签到桌前、合影站位没人挡")
    for spot in ["sign_in", "photo_mark"]:
        c.reset_to(c.spot_pos(spot))
        var closest := 9999.0
        for f in 30 * 30:
            life.step(1.0 / 30.0)
            if f > 30 * 3:
                for w in present(life):
                    closest = minf(closest, w.pos.distance_to(c.pos))
        check("玩家站 %s 30 秒，客人离得最近 %.0f（3 秒以后，要 ≥ %.0f）" % [spot, closest, CourtLife.YIELD_R * 0.9], closest >= CourtLife.YIELD_R * 0.9)

    print("6 新娘爸妈、摄影师")
    c.reset_to(Vector2(200, 300))
    var mom: Sprite2D = c.npc_nodes["bride_mom"]
    var faces := {}
    var dipped := false
    var base0: Vector2 = life.greeters.filter(func(g): return g["id"] == "bride_mom")[0]["base"]   # 站直时的（上一节可能正欠着身）
    for f in 30 * 25:
        life.step(1.0 / 30.0)
        faces["%d%s" % [mom.frame, mom.flip_h]] = true
        if (mom.get_meta("base_offset") as Vector2).y > base0.y + 0.5:
            dipped = true
    check("玩家不在跟前：新娘妈妈 25 秒里换过朝向（%d 种）、欠过身（%s）" % [faces.size(), dipped], faces.size() >= 2 and dipped)
    c.reset_to(Vector2(1240, 645))   # 签到桌东头外边，在妈妈右边（要转过来朝右看）
    for f in 30 * 1:
        life.step(1.0 / 30.0)
    var want: String = c._face_for(c.pos - mom.position)
    var fl: Dictionary = Spr.PROC_ANIM[want]
    var gm: Dictionary = life.greeters.filter(func(g): return g["id"] == "bride_mom")[0]
    var look_n := 0
    var free_n := 0
    for f in 30 * 6:
        life.step(1.0 / 30.0)
        if gm["act"] == "":   # 欠身那 0.7 秒照旧朝前，不算
            free_n += 1
            if mom.frame == int(fl["idle"]) and mom.flip_h == bool(fl["flip"]):
                look_n += 1
    check("玩家走近签到桌：新娘妈妈没在欠身的时候都转过来看着玩家（%s，%d/%d 帧）" % [want, look_n, free_n], want != "down" and free_n > 30 and look_n == free_n)
    var ph: Sprite2D = c.npc_nodes["photographer_w"]
    c.reset_to(Vector2(200, 300))
    var ph_faces := {}
    for f in 30 * 25:
        life.step(1.0 / 30.0)
        ph_faces["%d%s" % [ph.frame, ph.flip_h]] = true
    check("摄影师一会儿看相机一会儿招呼人（%d 种朝向）" % ph_faces.size(), ph_faces.size() >= 2)
    c.reset_to(c.spot_pos("photo_mark"))
    c._process(0.0)
    life.step(1.0 / 30.0)
    var right: Dictionary = Spr.PROC_ANIM["right"]
    check("玩家在合影站位：西边摄影师对着相机（朝右）", ph.frame == int(right["idle"]) and ph.flip_h == bool(right["flip"]))

    print("7 别的画布")
    check("后厅没有走动的客人", m.backhall.court_life == null)

    print("RESULT PASS" if ok else "RESULT FAIL")
    quit(0 if ok else 1)

## 没有客人时玩家的走路格子挡住多少格：按布局现算一张对比
func Entrance_solid_count() -> int:
    var c = m.court
    var g: Dictionary = c.compute_grid(c.cfg, c.obstacles, c.GRID_CELL, c.CLEAR)
    var n := 0
    for line in g["rows"]:
        for ch in str(line):
            if ch != "1":
                n += 1
    return n
