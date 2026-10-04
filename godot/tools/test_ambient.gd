extends SceneTree
## 验收：场景动效公共架子 + 宴会厅宫灯呼吸（05 10/4，清单 回执/动效清单-1004.md）。无界面跑整个 main.gd：
## 1 宴会厅挂上了动效，20 盏宫灯都找到，光心在每盏灯图上 (24,40)（灯罩正中），一个节点一次画完、加法混合
## 2 像素光：每格全不透明或全透明、只用那几档暖色、外边棋盘格点；亮中暗整档换，各盏错开；全关停在中档
## 3 降级：连续 3 秒低于 50 帧降一档，低于 40 帧全关，连续 10 秒 58 帧以上升一档；强制开关
## 4 切到别的画布，宴会厅的动效停（不跑 _process）
## 5 配置里没写的场景不挂（迎宾院现在没有）
## 用法：Godot --headless --path . --script res://tools/test_ambient.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const Ambient = preload("res://scripts/ambient/ambient.gd")

var m
var ok := true

func _initialize() -> void:
    run()

func check(name: String, cond: bool) -> void:
    print(("  好 " if cond else "  不行 ") + name)
    ok = ok and cond

func run() -> void:
    await process_frame
    m = Main.new()
    m.fast = true
    root.add_child(m)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    var hall = m.hall
    var amb = hall.get_node_or_null("ambient")
    check("宴会厅挂上了动效", amb != null)
    if amb == null:
        print("RESULT FAIL")
        quit(1)
        return
    var lg = amb.get_child(0) if amb.get_child_count() > 0 else null
    check("挂了 1 样（宫灯呼吸）", amb.get_child_count() == 1 and lg != null and lg.points.size() == 20)
    var want: Array = []
    for o in hall.cfg["occluders"]:
        if str(o.get("image", "")).get_file() == "art_lantern.png":
            want.append(Vector2(float(o["x"]) + 24.0, float(o["y"]) + 40.0))
    check("20 盏光心都在灯罩正中（零件左上角 + (24,40)）", want.size() == 20 and lg.points == want)
    check("加法混合、压在零件上面一点（z 1）、整格不插值", lg.material is CanvasItemMaterial and lg.material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD and lg.z_index == 1 and lg.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
    # 像素光：每格全不透明或全透明，颜色只用那几档；中心最亮，外边一格隔一格
    var hard := true
    var only_tiers := true
    var allowed := []
    for c in lg.tiers:
        allowed.append(Color8(int(c[0]), int(c[1]), int(c[2]), 255))
    for tx in lg.texs:
        var img: Image = tx.get_image()
        for y in img.get_height():
            for x in img.get_width():
                var px := img.get_pixel(x, y)
                if px.a8 != 0 and px.a8 != 255:
                    hard = false
                if px.a8 == 255 and not allowed.has(px):
                    only_tiers = false
    check("光圈每格要么全不透明要么全透明（没有半透明）", hard)
    check("光圈只用那几档暖色", only_tiers)
    var big: Image = lg.texs[0].get_image()
    var hc: int = lg.half
    check("中心是最亮那档", big.get_pixel(hc, hc) == allowed[allowed.size() - 1])
    var r0: int = int(lg.sizes[0][0])
    check("最外圈边上一格隔一格（棋盘格点）", big.get_pixel(hc + r0, hc).a8 != big.get_pixel(hc + r0, hc + 1).a8)
    check("光心是整数格", lg.points.all(func(p): return p == p.round()))
    # 一明一暗：整档换，亮 → 中 → 暗 → 中
    Ambient.set_forced(-1)
    var seen := {}
    var changes := 0
    var last := -1
    for k in 400:
        var sz: int = lg.size_of(0, k * 0.05)
        seen[sz] = true
        if last >= 0 and sz != last:
            changes += 1
        last = sz
    check("一盏灯三种大小都轮到（%d 种）" % seen.size(), seen.size() == 3)
    check("20 秒里换档 %d 次（每档 0.8～1.15 秒）" % changes, changes >= 17 and changes <= 26)
    var differ := false
    for k in 40:
        if lg.size_of(0, k * 0.25) != lg.size_of(1, k * 0.25):
            differ = true
    check("各盏不同步", differ)
    # 降级
    Ambient.set_forced(-1)
    for i in 3: Ambient.step(45.0)
    check("连续 3 秒 45 帧：降到 1 档", Ambient.level == 1)
    for i in 3: Ambient.step(35.0)
    check("连续 3 秒 35 帧：全关", Ambient.level == 0)
    check("全关：停在中档", lg.size_of(3, 7.7) == 1 and lg.size_of(5, 2.2) == 1)
    for i in 9: Ambient.step(60.0)
    check("9 秒 60 帧：还不升", Ambient.level == 0)
    Ambient.step(60.0)
    check("10 秒 60 帧：升一档", Ambient.level == 1)
    for i in 10: Ambient.step(60.0)
    check("再 10 秒：全开", Ambient.level == 2)
    Ambient.step(30.0)
    Ambient.step(60.0)
    Ambient.step(30.0)
    check("偶尔一秒掉帧不降", Ambient.level == 2)
    Ambient.set_forced(0)
    for i in 20: Ambient.step(60.0)
    check("强制关：帧数再好也不开", Ambient.level == 0)
    Ambient.set_forced(-1)
    check("恢复自动：全开", Ambient.level == 2)
    # 切画布
    m._show_canvas("banquet")
    await process_frame
    check("在宴会厅：动效在跑", amb.can_process())
    m._show_canvas("court")
    await process_frame
    check("切到迎宾院：宴会厅的动效停", not amb.can_process())
    check("迎宾院配置里没写，不挂", m.court.get_node_or_null("ambient") == null)
    print("RESULT PASS" if ok else "RESULT FAIL")
    quit(0 if ok else 1)
