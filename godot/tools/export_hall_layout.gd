extends SceneTree
## 导出宴会厅「摆位」：游戏里现在真在用的每个放东西的位置（01 9/24 派，给 GPT 画 5 张效果图用，拆下来要能原样放回游戏）。
## 不自己排：桌、椅、地毯、簿子、菜、灯、花、贺礼、新人、乐队、服务员、长凳，全部从 layered_hall.gd / hall_life.gd 跑出来的结果读
## 坐标都是 1536×1024 画布像素；人按脚点。画图交给 tools/draw_hall_layout.py
## 用法：Godot --headless --path . --script res://tools/export_hall_layout.gd -- --out=/某处/摆位.json

const Main = preload("res://scripts/main.gd")

var m
var started := false

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

func v(p: Vector2) -> Array:
    return [snappedf(p.x, 0.1), snappedf(p.y, 0.1)]

func rect(x0: float, y0: float, w: float, h: float) -> Array:
    return [snappedf(x0, 0.1), snappedf(y0, 0.1), snappedf(x0 + w, 0.1), snappedf(y0 + h, 0.1)]

func run() -> void:
    var out_path := ""
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--out="):
            out_path = a.substr(6)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.cloud.fake_no_news = true
    await m._enter_banquet()
    await create_timer(0.5).timeout
    var h = m.hall
    var life = h.life
    var cfg: Dictionary = h.cfg
    var sit_h: float = floorf(life.FH * h.SIT_KEEP) * life.sc      # 坐着的人露出来的上半身高
    var shin_h: float = 8.0 * life.sc                              # 朝外坐的人椅面下面的小腿
    var npc: Dictionary = life.seat_guests({})
    var d := {
        "scene": "scene_roman_banquet",
        "canvas": cfg["size"],
        "base": "claude-宴会厅底图-现用.png（游戏里的 assets/layered/scene_roman_banquet/base.png 原样）",
        "person_px": 84,
        "note": "坐标都是 1536×1024 画布像素，左上角是 0,0。[x, y] 是点，[x0, y0, x1, y1] 是框。站着的人按脚点；坐着的人给椅面点（屁股落在哪）和脚点。编号和 claude-宴会厅摆位图-v1.png 上的对得上",
    }

    # ---- 桌 ----
    var tables: Array = []
    var occ_by_foot := {}
    for o in cfg["occluders"]:
        if str(o["id"]).begins_with("blk_table_round"):
            occ_by_foot[int(o["foot"])] = o
    for t in cfg["tables"]:
        var tid := str(t["id"])
        var foot := Vector2(float(t["x"]), float(t["y"]))
        var c: Vector2 = h._seat_center(t)
        var tr := {"id": tid, "桌子着地点": v(foot), "桌心": v(c),
            "占地椭圆": {"中心": v(foot), "横半径": t["rx"], "竖半径": t["ry"]}}
        var o = occ_by_foot.get(int(t["y"]))
        if o != null:
            var img := Image.load_from_file(ProjectSettings.globalize_path(str(o["image"])))
            tr["桌子积木框"] = rect(float(o["x"]), float(o["y"]), img.get_width(), img.get_height())
            tr["桌子积木图"] = str(o["image"]).get_file()
        var rug: Dictionary = life.art.get("amb_rug", {})
        var rs: Array = rug.get("size", [230, 142])
        var ra: Array = rug.get("anchor", [115, 71])
        var rc := Vector2(foot.x, foot.y - 20.0)
        tr["地毯"] = {"中心": v(rc), "框": rect(rc.x - float(ra[0]), rc.y - float(ra[1]), float(rs[0]), float(rs[1]))}
        tr["簿子"] = {"中心": v(Vector2(foot.x, c.y)), "框": rect(foot.x - 8.0, c.y - 5.0, 16.0, 10.0)}
        var seats: Array = []
        for no in range(1, 11):
            var at: Vector2 = h.chair_world(t, no)
            var front: bool = h.seat_in_front(t, at)
            seats.append({"号": no, "椅面点": v(at), "脚点": v(at + Vector2(0, shin_h)),
                "头顶": v(at - Vector2(0, sit_h)),
                "在桌子前面画": front, "默认坐着NPC": npc.has("%s:%d" % [tid, no])})
        tr["座位"] = seats
        var dish_pts: Array = []
        var top: Vector2 = c + Vector2(0, -6)
        for sp in life.spots.get(tid, []):
            var dd: Vector2 = sp - top
            var dir := Vector2(dd.x / float(t["rx"]), dd.y / float(t["ry"]))
            dir = dir.normalized() if dir.length() > 0.001 else Vector2(0, 1)
            dish_pts.append({"服务员站的点": v(sp), "菜放在": v(top + Vector2(dir.x * 36.0, dir.y * 14.0))})
        tr["上菜"] = dish_pts
        tables.append(tr)
    d["桌"] = tables

    # ---- 红毯两边的灯和花、前景栏杆 ----
    var lamps: Array = []
    var pots: Array = []
    var rails: Array = []
    for o in cfg["occluders"]:
        var id := str(o["id"])
        if id.begins_with("blk_table_round"):
            continue
        var img := Image.load_from_file(ProjectSettings.globalize_path(str(o["image"])))
        var it := {"积木图": str(o["image"]).get_file(), "框": rect(float(o["x"]), float(o["y"]), img.get_width(), img.get_height()),
            "着地点": v(Vector2(float(o["x"]) + img.get_width() * 0.5, float(o["foot"])))}
        if id.begins_with("blk_lantern_floor"):
            lamps.append(it)
        elif id.begins_with("blk_flower_pot"):
            pots.append(it)
        else:
            rails.append(it)
    d["落地灯"] = lamps
    d["花盆"] = pots
    d["前景栏杆"] = rails

    # ---- 贺礼堆 ----
    var gp: Vector2 = life._vec(life.conf["gifts"])
    var ga: Dictionary = life.art.get("amb_gift_pile", {})
    var gs: Array = ga.get("size", [158, 106])
    var gan: Array = ga.get("anchor", [79, 105])
    d["贺礼堆"] = {"着地点": v(gp), "框": rect(gp.x - float(gan[0]), gp.y - float(gan[1]), float(gs[0]), float(gs[1]))}

    # ---- 新人（现在是一张合照立绘，两个人在一张图里）----
    var cf := Vector2(float(cfg["couple"][0]), float(cfg["couple"][1]))
    var ch: float = h._px_h(cf.y) * 1.25
    var ctex: Texture2D = load("res://assets/couple.png")
    var cw: float = ch * float(ctex.get_width()) / float(ctex.get_height())
    d["新人"] = {"两人中间的脚点": v(cf), "合照立绘框": rect(cf.x - cw * 0.5, cf.y - ch, cw, ch),
        "note": "现在是一张合照立绘（assets/couple.png），整张比人高 1.25 倍（人头顶上有留白）；分成两个人画时，脚点照这条脚线左右分开"}

    # ---- 乐队 ----
    var bj = JSON.parse_string(FileAccess.get_file_as_string(life.BAND_CFG))
    var st: Dictionary = bj["blocks"]["stage"]
    var sat := Vector2.ZERO
    for pl in bj["place"]:
        if str(pl.get("block", "")) == "stage":
            sat = life._vec(pl["at"])
    var s0: Vector2 = sat - life._vec(st["anchor"])
    # 四个人的脚点：02 对着 stage.png 看的（图里的像素），加上舞台左上角
    var feet := [["钢琴手（坐）", Vector2(75, 132)], ["小提琴手（左，站）", Vector2(182, 138)],
        ["大提琴手（坐）", Vector2(262, 142)], ["小提琴手（右，站）", Vector2(330, 138)]]
    var regs: Array = st["sway"]["regions"]
    var mus: Array = []
    for k in 4:
        var r: Array = regs[k]
        mus.append({"谁": feet[k][0], "脚点": v(s0 + feet[k][1]),
            "人所在框": rect(s0.x + float(r[0]), s0.y + float(r[1]), float(r[2]) - float(r[0]), feet[k][1].y - float(r[1]))})
    var heads: Array = []
    for p in life.heads:
        heads.append(v(p))
    d["乐队"] = {"整块舞台图": "assets/ambience/band/stage.png", "舞台框": rect(s0.x, s0.y, float(st["size"][0]), float(st["size"][1])),
        "舞台着地点": v(sat), "四个人": mus, "音符冒出来的点": heads,
        "note": "乐队现在是一整张舞台图（地毯、钢琴、四个人连在一起），不在底图里，叠在底图上"}

    # ---- 服务员 ----
    var paths: Array = []
    var ids: Array = life.spots.keys()
    ids.sort_custom(func(a, b): return int(str(a).substr(1)) < int(str(b).substr(1)))
    for tid in ids:
        var sp0: Vector2 = life.spots[tid][0]
        var pts: Array = [v(life.door)]
        for p in h.find_path(life.door, sp0):
            pts.append(v(p))
        paths.append({"去": tid, "路": pts})
    d["服务员"] = {"人数": life.waiters.size(), "进出的门（脚点）": v(life.door), "去各桌的路（从门出发，拐点）": paths,
        "note": "服务员从东侧门出来，走到某张桌边（见各桌「上菜」里的站点）放下菜，再回门；路是游戏里寻路算出来的，每趟挑的桌不同"}

    # ---- 长凳 ----
    var bw: float = h.BENCH_X1 - h.BENCH_X0 + 36.0
    var bx: float = h.BENCH_X0 - 18.0
    var bench_seats: Array = []
    for k in 8:
        var bp: Vector2 = h.bench_pos(k, 8)
        bench_seats.append({"号": k + 1, "椅面点": v(bp), "脚点": v(bp + Vector2(0, shin_h))})
    d["长凳"] = {"框": rect(bx, h.BENCH_Y - 32.0, bw, 48.0), "坐的位（8 个人时）": bench_seats,
        "note": "现在是代码画的占位凳子；一排坐 8 个人，人多了挤着叠"}

    # ---- 玩家、门、交互点 ----
    var pts2: Array = []
    for p in cfg["points"]:
        pts2.append({"id": p["id"], "点": v(Vector2(float(p["x"]), float(p["y"]))), "半径": p["r"]})
    d["玩家进厅站的点"] = v(Vector2(float(cfg["spawn"][0]), float(cfg["spawn"][1])))
    d["交互点"] = pts2

    var txt := JSON.stringify(d, " ", false)
    if out_path != "":
        var f := FileAccess.open(out_path, FileAccess.WRITE)
        f.store_string(txt)
        f.close()
        print("存了 ", out_path)
    else:
        print(txt)
    print("RESULT PASS")
    quit(0)
