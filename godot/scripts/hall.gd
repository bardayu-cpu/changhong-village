extends Node3D
## 罗曼山庄宴会厅：主桌在舞台前，十二张圆桌分两边，中间红毯通到门口
## 坐标：x 向右，z 向镜头（南），舞台在 z 负方向
signal reached(what: String)

const Pix = preload("res://scripts/pix.gd")
const Spr = preload("res://scripts/sprites.gd")

## 布局照 GPT 的效果图 approved_preview_v4：中间红地毯通到舞台，两边各两列圆桌、每桌铺一块地毯，
## 地毯两边是木格灯笼和花架，桌组之间立木格屏风，舞台前是主桌，新人站在主桌后面
const CELL := 0.5
const X0 := -11.9
const X1 := 11.9
const Z0 := -16.4
const Z1 := 3.7
const COUPLE_SPOT := Vector2(0.0, -15.4)
const SPAWN := Vector2(0.0, 1.2)
const SPEED := 3.2
const LOOK_AHEAD := 5.5   # 镜头往前多看一段，人站在画面下三分之一
const CAM_YAW_MAX := 0.785398   # 镜头左右最多转 45 度：再大，纸片人和道具会穿帮
const TABLE_ROWS := [-13.0, -7.8, -2.6]   # 排距 5.2 米：两桌椅子之间留一条能走的过道
const TABLE_COLS := [-9.6, -4.8, 4.8, 9.6]
const TABLE_TOP := 0.8
const HALL_W := 12.9          # 两边墙在 x = ±12.9
const AISLE_X := 1.9          # 灯笼、花架立在红地毯两边
const AISLE_LAMPS := [-14.6, -10.4, -5.2, -0.2]
const AISLE_FLOWERS := [-13.0, -7.8, -2.6]
const HEAD_Z := -18.0         # 主桌中线（在舞台上）
const COUPLE_Z := -18.9       # 新人站在主桌后面
var TABLES: Array = []
var _cache_rug := {}
const SCENE_JSON := "res://assets/scenes/scene_roman_banquet.json"

var font: Font
var cam: Camera3D
var player: Sprite3D
var tag: Label3D
var blob: MeshInstance3D
var exit_mark: MeshInstance3D
var exit_mat: StandardMaterial3D
var nav := AStarGrid2D.new()
var obst: Array = []
var path: Array = []
var pos := SPAWN
var face := "up"
var anim := 0.0
var look := Spr.PROC_ANIM   # 当前形象每个方向用哪几帧
var look_fps := 7.7
var cam_yaw := 0.0          # 镜头左右转的角度（弧度），拖屏幕改
var stick := Vector2.ZERO   # 摇杆输入，屏幕方向：x 向右、y 向下，长度 0～1
var player_h := 1.75
var cam_target := Vector3.ZERO
var couple_armed := true
var exit_armed := false
var walking_enabled := true
var t := 0.0
var guests: Array = []
var sheets := {}
var m_cloth: StandardMaterial3D
var m_gold: StandardMaterial3D
var m_wood: StandardMaterial3D   # 深色木头：椅子、灯笼架、屏风框

func build(preset: int, nickname: String, f: Font) -> void:
    font = f
    m_cloth = Pix.gmat("tex_cloth_red", 1.4)
    m_gold = Pix.gmat("tex_gold", 1.0)
    m_wood = Pix.flat("#3a2016", 0.7)
    for z in TABLE_ROWS:
        for x in TABLE_COLS:
            TABLES.append(Vector2(x, z))
    _env()
    _room()
    _stage()
    _head_table()
    for i in TABLES.size():
        _table(TABLES[i], i)
    _aisle()
    _screens()
    _pillars()
    _door()
    _merge_static()
    _props()
    _nav()
    _player(preset, nickname)
    cam = Camera3D.new()
    cam.fov = 40.0
    cam.current = true
    add_child(cam)
    snap_cam()

# ---------- 小工具 ----------
func _mi(mesh: Mesh, p: Vector3, m: Material, shadow := true) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    n.mesh = mesh
    n.position = p
    n.material_override = m
    n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(n)
    return n

func _box(p: Vector3, s: Vector3, m: Material, shadow := true) -> MeshInstance3D:
    var b := BoxMesh.new()
    b.size = s
    return _mi(b, p, m, shadow)

func _cyl(p: Vector3, r_top: float, r_bot: float, h: float, m: Material, seg := 20) -> MeshInstance3D:
    var c := CylinderMesh.new()
    c.top_radius = r_top
    c.bottom_radius = r_bot
    c.height = h
    c.radial_segments = seg
    return _mi(c, p, m)

## 不动的方块和圆柱按材质并成一个网格。原来每把椅子、每碟菜各画一次，一帧三百多次，手机微信里会卡
## 半透明的（出口光圈）、会动的（人物、名字）不并；地毯、桌面、椅背这类按贴图坐标贴的也并（Geo 带贴图坐标）
##
## 注意：网格数据必须自己在 CPU 上算，不能用 SurfaceTool.append_from、surface_get_arrays、
## get_mesh_arrays——它们都要把网格从显卡读回来（WebGL 的 getBufferSubData），
## 微信的 WebGL 不支持，搭厅搭到一半就崩。电脑上测不出来
func _merge_static() -> void:
    var geos := {}
    var olds: Array = []
    for n in find_children("*", "MeshInstance3D", true, false):
        var mi := n as MeshInstance3D
        var m := mi.material_override as BaseMaterial3D
        if mi == exit_mark or m == null:
            continue
        if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and m.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
            continue
        if not (mi.mesh is BoxMesh or mi.mesh is CylinderMesh or mi.mesh is PlaneMesh):
            continue
        var cast := mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        var key := "%d|%s" % [m.get_instance_id(), cast]
        if not geos.has(key):
            geos[key] = Geo.new(m, cast)
        var g: Geo = geos[key]
        var xf := _rel_xf(mi)
        if mi.mesh is BoxMesh:
            g.box(xf, (mi.mesh as BoxMesh).size)
        elif mi.mesh is PlaneMesh:
            g.plane(xf, (mi.mesh as PlaneMesh).size)
        else:
            var c := mi.mesh as CylinderMesh
            g.cyl(xf, c.top_radius, c.bottom_radius, c.height, c.radial_segments)
        olds.append(mi)
    for mi in olds:
        mi.get_parent().remove_child(mi)
        mi.free()
    # 并完只剩空壳的分组节点删掉
    for node in get_children():
        if node.get_class() == "Node3D" and node.get_child_count() == 0:
            node.free()
    for key in geos:
        add_child((geos[key] as Geo).build())

## 网格相对宴会厅的变换，一层层父节点乘上来。不用 global_transform：那个要求已经挂进场景树，测试和别的场景里不一定成立
func _rel_xf(n: Node3D) -> Transform3D:
    var xf := n.transform
    var p := n.get_parent()
    while p != null and p != self:
        xf = (p as Node3D).transform * xf
        p = p.get_parent()
    return xf

## 合并用的几何数据，全在 CPU 上算。带贴图坐标：
## 方块每个面各贴一整张（正着看，上边朝上）；平面按俯视贴（图的上边朝北）；圆柱顶面按圆贴
## 铺花纹的材质是按世界坐标铺的，用不到这些坐标；椅背、桌面这类「贴一整张」的积木要用
class Geo:
    var v := PackedVector3Array()
    var n := PackedVector3Array()
    var uv := PackedVector2Array()
    var idx := PackedInt32Array()
    var mat: Material
    var cast: bool

    func _init(m: Material, c: bool) -> void:
        mat = m
        cast = c

    ## 加一个三角形。out_n 是这一面朝外的方向，按它自动排顶点顺序（Godot 顺时针为正面）
    func tri(xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, out_n: Vector3,
            ta := Vector2.ZERO, tb := Vector2.ZERO, tc := Vector2.ZERO) -> void:
        if (b - a).cross(c - a).dot(out_n) > 0.0:
            var t := b; b = c; c = t
            var tn := nb; nb = nc; nc = tn
            var tt := tb; tb = tc; tc = tt
        for k in 3:
            var p: Vector3 = [a, b, c][k]
            idx.append(v.size())
            v.append(xf * p)
            n.append((xf.basis * ([na, nb, nc][k] as Vector3)).normalized())
            uv.append([ta, tb, tc][k])

    ## 一个面：中心 c，right/up 是这一面里朝右、朝上的方向（已经乘好半边长）
    func quad(xf: Transform3D, c: Vector3, right: Vector3, up: Vector3, nrm: Vector3) -> void:
        var tl := c - right + up
        var tr := c + right + up
        var br := c + right - up
        var bl := c - right - up
        tri(xf, tl, tr, br, nrm, nrm, nrm, nrm, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1))
        tri(xf, tl, br, bl, nrm, nrm, nrm, nrm, Vector2(0, 0), Vector2(1, 1), Vector2(0, 1))

    func box(xf: Transform3D, size: Vector3) -> void:
        var h := size * 0.5
        # 每个面：朝外方向、朝右、朝上。侧面上边朝上，顶面上边朝北
        for f in [[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
                [Vector3.RIGHT, Vector3.FORWARD, Vector3.UP], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
                [Vector3.UP, Vector3.RIGHT, Vector3.FORWARD], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK]]:
            var nrm: Vector3 = f[0]
            var r: Vector3 = f[1]
            var u: Vector3 = f[2]
            quad(xf, nrm * absf(h.dot(nrm)), r * absf(h.dot(r)), u * absf(h.dot(u)), nrm)

    ## 水平的平面（PlaneMesh 的样子），图的上边朝北
    func plane(xf: Transform3D, size: Vector2) -> void:
        quad(xf, Vector3.ZERO, Vector3(size.x * 0.5, 0, 0), Vector3(0, 0, -size.y * 0.5), Vector3.UP)

    func cyl(xf: Transform3D, rt: float, rb: float, height: float, seg: int) -> void:
        var hy := height * 0.5
        var slope := (rb - rt) / height
        for i in seg:
            var a0 := TAU * i / seg
            var a1 := TAU * (i + 1) / seg
            var d0 := Vector3(cos(a0), 0, sin(a0))
            var d1 := Vector3(cos(a1), 0, sin(a1))
            var n0 := Vector3(d0.x, slope, d0.z).normalized()
            var n1 := Vector3(d1.x, slope, d1.z).normalized()
            var b0 := d0 * rb - Vector3(0, hy, 0)
            var b1 := d1 * rb - Vector3(0, hy, 0)
            var t0 := d0 * rt + Vector3(0, hy, 0)
            var t1 := d1 * rt + Vector3(0, hy, 0)
            var mid := (d0 + d1).normalized()
            var u0 := float(i) / seg
            var u1 := float(i + 1) / seg
            tri(xf, b0, b1, t1, n0, n1, n1, mid, Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0))
            tri(xf, b0, t1, t0, n0, n1, n0, mid, Vector2(u0, 1), Vector2(u1, 0), Vector2(u0, 0))
            if rt > 0.0:
                tri(xf, Vector3(0, hy, 0), t0, t1, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP,
                    Vector2(0.5, 0.5), Vector2(0.5 + d0.x * 0.5, 0.5 + d0.z * 0.5), Vector2(0.5 + d1.x * 0.5, 0.5 + d1.z * 0.5))
            if rb > 0.0:
                tri(xf, Vector3(0, -hy, 0), b1, b0, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN,
                    Vector2(0.5, 0.5), Vector2(0.5 + d1.x * 0.5, 0.5 + d1.z * 0.5), Vector2(0.5 + d0.x * 0.5, 0.5 + d0.z * 0.5))

    func build() -> MeshInstance3D:
        var arr := []
        arr.resize(Mesh.ARRAY_MAX)
        arr[Mesh.ARRAY_VERTEX] = v
        arr[Mesh.ARRAY_NORMAL] = n
        arr[Mesh.ARRAY_TEX_UV] = uv
        arr[Mesh.ARRAY_INDEX] = idx
        var am := ArrayMesh.new()
        am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
        var out := MeshInstance3D.new()
        out.mesh = am
        out.material_override = mat
        out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        return out

## 开场先用俯视大广角把整个厅画几帧：每种材质的着色器第一次出现在画面里时才编译，
## 手机上一次要卡一下。趁开场黑屏全编完，走路时就不卡了
func warm_up() -> void:
    var keep := cam.transform
    var keep_fov := cam.fov
    cam.fov = 75.0
    cam.position = Vector3(0, 26, 8)
    cam.look_at(Vector3(0, 0, -9), Vector3.UP)
    # 用 process_frame 数帧：每帧必到；等「画完一帧」的信号，万一哪个平台不发就会一直黑屏
    for i in 4:
        await get_tree().process_frame
    cam.fov = keep_fov
    cam.transform = keep

func _omni(p: Vector3, energy := 1.0, rng := 6.5) -> void:
    var o := OmniLight3D.new()
    o.position = p
    o.light_color = Color("#ffa060")
    o.light_energy = energy
    o.omni_range = rng
    add_child(o)

# ---------- 环境与光 ----------
## 效果图是暖黄、明亮的：环境光提亮、偏暖；灯只放 4 盏（灯越多，手机上要编译的着色器越多、越慢）
func _env() -> void:
    var we := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color("#1a0d12")
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color("#c09a80")
    e.ambient_light_energy = 0.72
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    e.glow_enabled = true
    e.glow_intensity = 0.8
    e.glow_bloom = 0.12
    e.glow_hdr_threshold = 0.95
    we.environment = e
    add_child(we)
    var sun := DirectionalLight3D.new()
    sun.light_color = Color("#ffe0b8")
    sun.light_energy = 0.85
    sun.rotation_degrees = Vector3(-56, -28, 0)
    sun.shadow_enabled = true
    # 默认分 4 段画阴影，每个物体要多画 4 遍；2 段够用
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
    sun.directional_shadow_max_distance = 30.0
    add_child(sun)
    _omni(Vector3(0, 3.0, -11.0), 1.2, 9.0)
    _omni(Vector3(0, 3.0, -3.0), 1.2, 9.0)
    _omni(Vector3(0, 3.2, -16.8), 1.4, 9.0)
    _omni(Vector3(0, 2.4, 2.6), 0.8, 6.0)

## GPT 的道具贴片立在 3D 里（永远侧对镜头）。h 是高度（米），位置是底边中点
func _prop_sprite(name: String, p: Vector3, h: float) -> Sprite3D:
    var path := "res://assets/props/%s.png" % name
    if not ResourceLoader.exists(path):
        return null
    var s := Sprite3D.new()
    s.texture = load(path)
    s.pixel_size = h / s.texture.get_height()
    s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
    s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
    s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    s.position = p + Vector3(0, h * 0.5, 0)
    add_child(s)
    return s

## 地毯、红毯：GPT 的地毯贴图横向正好铺一张，两边是金边
func _rug(center: Vector3, size: Vector2) -> void:
    var pm := PlaneMesh.new()
    pm.size = size
    if not _cache_rug.has(size):
        var cm := StandardMaterial3D.new()
        cm.albedo_texture = Pix.gtex("tex_carpet_red")
        cm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
        cm.uv1_scale = Vector3(1, size.y / size.x, 1)
        cm.roughness = 1.0
        _cache_rug[size] = cm
    _mi(pm, center, _cache_rug[size], false)

# ---------- 厅 ----------
func _room() -> void:
    # 大厅地面：浅色石材（占位，等 GPT 交 tex_floor_stone），略带反光
    var floor_m := Pix.gmat("tex_floor_stone", 1.0 * 4.0)
    floor_m.roughness = 0.35
    _box(Vector3(0, -0.05, -8.5), Vector3(HALL_W * 2.0, 0.1, 28.0), floor_m, false)
    # 中间红地毯，从门口通到主桌前
    _rug(Vector3(0, 0.012, -5.6), Vector2(2.6, 18.2))
    # 后墙、帘子
    _box(Vector3(0, 3.6, -22.3), Vector3(HALL_W * 2.0, 7.2, 0.3), Pix.gmat("tex_wall_red", 2.0))
    var m_drape := Pix.gmat("tex_drape_red", 1.0)
    for sx in [-1.0, 1.0]:
        _box(Vector3(sx * 3.3, 3.4, -22.05), Vector3(1.4, 6.4, 0.2), m_drape)
        _box(Vector3(sx * 7.6, 3.4, -22.05), Vector3(1.6, 6.4, 0.2), m_drape)
    # 两边墙：木格窗，上下是深色木梁
    var m_window := Pix.gmat("tex_lattice", 2.6)
    for sx in [-1.0, 1.0]:
        _box(Vector3(sx * HALL_W, 2.6, -8.5), Vector3(0.3, 5.2, 28.0), m_window)
        _box(Vector3(sx * (HALL_W - 0.2), 0.3, -8.5), Vector3(0.12, 0.6, 28.0), m_wood)
        _box(Vector3(sx * (HALL_W - 0.2), 5.3, -8.5), Vector3(0.14, 0.24, 28.0), m_wood)
        _banner(Vector3(sx * (HALL_W - 0.18), 3.0, -14.0), sx)
    # 囍：金色大字挂在舞台正中（效果图这里是圆形山水挂画，GPT 还没交，先挂囍）
    var frame_m := m_gold
    _box(Vector3(0, 6.35, -22.1), Vector3(4.2, 0.18, 0.12), frame_m)
    _box(Vector3(0, 2.35, -22.1), Vector3(4.2, 0.18, 0.12), frame_m)
    _box(Vector3(-2.02, 4.35, -22.1), Vector3(0.18, 4.0, 0.12), frame_m)
    _box(Vector3(2.02, 4.35, -22.1), Vector3(0.18, 4.0, 0.12), frame_m)
    var xi_path := "res://assets/decals/decal_xi_gold.png"
    if ResourceLoader.exists(xi_path):
        # GPT 画的金色囍贴片，高 3.3 米，正好在金框里
        var xs := Sprite3D.new()
        xs.texture = load(xi_path)
        xs.pixel_size = 3.3 / xs.texture.get_height()
        xs.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
        xs.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
        xs.shaded = false
        xs.position = Vector3(0, 4.35, -21.9)
        add_child(xs)
    else:
        var xi := Label3D.new()
        xi.font = font
        xi.text = "囍"
        xi.font_size = 312   # 像素字体，要 12 的整倍数
        xi.pixel_size = 0.0105
        xi.modulate = Color("#f4d97a")
        xi.outline_size = 18
        xi.outline_modulate = Color("#8C2F27")
        xi.position = Vector3(0, 4.35, -21.9)
        xi.shaded = false
        add_child(xi)

## 侧墙上的红底囍挂幅（效果图右墙有一幅）
func _banner(p: Vector3, side: float) -> void:
    var cloth := _box(p, Vector3(0.06, 3.2, 1.8), m_cloth)
    cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _box(p + Vector3(0, 1.66, 0), Vector3(0.1, 0.1, 2.0), m_gold)
    var xi_path := "res://assets/decals/decal_xi_gold.png"
    if ResourceLoader.exists(xi_path):
        var xs := Sprite3D.new()
        xs.texture = load(xi_path)
        xs.pixel_size = 1.3 / xs.texture.get_height()
        xs.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
        xs.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
        xs.shaded = false
        xs.rotation.y = -side * PI / 2.0
        xs.position = p + Vector3(-side * 0.05, 0.2, 0)
        add_child(xs)

## 舞台：GPT 的木地板铺台面，两边有台阶上去，台上立两盏灯笼
func _stage() -> void:
    # 台面：GPT 的 tex_floor_wood 铺上去是红蓝杂色，和效果图的暖色木台对不上，先用代码画的木板占位（回执 A01 第 5 条）
    _box(Vector3(0, 0.25, -19.2), Vector3(17.2, 0.5, 5.6), Pix.mat(Pix.wood(), 2.0))
    _box(Vector3(0, 0.51, -16.42), Vector3(17.2, 0.05, 0.08), m_gold)
    for sx in [-1.0, 1.0]:
        for k in 3:
            var h := 0.5 * (k + 1) / 3.0
            _box(Vector3(sx * 7.0, h * 0.5, -15.4 - k * 0.34 - 0.17), Vector3(1.8, h, 0.34), m_cloth)
        for dx in [-0.95, 0.95]:
            _box(Vector3(sx * 7.0 + dx, 0.55, -15.9), Vector3(0.08, 1.1, 0.08), m_gold)
        _floor_lantern(Vector3(sx * 4.6, 0.5, -17.6))
        _floor_lantern(Vector3(sx * 8.2, 0.5, -20.6))
        obst.append([Vector2(sx * 7.0, -15.6), 0.9])

## 主桌：舞台上靠前的长桌，红桌裙、米色桌面、摆花；新人站在桌子后面
## 效果图里主桌在台下，这里放台上：对话点在舞台前 (0,-15.4)，镜头往前看 5.5 米，
## 新人在台上正好落在画面中间；放台下会贴着玩家，被写悄悄话的框挡住
func _head_table() -> void:
    var y0 := 0.5
    _box(Vector3(0, y0 + 0.38, HEAD_Z), Vector3(5.4, 0.76, 0.8), m_cloth)
    _box(Vector3(0, y0 + 0.775, HEAD_Z), Vector3(5.5, 0.04, 0.92), Pix.flat("#ecdcc0", 0.8))
    _box(Vector3(0, y0 + 0.74, HEAD_Z + 0.47), Vector3(5.5, 0.05, 0.02), m_gold)
    for x in [-2.0, -1.0, 1.0, 2.0]:
        _cyl(Vector3(x, y0 + 0.81, HEAD_Z + 0.15), 0.16, 0.16, 0.025, Pix.flat("#f6eedf", 0.4), 12)
    for x in [-1.6, 1.6]:
        _prop_sprite("prop_flower_basket", Vector3(x, y0 + 0.8, HEAD_Z - 0.1), 0.6)
    # 新人：用现有合照立绘，不重画、不改礼服
    var cp := Sprite3D.new()
    cp.texture = load("res://assets/couple.png")
    cp.pixel_size = 2.6 / 320.0
    cp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
    cp.shaded = false
    cp.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
    cp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    cp.position = Vector3(0, y0 + 1.3, COUPLE_Z)
    cp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    add_child(cp)

## 一张圆桌：底下一块地毯，红桌裙、金边、米色桌面、一圈盘子、中间一篮花，八把深色木椅
func _table(c: Vector2, idx: int) -> void:
    var x := c.x
    var z := c.y
    _rug(Vector3(x, 0.014, z), Vector2(4.5, 4.4))
    _cyl(Vector3(x, 0.37, z), 1.26, 1.32, 0.74, m_cloth)
    # 金边只露一圈：金盘上面再盖一层小一点的红桌布
    _cyl(Vector3(x, 0.755, z), 1.34, 1.34, 0.03, m_gold)
    _cyl(Vector3(x, 0.775, z), 1.28, 1.28, 0.02, m_cloth)
    if Pix.has_block("decals", "decal_tabletop"):
        # GPT 的桌面积木（A02）：红布、桌旗、一圈碗碟都画在图里，整张平铺在桌面上，直径和红桌布一样
        var pm := PlaneMesh.new()
        pm.size = Vector2(2.56, 2.56)
        _mi(pm, Vector3(x, 0.788, z), Pix.block_mat("decals", "decal_tabletop"), false)
    else:
        # 占位：中间米色转盘，一圈白盘子
        _cyl(Vector3(x, 0.795, z), 0.72, 0.72, 0.02, Pix.flat("#ecdcc0", 0.8))
        for k in 8:
            var a := TAU * k / 8.0 + TAU / 16.0
            _cyl(Vector3(x + cos(a) * 0.98, 0.8, z + sin(a) * 0.98), 0.15, 0.15, 0.02, Pix.flat("#f6eedf", 0.4), 12)
    _prop_sprite("prop_flower_basket", Vector3(x, 0.8, z), 0.55)
    var cushion := Pix.flat("#9c2a22", 0.8)
    # GPT 的雕花椅背（A02）：一整张贴在椅背前后两面，镂空的孔能透过去；没交就用深色木板
    var back_m: Material = Pix.block_mat("textures", "tex_chair_back") if Pix.has_block("textures", "tex_chair_back") else m_wood
    for k in 8:
        var a := TAU * k / 8.0 + TAU / 16.0
        var out := Vector2(cos(a), sin(a))
        var cp := c + out * 1.78
        _box(Vector3(cp.x, 0.44, cp.y), Vector3(0.48, 0.06, 0.48), m_wood)
        _box(Vector3(cp.x, 0.49, cp.y), Vector3(0.42, 0.05, 0.42), cushion)
        var back := _box(Vector3(cp.x + out.x * 0.22, 0.8, cp.y + out.y * 0.22), Vector3(0.48, 0.66, 0.06), back_m)
        back.rotation.y = atan2(out.x, out.y)
        # 桌子北边坐着其他宾客，桌布挡住腿，看着像坐下了
        if out.y < -0.3 and Pix.h2(idx * 7 + k, 3) > 0.35:
            _guest(Vector2(cp.x + out.x * 0.12, cp.y + out.y * 0.12), int(Pix.h2(idx, k) * 8.0) % 8)
    obst.append([c, 2.0])   # 椅背外沿约 2.02 米；再大，两排桌子中间的过道在半米一格的寻路网格里会被判成堵死

## 红地毯两边：木格落地灯笼和花架交替立着
func _aisle() -> void:
    for sx in [-1.0, 1.0]:
        for z in AISLE_LAMPS:
            _floor_lantern(Vector3(sx * AISLE_X, 0, z))
            obst.append([Vector2(sx * AISLE_X, z), 0.35])
        for z in AISLE_FLOWERS:
            _cyl(Vector3(sx * AISLE_X, 0.35, z), 0.2, 0.26, 0.7, m_wood, 12)
            _cyl(Vector3(sx * AISLE_X, 0.71, z), 0.24, 0.24, 0.03, m_gold, 12)
            _prop_sprite("prop_flower_basket", Vector3(sx * AISLE_X, 0.72, z), 0.95)
            obst.append([Vector2(sx * AISLE_X, z), 0.35])

## 木格落地灯笼：底座、立柱、会发光的木格灯罩、顶盖。p 是底座中心
func _floor_lantern(p: Vector3) -> void:
    _box(p + Vector3(0, 0.06, 0), Vector3(0.46, 0.12, 0.46), m_wood)
    _box(p + Vector3(0, 0.6, 0), Vector3(0.1, 1.0, 0.1), m_wood)
    var shade := _box(p + Vector3(0, 1.55, 0), Vector3(0.52, 0.92, 0.52), Pix.lamp_mat())
    shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _box(p + Vector3(0, 2.04, 0), Vector3(0.4, 0.06, 0.4), m_wood)
    _box(p + Vector3(0, 2.12, 0), Vector3(0.1, 0.1, 0.1), m_gold)

## 桌组之间的木格屏风（内外两列桌子中间，每排一扇）
func _screens() -> void:
    var m_lat := Pix.gmat("tex_lattice", 1.7)
    for sx in [-1.0, 1.0]:
        for z in TABLE_ROWS:
            var p := Vector3(sx * 7.2, 0, z)
            _box(p + Vector3(0, 0.95, 0), Vector3(0.08, 1.7, 2.2), m_lat)
            _box(p + Vector3(0, 1.84, 0), Vector3(0.12, 0.08, 2.3), m_wood)
            _box(p + Vector3(0, 0.06, 0), Vector3(0.14, 0.12, 2.3), m_wood)
            for dz in [-1.1, 1.1]:
                _box(p + Vector3(0, 0.95, dz), Vector3(0.12, 1.9, 0.1), m_wood)
            for dz in [-0.8, 0.0, 0.8]:
                obst.append([Vector2(p.x, z + dz), 0.4])

func _guest(p: Vector2, preset: int) -> void:
    var s := Sprite3D.new()
    var gl := Spr.gpt_look(preset)
    if gl.is_empty():
        if not sheets.has(preset):
            sheets[preset] = ImageTexture.create_from_image(Spr.sheet(preset))
        s.texture = sheets[preset]
        s.hframes = 9
        s.frame = 0
        s.pixel_size = 1.6 / 32.0
        var sc: Vector2 = Spr.PRESETS[preset]["scale"]
        s.scale = Vector3(sc.x, sc.y, 1)
        s.position = Vector3(p.x, 0.35 + 0.8 * sc.y, p.y)
    else:
        # GPT 画的宾客：坐着，所以画成 1.6 米高，脚被桌布挡住
        s.texture = gl["tex"]
        s.hframes = gl["hframes"]
        s.frame = gl["anim"]["down"]["idle"]
        s.pixel_size = 1.6 / float(gl["frame_h"])
        s.position = Vector3(p.x, 0.35 + 0.8, p.y)
    s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
    s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
    s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    add_child(s)
    guests.append(s)

## GPT 场景配置里的道具贴片：位置、缩放照 scenes/scene_roman_banquet.json，高度照每个道具的 json
## 落在圆桌范围里的（比如喜糖盒）摆到桌面上；落地的大件挡路
func _props() -> void:
    var cfg = _json(SCENE_JSON)
    if typeof(cfg) != TYPE_DICTIONARY:
        return
    for o in cfg.get("objects", []):
        var name := str(o.get("asset", ""))
        var tex_path := "res://assets/props/%s.png" % name
        var meta = _json("res://assets/props/%s.json" % name)
        if not ResourceLoader.exists(tex_path) or typeof(meta) != TYPE_DICTIONARY:
            push_warning("场景里的道具没有图或说明：" + name)
            continue
        var tex: Texture2D = load(tex_path)
        var h := float(meta.get("height_m", 0.5)) * float(o.get("scale", 1.0))
        var p := Vector2(float(o.get("x", 0.0)), float(o.get("z", 0.0)))
        var base_y := 0.0
        for c in TABLES:
            if p.distance_to(c) < 1.3:
                base_y = TABLE_TOP
        var s := Sprite3D.new()
        s.texture = tex
        s.pixel_size = h / tex.get_height()
        if bool(meta.get("billboard", true)):
            s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
        else:
            s.rotation.y = deg_to_rad(float(o.get("rot", 0.0)))
        s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
        s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
        s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        s.position = Vector3(p.x, base_y + h * 0.5, p.y)
        add_child(s)
        if base_y == 0.0 and h > 0.3:
            obst.append([p, 0.35])

func _json(path: String):
    if not FileAccess.file_exists(path):
        return null
    return JSON.parse_string(FileAccess.get_file_as_string(path))

func _pillars() -> void:
    var red := Pix.flat("#8C2F27", 0.6)
    for sx in [-1.0, 1.0]:
        for z in [-18.0, -12.0, -6.0, 0.0]:
            _cyl(Vector3(sx * (HALL_W - 0.45), 2.6, z), 0.28, 0.3, 5.2, red, 14)
            _cyl(Vector3(sx * (HALL_W - 0.45), 5.1, z), 0.36, 0.36, 0.14, m_gold, 14)
            _cyl(Vector3(sx * (HALL_W - 0.45), 0.08, z), 0.4, 0.4, 0.16, m_gold, 14)

## 门口：两根红柱子、横梁、两盏落地灯笼；离场时地上亮一圈光
func _door() -> void:
    var red := Pix.flat("#8C2F27", 0.6)
    for sx in [-1.0, 1.0]:
        _box(Vector3(sx * 1.8, 1.3, 4.4), Vector3(0.36, 2.6, 0.36), red)
        obst.append([Vector2(sx * 1.8, 4.4), 0.45])
        _floor_lantern(Vector3(sx * 2.6, 0, 3.9))
        obst.append([Vector2(sx * 2.6, 3.9), 0.35])
    _box(Vector3(0, 2.65, 4.4), Vector3(4.2, 0.3, 0.4), red)
    _box(Vector3(0, 2.84, 4.4), Vector3(4.4, 0.08, 0.5), m_gold)
    var disc := CylinderMesh.new()
    disc.top_radius = 0.9; disc.bottom_radius = 0.9; disc.height = 0.02; disc.radial_segments = 24
    exit_mat = Pix.glow("#F4D97A", 1.5).duplicate()   # 它会一闪一闪，不能和别人共用
    exit_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    exit_mat.albedo_color.a = 0.55
    exit_mark = _mi(disc, Vector3(0, 0.03, 3.1), exit_mat, false)
    exit_mark.visible = false

# ---------- 走路 ----------
func _nav() -> void:
    nav.region = Rect2i(0, 0, int(round((X1 - X0) / CELL)), int(round((Z1 - Z0) / CELL)))
    nav.cell_size = Vector2.ONE
    nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    nav.update()
    for j in nav.region.size.y:
        for i in nav.region.size.x:
            if not _free(_cell_pos(Vector2i(i, j))):
                nav.set_point_solid(Vector2i(i, j), true)
    # 被桌椅、台阶、墙围死的小角落也标成走不了：点到那儿时就近走到能到的地方，而不是原地不动
    var start := _cell_of(SPAWN)
    var seen := {start: true}
    var q: Array = [start]
    while not q.is_empty():
        var c: Vector2i = q.pop_back()
        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
            var n: Vector2i = c + d
            if nav.is_in_boundsv(n) and not nav.is_point_solid(n) and not seen.has(n):
                seen[n] = true
                q.append(n)
    for j in nav.region.size.y:
        for i in nav.region.size.x:
            var cell := Vector2i(i, j)
            if not nav.is_point_solid(cell) and not seen.has(cell):
                nav.set_point_solid(cell, true)

func _cell_pos(c: Vector2i) -> Vector2:
    return Vector2(X0 + (c.x + 0.5) * CELL, Z0 + (c.y + 0.5) * CELL)

func _cell_of(p: Vector2) -> Vector2i:
    return Vector2i(clampi(int((p.x - X0) / CELL), 0, nav.region.size.x - 1), clampi(int((p.y - Z0) / CELL), 0, nav.region.size.y - 1))

func _free(p: Vector2, r := 0.3) -> bool:
    if p.x < X0 + r or p.x > X1 - r or p.y < Z0 + r or p.y > Z1 - r:
        return false
    for o in obst:
        if p.distance_to(o[0]) < o[1] + r:
            return false
    return true

func _nearest_free(c: Vector2i) -> Vector2i:
    for rad in range(1, 30):
        for dj in range(-rad, rad + 1):
            for di in range(-rad, rad + 1):
                var n := c + Vector2i(di, dj)
                if nav.is_in_boundsv(n) and not nav.is_point_solid(n):
                    return n
    return c

func _clear(a: Vector2, b: Vector2) -> bool:
    var n := int(ceil(a.distance_to(b) / 0.2))
    for k in range(1, n):
        if not _free(a.lerp(b, float(k) / n), 0.28):
            return false
    return true

func tap(screen: Vector2) -> void:
    if not walking_enabled:
        return
    var o := cam.project_ray_origin(screen)
    var d := cam.project_ray_normal(screen)
    if absf(d.y) < 0.001:
        return
    var hit := o + d * (-o.y / d.y)
    var t0 := Time.get_ticks_usec()
    go_to(Vector2(hit.x, hit.z))
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

# ---------- 玩家 ----------
func _player(preset: int, nickname: String) -> void:
    player = Sprite3D.new()
    player.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
    player.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    player.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
    player.pixel_size = 1.75 / 32.0
    player.hframes = 9
    player.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    add_child(player)
    tag = Label3D.new()
    tag.font = font
    tag.font_size = 36
    tag.pixel_size = 0.0068
    tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    tag.modulate = Color("#F4D97A")
    tag.outline_size = 10
    tag.outline_modulate = Color("#1b1422")
    tag.no_depth_test = true
    add_child(tag)
    var pm := PlaneMesh.new()
    pm.size = Vector2(1.0, 0.6)
    var bm := StandardMaterial3D.new()
    bm.albedo_texture = Pix.blob()
    bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    blob = _mi(pm, Vector3.ZERO, bm, false)
    set_look(preset, nickname)

func set_look(preset: int, nickname: String) -> void:
    var gl := Spr.gpt_look(preset)
    if gl.is_empty():
        player.texture = ImageTexture.create_from_image(Spr.sheet(preset))
        player.hframes = 9
        player.pixel_size = 1.75 / 32.0
        var sc: Vector2 = Spr.PRESETS[preset]["scale"]
        player.scale = Vector3(sc.x, sc.y, 1)
        player_h = 1.75 * sc.y
        look = Spr.PROC_ANIM
        look_fps = 7.7
    else:
        player.texture = gl["tex"]
        player.hframes = gl["hframes"]
        player_h = gl["height_m"]
        player.pixel_size = player_h / float(gl["frame_h"])
        player.scale = Vector3.ONE
        look = gl["anim"]
        look_fps = gl["fps"]
    player.frame = look["up"]["idle"]
    tag.text = nickname

func reset_to(p: Vector2) -> void:
    pos = p
    path.clear()
    stick = Vector2.ZERO
    face = "up"
    snap_cam()

## 手指左右拖屏幕转镜头，最多各 45 度，松手停在那儿
func rotate_cam(drag_px: float) -> void:
    cam_yaw = clampf(cam_yaw - drag_px * 0.006, -CAM_YAW_MAX, CAM_YAW_MAX)

func _cam_basis() -> Basis:
    return Basis(Vector3.UP, cam_yaw)

func _cam_want() -> Vector3:
    return Vector3(pos.x * 0.5, 0.9, pos.y) + _cam_basis() * Vector3(0, 0, -LOOK_AHEAD)

func snap_cam() -> void:
    cam_target = _cam_want()
    _place_cam()

func _place_cam() -> void:
    cam.position = cam_target + _cam_basis() * Vector3(0, 15.5, 13.0)
    cam.look_at(cam_target, Vector3.UP)

## 人朝哪边：按走的方向相对镜头算（镜头转了，「往上走」还是背对镜头）
func _face_for(world_dir: Vector2) -> String:
    var local := _cam_basis().inverse() * Vector3(world_dir.x, 0, world_dir.y)
    if absf(local.x) > absf(local.z) * 1.2:
        return "right" if local.x > 0.0 else "left"
    return "up" if local.z < 0.0 else "down"

## 摇杆走路：挡住了就试着只走一个方向，贴着桌子边滑过去
func _stick_move(dt: float) -> bool:
    var d3 := _cam_basis() * Vector3(stick.x, 0, stick.y)
    var dir := Vector2(d3.x, d3.z)
    var step := dir * SPEED * dt
    for np: Vector2 in [pos + step, pos + Vector2(step.x, 0), pos + Vector2(0, step.y)]:
        if np != pos and _free(np, 0.24):
            pos = np
            face = _face_for(dir)
            return true
    face = _face_for(dir)
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
        if dist < 0.06:
            path.pop_front()
        else:
            var np := pos + to / dist * minf(dist, SPEED * dt)
            if _free(np, 0.24):
                pos = np
                moving = true
            else:
                path.clear()
            face = _face_for(to)
    anim = anim + dt if moving else 0.0
    var fl: Dictionary = look[face]
    var walk: Array = fl["walk"]
    player.frame = walk[int(anim * look_fps) % walk.size()] if moving else fl["idle"]
    player.flip_h = fl["flip"]
    player.position = Vector3(pos.x, player_h * 0.5, pos.y)
    tag.position = Vector3(pos.x, player_h + 0.35, pos.y)
    blob.position = Vector3(pos.x, 0.02, pos.y)
    cam_target = cam_target.lerp(_cam_want(), 1.0 - exp(-dt * 5.0))
    _place_cam()
    if exit_mark.visible:
        exit_mat.emission_energy_multiplier = 1.2 + sin(t * 3.0) * 0.6
    if couple_armed and pos.distance_to(COUPLE_SPOT) < 1.7:
        couple_armed = false
        path.clear()
        face = "up"
        reached.emit("couple")
    if exit_armed and pos.y > 2.7 and absf(pos.x) < 1.5:
        exit_armed = false
        path.clear()
        reached.emit("exit")

func arm_exit() -> void:
    exit_armed = true
    exit_mark.visible = true
