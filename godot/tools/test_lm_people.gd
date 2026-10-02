extends SceneTree
## 验收：罗曼山庄的人接进游戏的路（01 E 10/2：GPT 在画全套，图一到放进去就换；先拿假图跑通，假图不进仓库）
## 假图这个测试自己现画到 user://lm_fake/（色块小人，照 ASSETS §3 的格子），不靠 GPT 的文件：
##   宾客 01～12（11 号小孩画满格子、12 号小孩只画下面 53 高，两种画法都要缩对）、服务员 01～03（两行：走路 + 端托盘）、乐手 01～04
## 1 这套人用的是罗曼山庄的宾客：12 行，小孩认出来；站着的高照 height_m（大人 84、小孩约 53），坐下照画的高截上半身
## 2 别桌宾客：同一桌不重样，小孩一桌最多一个
## 3 18 位亲友：照称呼固定长相（REL_LOOKS），同一桌不重样
## 4 服务员：用罗曼山庄服务员，端菜走用托盘那一行，菜挂在托盘点上；点到服务员顶上说「罗曼山庄服务员 · 名字」，人不走过去
## 5 乐手：四位在 03 量的脚点，演奏那几帧会动
## 6 选人：形象 0～7 用宾客 01～08
## 用法：Godot --headless --path . --script res://tools/test_lm_people.gd ；最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const LMPeople = preload("res://scripts/lm_people.gd")
const Spr = preload("res://scripts/sprites.gd")
const Relatives = preload("res://scripts/relatives.gd")
const FAKE := "user://lm_fake/"

var m
var started := false
var ok := true

func _initialize() -> void:
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Main.HALL55_FLAG))
    _make_fakes()
    LMPeople.dir = FAKE
    LMPeople.clear_cache()
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

# ---------- 假图 ----------
func _save(img: Image, code: String, meta: Dictionary) -> void:
    img.save_png(ProjectSettings.globalize_path(FAKE + "chr_%s.png" % code))
    var f := FileAccess.open(FAKE + "chr_%s.json" % code, FileAccess.WRITE)
    f.store_string(JSON.stringify(meta))
    f.close()

## 一格画一个色块小人：从 top 画到格子最下面，宽 30，头一块深色；dir 那一帧在头上点一个记号（看得出朝向换了）
func _person(img: Image, ox: int, oy: int, fw: int, fh: int, top: int, col: Color, mark: int) -> void:
    var x0 := ox + (fw - 30) / 2
    img.fill_rect(Rect2i(x0, oy + top, 30, fh - top), col)
    img.fill_rect(Rect2i(x0 + 6, oy + top, 18, mini(16, fh - top)), col.darkened(0.5))
    img.fill_rect(Rect2i(x0 + mark * 6, oy + top + 2, 4, 4), Color.WHITE)

func _make_fakes() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FAKE))
    var walk := {"down": [0, 1, 2, 3], "left": [4, 5, 6, 7], "right": [8, 9, 10, 11], "up": [12, 13, 14, 15]}
    for i in range(1, 13):
        var img := Image.create_empty(1024, 84, false, Image.FORMAT_RGBA8)
        var top := 31 if i == 12 else 0   # 12 号小孩只画下面 53 高；11 号小孩画满格子
        for f in 16:
            _person(img, f * 64, 0, 64, 84, top, Color.from_hsv(float(i) / 12.0, 0.6, 0.8), f / 4)
        _save(img, LMPeople.guest_code(i), {"frame": [64, 84], "frames": walk, "fps": 8, "height_m": 1.1 if i >= 11 else 1.75})
    for i in range(1, 4):
        var img := Image.create_empty(1024, 168, false, Image.FORMAT_RGBA8)
        for f in 16:
            _person(img, f * 64, 0, 64, 84, 0, Color(0.7, 0.1, 0.1), f / 4)
            _person(img, f * 64, 84, 64, 84, 0, Color(0.7, 0.1, 0.1), f / 4)
            img.fill_rect(Rect2i(f * 64 + 36, 84 + 38, 20, 4), Color(0.8, 0.8, 0.8))   # 托盘
        _save(img, LMPeople.waiter_code(i), {"frame": [64, 84], "frames": walk, "fps": 8, "height_m": 1.75,
            "frames_tray": {"down": [16, 17, 18, 19], "left": [20, 21, 22, 23], "right": [24, 25, 26, 27], "up": [28, 29, 30, 31]}, "tray": [46, 38]})
    var sizes := [[64, 84], [80, 96], [64, 96], [64, 96]]
    for i in range(1, 5):
        var fw: int = sizes[i - 1][0]
        var fh: int = sizes[i - 1][1]
        var img := Image.create_empty(fw * 4, fh, false, Image.FORMAT_RGBA8)
        for f in 4:
            _person(img, f * fw, 0, fw, fh, 10, Color(0.2, 0.2, 0.6), f)
        _save(img, LMPeople.band_code(i), {"frame": [fw, fh], "frames": {"play": [0, 1, 2, 3]}, "fps": 6})

func _cleanup() -> void:
    var d := DirAccess.open(FAKE)
    if d != null:
        for f in d.get_files():
            d.remove(f)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(FAKE))

# ---------- 测 ----------
func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    await m._enter_banquet()
    m._set_feast_force("feast")
    await create_timer(0.5).timeout
    var h = m.hall
    var life = h.life
    var k: Dictionary = life._kit()

    print("1 这套人")
    var rows: Array = k["rows"]
    var kids := rows.filter(func(r): return r["kid"]).map(func(r): return r["code"])
    check("用罗曼山庄的宾客：%s，%d 行，小孩 %s" % [k["lm"], rows.size(), kids], k["lm"] and rows.size() == 12 and kids == ["LM-GUEST-11", "LM-GUEST-12"])
    var hs: Array = rows.map(func(r): return snappedf(float(r["sc"]) * float(r["h"]), 0.1))
    var adult: float = h._px_h(500.0)
    check("站着多高：大人 %s、11 号小孩（画满格子）%s、12 号小孩（只画下面 53）%s，要 %.0f 和 %.1f" % [hs[0], hs[10], hs[11], adult, adult * 1.1 / 1.75],
        absf(hs[0] - adult) < 0.6 and absf(hs[10] - adult * 1.1 / 1.75) < 0.6 and absf(hs[11] - adult * 1.1 / 1.75) < 0.6)
    var up12: Sprite2D = life._kit_upper(11, 0, false)
    check("坐下截上半身照画的高截：12 号小孩从格子第 %.0f 行截 %.0f 行（画在 31 往下，高 53）" % [up12.region_rect.position.y - 11 * 84, up12.region_rect.size.y],
        is_equal_approx(up12.region_rect.position.y, 11 * 84 + 31) and is_equal_approx(up12.region_rect.size.y, floorf(53 * h.SIT_KEEP)))
    up12.free()

    print("2 别桌宾客")
    var by_table := {}
    for g in life.guests:
        if not by_table.has(g.table):
            by_table[g.table] = []
        by_table[g.table].append(g.row)
    var dup := 0
    var kid2 := 0
    for tid in by_table:
        var rs: Array = by_table[tid]
        var seen := {}
        var nk := 0
        for r in rs:
            if seen.has(r) and rs.size() <= 12:
                dup += 1
            seen[r] = true
            if rows[r]["kid"]:
                nk += 1
        if nk > 1:
            kid2 += 1
    check("%d 张桌坐了宾客：同一桌重样的 %d 处、小孩超过一个的桌 %d 张" % [by_table.size(), dup, kid2], by_table.size() > 40 and dup == 0 and kid2 == 0)

    print("3 亲友")
    var rel = life.relatives
    var wrong: Array = []
    var rel_tables := {}
    for r in rel.rels:
        var want: String = Relatives.REL_LOOKS.get(r.title, "")
        if rows[r.row]["code"] != want:
            wrong.append("%s:%s" % [r.title, rows[r.row]["code"]])
        if not rel_tables.has(r.table):
            rel_tables[r.table] = {}
        if rel_tables[r.table].has(r.row):
            wrong.append("%s 跟同桌撞脸" % r.title)
        rel_tables[r.table][r.row] = true
    check("18 位亲友照称呼固定长相、同一桌不重样（不对的 %s）" % [wrong], rel.rels.size() == 18 and wrong.is_empty())

    print("4 服务员")
    var lmw: Array = life.waiters.filter(func(w): return w.kind == "waiter" and not w.lm.is_empty())
    var w0 = lmw[0] if not lmw.is_empty() else null
    var tray_ok := false
    var frame_ok := false
    if w0 != null:
        w0.full = true
        life._tray_look(w0)
        w0.state = "carry"
        w0.face = "down"
        w0.anim = 0.3
        life._pose_waiter(w0, true)
        frame_ok = w0.body.frame >= 16 and w0.body.frame < 32
        var exp: Vector2 = Vector2(46.0 - 32.0, 38.0 - 84.0) * w0.body.scale.x   # 托盘点 (46,38) 相对脚底：x 减半个格宽、y 减画的最下面一行（走路晃的 1 像素不算）
        tray_ok = w0.tray != null and w0.tray.visible and absf(w0.tray.position.x - exp.x) < 0.6 and absf(w0.tray.position.y - exp.y) < 3.0
    check("服务员用罗曼山庄的（%d 位）、端菜走用托盘那行（第 %s 帧）、菜挂在托盘点上（%s）" % [lmw.size(), w0.body.frame if w0 != null else -1, w0.tray.position if w0 != null and w0.tray != null else null],
        lmw.size() == life.waiters.filter(func(w): return w.kind == "waiter").size() and lmw.size() > 0 and frame_ok and tray_ok)

    var said := []
    h.waiter_tap.connect(func(t): said.append(t))
    var nm := ""
    var miss := "?"
    if w0 != null:
        var want := "罗曼山庄服务员 · " + LMPeople.waiter_name(str(w0.lm["code"]))
        var me_at: Vector2 = h.player.position
        h.tap(h.get_viewport().get_canvas_transform() * (w0.pos - Vector2(0, 20.0 * w0.body.scale.x)))
        nm = said[0] if not said.is_empty() else ""
        miss = life.waiter_at(w0.pos + Vector2(200, 0))
        check("点服务员 %s 说「%s」、人没走（%s）；点旁边空地不说（%s）" % [w0.lm["code"], nm, h.player.position == me_at and h.path.is_empty(), miss],
            nm == want and want.length() > 10 and miss == "" and h.player.position == me_at)
    check("名字表 40 位：01 %s、40 %s" % [LMPeople.waiter_name("LM-WAITER-01"), LMPeople.waiter_name("LM-WAITER-40")],
        LMPeople.waiter_name("LM-WAITER-01") == "陈子航" and LMPeople.waiter_name("LM-WAITER-40") == "崔琳")

    print("5 乐手")
    var feet := []
    for b in life.lm_band:
        var node: Node2D = (b["spr"] as Sprite2D).get_parent()
        feet.append(node.position)
    var f0: int = (life.lm_band[0]["spr"] as Sprite2D).frame if not life.lm_band.is_empty() else -1
    life._process(0.2)
    var f1: int = (life.lm_band[0]["spr"] as Sprite2D).frame if not life.lm_band.is_empty() else -1
    var foot_px := Vector2.ZERO
    if not life.lm_band.is_empty():
        var s0: Sprite2D = life.lm_band[1]["spr"]   # 大提琴手 80×96：格子下沿正中要落在脚点上
        foot_px = s0.position + Vector2(40, 96) * s0.scale.x
    check("四位乐手在 03 量的脚点 %s，演奏帧会换（%d → %d），格子下沿正中踩在脚点上（%s）" % [feet, f0, f1, foot_px],
        feet == [Vector2(1128, 293), Vector2(1200, 292), Vector2(1257, 290), Vector2(1302, 290)] and f0 != f1 and foot_px.is_equal_approx(Vector2.ZERO))

    print("6 选人")
    var gl: Dictionary = Spr.gpt_look(0)
    var g8: Dictionary = Spr.gpt_look(7)
    check("形象 0 用宾客 %s、形象 7 用 %s，帧 %s×%s" % [gl.get("code"), g8.get("code"), gl.get("frame_w"), gl.get("frame_h")],
        gl.get("code") == "LM-GUEST-01" and g8.get("code") == "LM-GUEST-08" and int(gl.get("frame_w", 0)) == 64)

    _cleanup()
    LMPeople.dir = "res://assets/characters/lm/"
    LMPeople.clear_cache()
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
