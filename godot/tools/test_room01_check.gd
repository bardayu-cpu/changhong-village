extends SceneTree
## 化妆间单独成屋（room01 02a8148，02 F 做：像素成品、后厅原来那间封成红门 + 屋顶、三位连同第 67 版的冒泡对话搬进新屋、换装点挪进新屋），03 自己重测
## （01 H 10/4 派，不改游戏代码；不看 02 的 test_makeup_room，另起量法）：
##   1 来回走通：后厅走廊化妆间门口 → 整屏切进化妆间、站南门里边；南门出去 → 回走廊门口外；来回 3 趟，每趟站稳 3 秒不弹回
##   2 后厅原来那间封了：原来那间屋（x 1195～1536、y 226～684）里没有一个能站的格子是从走廊走得到的；门洞挡人的占地在
##   3 人：新娘、化妆师、化妆助理在新屋里：谁坐着谁的脚点在某张凳子 / 沙发上（不悬空，≤ 8 像素）；冒泡只有这三位冒（60 秒），八位静坐的替身不冒、
##     不在能点的人里、点他们的头不开对话框；7 段对话（化妆师 2 支、化妆助理 2 支、新娘）选项都走到底，每页名字牌对、说完收；
##     新娘对话框头像不出、身份卡不出图、称呼「新娘」；化妆助理走一圈：不进南墙门洞、站点和路过的地方过道够宽、60 秒内回原位
##   4 换装点：在屏风南边、从出生点走得到、走到了不冒开发字样；过道：从出生点走到每个站点、凳子前、换装点，路上的过道宽度 ≥ 1.5 米
##     （左右 1 米 = 48 像素、前后 1 米 = 32 像素）；首饰中岛两边的道直着穿一趟
##   5 屋名框（手机 540×960、长屏 585×1266）：进屋第一眼不压任何一个人的身子
## 用法：Godot --headless --path . --script res://tools/test_room01_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const Ent = preload("res://scripts/entrance.gd")
const DT := 1.0 / 30.0
const OLD_ROOM := Rect2(1195, 226, 341, 458)
const GAP := Rect2(227, 846, 86, 112)   # 新屋南门洞（GPT 整间版走路范围第二块 227～313 × 846～954，南墙 wall_s_0 / wall_s_1 之间）

var m
var started := false
var ok := true
var mk   # areas["makeup"]
var lf
var ui

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(600.0).timeout.connect(func():
        print("RESULT FAIL 600 秒没跑完")
        quit(1))

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

func tick(n: int) -> void:
    for i in n:
        m.cv._process(DT)
        m._process(DT)

## 对话框现在这句的原文（第 69 版合进来以后有 line_raw，没合的老版本直接读字）
func raw_line() -> String:
    var r = ui.get("line_raw")
    return str(r) if r != null else ui.line_label.text

func settle_switch() -> void:
    for i in 400:
        await process_frame
        if not m.switching:
            break
    await frames(6)

func walk_to(target: Vector2, secs := 60.0) -> void:
    var c = m.cv
    c.walking_enabled = true
    c.go_to(target)
    for i in int(secs / DT):
        tick(1)
        if m.cv != c or c.path.is_empty() or m.switching:
            break
    await settle_switch()

func to_screen(wp: Vector2) -> Vector2:
    var sv: SubViewport = m.view.get_child(0)
    var cc: Vector2 = m.cv.cam.get_screen_center_position()
    var z: float = m.cv.cam.zoom.x
    var in_sv := (wp - cc) * z + Vector2(sv.size) * 0.5
    return in_sv * (Vector2(get_root().size) / Vector2(sv.size))

func enter(id: String) -> void:
    m.dialog.visible = false
    m.say_token += 1
    if m.state != id:
        m.switching = false
        m.ensure_canvas(id)
        if ui != null and ui.is_open():
            ui.hide_all()
        m._show_canvas(id)
        m._goto(id)
        await frames(4)
    m.dialog.visible = false
    m.cv.walking_enabled = true

## 屋里挡人的家具占地（占地中心站不了的才算）+ 四面墙（走路范围第一块）
func blockers(c) -> Array:
    var out: Array = []
    for it in c.cfg["items"]:
        if not it.has("rect"):
            continue
        var r: Array = it["rect"]
        var rr := Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))
        if rr.size.x < 2.0 or rr.size.y < 2.0:
            continue
        if not c._free(rr.get_center()):
            out.append(rr)
    return out

## 这一点所在的道：往左右量（家具占地边到边、墙到墙，像素）/ 往前后量。walls 是屋子走路范围外框
func gap_xy(bl: Array, walls: Rect2, q: Vector2) -> Vector2:
    var left := walls.position.x
    var right := walls.end.x
    var top := walls.position.y
    var bottom := walls.end.y
    for rr in bl:
        var r: Rect2 = rr
        if q.y >= r.position.y - 1.0 and q.y <= r.end.y + 1.0:
            if r.end.x <= q.x:
                left = maxf(left, r.end.x)
            elif r.position.x >= q.x:
                right = minf(right, r.position.x)
        if q.x >= r.position.x - 1.0 and q.x <= r.end.x + 1.0:
            if r.end.y <= q.y:
                top = maxf(top, r.end.y)
            elif r.position.y >= q.y:
                bottom = minf(bottom, r.position.y)
    return Vector2(right - left, bottom - top)

## 沿一条路的最窄过道（米，按家具占地量）：往南北走量左右那段（48 像素 = 1 米），往东西走量前后那段（32 像素 = 1 米）。路的头尾各 70 像素不算（家具跟前）
func aisle_min(bl: Array, walls: Rect2, path: Array) -> Array:
    var best := 99.0
    var at := Vector2.ZERO
    var total := 0.0
    for i in range(1, path.size()):
        total += (path[i] as Vector2).distance_to(path[i - 1])
    var run := 0.0
    for i in range(1, path.size()):
        var a: Vector2 = path[i - 1]
        var b: Vector2 = path[i]
        var seg := b - a
        var L := seg.length()
        if L < 1.0:
            continue
        var n := int(L / 8.0) + 1
        for k in n:
            var q: Vector2 = a + seg * (float(k) / float(n))
            var along := run + L * float(k) / float(n)
            if along < 70.0 or total - along < 70.0:
                continue
            var g := gap_xy(bl, walls, q)
            var wm: float = g.x / 48.0 if absf(seg.y) >= absf(seg.x) else g.y / 32.0
            if wm < best:
                best = wm
                at = q
        run += L
    return [best, at]

## 能站格子的净空：每 step 像素一个点，到最近一个不能站的点有多远（像素，chamfer 近似）。
## 不能站 = 家具占地往外各放 Ent.CLEAR 的挡人距离以后的范围，所以两件家具之间真正的通道宽 ≈ 2 × 净空半径 + 2 × Ent.CLEAR
func clearance_grid(c, walls: Rect2, step: float) -> Dictionary:
    var nx := int(walls.size.x / step) + 3
    var ny := int(walls.size.y / step) + 3
    var x0 := walls.position.x - step
    var y0 := walls.position.y - step
    var d := PackedFloat32Array()
    d.resize(nx * ny)
    for j in ny:
        for i in nx:
            d[j * nx + i] = 1.0e9 if c._free(Vector2(x0 + float(i) * step, y0 + float(j) * step)) else 0.0
    var dg := step * 1.4142
    for j in ny:
        for i in nx:
            var k := j * nx + i
            var v: float = d[k]
            if v == 0.0:
                continue
            if i > 0:
                v = minf(v, d[k - 1] + step)
            if j > 0:
                v = minf(v, d[k - nx] + step)
                if i > 0:
                    v = minf(v, d[k - nx - 1] + dg)
                if i < nx - 1:
                    v = minf(v, d[k - nx + 1] + dg)
            d[k] = v
    for j in range(ny - 1, -1, -1):
        for i in range(nx - 1, -1, -1):
            var k2 := j * nx + i
            var v2: float = d[k2]
            if v2 == 0.0:
                continue
            if i < nx - 1:
                v2 = minf(v2, d[k2 + 1] + step)
            if j < ny - 1:
                v2 = minf(v2, d[k2 + nx] + step)
                if i < nx - 1:
                    v2 = minf(v2, d[k2 + nx + 1] + dg)
                if i > 0:
                    v2 = minf(v2, d[k2 + nx - 1] + dg)
            d[k2] = v2
    return {"d": d, "nx": nx, "ny": ny, "x0": x0, "y0": y0, "step": step}

func _cell_of(cg: Dictionary, p: Vector2) -> Vector2i:
    return Vector2i(clampi(int(round((p.x - float(cg["x0"])) / float(cg["step"]))), 0, int(cg["nx"]) - 1), clampi(int(round((p.y - float(cg["y0"])) / float(cg["step"]))), 0, int(cg["ny"]) - 1))

## 从 from 走到 to，只走净空 ≥ t 的格子（头尾 exempt 像素以内不要求，那是家具跟前）能不能走通
func _reach(cg: Dictionary, from: Vector2, to: Vector2, t: float, exempt: float) -> bool:
    var d: PackedFloat32Array = cg["d"]
    var nx: int = cg["nx"]
    var ny: int = cg["ny"]
    var step: float = cg["step"]
    var a := _cell_of(cg, from)
    var b := _cell_of(cg, to)
    var seen := {a: true}
    var q: Array = [a]
    while not q.is_empty():
        var cur: Vector2i = q.pop_back()
        if cur == b:
            return true
        for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
            var n: Vector2i = cur + dv
            if n.x < 0 or n.y < 0 or n.x >= nx or n.y >= ny or seen.has(n):
                continue
            var dd: float = d[n.y * nx + n.x]
            if dd <= 0.0:
                continue
            var pos := Vector2(float(cg["x0"]) + float(n.x) * step, float(cg["y0"]) + float(n.y) * step)
            if dd >= t or pos.distance_to(from) <= exempt or pos.distance_to(to) <= exempt:
                seen[n] = true
                q.append(n)
    return false

## 从 from 到 to 最宽的那条路上最窄的一处，净空半径多大（像素）：二分找「能走通的最大门槛」
func bottleneck(cg: Dictionary, from: Vector2, to: Vector2, exempt: float) -> float:
    var lo := 0.0
    var hi := 200.0
    for it in 14:
        var mid := (lo + hi) * 0.5
        if _reach(cg, from, to, mid, exempt):
            lo = mid
        else:
            hi = mid
    return lo

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://test_r01_court.json"
    m.games_save.local_path = "user://test_r01_games.json"
    m.court_save.signed_in = true
    await m._enter_court()
    m.dialog.visible = false
    m.ensure_canvas("backhall")
    m.ensure_canvas("makeup")
    mk = m.areas["makeup"]
    ui = m.lounge_ui

    print("1 来回走通")
    await enter("backhall")
    var bh = m.backhall
    var to_mk: Vector2 = bh.points["to_makeup"]["pos"]
    var out_at: Vector2 = Vector2(float(bh.points["to_makeup"]["arrive"][0]), float(bh.points["to_makeup"]["arrive"][1]))
    var round_bad: Array = []
    for trip in 3:
        bh.reset_to(out_at + Vector2(0, 60))
        await walk_to(to_mk)
        var in_state: String = m.state
        var in_pos: Vector2 = m.cv.pos
        var in_ok: bool = in_state == "makeup" and in_pos.distance_to(mk.SPAWN) < 40.0 and mk._free(in_pos) and m.cv == mk
        tick(90)
        var stay_in: bool = m.state == "makeup"
        await walk_to(mk.points["to_backhall"]["pos"])
        var out_state: String = m.state
        var out_pos: Vector2 = m.cv.pos
        var out_ok: bool = out_state == "backhall" and out_pos.distance_to(out_at) < 60.0 and bh._free(out_pos)
        tick(90)
        var stay_out: bool = m.state == "backhall"
        if not (in_ok and stay_in and out_ok and stay_out):
            round_bad.append("第 %d 趟：进 %s %s（%s）、站稳 %s；出 %s %s（%s）、站稳 %s" % [trip + 1, in_state, str(in_pos), str(in_ok), str(stay_in), out_state, str(out_pos), str(out_ok), str(stay_out)])
    for x in round_bad:
        print("    ", x)
    check("后厅走廊 ⇄ 化妆间来回 3 趟：进屋站南门里边（%s 附近）、出来站走廊门口外（%s 附近）、各站稳 3 秒不弹回（%d 趟不对）" % [str(mk.SPAWN), str(out_at), round_bad.size()], round_bad.is_empty())

    print("2 后厅原来那间封了")
    bh = m.backhall
    var start: Vector2 = out_at
    var reach := 0
    var free_cells := 0
    var sample_ex := ""
    var x0 := OLD_ROOM.position.x
    while x0 < OLD_ROOM.end.x:
        var y0 := OLD_ROOM.position.y
        while y0 < OLD_ROOM.end.y:
            var q := Vector2(x0, y0)
            if bh._free(q):
                free_cells += 1
                var pth: Array = bh.find_path(start, q)
                if not pth.is_empty() and (pth[pth.size() - 1] as Vector2).distance_to(q) < 14.0:
                    reach += 1
                    if sample_ex == "":
                        sample_ex = str(q)
            y0 += 12.0
        x0 += 12.0
    var door_blocker := false
    for it in bh.cfg["items"]:
        if str(it.get("id", "")) == "makeup_door":
            door_blocker = true
    check("原来那间屋里（x 1195～1536、y 226～684）能站的点 %d 个，从走廊走得到的 %d 个（例 %s）；门洞挡人的占地在 %s" % [free_cells, reach, sample_ex, str(door_blocker)], reach == 0 and door_blocker)

    print("3 人")
    lf = mk.lives[0]
    var names: Array = lf.people.keys()
    await enter("makeup")
    ui.attach(lf)
    mk.reset_to(mk.SPAWN)
    tick(2)
    # 凳子、沙发
    var seats: Array = []
    for it in mk.cfg["items"]:
        var iid := str(it.get("id", ""))
        if iid.begins_with("stool") or iid.begins_with("fit_stool") or iid.begins_with("sofa") or iid.begins_with("pouf") or iid.begins_with("armchair"):   # 能坐的：化妆凳、试衣凳、沙发、圆墩、单人椅
            var r: Array = it["rect"]
            seats.append([iid, Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))])
    var sit_bad: Array = []
    var sit_info: Array = []
    for id in names:
        var p: Dictionary = lf.people[id]
        var foot: Vector2 = p["foot"]
        var best := 1e9
        var seat_id := ""
        for s in seats:
            var rr: Rect2 = s[1]
            var dx: float = maxf(maxf(rr.position.x - foot.x, 0.0), foot.x - rr.end.x)
            var dy: float = maxf(maxf(rr.end.y - foot.y, 0.0), foot.y - (rr.end.y + 12.0))   # 脚点该在座面前沿往南 0～12 像素
            var dd: float = Vector2(dx, dy).length()
            if dd < best:
                best = dd
                seat_id = str(s[0])
        sit_info.append("%s %s 脚 %s 离 %s %.1f" % [id, str(p["mode"]), str(foot), seat_id, best])
        if str(p["mode"]) == "sit" and best > 8.0:
            sit_bad.append("%s 坐着但脚点 %s 离最近的座位 %s 有 %.1f 像素（悬空）" % [id, str(foot), seat_id, best])
    print("    ", sit_info)
    var guest_ok: Array = []
    for n in mk.cfg["npcs"]:
        var nid := str(n["id"])
        if nid.begins_with("guest_"):
            var gp := Vector2(float(n["x"]), float(n["y"]))
            var best2 := 1e9
            for s in seats:
                var rr2: Rect2 = s[1]
                var dx2: float = maxf(maxf(rr2.position.x - gp.x, 0.0), gp.x - rr2.end.x)
                var dy2: float = maxf(maxf(rr2.end.y - gp.y, 0.0), gp.y - (rr2.end.y + 12.0))
                best2 = minf(best2, Vector2(dx2, dy2).length())
            if best2 > 8.0:
                guest_ok.append("%s 脚 %s 离座位 %.1f" % [nid, str(gp), best2])
    for x in sit_bad + guest_ok:
        print("    ", x)
    check("坐着的人脚点都在凳子 / 沙发上（≤ 8 像素；新娘、化妆师、助理 %d 处悬空；8 位静坐替身 %d 处悬空）" % [sit_bad.size(), guest_ok.size()], sit_bad.is_empty() and guest_ok.is_empty() and names.size() == 3)

    # 冒泡 60 秒：谁冒了
    var bub_ids := {}
    var guest_bub := 0
    for step in int(60.0 / DT):
        m.cv._process(DT)
        m._process(DT)
        if step % 10 == 0:
            for id in lf.bubbles.keys():
                bub_ids[str(id)] = true
    for id in bub_ids:
        if not (id in names):
            guest_bub += 1
    # 世界里所有叫 bubble 的节点：只在这三位头上
    var talk_ids: Array = []
    if mk.get("talkers") is Dictionary:
        talk_ids = (mk.talkers as Dictionary).keys()
    var guests_talkable: Array = talk_ids.filter(func(i): return str(i).begins_with("guest_"))
    check("60 秒冒过泡的 %s；八位静坐替身冒泡 %d 次、在能点的人里的 %d 位 %s" % [str(bub_ids.keys()), guest_bub, guests_talkable.size(), str(guests_talkable)], guest_bub == 0 and guests_talkable.is_empty() and bub_ids.size() >= 1)
    # 点替身的头：不开对话框
    ui.hide_all()
    m.dialog.visible = false
    mk.reset_to(mk.SPAWN)
    tick(2)
    var tap_bad: Array = []
    for n in mk.cfg["npcs"]:
        var nid2 := str(n["id"])
        if nid2.begins_with("guest_"):
            mk.walking_enabled = true
            mk.tap(mk.get_viewport().get_canvas_transform() * (Vector2(float(n["x"]), float(n["y"])) + Vector2(0, -50)))
            tick(3)
            if ui.talk_box.visible or ui.is_open():
                tap_bad.append("点 %s 开了对话框" % nid2)
                ui.hide_all()
            mk.path.clear()
            mk.reset_to(mk.SPAWN)
            tick(1)
    check("点八位静坐替身的头：都不开对话框（%d 处）" % tap_bad.size(), tap_bad.is_empty())

    # 7 段对话（化妆师 2 支、助理 2 支、新娘）：选项都走到底
    var dlg_bad: Array = []
    var pages := 0
    for id in names:
        var branches := 1
        for br in 3:
            ui.hide_all()
            mk.reset_to(mk.SPAWN)
            tick(1)
            ui.open_talk(str(id))
            for i in 300:
                await process_frame
                if ui.talk_box.visible and raw_line() != "":
                    break
            if not ui.talk_box.visible:
                dlg_bad.append("%s：对话框没开" % id)
                break
            var want_name: String = str(lf.data["people"][id]["title"])
            var opened_choice := false
            for page in 30:
                pages += 1
                if ui.name_label.text != want_name or raw_line() == "":
                    dlg_bad.append("%s 第 %d 页：名字牌「%s」、字「%s」" % [id, page + 1, ui.name_label.text, raw_line()])
                if ui.choices.visible:
                    var btns: Array = ui.choices.get_children()
                    branches = maxi(branches, btns.size())
                    opened_choice = true
                    (btns[mini(br, btns.size() - 1)] as Button).pressed.emit()
                else:
                    ui.next_line()
                    await frames(2)
                    if not ui.talk_box.visible:
                        break
            if ui.talk_box.visible:
                dlg_bad.append("%s 第 %d 条：30 页还没说完 / 没收" % [id, br + 1])
                ui.close_talk()
            if not ui.talk_box.visible and not mk.walking_enabled:
                dlg_bad.append("%s：说完没放开走路" % id)
            if not opened_choice and br > 0:
                break
        # 只在有选项的人身上走几条
    print("    共翻了 %d 页" % pages)
    check("三位的对话：每条选项都走到底、名字牌对、说完收、说完能走（%d 处不对 %s）" % [dlg_bad.size(), str(dlg_bad)], dlg_bad.is_empty() and pages >= 10)

    # 新娘：对话框没头像、身份卡没图、称呼「新娘」
    ui.hide_all()
    mk.reset_to(mk.SPAWN)
    tick(1)
    ui.open_talk("bride")
    for i in 300:
        await process_frame
        if ui.talk_box.visible and raw_line() != "":
            break
    var no_portrait: bool = ui.talk_box.visible and not ui.portrait.visible
    var nm: String = ui.name_label.text
    ui.open_card("bride")
    await frames(4)
    var card_img := false
    if ui.card != null:
        for n2 in ui.card.find_children("*", "TextureRect", true, false):
            if (n2 as TextureRect).texture != null and (n2 as TextureRect).visible:
                card_img = true
    var card_title_ok := false
    if ui.card != null:
        for n3 in ui.card.find_children("*", "Label", true, false):
            if (n3 as Label).text == "新娘":
                card_title_ok = true
    check("新娘：对话框头像不出（%s）、名字牌「%s」、身份卡有图 %s（要没有）、身份卡称呼「新娘」%s" % [str(no_portrait), nm, str(card_img), str(card_title_ok)], no_portrait and nm == "新娘" and not card_img and card_title_ok)
    ui.hide_all()

    # 助理走一圈
    var asst: Dictionary = lf.people["makeup_2"]
    var spots: Array = asst["spots"]
    var gap_hits := 0
    var left_home := false
    var back_t := -1.0
    var visited := {}
    var min_free_w := 99.0
    var min_at := Vector2.ZERO
    var bl0: Array = blockers(mk)
    var wp0: Array = mk.cfg["walk"][0]
    var walls0 := Rect2(float(wp0[0][0]), float(wp0[0][1]), float(wp0[1][0]) - float(wp0[0][0]), float(wp0[2][1]) - float(wp0[0][1]))
    var seen_stop: Array = []
    for mode in ["A 玩家站远处", "B 玩家站在第一个站点上"]:
        ui.hide_all()
        mk.reset_to(mk.SPAWN if mode.begins_with("A") else (spots[0] as Vector2) + Vector2(60, 0))
        (asst["legs"] as Array).clear()
        (asst["path"] as Array).clear()
        asst["foot"] = asst["home"]
        asst["wait"] = 0.1
        left_home = false
        back_t = -1.0
        for step in int(75.0 / DT):
            m.cv._process(DT)
            m._process(DT)
            var f: Vector2 = asst["foot"]
            for k in spots.size():
                if f.distance_to(spots[k]) < 2.0:
                    visited[k] = true
            if GAP.has_point(f):
                gap_hits += 1
            if f.distance_to(asst["home"]) > 12.0:
                left_home = true
                # 站点和路过处的过道宽：她占着的这一点左右 / 前后还剩多宽
                if step % 6 == 0:
                    var gg := gap_xy(bl0, walls0, f)
                    var ww: float = maxf(gg.x / 48.0, gg.y / 32.0)   # 两个方向里宽的那个是她站的那条道
                    if ww < min_free_w:
                        min_free_w = ww
                        min_at = f
            elif left_home and back_t < 0.0:
                back_t = float(step) * DT
        if mode.begins_with("A"):
            seen_stop.append("A：回原位 %.1f 秒" % back_t)
        else:
            seen_stop.append("B：回原位 %.1f 秒" % back_t)
    check("化妆助理走一圈（玩家站远处、站在第一个站点上各一遍）：站点 %d 个都到过（%d）、不进南墙门洞（%d 次）、走过的地方道宽最窄 %.1f 米（%s，要 ≥ 1.5）、%s" % [spots.size(), visited.size(), gap_hits, min_free_w, str(min_at), str(seen_stop)], visited.size() == spots.size() and gap_hits == 0 and min_free_w >= 1.5 and back_t > 0.0 and back_t < 60.0)

    print("4 换装点、过道")
    mk.reset_to(mk.SPAWN)
    tick(2)
    var dress: Vector2 = mk.points["dress"]["pos"]
    var dr: float = float(mk.points["dress"]["r"])
    var screen_r := Rect2()
    for it in mk.cfg["items"]:
        var nm2 := str((it.get("scale", {}) as Dictionary).get("name", "")) + str(it.get("id", ""))
        if nm2.contains("屏风") or nm2.contains("screen") or str(it.get("id", "")) == "fit_w":   # GPT 整间版没有屏风：换装点在西边试衣间（fit_w）南边
            var rr3: Array = it["rect"]
            screen_r = Rect2(float(rr3[0]), float(rr3[1]), float(rr3[2]) - float(rr3[0]), float(rr3[3]) - float(rr3[1]))
    var path_d: Array = mk.find_path(mk.SPAWN, dress)
    var reach_d: bool = not path_d.is_empty() and (path_d[path_d.size() - 1] as Vector2).distance_to(dress) <= dr + 2.0
    m.note_box.visible = false
    m.note_token += 1
    m.dialog.visible = false
    await walk_to(dress)
    var at_dress: float = mk.pos.distance_to(dress)
    var texts := ""
    if m.dialog.visible:
        texts += m.dialog_text.text
    if m.note_box.visible:
        texts += m.note.text
    var btn_txt: Array = []
    if m.backhall_ui != null:
        for bn in m.backhall_ui.find_children("*", "Button", true, false):
            if (bn as Button).is_visible_in_tree():
                btn_txt.append((bn as Button).text)
    texts += " 按钮" + str(btn_txt)
    var dev_text: bool = texts.contains("待") or texts.contains("预留") or texts.contains("TODO")
    check("换装点 %s（r %d）：屏风 %s，点在屏风南边 %s；从出生点走得到 %s；走到了离点 %.0f 像素、没有开发字样（提示 / 按钮「%s」）" % [str(dress), int(dr), str(screen_r), str(dress.y > screen_r.end.y if screen_r.size.y > 0.0 else "没找到屏风"), str(reach_d), at_dress, texts], reach_d and at_dress <= dr + 2.0 and screen_r.size.y > 0.0 and dress.y > screen_r.end.y and not dev_text and mk._free(dress))
    mk.reset_to(mk.SPAWN)
    tick(2)
    var targets: Array = []
    for sp in mk.cfg["stand_points"]:
        if str(sp["id"]).begins_with("makeup_artist"):
            continue   # 这两个是化妆师自己坐 / 站的家，在家具跟前，不是给玩家走的
        targets.append([str(sp["id"]), Vector2(float(sp["x"]), float(sp["y"]))])
    for it in mk.cfg["items"]:
        var iid2 := str(it.get("id", ""))
        if iid2.begins_with("stool_"):
            var r4: Array = it["rect"]
            targets.append([iid2 + "前", Vector2((float(r4[0]) + float(r4[2])) * 0.5, float(r4[3]) + 22.0)])
    targets.append(["换装点", dress])
    var wp: Array = mk.cfg["walk"][0]
    var walls_mk := Rect2(float(wp[0][0]), float(wp[0][1]), float(wp[1][0]) - float(wp[0][0]), float(wp[2][1]) - float(wp[0][1]))
    # 过道（01 H 10/4 的要求：至少 1.5 米；左右 48 像素 = 1 米）：量「从出生点走到每个点，最宽的那条路上最窄的一处」有多宽——
    # 不管 A* 挑哪条路、也不管花座这种小摆件，都按真能走的最好那条路量（旧办法按 A* 挑的路、又把贴着柜子的小花座当成一道墙，量不准）。
    # 通道宽 ≈ 2 × 净空半径 + 2 × Ent.CLEAR（格子是 6 像素一个点量的，有 ±0.1 米上下的误差）；头尾各 70 像素（家具跟前）不要求
    var cg: Dictionary = clearance_grid(mk, walls_mk, 6.0)
    var aisle_rows: Array = []
    var aisle_bad: Array = []
    var aisle_min_all := 99.0
    var unreach: Array = []
    for t in targets:
        var pth2: Array = mk.find_path(mk.SPAWN, t[1])
        if pth2.is_empty() or (pth2[pth2.size() - 1] as Vector2).distance_to(t[1]) > 16.0:
            unreach.append(str(t[0]))
            continue
        var bn: float = bottleneck(cg, mk.SPAWN, t[1], 70.0)
        var wm: float = (2.0 * bn + 2.0 * Ent.CLEAR) / 48.0
        aisle_rows.append("%s %.2f" % [str(t[0]), wm])
        aisle_min_all = minf(aisle_min_all, wm)
        if wm < 1.5:
            aisle_bad.append("%s：最宽的那条路最窄处约 %.2f 米" % [str(t[0]), wm])
    print("    各点最宽那条路的最窄处（米）：", aisle_rows)
    for x in aisle_bad + unreach:
        print("    ", x)
    check("从出生点走到 %d 个站点 / 凳子前 / 换装点：都走得到（%d 个走不到）、最宽那条路的最窄处 %.2f 米（要 ≥ 1.5）、不够的 %d 条" % [targets.size(), unreach.size(), aisle_min_all, aisle_bad.size()], unreach.is_empty() and aisle_bad.is_empty())
    # 首饰中岛两边的道直着穿一趟
    var island_ok := true
    var island_note := ""
    for it in mk.cfg["items"]:
        if str(it.get("id", "")).begins_with("island") or str(it.get("id", "")).begins_with("jewel"):
            var ri: Array = it["rect"]
            var left_x: float = float(ri[0]) - 28.0
            var right_x: float = float(ri[2]) + 28.0
            for px in [left_x, right_x]:
                var a2 := Vector2(px, float(ri[1]) - 24.0)
                var b2 := Vector2(px, float(ri[3]) + 24.0)
                if not (mk._free(a2) and mk._free(b2)):
                    continue
                var pp: Array = mk.find_path(a2, b2)
                var straight_len: float = a2.distance_to(b2)
                var plen := 0.0
                for i in range(1, pp.size()):
                    plen += (pp[i] as Vector2).distance_to(pp[i - 1])
                if pp.is_empty() or plen > straight_len * 1.25:
                    island_ok = false
                    island_note += "%s 旁 x=%d 绕了 %.0f（直线 %.0f） " % [str(it.get("id")), int(px), plen, straight_len]
    check("首饰中岛两边的道直着穿过去（路程不超过直线的 1.25 倍）：%s" % ("都直通" if island_ok else island_note), island_ok)

    print("6 走路不卡（我原来 test_makeup_check 管的那几样，搬到新屋重做）")
    # 6a 孤岛 + 窄道：把能站的点按 12 像素排成格子；「宽格」= 自己和八个邻居都能站（人身子要占三格）；
    #    从出生点只走宽格，到得了每个站点 / 凳子前 / 换装点 / 新娘跟前，就说明没有一格宽的窄道把它们隔开；另数孤岛（能站但从出生点走不到的格子）
    var STEP := 12.0
    var x_lo: float = walls_mk.position.x
    var y_lo: float = walls_mk.position.y
    var nx := int(walls_mk.size.x / STEP) + 1
    var ny := int(walls_mk.size.y / STEP) + 1
    var freeg := {}
    for ix in nx:
        for iy in ny:
            var q := Vector2(x_lo + float(ix) * STEP, y_lo + float(iy) * STEP)
            if mk._free(q):
                freeg[Vector2i(ix, iy)] = true
    var wide := {}
    for k in freeg:
        var okc := true
        for dx in [-1, 0, 1]:
            for dy in [-1, 0, 1]:
                if not freeg.has(Vector2i(k.x + dx, k.y + dy)):
                    okc = false
        if okc:
            wide[k] = true
    var from_c := Vector2i(int(round((mk.SPAWN.x - x_lo) / STEP)), int(round((mk.SPAWN.y - y_lo) / STEP)))
    # 出生点在南门里边，南门那一截本来就窄（走路范围第二块 68 宽），从屋里这头起算：南门内第一格宽格
    var seed_c := Vector2i(-1, -1)
    var bd := 1e9
    for k in wide:
        var d2: float = Vector2(float(k.x), float(k.y)).distance_to(Vector2(from_c))
        if d2 < bd:
            bd = d2
            seed_c = k
    var seen := {seed_c: true}
    var queue: Array = [seed_c]
    while not queue.is_empty():
        var cur: Vector2i = queue.pop_front()
        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
            var nb: Vector2i = cur + d
            if wide.has(nb) and not seen.has(nb):
                seen[nb] = true
                queue.append(nb)
    var islands := 0
    var seen_free := {}
    var q2: Array = [Vector2i(int(round((mk.SPAWN.x - x_lo) / STEP)), int(round((mk.SPAWN.y - y_lo) / STEP)))]
    if freeg.has(q2[0]):
        seen_free[q2[0]] = true
    while not q2.is_empty():
        var cur2: Vector2i = q2.pop_front()
        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
            var nb2: Vector2i = cur2 + d
            if freeg.has(nb2) and not seen_free.has(nb2):
                seen_free[nb2] = true
                q2.append(nb2)
    islands = freeg.size() - seen_free.size()
    var cut_off: Array = []
    for t in targets:
        var tp: Vector2 = t[1]
        var tc := Vector2i(int(round((tp.x - x_lo) / STEP)), int(round((tp.y - y_lo) / STEP)))
        var near_ok := false
        for dx in range(-4, 5):
            for dy in range(-4, 5):
                if seen.has(Vector2i(tc.x + dx, tc.y + dy)):
                    near_ok = true
        if not near_ok:
            cut_off.append(str(t[0]))
    print("    宽格（自己和八个邻居都能站）%d 个 / 能站 %d 个；只走宽格到不了的点 %s（通道窄，数在上面「最窄处」那条里判）" % [wide.size(), freeg.size(), str(cut_off)])
    check("能站的格子 %d 个，孤岛（能站但从出生点走不到）%d 个" % [freeg.size(), islands], islands == 0)
    # 6b 摇杆照寻路走：到每个点，卡住 2 秒算失败
    var stuck_bad: Array = []
    for t in targets:
        mk.reset_to(mk.SPAWN)
        mk.walking_enabled = true
        tick(2)
        var pth3: Array = mk.find_path(mk.SPAWN, t[1])
        var wi := 0
        var still := 0.0
        var done := false
        var last: Vector2 = mk.pos
        for step in int(90.0 / DT):
            if wi >= pth3.size():
                done = true
                break
            var wp3: Vector2 = pth3[wi]
            if mk.pos.distance_to(wp3) < 8.0:
                wi += 1
                continue
            mk.stick = (wp3 - mk.pos).normalized()
            m.cv._process(DT)
            m._process(DT)
            if mk.pos.distance_to(last) < 0.5:
                still += DT
            else:
                still = 0.0
            last = mk.pos
            if still > 2.0:
                break
        mk.stick = Vector2.ZERO
        if not done:
            stuck_bad.append("%s：摇杆走到第 %d / %d 个拐点卡住 %s" % [str(t[0]), wi, pth3.size(), str(mk.pos)])
        if m.state != "makeup":
            stuck_bad.append("%s：走着走着出了屋（%s）" % [str(t[0]), m.state])
            await enter("makeup")
    for x in stuck_bad:
        print("    ", x)
    check("摇杆照寻路从出生点走到 %d 个点：卡住的 %d 个" % [targets.size(), stuck_bad.size()], stuck_bad.is_empty())

    print("5 屋名框不压人")
    var cover: Array = []
    for sz in [Vector2i(540, 960), Vector2i(585, 1266)]:
        get_root().size = sz
        await frames(4)
        await enter("backhall")
        await enter("makeup")
        mk.reset_to(mk.SPAWN)
        await frames(6)
        var tb: Rect2 = m.room_title_box.get_global_rect() if m.room_title_box.visible else Rect2()
        if tb.size.x <= 0.0:
            cover.append("%s：屋名框没出来" % str(sz))
        for n in mk.cfg["npcs"]:
            var fp := Vector2(float(n["x"]), float(n["y"]))
            var sa: Vector2 = to_screen(fp + Vector2(-16, -70))
            var sb: Vector2 = to_screen(fp + Vector2(16, 0))
            var body := Rect2(sa, sb - sa).abs()
            if tb.size.x > 0.0 and tb.intersects(body):
                cover.append("%s：屋名框 %s 压 %s 的身子 %s" % [str(sz), str(tb), str(n["id"]), str(body)])
        # 玩家自己
        var pp2: Vector2 = to_screen(mk.pos)
        if tb.size.x > 0.0 and tb.intersects(Rect2(pp2.x - 16, pp2.y - 70, 32, 70)):
            cover.append("%s：压玩家自己" % str(sz))
    for x in cover:
        print("    ", x)
    get_root().size = Vector2i(540, 960)
    check("进屋第一眼（手机、长屏）：屋名框不压 11 个人的身子也不压自己（%d 处）" % cover.size(), cover.is_empty())

    DirAccess.remove_absolute("user://test_r01_court.json")
    DirAccess.remove_absolute("user://test_r01_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
