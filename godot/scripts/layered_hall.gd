extends Node2D
## 分层场景（ASSETS.md 第 14 节）：画面就是 GPT 的场景图。底图打底，一块块积木叠在上面，人在积木之间走
## 谁在前谁在后按脚的高低定（y 排序）：每块积木的原点放在它着地的那一行，人的原点在脚底
## 数据由 tools/build_layered.py 生成：能走的格子、遮挡块、交互点都在 scene.json 里，手机上不用现算
## 对外的接口和 3D 的 hall.gd 一样，main.gd 两种都能用；镜头不转，只跟着人移动
signal reached(what: String)

const Spr = preload("res://scripts/sprites.gd")
const DATA := "res://assets/layered/scene_roman_banquet/scene.json"
const SPEED_M := 3.2      # 走路速度，米/秒；换成像素按人所在那一行的比例算
const PERSON_M := 1.75

var cfg: Dictionary
var base_tex: Texture2D
var world: Node2D          # 开了 y 排序：积木、新人、玩家都在这里面
var cam: Camera2D
var player: Sprite2D
var tag: Label
var tag_anchor: Node2D
var exit_mark: Polygon2D
var exit_mat_t := 0.0
var nav := AStarGrid2D.new()
var cell := 10.0
var cols := 0
var rows := 0
var walk := PackedByteArray()   # 1 = 能站
var path: Array = []
var pos := Vector2.ZERO
var face := "up"
var anim := 0.0
var look := Spr.PROC_ANIM
var look_fps := 7.7
var frame_h := 32.0
var stick := Vector2.ZERO   # 摇杆：屏幕方向，x 向右、y 向下，长度 0～1
var couple_armed := true
var exit_armed := false
var walking_enabled := true
var t := 0.0
var SPAWN := Vector2.ZERO
var COUPLE_SPOT := Vector2.ZERO
var couple_r := 70.0
var door := Vector2.ZERO
var door_r := 60.0
var font: Font

func build(preset: int, nickname: String, f: Font) -> void:
    font = f
    cfg = JSON.parse_string(FileAccess.get_file_as_string(DATA))
    base_tex = load(cfg["base"])
    var base := Sprite2D.new()
    base.texture = base_tex
    base.centered = false
    base.z_index = -10
    base.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    add_child(base)
    world = Node2D.new()
    world.y_sort_enabled = true
    add_child(world)
    _occluders()
    _walk_grid()
    SPAWN = Vector2(cfg["spawn"][0], cfg["spawn"][1])
    for p in cfg["points"]:
        if p["id"] == "couple_table":
            COUPLE_SPOT = Vector2(p["x"], p["y"])
            couple_r = float(p["r"])
        elif p["id"] == "door":
            door = Vector2(p["x"], p["y"])
            door_r = float(p["r"])
    _couple()
    _player(preset, nickname)
    _exit_mark()
    cam = Camera2D.new()
    cam.limit_left = 0
    cam.limit_top = 0
    cam.limit_right = int(cfg["size"][0])
    cam.limit_bottom = int(cfg["size"][1])
    cam.position_smoothing_enabled = true
    cam.position_smoothing_speed = 6.0
    add_child(cam)
    cam.make_current()
    _fit_zoom()
    get_viewport().size_changed.connect(_fit_zoom)
    snap_cam()

## 场景图的高度正好铺满屏幕高度，左右跟着人移动
func _fit_zoom() -> void:
    var vh := float(get_viewport().get_visible_rect().size.y)
    var z := vh / float(cfg["size"][1])
    cam.zoom = Vector2(z, z)

## 遮挡块：临时版用底图把这一块重画一遍（多边形贴底图），GPT 的积木到了换成积木图
func _occluders() -> void:
    for o in cfg["occluders"]:
        var foot := float(o["foot"])
        var holder := Node2D.new()
        holder.position = Vector2(0, foot)
        world.add_child(holder)
        if o.has("image"):
            var s := Sprite2D.new()
            s.texture = load(o["image"])
            s.centered = false
            s.offset = Vector2(o["x"], float(o["y"]) - foot)
            s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
            holder.add_child(s)
        else:
            # 一块可以由几个形状拼成（桌面加一把把椅子）
            for shape in o["polys"]:
                var pts := PackedVector2Array()
                var uvs := PackedVector2Array()
                for p in shape:
                    pts.append(Vector2(p[0], float(p[1]) - foot))
                    uvs.append(Vector2(p[0], p[1]))
                var poly := Polygon2D.new()
                poly.texture = base_tex
                poly.polygon = pts
                poly.uv = uvs
                poly.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
                holder.add_child(poly)

func _walk_grid() -> void:
    var g: Dictionary = cfg["walk_grid"]
    cell = float(g["cell"])
    cols = int(g["cols"])
    var lines: Array = g["rows"]
    rows = lines.size()
    walk.resize(cols * rows)
    nav.region = Rect2i(0, 0, cols, rows)
    nav.cell_size = Vector2.ONE
    nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    nav.update()
    for j in rows:
        var line: String = lines[j]
        for i in cols:
            var ok := line.unicode_at(i) == 49   # "1"
            walk[j * cols + i] = 1 if ok else 0
            if not ok:
                nav.set_point_solid(Vector2i(i, j), true)

## 人在这一行（脚的 y）应该画多高（像素）：按 scene.json 里两行的高度线性插值
func _px_h(y: float) -> float:
    var pp: Dictionary = cfg["person_px"]
    var k := (y - float(pp["far_y"])) / (float(pp["near_y"]) - float(pp["far_y"]))
    return lerpf(float(pp["far_h"]), float(pp["near_h"]), k)

func px_per_m(y: float) -> float:
    return _px_h(y) / PERSON_M

func _couple() -> void:
    var cp := Sprite2D.new()
    cp.texture = load("res://assets/couple.png")
    cp.centered = false
    var foot := Vector2(cfg["couple"][0], cfg["couple"][1])
    var h := _px_h(foot.y) * 1.25   # 合照立绘里人上面还有一点空，整张比人高一些
    var sc := h / float(cp.texture.get_height())
    cp.scale = Vector2(sc, sc)
    cp.offset = Vector2(-cp.texture.get_width() * 0.5, -cp.texture.get_height())
    cp.position = foot
    cp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    world.add_child(cp)

func _player(preset: int, nickname: String) -> void:
    player = Sprite2D.new()
    player.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    world.add_child(player)
    tag_anchor = Node2D.new()
    tag_anchor.z_index = 5
    add_child(tag_anchor)
    tag = Label.new()
    tag.add_theme_font_override("font", font)
    tag.add_theme_font_size_override("font_size", 12)
    tag.add_theme_color_override("font_color", Color("#F4D97A"))
    tag.add_theme_color_override("font_shadow_color", Color("#1b1422"))
    tag.add_theme_constant_override("shadow_offset_x", 1)
    tag.add_theme_constant_override("shadow_offset_y", 1)
    tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tag.size = Vector2(120, 16)
    tag.position = Vector2(-60, -16)
    tag_anchor.add_child(tag)
    set_look(preset, nickname)

func set_look(preset: int, nickname: String) -> void:
    var gl := Spr.gpt_look(preset)
    if gl.is_empty():
        player.texture = ImageTexture.create_from_image(Spr.sheet(preset))
        player.hframes = 9
        frame_h = 32.0
        look = Spr.PROC_ANIM
        look_fps = 7.7
    else:
        player.texture = gl["tex"]
        player.hframes = gl["hframes"]
        frame_h = float(gl["frame_h"])
        look = gl["anim"]
        look_fps = gl["fps"]
    player.centered = true
    player.offset = Vector2(0, -frame_h * 0.5)   # 原点在脚底
    player.frame = look["up"]["idle"]
    tag.text = nickname

func _exit_mark() -> void:
    exit_mark = Polygon2D.new()
    var pts := PackedVector2Array()
    for i in 24:
        var a := TAU * i / 24.0
        pts.append(Vector2(cos(a) * door_r, sin(a) * door_r * 0.4))
    exit_mark.polygon = pts
    exit_mark.color = Color(1.0, 0.85, 0.4, 0.45)
    exit_mark.position = door
    exit_mark.z_index = -5
    exit_mark.visible = false
    add_child(exit_mark)

func arm_exit() -> void:
    exit_armed = true
    exit_mark.visible = true

# ---------- 走路 ----------
func _cell_of(p: Vector2) -> Vector2i:
    return Vector2i(clampi(int(p.x / cell), 0, cols - 1), clampi(int(p.y / cell), 0, rows - 1))

func _cell_pos(c: Vector2i) -> Vector2:
    return Vector2((c.x + 0.5) * cell, (c.y + 0.5) * cell)

## 这个位置能不能站：看它落在哪一格
func _free(p: Vector2, _r := 0.0) -> bool:
    if p.x < 0 or p.y < 0 or p.x >= cols * cell or p.y >= rows * cell:
        return false
    var c := _cell_of(p)
    return walk[c.y * cols + c.x] == 1

func _nearest_free(c: Vector2i) -> Vector2i:
    for rad in range(1, 40):
        for dj in range(-rad, rad + 1):
            for di in range(-rad, rad + 1):
                var n := c + Vector2i(di, dj)
                if nav.is_in_boundsv(n) and not nav.is_point_solid(n):
                    return n
    return c

func _cell_ok(c: Vector2i) -> bool:
    return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows and walk[c.y * cols + c.x] == 1

## 两点之间能不能直着走：线段经过的每一格都要能站（一格一格顺着走，斜着擦过的角也不漏）
func _clear(a: Vector2, b: Vector2) -> bool:
    var p := a / cell
    var q := b / cell
    var c := Vector2i(floori(p.x), floori(p.y))
    var end := Vector2i(floori(q.x), floori(q.y))
    var d := q - p
    var sx := 1 if d.x > 0.0 else -1
    var sy := 1 if d.y > 0.0 else -1
    var tdx := absf(1.0 / d.x) if d.x != 0.0 else INF
    var tdy := absf(1.0 / d.y) if d.y != 0.0 else INF
    var tx := (float(c.x + (1 if sx > 0 else 0)) - p.x) / d.x if d.x != 0.0 else INF
    var ty := (float(c.y + (1 if sy > 0 else 0)) - p.y) / d.y if d.y != 0.0 else INF
    var len_c := d.length()
    for guard in 2000:
        if not _cell_ok(c):
            return false
        if c == end:
            return true
        if absf(tx - ty) * len_c < 0.05:
            # 穿过（或几乎穿过）格子的角：角两边的格子也都要能站，走的时候差一点点也不会踩进去
            if not _cell_ok(c + Vector2i(sx, 0)) or not _cell_ok(c + Vector2i(0, sy)):
                return false
            c += Vector2i(sx, sy)
            tx += tdx
            ty += tdy
        elif tx < ty:
            c.x += sx
            tx += tdx
        else:
            c.y += sy
            ty += tdy
    return false

func tap(screen: Vector2) -> void:
    if not walking_enabled:
        return
    var t0 := Time.get_ticks_usec()
    go_to(get_viewport().get_canvas_transform().affine_inverse() * screen)
    var ms := (Time.get_ticks_usec() - t0) / 1000.0
    if ms > 20.0:
        print("[suqi] 寻路用了 %d 毫秒" % int(ms))

func go_to(target: Vector2) -> void:
    var a := _cell_of(pos)
    var b := _cell_of(target)
    if nav.is_point_solid(a): a = _nearest_free(a)
    if nav.is_point_solid(b): b = _nearest_free(b)
    var ids := nav.get_id_path(a, b)
    if ids.is_empty():
        return
    var pts: Array = []
    for id in ids: pts.append(_cell_pos(id))
    if _free(target): pts[pts.size() - 1] = target
    var out: Array = []
    var from := pos
    var k := 0
    while k < pts.size():
        var far := k
        for m in range(pts.size() - 1, k, -1):
            if _clear(from, pts[m]):
                far = m
                break
        out.append(pts[far])
        from = pts[far]
        k = far + 1
    path = out

func reset_to(p: Vector2) -> void:
    pos = p
    path.clear()
    stick = Vector2.ZERO
    face = "up"
    snap_cam()

## 截图用：从某个点往旁边挪几米（换成这一行的像素）
func near(p: Vector2, v_m: Vector2) -> Vector2:
    return p + v_m * px_per_m(p.y)

## 分层场景的镜头不转
func rotate_cam(_drag_px: float) -> void:
    pass

func snap_cam() -> void:
    if cam:
        cam.position = pos
        cam.reset_smoothing()

## 没有 3D 着色器要预热，等两帧就行
func warm_up() -> void:
    for i in 2:
        await get_tree().process_frame

func _face_for(d: Vector2) -> String:
    if absf(d.x) > absf(d.y) * 1.2:
        return "right" if d.x > 0.0 else "left"
    return "up" if d.y < 0.0 else "down"

## 摇杆走路：挡住了就试着只走一个方向，贴着桌边滑过去
func _stick_move(dt: float) -> bool:
    var step := stick * SPEED_M * px_per_m(pos.y) * dt
    face = _face_for(stick)
    for np: Vector2 in [pos + step, pos + Vector2(step.x, 0), pos + Vector2(0, step.y)]:
        if np != pos and _free(np):
            pos = np
            return true
    return false

func _process(dt: float) -> void:
    t += dt
    var moving := false
    if stick.length() > 0.15 and walking_enabled:
        path.clear()
        moving = _stick_move(dt)
    elif not path.is_empty():
        var tgt: Vector2 = path[0]
        var to := tgt - pos
        var dist := to.length()
        var speed := SPEED_M * px_per_m(pos.y)
        if dist < 2.0:
            pos = tgt   # 到拐点就站准，下一段从算好的起点出发
            path.pop_front()
        else:
            var np := pos + to / dist * minf(dist, speed * dt)
            if _free(np):
                pos = np
                moving = true
            else:
                path.clear()
            face = _face_for(to)
    anim = anim + dt if moving else 0.0
    var fl: Dictionary = look[face]
    var walk_frames: Array = fl["walk"]
    player.frame = walk_frames[int(anim * look_fps) % walk_frames.size()] if moving else fl["idle"]
    player.flip_h = fl["flip"]
    # 占位人物的迈腿只有 1 像素，看着像滑行：走路时加一点上下起伏，重画的人物有走路帧后再收小
    var bob := -absf(sin(anim * look_fps * PI)) * 1.6 if moving else 0.0
    # 左右脚交替：每迈一步身体往落脚那边偏一点（上下走时看得最清楚）
    var sway := 0.0
    if moving:
        sway = 0.9 if int(anim * look_fps) % 4 < 2 else -0.9
    player.offset = Vector2(sway, -frame_h * 0.5 + bob)
    player.position = pos
    var sc := _px_h(pos.y) / frame_h
    player.scale = Vector2(sc, sc)
    tag_anchor.position = pos - Vector2(0, _px_h(pos.y) + 2.0)
    if cam:
        cam.position = pos
    if exit_mark.visible:
        exit_mark.color.a = 0.35 + sin(t * 3.0) * 0.15
    if couple_armed and pos.distance_to(COUPLE_SPOT) < couple_r:
        couple_armed = false
        path.clear()
        face = "up"
        reached.emit("couple")
    if exit_armed and pos.distance_to(door) < door_r:
        exit_armed = false
        path.clear()
        reached.emit("exit")
