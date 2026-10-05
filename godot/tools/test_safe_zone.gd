extends SceneTree
## 罗-12 话泡躲开屏幕禁区（scripts/ui/dialog_skin.gd 的 SafeKeep，组件库第二节第 5 条）。无界面跑，窗口设成手机 540×960。
## 一块空画布、一个 1 倍镜头，把泡冒在屏幕上不同地方，看它最后摆在哪：
##   中间：照旧在头顶；靠左 / 靠右：往里推、尾巴照旧在原点；顶上（顶栏下沿 + 8 以内）：挪身侧；顶上又贴边放不下身侧：挪脚下
##   每种都核：框整个在禁区外（顶栏下沿 + 8、四边 16、胶囊）
## 用法：Godot --headless --path . --script res://tools/test_safe_zone.gd ；最后一行 RESULT PASS 才算过
const DSk = preload("res://scripts/ui/dialog_skin.gd")
var ok := true
var world: Node2D
var cam: Camera2D

func check(name: String, cond: bool) -> void:
    print(("  好 " if cond else "  不行 ") + name)
    ok = ok and cond

func _initialize() -> void:
    _run()

func frames(n: int) -> void:
    for i in n:
        await process_frame

func box_rect(b: Node2D) -> Rect2:
    var box: Control = null
    for c in b.get_children():
        if c is Control:
            box = c
    var xf := b.get_global_transform_with_canvas()
    return Rect2(xf * box.position, box.size * xf.get_scale())

func tip(b: Node2D) -> Vector2:   # 尾巴尖在屏幕上哪（按尾巴图的尖算）
    var t: Sprite2D = b.get_node("tail")
    return t.get_global_transform_with_canvas() * Vector2(3.5 * DSk.BU, 5.0 * DSk.BU)

func safe(r: Rect2) -> bool:
    var vs := Vector2(540, 960)
    return r.position.x >= 16.0 - 0.5 and r.end.x <= vs.x - 16.0 + 0.5 and r.position.y >= DSk.safe_top - 0.5 and r.end.y <= vs.y - 16.0 + 0.5 \
        and not (DSk.capsule.size.x > 0.0 and r.intersects(DSk.capsule))

func put(at: Vector2, text: String) -> Node2D:
    var built: Dictionary = DSk.bubble(text, null, 24)
    var b: Node2D = built["node"]
    b.position = at
    world.add_child(b)
    return b

func _run() -> void:
    await process_frame
    root.size = Vector2i(1080, 1920)
    await frames(2)
    check("窗口是手机 540×960（%s）" % str(root.get_visible_rect().size), root.get_visible_rect().size == Vector2(540, 960))
    world = Node2D.new()
    root.add_child(world)
    cam = Camera2D.new()
    cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
    world.add_child(cam)
    cam.make_current()
    DSk.safe_top = 76.0      # 顶栏下沿 68 + 8（跟游戏里差不多）
    DSk.capsule = Rect2(400, 0, 140, 124).grow(8)
    await frames(2)
    var cases := [["中间", Vector2(270, 500), "up"], ["贴左边（推到边，尾巴偏一点）", Vector2(30, 500), "up"], ["贴右边（推到边，尾巴偏一点）", Vector2(515, 500), "up"], ["偏左（往里推）", Vector2(90, 500), "up"],
        ["顶上中间", Vector2(270, 90), "side"], ["顶上靠左", Vector2(40, 90), "side"], ["右上胶囊底下", Vector2(470, 160), "side"],
        ["顶上又窄（左上角、字长）", Vector2(200, 60), "down"]]
    for cs in cases:
        var text := "这里挡住了，是不是要预留一下安全边距" if str(cs[0]).contains("字长") else "来了来了，快坐"
        var b := put(cs[1], text)
        await frames(3)
        var k = b.get_node("safe_keep")
        var r := box_rect(b)
        var tp := tip(b)
        var tip_ok := false
        match str(k.mode):
            "up": tip_ok = tp.distance_to(cs[1]) < 8.0   # 贴边时框守住 16，尾巴可以偏几像素
            "side": tip_ok = absf(tp.x - (cs[1] as Vector2).x) <= 20.0 and absf(tp.y - ((cs[1] as Vector2).y + 22.0)) <= 4.0
            "down": tip_ok = tp.distance_to((cs[1] as Vector2) + Vector2(0, 92)) < 3.0
        check("%s %s：放在 %s（要 %s）、框 %s 在禁区外、尾巴尖 %s 指着人" % [cs[0], str(cs[1]), k.mode, cs[2], str(r), str(tp.round())],
            str(k.mode) == str(cs[2]) and safe(r) and tip_ok)
        b.queue_free()
        await frames(1)
    # 开关关上：照旧在头顶（截图改前改后对比用）
    DSk.safe_on = false
    var b2 := put(Vector2(270, 90), "来了来了，快坐")
    await frames(3)
    check("safe_on 关上：照旧在头顶（%s）" % b2.get_node("safe_keep").mode, b2.get_node("safe_keep").mode == "up" and box_rect(b2).position.y < 76.0)
    DSk.safe_on = true
    print("RESULT %s" % ("PASS" if ok else "FAIL"))
    quit(0 if ok else 1)
