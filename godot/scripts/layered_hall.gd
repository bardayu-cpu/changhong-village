extends Node2D
## 分层场景（ASSETS.md 第 14 节）：画面就是 GPT 的场景图。底图打底，一块块积木叠在上面，人在积木之间走
## 谁在前谁在后按脚的高低定（y 排序）：每块积木的原点放在它着地的那一行，人的原点在脚底
## 数据由 tools/build_layered.py 生成：能走的格子、遮挡块、交互点都在 scene.json 里，手机上不用现算
## 对外的接口和 3D 的 hall.gd 一样，main.gd 两种都能用；镜头不转，只跟着人移动
signal reached(what: String)

const Spr = preload("res://scripts/sprites.gd")
const Life = preload("res://scripts/hall_life.gd")
const GameCfg = preload("res://scripts/games/game_config.gd")
## 画布的图（底图、积木）从哪来统一走这里（HANDOFF §0.9）：现在从包里读，远程加载真机验过以后只改那一处
const Canvas = preload("res://scripts/canvas_assets.gd")
const DATA := "res://assets/layered/scene_roman_banquet/scene.json"
const SPEED_M := 3.2      # 走路速度，米/秒；换成像素按人所在那一行的比例算
## 走路速度备选两档（HANDOFF：3.2 备选 2.4，阿鱼真机比一比）；调试版右下角的按钮切换 speed_m
const SPEED_CHOICES := [3.2, 2.4]
const PERSON_M := 1.75
## 坐着的样子（占位，9/17）：还没有坐姿帧，第 21 版人只是站到椅位上，阿鱼真机上看不出坐下了。
## 先把站姿帧从头往下截一段（下半身不画），抬到大约椅面的高度；等新画风人物的坐姿帧到了换掉
const SIT_KEEP := 0.62    # 留上半身：人高的这么多
const SIT_LIFT := 0.0     # 上半身下沿抬离椅位点多少（人高的比例）。椅位点量的就是画里的椅面，不用再抬
const SIT_ANIM := 0.3     # 从站的地方挪到椅子上用多久，秒（第 21 版是瞬移，挪一米不到，看不出动过）
## 椅位圈（画里椅面那一圈）相对桌子占地椭圆（x、y、rx、ry）的位置，9/17 对着试点积木 blk_table_round.png 量的：
## 后排椅面约 y 470、前排约 562、左右约 x ±65。A04 整批换桌子积木要重量
const SEAT_DY := -0.85    # 圈心在占地中心往上 0.85 个 ry
const SEAT_RX := -15.0    # 横半径 = rx - 15
const SEAT_RY := -6.0     # 竖半径 = ry - 6
## 走到椅子（或坐着的人）多近算「在旁边」：原来 60 像素，每张桌正前方那把（6 号）离最近能站的地方 63～69 像素，
## 12 把椅子永远不出「坐这儿」（9/18 晚查出来的）。放到 78，最远那把也够得着
const NEAR_R := 78.0

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
var look_hframes := 9      # 形象图集一行几帧；坐着时截半身会临时把 hframes 改成 1，站起来还原
var speed_m := SPEED_M     # 现在用的走路速度，米/秒
var stick := Vector2.ZERO   # 摇杆：屏幕方向，x 向右、y 向下，长度 0～1
var cam_pan := Vector2.ZERO # 手指左右拖出来的镜头偏移（画布像素，阿鱼 9/18 晚要能拖着看全厅）；人一走就慢慢收回到自己身上
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
var life: Node2D           # 厅里的热闹：服务员、乐队、贺礼、彩带、灯笼光、别桌的 NPC 宾客（hall_life.gd，阿鱼 9/18）

func build(preset: int, nickname: String, f: Font) -> void:
    font = f
    cfg = JSON.parse_string(FileAccess.get_file_as_string(DATA))
    base_tex = Canvas.texture(cfg["base"])
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
    _books()
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
    life = Life.new()
    life.name = "life"
    add_child(life)
    life.build(self)
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

## 桌心的簿子（蓝图 3.2 桌簿）：每张摆出来的桌子一本。占位：代码画的小簿子（红封皮、米白内页、几道字迹），
## 正式的簿子积木 blk_guestbook 到了再换。按桌子着地那一行排前后，画在桌面上、在桌前的人后面
func _books() -> void:
    var tex := _book_texture()
    for t in cfg.get("tables", []):
        var s := Sprite2D.new()
        s.texture = tex
        s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        s.centered = true
        s.position = Vector2(float(t["x"]), float(t["y"]) + 0.5)
        s.offset = Vector2(0.0, _seat_center(t).y - float(t["y"]))
        world.add_child(s)

static func _book_texture() -> ImageTexture:
    # 8×5 个美术像素，每个 2×2 画布像素（和积木一样粗），16×10，约 0.33 米宽
    var rows := [".RRRRRR.", "RWWrWWWR", "RkWrWkWR", "RWWrWWWR", ".RRRRRR."]
    var pal := {"R": Color("#9e2a2b"), "r": Color("#6e1e1e"), "W": Color("#f4ead2"), "k": Color("#8a7a66")}
    var img := Image.create(16, 10, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    for j in rows.size():
        var line: String = rows[j]
        for i in line.length():
            var ch := line[i]
            if pal.has(ch):
                img.fill_rect(Rect2i(i * 2, j * 2, 2, 2), pal[ch])
    return ImageTexture.create_from_image(img)

## 遮挡块：临时版用底图把这一块重画一遍（多边形贴底图），GPT 的积木到了换成积木图
func _occluders() -> void:
    for o in cfg["occluders"]:
        var foot := float(o["foot"])
        var holder := Node2D.new()
        holder.position = Vector2(0, foot)
        world.add_child(holder)
        if o.has("image"):
            var s := Sprite2D.new()
            s.texture = Canvas.texture(o["image"])
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
    player.region_enabled = false   # 坐着时截过半身，换形象先还原
    player.frame = 0
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
    look_hframes = player.hframes
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
    var wp := get_viewport().get_canvas_transform().affine_inverse() * screen
    # 点到桌心的菜（椅位圈中间那一块）：告诉 main 开这桌的小游戏。坐在这桌就不走路（一走就站起来了）
    var tid := table_at(wp)
    if tid != "":
        game_tap.emit(tid)
        if seated and str(my_seat.get("table_id", "")) == tid:
            return
    go_to(wp)
    var ms := (Time.get_ticks_usec() - t0) / 1000.0
    if ms > 20.0:
        print("[suqi] 寻路用了 %d 毫秒" % int(ms))

func go_to(target: Vector2) -> void:
    stand_up()   # 坐着的时候点地面：先起身，再从起身点算路，不然路是从桌子占地里出发的
    var out := find_path(pos, target)
    if out.is_empty():
        return
    path = out

## 从 from 走到 target 要经过的拐点（不含起点，能直着走的格子合成一段）；走不到返回空。
## 玩家点地面、服务员在桌子之间走（hall_life.gd）都用它
func find_path(from: Vector2, target: Vector2) -> Array:
    var a := _cell_of(from)
    var b := _cell_of(target)
    if nav.is_point_solid(a): a = _nearest_free(a)
    if nav.is_point_solid(b): b = _nearest_free(b)
    var ids := nav.get_id_path(a, b)
    if ids.is_empty():
        return []
    var pts: Array = []
    for id in ids: pts.append(_cell_pos(id))
    if _free(target): pts[pts.size() - 1] = target
    var out: Array = []
    var cur := from
    var k := 0
    while k < pts.size():
        var far := k
        for m in range(pts.size() - 1, k, -1):
            if _clear(cur, pts[m]):
                far = m
                break
        out.append(pts[far])
        cur = pts[far]
        k = far + 1
    return out

func reset_to(p: Vector2) -> void:
    pos = p
    path.clear()
    stick = Vector2.ZERO
    face = "up"
    seated = false
    sit_t = SIT_ANIM
    snap_cam()
    # 传送到新位置：椅子按钮、昵称按钮该收的收、该冒的冒，不等 0.15 秒的自然扫描
    _scan_chairs(1.0)

## 这个点落在哪张桌的桌心（椅位圈中间、放菜的那块桌面）；都不在返回 ""
func table_at(wp: Vector2) -> String:
    for t in cfg.get("tables", []):
        var c := _seat_center(t) + Vector2(0, -4)
        var d := wp - c
        if (d.x / 52.0) * (d.x / 52.0) + (d.y / 30.0) * (d.y / 30.0) <= 1.0:
            return str(t["id"])
    return ""

## 截图用：从某个点往旁边挪几米（换成这一行的像素）
func near(p: Vector2, v_m: Vector2) -> Vector2:
    return p + v_m * px_per_m(p.y)

## main.gd 里「别处左右拖」调这个（3D 厅是转镜头）。分层场景的镜头不转，改成左右挪着看全厅：
## 手指往左拖，画面跟着往左走（看右边）；拖到厅的边上就停
func rotate_cam(drag_px: float) -> void:
    if cam == null or cam.zoom.x <= 0.0:
        return
    cam_pan.x -= drag_px / cam.zoom.x
    _clamp_pan()

## 镜头中心不出厅：左右各留半屏宽
func _clamp_pan() -> void:
    var half := float(get_viewport().get_visible_rect().size.x) * 0.5 / cam.zoom.x
    var w := float(cfg["size"][0])
    var cx := pos.x + cam_pan.x
    if w > half * 2.0:
        cx = clampf(cx, half, w - half)
    else:
        cx = w * 0.5
    cam_pan.x = cx - pos.x

func snap_cam() -> void:
    cam_pan = Vector2.ZERO
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
    var step := stick * speed_m * px_per_m(pos.y) * dt
    face = _face_for(stick)
    for np: Vector2 in [pos + step, pos + Vector2(step.x, 0), pos + Vector2(0, step.y)]:
        if np != pos and _free(np):
            pos = np
            return true
    return false

func _process(dt: float) -> void:
    t += dt
    var moving := false
    if seated and sit_t < SIT_ANIM:
        # 坐下的那一下：从站的地方滑到椅位上，先快后慢，最后正好停在椅位
        sit_t = minf(sit_t + dt, SIT_ANIM)
        var k := sit_t / SIT_ANIM
        pos = sit_from.lerp(sit_seat, 1.0 - (1.0 - k) * (1.0 - k))
    if stick.length() > 0.15 and walking_enabled:
        stand_up()   # 坐着的时候推摇杆：先起身，从椅子外侧那一步开始走
        path.clear()
        moving = _stick_move(dt)
    elif not path.is_empty():
        var tgt: Vector2 = path[0]
        var to := tgt - pos
        var dist := to.length()
        var speed := speed_m * px_per_m(pos.y)
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
    player.flip_h = fl["flip"]
    if seated:
        # 坐着（占位）：只画站姿帧的上半身，下沿抬到椅面高，见 SIT_KEEP、SIT_LIFT
        var fw := float(player.texture.get_width()) / float(look_hframes)
        var keep := floorf(frame_h * SIT_KEEP)
        if not player.region_enabled:
            player.frame = 0
            player.hframes = 1
            player.region_enabled = true
        player.region_rect = Rect2(float(fl["idle"]) * fw, 0.0, fw, keep)
        player.offset = Vector2(0.0, -keep * 0.5 - frame_h * SIT_LIFT)
        player.z_index = 1 if seat_front else 0
        tag_anchor.position = pos - Vector2(0, _px_h(pos.y) * (SIT_KEEP + SIT_LIFT) + 2.0)
    else:
        if player.region_enabled:
            player.region_enabled = false
            player.hframes = look_hframes
            player.z_index = 0
        var walk_frames: Array = fl["walk"]
        player.frame = walk_frames[int(anim * look_fps) % walk_frames.size()] if moving else fl["idle"]
        # 占位人物的迈腿只有 1 像素，看着像滑行：走路时加一点上下起伏，重画的人物有走路帧后再收小
        var bob := -absf(sin(anim * look_fps * PI)) * 1.6 if moving else 0.0
        # 左右脚交替：每迈一步身体往落脚那边偏一点（上下走时看得最清楚）
        var sway := 0.0
        if moving:
            sway = 0.9 if int(anim * look_fps) % 4 < 2 else -0.9
        player.offset = Vector2(sway, -frame_h * 0.5 + bob)
        tag_anchor.position = pos - Vector2(0, _px_h(pos.y) + 2.0)
    player.position = pos
    var sc := _px_h(pos.y) / frame_h
    player.scale = Vector2(sc, sc)
    if moving or (seated and sit_t < SIT_ANIM):
        # 一走（或坐下那一下）镜头就慢慢回到自己身上，约半秒收回大半
        cam_pan = cam_pan.lerp(Vector2.ZERO, minf(dt * 4.0, 1.0))
    if cam:
        cam.position = pos + cam_pan
    if my_cup != null:
        cup_left = maxf(cup_left - dt, 0.0)
        my_cup.visible = cup_left > 0.0
        var body_h := _px_h(pos.y) * (SIT_KEEP if seated else 1.0)
        my_cup.position = pos + Vector2(-14.0 if face == "left" else 14.0, -body_h + 22.0)
    if exit_mark.visible:
        exit_mark.color.a = 0.35 + sin(t * 3.0) * 0.15
    if couple_armed and pos.distance_to(COUPLE_SPOT) < couple_r:
        couple_armed = false
        path.clear()
        face = "up"
        reached.emit("couple")
    _scan_chairs(dt)
    if exit_armed and pos.distance_to(door) < door_r:
        exit_armed = false
        path.clear()
        reached.emit("exit")

# ---------- 席位：enterHall 的数据画成坐着的人（蓝图 3.2） ----------
signal chair_near(table_id: String, chair_no: int)   # 走到空椅子旁触发；chair_no 0 表示离开了
signal person_near(openid: String)   # 走到「有人坐、不是自己」的椅子旁触发（看人、敬酒，蓝图 3.2）；"" 表示走开了
signal table_near(table_id: String)   # 走到桌边（翻簿子，第 24 版）；"" 表示走开了
signal game_tap(table_id: String)     # 点了某张桌桌心的菜（席间小游戏，蓝图 3.2 9/19：坐下后点桌心的菜开游戏）

var seats_holder: Node2D
var seat_tags: Node2D
var seat_marker: Polygon2D
var chairs: Array = []          # [{table_id, chair_no, pos}]
var seat_taken: Dictionary = {} # "T1:3" -> openid
var resident_nodes: Dictionary = {}  # openid -> {spr, preset, at, center}：坐着的住民，敬酒时要让他站起来（9/18 晚）
var cup_left := 0.0              # 自己举杯还剩几秒（敬酒、被敬酒时）
var my_cup: Sprite2D
var npc_taken: Dictionary = {}  # "T7:3" -> true：NPC 宾客坐着的椅子（hall_life.gd）。点不开；9/18 晚起照样出「坐这儿」，坐下时 NPC 让座
var table_names: Dictionary = {} # table_id -> 第一个坐下的人的昵称（桌牌）
var my_seat := {"table_id": "", "chair_no": 0}
var my_openid := ""              # set_seats 存的自己 openid：判断「是不是自己」，main 敬酒时也要用
var resident_names: Dictionary = {}  # set_seats 存的 data["names"]：openid -> {nick, avatar, inviter}，给 main 读昵称、形象、邀请人
var near_key := ""
var person_near_key := ""
var table_near_key := ""         # _scan_chairs 里翻簿子那部分最新一次发出的桌 id，""=没在任何桌边
var seat_scan := 0.0
var seated := false              # 坐在自己椅子上：停在椅位面朝桌心，一动就站起来
var seat_stand_spot := Vector2.ZERO   # 起身落脚的点：椅子外侧一步，保证不在桌子占地里
var sit_from := Vector2.ZERO     # 坐下那一下从哪滑过来
var sit_seat := Vector2.ZERO     # 滑到哪（椅位）
var sit_t := SIT_ANIM            # 滑了多久；等于 SIT_ANIM 表示没在滑
var seat_front := false          # 自己坐的椅子在桌子两边或前面：画在桌子前面（seat_in_front）

## 椅子在画布上的位置：绕桌子占地一圈，1 号在正后方（靠里），顺时针
func chair_world(t: Dictionary, no: int) -> Vector2:
    var a := -PI / 2.0 + TAU * float(no - 1) / 10.0
    var c := _seat_center(t)
    return Vector2(c.x + cos(a) * (float(t["rx"]) + SEAT_RX), c.y + sin(a) * (float(t["ry"]) + SEAT_RY))

## 椅位圈的圈心：桌子积木里画出来的那圈椅子，比桌子占地椭圆靠上（占地椭圆的中心在桌子着地的那一行）。
## 9/17 对着试点积木 blk_table_round.png 量的，原来按占地椭圆往外扩，坐下的人飘在椅子外面一大截
func _seat_center(t: Dictionary) -> Vector2:
    return Vector2(float(t["x"]), float(t["y"]) + SEAT_DY * float(t["ry"]))

## 坐在这把椅子上的人画不画在桌子前面：桌子后面那几把（圈的上半截）照 y 排序躲在桌子后面；
## 两边和前面的画在桌子前面。桌子积木只有一条着地线，分不出人在桌子哪一侧，只能按椅子在圈上的位置定
func seat_in_front(t: Dictionary, seat: Vector2) -> bool:
    return seat.y >= _seat_center(t).y - 0.5 * float(t["ry"])

func set_seats(data: Dictionary, me_id: String) -> void:
    if seats_holder != null:
        seats_holder.queue_free()
    if seat_tags != null:
        seat_tags.queue_free()
    seats_holder = Node2D.new()
    seats_holder.y_sort_enabled = true
    world.add_child(seats_holder)
    resident_nodes.clear()
    seat_tags = Node2D.new()
    seat_tags.z_index = 4
    add_child(seat_tags)
    chairs.clear()
    seat_taken.clear()
    table_names.clear()
    my_seat = data.get("me", my_seat)
    my_openid = me_id
    var names: Dictionary = data.get("names", {})
    resident_names = names
    var signed := {}
    var by_id := {}
    for t in cfg.get("tables", []):
        by_id[t["id"]] = t
    for tb in data.get("tables", []):
        if not by_id.has(tb["id"]):
            continue   # 试点只摆了两张桌，服务端多出来的桌先不画
        var t: Dictionary = by_id[tb["id"]]
        for no in range(1, 11):
            chairs.append({"table_id": tb["id"], "chair_no": no, "pos": chair_world(t, no)})
        var first_at := INF   # 桌牌：这桌最早坐下的人（sat_at 最小；旧数据没有 sat_at 就按列表里第一个）
        for s in tb.get("seats", []):
            var no := int(s["chair_no"])
            seat_taken["%s:%d" % [tb["id"], no]] = s["openid"]
            var info: Dictionary = names.get(s["openid"], {})
            var sat_at := float(s.get("sat_at", 0))
            if str(info.get("nick", "")) != "" and (not table_names.has(tb["id"]) or sat_at < first_at):
                table_names[tb["id"]] = str(info["nick"])
                first_at = sat_at
            if s["openid"] == me_id:
                continue   # 自己是走动的玩家，不画坐着的
            var at := chair_world(t, no)
            _seated(info, at, _seat_center(t), seat_in_front(t, at), str(s["openid"]))
        if table_names.has(tb["id"]):
            signed[tb["id"]] = true
            _table_sign(t, str(table_names[tb["id"]]))
    # 没有真人的桌也挂桌牌，只写游戏名（蓝图 3.2 9/19：桌牌带上游戏名，走到哪桌玩哪样）
    for t in cfg.get("tables", []):
        if not signed.has(t["id"]):
            _table_sign(t, "")
    # 别桌的 NPC 宾客：真人坐了的椅子让出来（阿鱼 9/18 定留，见 hall_life.gd 开头）
    npc_taken = life.seat_guests(seat_taken) if life != null else {}
    _my_marker()
    # 椅子列表整个重建过（换桌、重进厅都会走到这）：旧的按钮状态可能对不上了，立刻重扫一次
    _scan_chairs(1.0)

## 桌牌「XX那桌·吃席」（蓝图 3.2：桌牌由引擎渲染，XX 是这桌第一个坐下的人；9/19 起带上这桌的小游戏名），立在桌心；
## 没有真人坐的桌只写游戏名
func _table_sign(t: Dictionary, nick: String) -> void:
    var l := Label.new()
    var game_title := GameCfg.title(GameCfg.game_for_table(str(t["id"])))
    var parts: Array[String] = []
    if nick != "":
        parts.append(nick + "那桌")
    if game_title != "":
        parts.append(game_title)
    if parts.is_empty():
        return
    l.text = "·".join(parts)
    l.add_theme_font_override("font", font)
    l.add_theme_font_size_override("font_size", 12)
    l.add_theme_color_override("font_color", Color("#F4D97A"))
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.08, 0.05, 0.1, 0.8)
    sb.border_color = Color("#d4af37")
    sb.set_border_width_all(1)
    sb.set_corner_radius_all(3)
    sb.content_margin_left = 4; sb.content_margin_right = 4
    sb.content_margin_top = 1; sb.content_margin_bottom = 1
    l.add_theme_stylebox_override("normal", sb)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.size = l.get_combined_minimum_size()   # 牌子只包住字，居中立在桌心
    l.position = _seat_center(t) - Vector2(l.size.x * 0.5, l.size.y + 8.0)   # 立在簿子上方，不挡簿子
    l.name = "sign_" + str(t["id"])
    seat_tags.add_child(l)

## 坐着的住民：和自己坐下一样画上半身（占位，SIT_KEEP、SIT_LIFT），不然别人像站在桌边、只有自己像坐着
func _seated(info: Dictionary, at: Vector2, center: Vector2, front: bool, openid := "") -> void:
    var preset := int(info.get("avatar", -1))
    if preset < 0 or preset > 7:
        preset = 0
    var s := Sprite2D.new()
    var gl := Spr.gpt_look(preset)
    var lk: Dictionary
    var fh: float
    if gl.is_empty():
        s.texture = ImageTexture.create_from_image(Spr.sheet(preset))
        s.hframes = 9
        fh = 32.0
        lk = Spr.PROC_ANIM
    else:
        s.texture = gl["tex"]
        s.hframes = gl["hframes"]
        fh = float(gl["frame_h"])
        lk = gl["anim"]
    var fl: Dictionary = lk[_face_for(center - at)]
    var fw := float(s.texture.get_width()) / float(s.hframes)
    var keep := floorf(fh * SIT_KEEP)
    s.hframes = 1
    s.region_enabled = true
    s.region_rect = Rect2(float(fl["idle"]) * fw, 0.0, fw, keep)
    s.flip_h = fl["flip"]
    s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    s.centered = true
    s.offset = Vector2(0, -keep * 0.5 - fh * SIT_LIFT)
    var sc := _px_h(at.y) / fh
    s.scale = Vector2(sc, sc)
    s.position = at
    s.z_index = 1 if front else 0
    seats_holder.add_child(s)
    if openid != "":
        resident_nodes[openid] = {"spr": s, "preset": preset, "at": at, "center": center}
    var nick := str(info.get("nick", ""))
    if nick != "" and font != null:
        var l := Label.new()
        l.text = nick
        l.add_theme_font_override("font", font)
        l.add_theme_font_size_override("font_size", 12)
        l.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
        l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
        l.add_theme_constant_override("outline_size", 4)
        l.size = Vector2(96, 14)
        l.position = at - Vector2(48, _px_h(at.y) * (SIT_KEEP + SIT_LIFT) + 16.0)
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        seat_tags.add_child(l)

# ---------- 敬酒的样子（阿鱼 9/18 晚：被敬的人要站起来，两人碰杯）----------
const TOAST_SHOW := 2.8   # 站起来、举杯多久，秒（和 toast_scene.gd 的插图一样长）
const CUP_TEX := "res://assets/ambience/amb_cup.png"

## 我敬了坐着的某人：在我这边他从椅子上站起来（站到椅子外侧那一步），面朝我举杯，过一会儿坐回去
func resident_toast(openid: String) -> bool:
    var r: Dictionary = resident_nodes.get(openid, {})
    if r.is_empty() or not is_instance_valid(r["spr"]):
        return false
    var seated_spr: Sprite2D = r["spr"]
    var preset: int = int(r["preset"])
    var stand := _stand_spot(r["at"], r["center"])
    var st := Sprite2D.new()
    var gl := Spr.gpt_look(preset)
    var lk: Dictionary
    var fh: float
    if gl.is_empty():
        st.texture = ImageTexture.create_from_image(Spr.sheet(preset))
        st.hframes = 9
        fh = 32.0
        lk = Spr.PROC_ANIM
    else:
        st.texture = gl["tex"]
        st.hframes = gl["hframes"]
        fh = float(gl["frame_h"])
        lk = gl["anim"]
    var fl: Dictionary = lk[_face_for(pos - stand)]
    st.frame = int(fl["idle"])
    st.flip_h = bool(fl["flip"])
    st.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    st.centered = true
    st.offset = Vector2(0, -fh * 0.5)
    var k := _px_h(stand.y) / fh
    st.scale = Vector2(k, k)
    st.position = stand
    st.name = "toast_stand"
    world.add_child(st)
    seated_spr.visible = false
    var cup := _cup_sprite()
    cup.position = stand + Vector2(14.0 if pos.x >= stand.x else -14.0, -_px_h(stand.y) + 22.0)
    add_child(cup)
    get_tree().create_timer(TOAST_SHOW).timeout.connect(func():
        if is_instance_valid(st): st.queue_free()
        if is_instance_valid(cup): cup.queue_free()
        if is_instance_valid(seated_spr): seated_spr.visible = true)
    return true

## 自己举杯 secs 秒：酒杯在手边举到头旁边
func raise_cup(secs := TOAST_SHOW) -> void:
    if my_cup == null:
        my_cup = _cup_sprite()
        add_child(my_cup)
    cup_left = secs

## 有人敬我（在厅里当场收到）：坐着就站起来、举杯，插图完了没动过就坐回原位
func toasted_me() -> void:
    var was := seated
    var seat: Dictionary = my_seat.duplicate()
    if seated:
        stand_up()
    face = "down"
    raise_cup()
    if was:
        get_tree().create_timer(TOAST_SHOW).timeout.connect(func():
            if not seated and path.is_empty() and stick == Vector2.ZERO and my_seat == seat:
                sit_at(str(seat.get("table_id", "")), int(seat.get("chair_no", 0))))

func _cup_sprite() -> Sprite2D:
    var c := Sprite2D.new()
    if ResourceLoader.exists(CUP_TEX):
        c.texture = load(CUP_TEX)
    c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    c.z_index = 5
    c.visible = true
    return c

## 自己座位的小金标
func _my_marker() -> void:
    if seat_marker != null:
        seat_marker.queue_free()
        seat_marker = null
    var pos := _my_chair_pos()
    if pos == Vector2.ZERO:
        return
    seat_marker = Polygon2D.new()
    var pts := PackedVector2Array()
    for i in 16:
        var a := TAU * i / 16.0
        pts.append(Vector2(cos(a) * 14.0, sin(a) * 6.0))
    seat_marker.polygon = pts
    seat_marker.color = Color(1.0, 0.85, 0.4, 0.55)
    seat_marker.position = pos
    # 要画在底图和桌子上面才看得见：原来是 -5，沉到底图下面，电脑上也看不到（第 19 版修）
    seat_marker.z_index = 4
    add_child(seat_marker)

func _my_chair_pos() -> Vector2:
    for c in chairs:
        if c["table_id"] == my_seat.get("table_id", "") and c["chair_no"] == int(my_seat.get("chair_no", 0)):
            return c["pos"]
    return Vector2.ZERO

## 换桌成功后本地更新，不用重新拉 enterHall。顺便把人挪到那把椅子上坐下——
## 第 20 版只有金标挪了位置、人还站在原地，阿鱼没看出来成功，连点了四次
func apply_change(table_id: String, chair_no: int, me_id: String) -> void:
    var old := "%s:%d" % [my_seat.get("table_id", ""), int(my_seat.get("chair_no", 0))]
    if seat_taken.get(old, "") == me_id:
        seat_taken.erase(old)
    my_seat = {"table_id": table_id, "chair_no": chair_no}
    var key := "%s:%d" % [table_id, chair_no]
    seat_taken[key] = me_id
    # 这把原来坐着 NPC：它站起来走掉，把椅子让给我（阿鱼 9/18 晚）
    if life != null and npc_taken.has(key):
        life.vacate(key)
        npc_taken = life.npc_taken
    _my_marker()
    sit_at(table_id, chair_no)

func _table_cfg(table_id: String) -> Dictionary:
    for t in cfg.get("tables", []):
        if str(t["id"]) == table_id:
            return t
    return {}

## 翻簿子的「离桌子占地椭圆一圈 60 像素内」：沿桌心到人的方向量出椭圆边界那一点，
## 两点距离相减，正数是在外面、负数是在里面。跟 chair_world 一样用 rx、ry 撑扁的圆算角度
func _table_edge_dist(t: Dictionary, p: Vector2) -> float:
    var c := Vector2(float(t["x"]), float(t["y"]))
    var d := p - c
    var rx: float = float(t["rx"])
    var ry: float = float(t["ry"])
    if d.length() < 0.001:
        return -minf(rx, ry)   # 正好站在桌心（理论上不会发生），当作在里面
    var ang := atan2(d.y / ry, d.x / rx)
    var edge := Vector2(cos(ang) * rx, sin(ang) * ry)
    return d.length() - edge.length()

## 坐下：人滑到椅子上（SIT_ANIM 秒），面朝桌心，停着不动，只画上半身（_process 里，占位）。
## 还没有坐姿帧（等新画风人物）；椅子和桌子画在同一块积木里挪不动，「拖椅子坐下」在待讨论里
func sit_at(table_id: String, chair_no: int) -> void:
    var t := _table_cfg(table_id)
    if t.is_empty():
        return   # 服务端把人分到了还没摆出来的桌，坐不了，main.gd 那边会提示先找把椅子
    var seat := chair_world(t, chair_no)
    var center := _seat_center(t)
    seat_front = seat_in_front(t, seat)
    path.clear()
    stick = Vector2.ZERO
    sit_from = pos
    sit_seat = seat
    sit_t = 0.0
    face = _face_for(center - seat)
    seated = true
    seat_stand_spot = _stand_spot(seat, center)
    # 坐下就把「坐这儿」收起来；站起来走近别的空椅子时，扫描会照旧弹出来
    seat_scan = 0.0
    if near_key != "":
        near_key = ""
        chair_near.emit("", 0)

## 起身落脚的点：从桌心往外，沿椅子那个方向退开一步，退到能站的地方为止
func _stand_spot(seat: Vector2, center: Vector2) -> Vector2:
    var dir := seat - center
    dir = dir.normalized() if dir.length() > 0.001 else Vector2(0.0, 1.0)
    var step := px_per_m(seat.y)
    for k in 10:
        var p := seat + dir * step * (0.6 + 0.3 * k)
        if _free(p):
            return p
    return _cell_pos(_nearest_free(_cell_of(seat)))

## 站起来：从椅子外侧那一步起身，不会卡在桌子占地里
func stand_up() -> void:
    if not seated:
        return
    seated = false
    sit_t = SIT_ANIM   # 正在往椅子上滑也立刻停
    if seat_stand_spot != Vector2.ZERO and _free(seat_stand_spot):
        pos = seat_stand_spot

## 每 0.15 秒扫一次：人旁边有没有空椅子（不含自己那把）；同时扫旁边坐着的人（看人、敬酒，蓝图 3.2）
func _scan_chairs(dt: float) -> void:
    if chairs.is_empty():
        return
    seat_scan += dt
    if seat_scan < 0.15:
        return
    seat_scan = 0.0
    # 坐着的时候不提「坐这儿」：刚坐下又冒出一个按钮，看着像没坐成。
    # 要「走近别的空椅子」总得先动，一动就起身了，那时照旧弹
    if seated:
        if near_key != "":
            near_key = ""
            chair_near.emit("", 0)
    else:
        var best_key := ""
        var best_tid := ""
        var best_no := 0
        var best_d := NEAR_R
        for c in chairs:
            var key: String = "%s:%d" % [c["table_id"], c["chair_no"]]
            if seat_taken.has(key):
                continue   # NPC 坐着的也算空椅子：坐下时 NPC 让座
            var d: float = pos.distance_to(c["pos"])
            if d < best_d:
                best_d = d
                best_key = key
                best_tid = c["table_id"]
                best_no = c["chair_no"]
        if best_key != near_key:
            near_key = best_key
            chair_near.emit(best_tid, best_no)
    # 看人：最近的「有人坐、不是自己」的椅子，NEAR_R 以内，和「坐这儿」一个距离。
    # 坐在自己椅子上时邻座照样能敬酒（第 22 版规则 6），所以这一段不受 seated 影响
    var best_pid := ""
    var best_pd := NEAR_R
    for c in chairs:
        var key: String = "%s:%d" % [c["table_id"], c["chair_no"]]
        var occ: String = str(seat_taken.get(key, ""))
        if occ == "" or occ == my_openid:
            continue
        var d: float = pos.distance_to(c["pos"])
        if d < best_pd:
            best_pd = d
            best_pid = occ
    if best_pid != person_near_key:
        person_near_key = best_pid
        person_near.emit(best_pid)
    # 翻簿子：走到桌边（占地椭圆边缘 60 像素内）冒「翻簿子」；坐在自己椅子上时也算自己那桌（蓝图 3.2，
    # 第 24 版规则 1），不受 seated 影响——跟看人一样，坐着也能翻自己桌上的簿子
    var best_table := ""
    if seated:
        var my_t := _table_cfg(str(my_seat.get("table_id", "")))
        if not my_t.is_empty():
            best_table = str(my_t["id"])
    if best_table == "":
        var best_td := 60.0
        for t in cfg.get("tables", []):
            var td: float = _table_edge_dist(t, pos)
            if td < best_td:
                best_td = td
                best_table = str(t["id"])
    if best_table != table_near_key:
        table_near_key = best_table
        table_near.emit(best_table)
