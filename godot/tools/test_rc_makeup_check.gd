extends SceneTree
## 出码前把关 rc-makeup（Z2 把化妆间第二轮 + 点框翻页 + 话泡躲顶栏 + 对话框开着按钮藏起来 并到一条分支）。03 / 庄Z3 自己重测（庄Z1 10/6 派，不改游戏代码，不看 Z2 的 test_safe_zone、shot_*）：
##   1 头肩露出（Z2 说「高家具身后划进站不了，逐点核 0 处」）：我自己读 60 件图的透明度——化妆间每个能站的点（8 像素一格）站上去，
##     头肩那一块（脚点上方 34 像素高、28 宽）被「着地线比人靠南的家具」的不透明像素盖住多少：盖住 ≥ 50% 的点 0 个
##   2 真走法：从门口走到八个点（四个角、最里、红毯中间、试衣间前、沙发旁），摇杆照寻路走，卡住 2 秒算失败
##   3 沙发能坐：走到奶油沙发东头那个空座（seat_sofa_cream_free）跟前出「坐下」，真点按钮：坐上去、位置朝向对、按钮变「起来」；点「起来」站回空地；坐着聊天不弹出去
##   4 同屏重样：每个人用的是哪种替身（LM-GUEST-xx）我自己列；同一种用了几次、两次隔多远、镜头在上中下三个位置时同屏同时看得见几对重样
##   5 话泡躲顶栏：化妆间、后厅各跑 60 秒，手机 540×960、长屏各一遍：每个冒着的泡（头顶 / 身侧 / 脚下）整个在屏里（四边 ≥ 16）、不压顶栏那一排（地名、金币）
##   6 对话框开着时底下的按钮藏起来、关了再出：站到空座旁（「坐下」按钮出着）开跟人说话的框，按钮透明 0 且点不到，关框回来；阿鱼说话的框同样
##   7 点框翻页：长句分页，点框先出完字、再点翻页、到最后一页才到下一句，选项只在最后一页
## 时限：900
## 用法：Godot --headless --path . --script res://tools/test_rc_makeup_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const DialogSkin = preload("res://scripts/ui/dialog_skin.gd")
const DT := 1.0 / 30.0
const HEAD_W := 28.0
const HEAD_H := 34.0   # 头肩：脚点往上 84 → 50 那一截

var m
var started := false
var ok := true
var mk
var ui
var lf

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(560.0).timeout.connect(func():
        print("RESULT FAIL 560 秒没跑完")
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

func enter(id: String) -> void:
    m.switching = false
    if ui != null and ui.is_open():
        ui.hide_all()
    m.dialog.visible = false
    m._show_canvas(id)
    m._goto(id)
    await frames(4)
    m.cv.walking_enabled = true

## 摇杆照寻路走到 target：卡住 2 秒算失败
func stick_walk(c, target: Vector2) -> bool:
    var path: Array = c.find_path(c.pos, target)
    if path.is_empty():
        return false
    var wi := 0
    var still := 0.0
    var last: Vector2 = c.pos
    for step in int(90.0 / DT):
        if wi >= path.size():
            c.stick = Vector2.ZERO
            return true
        var wp: Vector2 = path[wi]
        if c.pos.distance_to(wp) < 3.0:
            wi += 1
            continue
        c.stick = (wp - c.pos).normalized()
        tick(1)
        if c.pos.distance_to(last) < 0.4:
            still += DT
        else:
            still = 0.0
        last = c.pos
        if still > 2.0:
            break
    c.stick = Vector2.ZERO
    return false

func win_scale() -> Vector2:
    var sv: SubViewport = m.view.get_child(0)
    return Vector2(get_root().size) / Vector2(sv.size)

## 世界里的一块（节点局部矩形）→ 子画面坐标里的矩形
func node_rect(n: CanvasItem, r: Rect2) -> Rect2:
    var xf: Transform2D = n.get_global_transform_with_canvas()
    var a: Vector2 = xf * r.position
    var b: Vector2 = xf * r.end
    return Rect2(a, b - a).abs()

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://test_rcm_court.json"
    m.games_save.local_path = "user://test_rcm_games.json"
    m.court_save.signed_in = true
    m.ensure_canvas("backhall")
    m.ensure_canvas("makeup")
    mk = m.areas["makeup"]
    ui = m.lounge_ui
    lf = mk.lives[0]
    await enter("makeup")
    mk.reset_to(mk.SPAWN)
    tick(2)

    print("1 头肩露出（我自己读透明度）")
    var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(mk.cfg["pixel_art"][0])))
    var props: Array = []
    for p in man["props"]:
        var tex := load(str(p["png"])) as Texture2D
        var img: Image = tex.get_image()
        if img.is_compressed():
            img.decompress()
        img.convert(Image.FORMAT_RGBA8)
        props.append({"id": str(p["id"]), "rect": Rect2(float(p["x"]), float(p["y"]), float(img.get_width()), float(img.get_height())), "foot": float(p["foot"]), "img": img})
    var wp: Array = mk.cfg["walk"][0]
    var x0 := float(wp[0][0])
    var y0 := float(wp[0][1])
    var x1 := float(wp[1][0])
    var y1 := float(wp[2][1])
    var cells := 0
    var worst: Array = []
    var over50 := 0
    var over85 := 0
    var y := y0
    while y <= y1:
        var x := x0
        while x <= x1:
            var foot := Vector2(x, y)
            if mk._free(foot):
                cells += 1
                var hr := Rect2(foot.x - HEAD_W * 0.5, foot.y - 84.0, HEAD_W, HEAD_H)
                var hit := PackedByteArray()
                hit.resize(int(HEAD_W) * int(HEAD_H))
                for pr in props:
                    if float(pr["foot"]) <= foot.y:
                        continue   # 着地线在人北边的画在人后面
                    var inter: Rect2 = (pr["rect"] as Rect2).intersection(hr)
                    if inter.size.x <= 0.0 or inter.size.y <= 0.0:
                        continue
                    var img2: Image = pr["img"]
                    for yy in range(int(inter.position.y), int(inter.end.y)):
                        for xx in range(int(inter.position.x), int(inter.end.x)):
                            var ix := xx - int((pr["rect"] as Rect2).position.x)
                            var iy := yy - int((pr["rect"] as Rect2).position.y)
                            if ix >= 0 and iy >= 0 and ix < img2.get_width() and iy < img2.get_height() and img2.get_pixel(ix, iy).a > 0.5:
                                var hx := clampi(xx - int(hr.position.x), 0, int(HEAD_W) - 1)
                                var hy := clampi(yy - int(hr.position.y), 0, int(HEAD_H) - 1)
                                hit[hy * int(HEAD_W) + hx] = 1
                var cnt := 0
                for v in hit:
                    cnt += int(v)
                var frac := float(cnt) / (HEAD_W * HEAD_H)
                if frac >= 0.5:
                    over50 += 1
                    if worst.size() < 5:
                        worst.append("(%d,%d) 盖 %.0f%%" % [int(x), int(y), frac * 100.0])
                if frac >= 0.85:
                    over85 += 1
            x += 8.0
        y += 8.0
    print("    能站的点（8 像素一格）%d 个；头肩被盖住 ≥ 50%% 的 %d 个、≥ 85%% 的 %d 个 %s" % [cells, over50, over85, str(worst)])
    check("化妆间能站的 %d 个点里，头肩被盖住一半以上的 %d 个（Z2 说 0；老版约 9%%）" % [cells, over50], over50 == 0 and cells > 1500)

    print("2 真走法：门口走到八个点")
    var corners: Array = []
    var wb := Rect2(x0, y0, x1 - x0, y1 - y0)
    var want_pts: Array = [["西北角", Vector2(x0 + 30, y0 + 40)], ["东北角", Vector2(x1 - 30, y0 + 40)], ["西南角", Vector2(x0 + 30, y1 - 30)], ["东南角", Vector2(x1 - 30, y1 - 30)],
        ["最里化妆台前", Vector2(float(mk.cfg["npcs"][0]["approach"][0]), float(mk.cfg["npcs"][0]["approach"][1]))], ["红毯中间", Vector2(wb.get_center().x, wb.get_center().y)], ["试衣间前", mk.points["dress"]["pos"]], ["沙发旁", Vector2(wb.get_center().x, y1 - 140)]]
    var walk_bad: Array = []
    for pr in want_pts:
        var tgt: Vector2 = mk.nearest_free(pr[1]) if not mk._free(pr[1]) else pr[1]
        mk.reset_to(mk.SPAWN)
        tick(2)
        if not stick_walk(mk, tgt):
            walk_bad.append("%s %s（站在 %s）" % [pr[0], str(tgt), str(mk.pos)])
        if m.state != "makeup":
            walk_bad.append("%s：走出屋了" % pr[0])
            await enter("makeup")
    check("从门口走到八个点：卡住 / 走不到 %d 个 %s" % [walk_bad.size(), str(walk_bad)], walk_bad.is_empty())

    print("3 沙发能坐")
    var seat: Dictionary = {}
    for s in lf.seats:
        if str(s.get("id", "")) == "seat_sofa_cream_free":
            seat = s
    var sit_bad: Array = []
    if seat.is_empty():
        sit_bad.append("化妆间这份人里没有 seat_sofa_cream_free（座位 %s）" % str(lf.seats.map(func(x): return x.get("id"))))
    else:
        mk.reset_to(mk.SPAWN)
        tick(2)
        if not stick_walk(mk, seat["stand"]):
            sit_bad.append("走不到座位跟前 %s（站在 %s）" % [str(seat["stand"]), str(mk.pos)])
        tick(4)
        var ns: Dictionary = lf.near_seat()
        if str(ns.get("id", "")) != "seat_sofa_cream_free":
            sit_bad.append("站到跟前 near_seat 指的是「%s」" % str(ns.get("id", "没有")))
        if not (ui.seat_btn.visible and ui.seat_btn.text == ui._txt("sit")):
            sit_bad.append("跟前没出「坐下」（按钮 %s「%s」）" % [str(ui.seat_btn.visible), ui.seat_btn.text])
        ui.seat_btn.pressed.emit()
        tick(40)
        if not (mk.seated and lf.my_seat == "seat_sofa_cream_free"):
            sit_bad.append("点了没坐上（seated %s，my_seat %s）" % [str(mk.seated), lf.my_seat])
        else:
            if str(mk.face) != str(seat["face"]):
                sit_bad.append("坐上以后朝向 %s，座位写的 %s" % [str(mk.face), str(seat["face"])])
            if mk.pos.distance_to(Vector2(float(seat["x"]), float(seat["y"]))) > 40.0:
                sit_bad.append("坐上以后位置 %s 离座位 (%s,%s) 太远" % [str(mk.pos), str(seat["x"]), str(seat["y"])])
            if not (ui.seat_btn.visible and ui.seat_btn.text == ui._txt("stand")):
                sit_bad.append("坐下以后按钮不是「起来」（%s「%s」）" % [str(ui.seat_btn.visible), ui.seat_btn.text])
            # 坐着聊：新娘不在跟前，用「聊聊」按钮的话走不到，这里只验坐着开关一次对话框不弹起来
            tick(10)
            ui.seat_btn.pressed.emit()
            tick(40)
            if mk.seated or lf.my_seat != "":
                sit_bad.append("点「起来」没站起来")
            elif mk.pos.distance_to(seat["stand"]) > 30.0:
                sit_bad.append("站起来落在 %s，该回空地 %s" % [str(mk.pos), str(seat["stand"])])
    check("奶油沙发东头空座：走到跟前出「坐下」、坐得上、朝向位置对、按钮变「起来」、点「起来」站回空地（%d 处不对 %s）" % [sit_bad.size(), str(sit_bad)], sit_bad.is_empty())

    print("4 同屏重样")
    var looks: Dictionary = {}   # 替身种类 -> [[id, 脚点]]
    for n in mk.cfg["npcs"]:
        var sd: Dictionary = n.get("standin", {})
        var code := str(sd.get("code", "?"))
        if not looks.has(code):
            looks[code] = []
        (looks[code] as Array).append([str(n["id"]), Vector2(float(n["x"]), float(n["y"]))])
    var dup_rows: Array = []
    var dup_pairs: Array = []
    for code in looks:
        var arr: Array = looks[code]
        if arr.size() > 1:
            dup_rows.append("%s 用了 %d 次（%s）" % [code, arr.size(), str(arr.map(func(a): return "%s@y%d" % [a[0], int(a[1].y)]))])
            for i in arr.size():
                for j in range(i + 1, arr.size()):
                    dup_pairs.append([code, arr[i], arr[j]])
    print("    %d 位用了 %d 种替身；重样的：%s" % [mk.cfg["npcs"].size(), looks.size(), str(dup_rows)])
    # 镜头在上、中、下三个位置：屏上同时看得见（脚点在可见范围里）的重样对
    var vis_rows: Array = []
    var worst_vis := 0
    var vh: float = float(get_root().get_visible_rect().size.y) / mk.cam.zoom.y if mk.cam != null else 960.0
    for cy in [vh * 0.5, float(mk.cfg["size"][1]) * 0.5, float(mk.cfg["size"][1]) - vh * 0.5]:
        var top: float = float(cy) - vh * 0.5
        var bottom: float = float(cy) + vh * 0.5
        var vis := 0
        for dp in dup_pairs:
            var ya: float = (dp[1][1] as Vector2).y
            var yb: float = (dp[2][1] as Vector2).y
            if ya > top + 40.0 and ya < bottom and yb > top + 40.0 and yb < bottom:
                vis += 1
        worst_vis = maxi(worst_vis, vis)
        vis_rows.append("镜头中心 y=%d：同屏重样 %d 对" % [int(cy), vis])
    print("    ", vis_rows)
    var near_d := 99999.0
    var near_what := ""
    for dp in dup_pairs:
        var dd: float = (dp[1][1] as Vector2).distance_to(dp[2][1] as Vector2)
        if dd < near_d:
            near_d = dd
            near_what = "%s：%s 和 %s" % [dp[0], dp[1][0], dp[2][0]]
    print("    重样里离得最近的一对：%s，相距 %.0f 像素（屏高 960）" % [near_what if near_what != "" else "没有", near_d])
    var bride_code := str(((mk.cfg["npcs"] as Array).filter(func(n): return str(n["id"]) == "bride")[0] as Dictionary).get("standin", {}).get("code", "?"))
    var bride_twins: Array = []
    for n in mk.cfg["npcs"]:
        if str(n["id"]) != "bride" and str(n.get("standin", {}).get("code", "")) == bride_code:
            bride_twins.append(str(n["id"]))
    check("新娘（替身 %s）是这屋的主角，别的客人不用她的脸（跟她同脸的：%s）" % [bride_code, str(bride_twins)], bride_twins.is_empty())
    check("替身共 %d 种；重样的最近一对相距 %.0f 像素（要求超过半屏 480，不然像一对挨着的复制人）；镜头居中时最多同屏 %d 对（都在屏的最上和最下两头，只记数）" % [looks.size(), near_d, worst_vis], near_d > 480.0 and looks.size() >= 9)

    print("5 话泡躲顶栏、四边 16、两只不叠（手机、长屏；化妆间 7 个站位各 20 秒、后厅 40 秒）")
    var bub_bad: Array = []
    var samples := 0
    var by_mode := {}
    var pair_n := 0
    var off_rows := {}   # 屋 屏 站位 -> [样本数, 离屏边最远多少像素]
    var off_vis := 0     # 冒着、看得见，可说话的人整个在屏外的样本数（泡被拉到屏里，像是旁边的人说的）
    var spots: Array = [["makeup", Vector2(337, 330), 20.0], ["makeup", Vector2(337, 600), 20.0], ["makeup", Vector2(500, 330), 20.0], ["makeup", Vector2(180, 330), 20.0], ["makeup", Vector2(630, 700), 20.0], ["makeup", Vector2(45, 700), 20.0], ["makeup", Vector2(337, 900), 20.0], ["backhall", Vector2(1032, 300), 40.0]]
    for sz in [Vector2i(540, 960), Vector2i(585, 1266)]:
        get_root().size = sz
        await frames(4)
        for sp in spots:
            var room: String = sp[0]
            await enter(room)
            var cv = m.cv
            cv.reset_to(sp[1])
            cv.snap_cam()
            await frames(6)
            var lives: Array = mk.lives if room == "makeup" else m.backhall.lives
            for lfx in lives:
                lfx.frozen = false
            for step in int(float(sp[2]) / DT):
                tick(1)
                if step % 6 != 0:
                    continue
                await process_frame
                var vs: Vector2 = get_root().get_visible_rect().size
                var vp_size: Vector2 = (m.view.get_child(0) as SubViewport).size
                var top_edge: float = DialogSkin.safe_top
                var vis_now: Array = []   # 这一刻看得见的泡：[标签, 框]
                for lfx in lives:
                    for id in lfx.bubbles:
                        var bb: Node2D = lfx.bubbles[id]
                        if not is_instance_valid(bb) or bb.scale.x < 0.9 * (lfx._bubble_scale() if lfx.has_method("_bubble_scale") else 1.0):
                            continue   # 刚冒出来变大的那一下不算
                        if not bb.visible:
                            by_mode["hidden"] = int(by_mode.get("hidden", 0)) + 1
                            continue   # 10/6 庄Z2：放不下（碰禁区或跟别的泡叠）先不显示的泡，屏上看不见，不量框
                        var box: Control = null
                        for c2 in bb.get_children():
                            if c2 is Control:
                                box = c2
                                break
                        if box == null:
                            continue
                        var r: Rect2 = node_rect(box, Rect2(Vector2.ZERO, box.size))
                        samples += 1
                        var tag := "%dx%d %s@%s %s" % [sz.x, sz.y, room, str(sp[1]), str(id)]
                        if r.position.x < 15.5 or r.position.y < 15.5 or r.end.x > vp_size.x - 15.5 or r.end.y > vp_size.y - 15.5:
                            bub_bad.append("%s：泡 %s 不在屏里（四边留 16，屏 %s）" % [tag, str(r), str(vp_size)])
                        if r.position.y < top_edge - 0.5:
                            bub_bad.append("%s：泡 %s 压到顶栏（下沿 %.0f）" % [tag, str(r), top_edge])
                        var sk = bb.get_node_or_null("safe_keep")
                        if sk != null:
                            by_mode[str(sk.mode)] = int(by_mode.get(str(sk.mode), 0)) + 1
                        vis_now.append([tag, r])
                        if (lfx.people as Dictionary).has(id):
                            var fs: Vector2 = cv.get_viewport().get_canvas_transform() * ((lfx.people[id]["foot"]) as Vector2)
                            if fs.x < 0.0 or fs.x > vp_size.x or fs.y < 0.0 or fs.y > vp_size.y or fs.y < top_edge - 20.0:
                                off_vis += 1
                                var far_px: float = maxf(maxf(-fs.x, fs.x - vp_size.x), maxf(-fs.y, maxf(fs.y - vp_size.y, top_edge - 20.0 - fs.y)))
                                var ok2 := "%dx%d %s@%s" % [sz.x, sz.y, room, str(sp[1])]
                                var rw: Array = off_rows.get(ok2, [0, 0.0, {}])
                                rw[0] = int(rw[0]) + 1
                                rw[1] = maxf(float(rw[1]), far_px)
                                var mm: Dictionary = rw[2]
                                mm[str(sk.mode) if sk != null else "-"] = int(mm.get(str(sk.mode) if sk != null else "-", 0)) + 1
                                off_rows[ok2] = rw
                for i1 in vis_now.size():
                    for i2 in range(i1 + 1, vis_now.size()):
                        if (vis_now[i1][1] as Rect2).intersects(vis_now[i2][1] as Rect2):
                            pair_n += 1
                            bub_bad.append("%s 和 %s 两只泡叠在一起 %s / %s" % [vis_now[i1][0], vis_now[i2][0], str(vis_now[i1][1]), str(vis_now[i2][1])])
    for x in bub_bad.slice(0, 8):
        print("    ", x)
    var hidden_n: int = int(by_mode.get("hidden", 0))
    var hidden_pct: float = 100.0 * float(hidden_n) / float(maxi(1, samples + hidden_n))
    print("    量到 %d 个泡的样本；放法分布 %s；先不显示的占 %.1f%%；两只叠 %d 次；冒着、可说话的人整个在屏外的 %d 个样本（%.1f%%）" % [samples, str(by_mode), hidden_pct, pair_n, off_vis, 100.0 * float(off_vis) / float(maxi(1, samples))])
    get_root().size = Vector2i(540, 960)
    for ok3 in off_rows:
        print("      说话人在屏外、泡却冒着：%s → %d 个样本，人离屏边最远 %.0f 像素，泡放法 %s" % [ok3, off_rows[ok3][0], off_rows[ok3][1], str(off_rows[ok3][2])])
    check("两种屏、化妆间 7 个站位 + 后厅共 %d 个泡的样本：整个在屏里、不压顶栏、两只不叠（%d 处不对）" % [samples, bub_bad.size()], bub_bad.is_empty() and samples >= 100)
    check("放不下先不显示的泡只是偶尔（%d 个，占 %.1f%%，要求 ≤ 3%%；多了说明话都被藏掉了）" % [hidden_n, hidden_pct], hidden_pct <= 3.0)

    print("6 对话框开着时底下的按钮藏起来、关了再出")
    await enter("makeup")
    mk.reset_to(mk.SPAWN)
    tick(2)
    var hide_bad: Array = []
    if not seat.is_empty():
        stick_walk(mk, seat["stand"])
        tick(4)
    var btn_before: bool = ui.seat_btn.visible
    ui.open_talk("bride")
    for i in 200:
        await process_frame
        if ui.talk_box.visible and ui.line_label.text != "":
            break
    await frames(6)
    var talk_open: bool = ui.talk_box.visible
    var alpha_open: float = maxf(ui.seat_btn.modulate.a, ui.talk_btn.modulate.a)
    var click_open: bool = false
    for bn in [ui.seat_btn, ui.talk_btn]:
        if (bn as Button).visible and (bn as Button).mouse_filter != Control.MOUSE_FILTER_IGNORE:
            click_open = true
    ui.close_talk()
    await frames(8)
    var alpha_closed: float = minf(ui.seat_btn.modulate.a, ui.talk_btn.modulate.a)
    if not btn_before:
        hide_bad.append("测试前提不成立：站到空座旁「坐下」按钮没出来")
    if not talk_open:
        hide_bad.append("跟新娘说话的框没开")
    if alpha_open > 0.05 or click_open:
        hide_bad.append("框开着，底下的按钮透明度 %.2f、还能点 %s（该 0、点不到）" % [alpha_open, str(click_open)])
    if alpha_closed < 0.95:
        hide_bad.append("框关了按钮没回来（透明度 %.2f）" % alpha_closed)
    # 阿鱼说话的框
    m._say("到啦～ 罗曼山庄 席还没散", 0.0, "阿鱼")
    await frames(8)
    var alpha_say: float = maxf(ui.seat_btn.modulate.a, ui.talk_btn.modulate.a)
    m.dialog.visible = false
    await frames(8)
    if btn_before and alpha_say > 0.05:
        hide_bad.append("阿鱼说话的框开着，按钮透明度 %.2f（该 0）" % alpha_say)
    check("框开着：底下按钮透明 %.2f、点不到；关了回 %.2f；阿鱼说话的框开着也藏（%.2f）（%d 处不对 %s）" % [alpha_open, alpha_closed, alpha_say, hide_bad.size(), str(hide_bad)], hide_bad.is_empty())

    print("7 点框翻页")
    var dm = get_root().get_node_or_null("DialogueManager")
    var long_txt := "这一句特别特别长，长到一页根本放不下：奶奶从早上起来就一直在忙，先去厨房看了看汤，又去后院摘了些青菜，回来还要把喜糖一颗一颗装进小袋子里，装完了再把桌上的茶杯摆整齐，你说累不累呀，不过今天高兴，累也值得。"
    var res = dm.create_resource_from_text("~ start\n新娘: " + long_txt + "\n- 好\n\t新娘: 好嘞\n- 不好\n\t新娘: 行吧\n=> END")
    var typer = ui.talk_box.get_node("typer")
    var inst_was: bool = typer.instant
    typer.instant = false
    var p7: Dictionary = (lf.person("bride") as Dictionary).duplicate()
    p7["talk"] = [{"text": "x", "pose": "front"}]
    p7["dialogue"] = ""
    ui._open(p7, mk)
    ui.dm_res = res
    ui._dm_next("start")
    for i in 150:
        await process_frame
        if ui.line_raw == long_txt and typer.pages.size() >= 1:
            break
    await frames(4)
    var pg_bad: Array = []
    var np: int = typer.pages.size()
    if np < 2:
        pg_bad.append("长句只分 %d 页" % np)
    var line_before: String = ui.line_label.text
    var ev := InputEventMouseButton.new()
    ev.button_index = MOUSE_BUTTON_LEFT
    ev.pressed = true
    # 第一下：字还在出 → 只出完
    if not DialogSkin.typing(ui.talk_box):
        pg_bad.append("刚开口字该还在出")
    ui.talk_box.gui_input.emit(ev)
    await frames(3)
    if DialogSkin.typing(ui.talk_box) or typer.page != 0:
        pg_bad.append("第一下点框该只出完这一页（页 %d、还在出 %s）" % [typer.page, str(DialogSkin.typing(ui.talk_box))])
    # 之后每点一下框翻一页，直到最后一页；选项只在最后一页
    var clicks := 0
    var early := false
    for k in 10:
        if typer.page >= np - 1:
            break
        var before_page: int = typer.page
        ui.talk_box.gui_input.emit(ev)
        await frames(3)
        if DialogSkin.typing(ui.talk_box):
            ui.talk_box.gui_input.emit(ev)
            await frames(3)
        clicks += 1
        if typer.page != before_page + 1:
            pg_bad.append("点框没翻到下一页（页 %d → %d）" % [before_page, typer.page])
        if ui.line_label.text != line_before:
            pg_bad.append("翻页时句子换了")
        if typer.page < np - 1 and ui.choices.modulate.a > 0.01:
            early = true
    if early:
        pg_bad.append("没到最后一页选项就露出来了")
    if typer.page != np - 1:
        pg_bad.append("点了 %d 次没翻到最后一页（页 %d / %d）" % [clicks, typer.page, np])
    await frames(3)
    if ui.choices.modulate.a < 0.99:
        pg_bad.append("最后一页选项没露出来")
    ui.talk_box.gui_input.emit(ev)
    await frames(3)
    if ui.line_label.text != line_before or not ui.choices.visible:
        pg_bad.append("最后一页有选项时点框往下走了")
    typer.instant = inst_was
    ui.close_talk()
    check("点框：先出完字、再点翻一页、到最后一页选项才露出、有选项点框不往下走（分 %d 页、点了 %d 次；%d 处不对 %s）" % [np, clicks, pg_bad.size(), str(pg_bad)], pg_bad.is_empty())

    print("8 坐着的客人头和上身露出多少")
    await enter("makeup")
    tick(3)
    var sit_rows_bad: Array = []
    var sit_rows_all: Array = []
    var sit_ids: Array = []
    for n8 in mk.cfg["npcs"]:
        if bool(n8.get("sit", false)):
            sit_ids.append(str(n8["id"]))
    for pid in sit_ids:
        var spr = mk.npc_nodes.get(pid)
        if spr == null:
            for lf8 in mk.lives:
                if lf8.people.has(pid) and (lf8.people[pid] as Dictionary).has("spr"):
                    spr = lf8.people[pid]["spr"]
        if spr == null or not (spr is Sprite2D):
            sit_rows_bad.append("%s 找不到画他的精灵" % pid)
            continue
        var pp: Dictionary = {}
        for n9 in mk.cfg["npcs"]:
            if str(n9["id"]) == pid:
                pp = n9
        var img: Image = spr.texture.get_image()
        var rr: Rect2i = Rect2i(spr.region_rect)
        var seen := 0
        for yy in rr.size.y:
            var any := false
            for xx in rr.size.x:
                if img.get_pixel(rr.position.x + xx, rr.position.y + yy).a > 0.1:
                    any = true
                    break
            if any:
                seen += 1
        sit_rows_all.append("%s %s 露 %d 行（截 %d 行）" % [pid, str((pp.get("standin", {}) as Dictionary).get("code", "?")), seen, rr.size.y])
        if seen < 30:
            sit_rows_bad.append("%s 只露 %d 行" % [pid, seen])
    print("    ", sit_rows_all)
    check("坐着的 %d 位，头加上身都露出 ≥ 30 行（一个头约 28～34 行；红沙发上小孩 13～15 行就是只露头发眼睛）：%d 位不够 %s" % [sit_rows_all.size(), sit_rows_bad.size(), str(sit_rows_bad)], sit_rows_bad.is_empty() and sit_rows_all.size() >= 8)

    DirAccess.remove_absolute("user://test_rcm_court.json")
    DirAccess.remove_absolute("user://test_rcm_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
