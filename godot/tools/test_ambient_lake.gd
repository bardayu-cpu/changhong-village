extends SceneTree
## 验收：湖边动效（05 10/4，01 H 派：只上湖面波光 + 小船起伏）。无界面跑整个 main.gd，进湖边：
## 1 东西两块水面各挂一块波光，贴在那张像素画背景后面一个（背景上面、人和船下面），范围是背景上 (0,300) 起 1536×486，整格不插值
## 2 波光换的两对颜色都是那张背景水面上本来有的颜色（不新加颜色）；亮一档的颜色比原色亮
## 3 五条船都找到；每条只在原位和往上 1 像素之间换，换的是图（offset），着地线（position.y）不动；各条不同步
## 4 档位：1 档波光亮的机会减半；0 档波光藏掉、船回原位；恢复后照常
## 5 切到别的画布，湖边的动效停
## 用法：Godot --headless --path . --script res://tools/test_ambient_lake.gd
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

func frames(n: int) -> void:
    for i in n:
        await process_frame

func run() -> void:
    await process_frame
    m = Main.new()
    m.fast = true
    root.add_child(m)
    for i in 1200:
        if m.state == "title":
            break
        await process_frame
    m.ensure_canvas("lake")
    m._show_canvas("lake")
    await frames(3)
    var lk = m.lake
    var amb = lk.get_node_or_null("ambient")
    check("湖边挂上了动效", amb != null)
    if amb == null:
        print("RESULT FAIL")
        quit(1)
        return
    check("挂了 3 样（两块波光、船）", amb.effects.size() == 3)
    var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ambient.json"))["scene_luoman_lake"]
    for half in ["west", "east"]:
        var bg: Sprite2D = lk.find_child("px_background_lake_" + half, true, false)
        var wg: Sprite2D = lk.find_child("water_glint_" + half, true, false)
        check("%s：有背景、有波光" % half, bg != null and wg != null)
        if bg == null or wg == null:
            continue
        check("%s：波光紧贴在背景后面一个（同一层）" % half, wg.get_parent() == bg.get_parent() and wg.get_index() == bg.get_index() + 1)
        check("%s：波光在人和零件下面（地面层）" % half, wg.get_parent().z_index < 0)
        check("%s：范围 = 背景上 (0,300) 起 1536×486" % half, wg.region_enabled and wg.region_rect == Rect2(0, 300, 1536, 486) and wg.position == bg.position + Vector2(0, 300))
        check("%s：整格不插值、跟背景同一张图" % half, wg.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and wg.texture == bg.texture)
        # 颜色：两对都是这张图水面上本来有的颜色
        var img: Image = bg.texture.get_image()
        var seen := {}
        for y in range(300, 786, 3):
            for x in range(0, 1536, 3):
                seen[img.get_pixel(x, y).to_html(false)] = true
        var all_in := true
        var brighter := true
        for pair in cfg["water_glint"][0]["map"]:
            var a := Color8(int(pair[0][0]), int(pair[0][1]), int(pair[0][2]))
            var b := Color8(int(pair[1][0]), int(pair[1][1]), int(pair[1][2]))
            if not seen.has(a.to_html(false)) or not seen.has(b.to_html(false)):
                all_in = false
            if b.get_luminance() <= a.get_luminance():
                brighter = false
        check("%s：换的颜色都是这张图水面上本来有的" % half, all_in)
        check("%s：换成的颜色比原色亮一档" % half, brighter)
    # 船
    var bb = null
    for e in amb.effects:
        if e.get("boats") != null:
            bb = e
    check("五条船都找到", bb != null and bb.boats.size() == 5)
    if bb != null:
        Ambient.set_forced(-1)
        var only01 := true
        var both := true
        for i in bb.boats.size():
            var seen := {}
            for k in 200:
                var v: int = bb.lift_of(i, k * 0.05)
                seen[v] = true
                if v != 0 and v != 1:
                    only01 = false
            if seen.size() != 2:
                both = false
        check("每条船只在原位和往上 1 像素之间换", only01 and both)
        var differ := false
        for k in 40:
            if bb.lift_of(0, k * 0.2) != bb.lift_of(4, k * 0.2):
                differ = true
        check("各条不同步", differ)
        var s: Sprite2D = bb.boats[0]["s"]
        var foot := s.position.y
        var y0: float = bb.boats[0]["y"]
        var offs := {}
        for k in 60:
            bb._process(0.1)
            offs[s.offset.y] = true
        check("挪的是图（offset 只有 %s），着地线不动" % str(offs.keys()), offs.size() == 2 and offs.has(y0) and offs.has(y0 - 1.0) and s.position.y == foot)
        # 全关：船回原位
        Ambient.set_forced(0)
        for k in 10:
            bb._process(0.1)
        var back := true
        for b in bb.boats:
            if b["s"].offset.y != b["y"]:
                back = false
        check("全关：船都回原位", back)
    # 波光档位
    var wgw: Sprite2D = lk.find_child("water_glint_west", true, false)
    if wgw != null:
        var d0 := float(cfg["water_glint"][0]["density"])
        Ambient.set_forced(0)
        wgw._process(0.1)
        check("全关：波光藏掉", not wgw.visible)
        Ambient.set_forced(-1)
        Ambient.level = 1
        wgw._process(0.1)
        check("1 档：波光在、亮的机会减半", wgw.visible and is_equal_approx(float(wgw.material.get_shader_parameter("density")), d0 * 0.5))
        Ambient.set_forced(-1)
        wgw._process(0.1)
        check("恢复全开：照常", wgw.visible and is_equal_approx(float(wgw.material.get_shader_parameter("density")), d0))
    # 切画布
    check("在湖边：动效在跑", amb.can_process() and (wgw == null or wgw.can_process()))
    m._show_canvas("court")
    await process_frame
    check("切到迎宾院：湖边的动效停", not amb.can_process() and (wgw == null or not wgw.can_process()))
    print("RESULT PASS" if ok else "RESULT FAIL")
    quit(0 if ok else 1)
