extends RefCounted
## 像素贴图：全部逐像素生成，材质里用最近邻显示，不依赖外部图片
## 颜色取自美术生图包 1.2 的调色板

static func h2(x: int, y: int) -> float:
    var h: int = (x * 374761393 + y * 668265263) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return float(h & 0xFFFF) / 65536.0

static func vnoise(x: float, y: float) -> float:
    var xi := int(floor(x))
    var yi := int(floor(y))
    var xf := x - xi
    var yf := y - yi
    var a := h2(xi, yi)
    var b := h2(xi + 1, yi)
    var c := h2(xi, yi + 1)
    var d := h2(xi + 1, yi + 1)
    var u := xf * xf * (3.0 - 2.0 * xf)
    var v := yf * yf * (3.0 - 2.0 * yf)
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v

static func fbm(x: float, y: float) -> float:
    return vnoise(x, y) * 0.55 + vnoise(x * 2.3, y * 2.3) * 0.3 + vnoise(x * 5.1, y * 5.1) * 0.15

static func blank(w: int, h: int) -> Image:
    return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)

static func noise(im: Image, x: int, y: int, w: int, h: int, hexes: Array, seed := 1, sc := 0.35) -> void:
    var cols: Array = []
    for hx in hexes: cols.append(Color(hx))
    for j in h:
        for i in w:
            var n := fbm((x + i) * sc + seed * 13.1, (y + j) * sc) + (h2(x + i + seed * 71, y + j) - 0.5) * 0.25
            im.set_pixel(x + i, y + j, cols[clampi(int(n * cols.size()), 0, cols.size() - 1)])

static func tex(im: Image) -> ImageTexture:
    im.generate_mipmaps()
    return ImageTexture.create_from_image(im)

## 盒子、圆柱用世界坐标三向投影，贴图按真实尺寸重复，不拉伸
static func mat(t: Texture2D, tile := 2.0, tint := Color.WHITE) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_texture = t
    m.albedo_color = tint
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
    m.uv1_triplanar = true
    m.uv1_world_triplanar = true
    m.uv1_scale = Vector3.ONE / tile
    m.roughness = 0.9
    return m

## GPT 交付的贴图（assets/textures，由 tools/import_gpt.py 接进来）；还没交的用代码画的占位
static func gtex(name: String) -> Texture2D:
    var p := "res://assets/textures/%s.png" % name
    if ResourceLoader.exists(p):
        return load(p)
    match name:
        "tex_floor_wood": return wood()
        "tex_cloth_red": return cloth()
        "tex_wall_red": return wall()
        "tex_drape_red": return drape()
        "tex_lattice": return lattice()
        "tex_gold": return gold()
        "tex_carpet_red": return carpet()
        "tex_floor_stone": return marble()
    push_warning("没有这张贴图：" + name)
    return tex(blank(4, 4))

## 铺在 3D 表面上的材质。GPT 的贴图按 16 像素 = 1 米铺（ASSETS.md 第 2 节）；占位图用原来的铺法
static func gmat(name: String, fallback_tile: float) -> StandardMaterial3D:
    var t := gtex(name)
    var from_gpt := ResourceLoader.exists("res://assets/textures/%s.png" % name)
    return mat(t, t.get_width() / 16.0 if from_gpt else fallback_tile)

## 大厅浅色石材地面的占位图：效果图里是米色大方砖，GPT 这批没交，先用这张（64×64，一格 1 米）
static func marble() -> ImageTexture:
    var im := blank(64, 64)
    noise(im, 0, 0, 64, 64, ["#b8a17e", "#bea683", "#b19a77", "#bba481"], 11, 0.3)
    for y in 64:
        for x in 64:
            if x % 16 == 0 or y % 16 == 0:
                im.set_pixel(x, y, Color("#8a7152"))
            elif (x + 2 * y) % 29 == 0 and h2(x / 16, y / 16) > 0.55:
                im.set_pixel(x, y, Color("#a88f6b"))   # 淡淡的石纹
    return tex(im)

## 木格灯笼的灯罩：GPT 的木格窗贴图，窗格会发光。一面正好是一整扇窗
static func lamp_mat() -> StandardMaterial3D:
    if not _cache.has("lamp"):
        var m := mat(gtex("tex_lattice"), 0.5)
        m.emission_enabled = true
        m.emission_texture = m.albedo_texture
        m.emission = Color("#ffb45e")
        m.emission_energy_multiplier = 1.0
        _cache["lamp"] = m
    return _cache["lamp"]

## GPT 的积木图在不在工程里（assets/<类型>/<名字>.png）
static func has_block(kind: String, name: String) -> bool:
    return ResourceLoader.exists("res://assets/%s/%s.png" % [kind, name])

## 「贴一整张」的积木材质：椅背、桌面这类，按贴图坐标贴满一个面（不按世界坐标铺）。
## 镂空和圆外的透明用挖孔处理：还是不透明物体，不用排序，能和别的一起合并
static func block_mat(kind: String, name: String) -> StandardMaterial3D:
    var key := "block|%s|%s" % [kind, name]
    if not _cache.has(key):
        var m := StandardMaterial3D.new()
        m.albedo_texture = load("res://assets/%s/%s.png" % [kind, name])
        m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
        m.alpha_scissor_threshold = 0.5
        m.roughness = 0.9
        _cache[key] = m
    return _cache[key]

## 同样参数的纯色、发光材质共用一个：宴会厅合并网格是按材质并的，材质不共用就并不到一起
## 要单独改参数的（比如会闪的出口光圈），拿到后先 duplicate()
static var _cache := {}

static func flat(hx: String, rough := 0.85) -> StandardMaterial3D:
    var key := "flat|%s|%.2f" % [hx, rough]
    if not _cache.has(key):
        var m := StandardMaterial3D.new()
        m.albedo_color = Color(hx)
        m.roughness = rough
        _cache[key] = m
    return _cache[key]

static func glow(hx: String, energy := 2.0) -> StandardMaterial3D:
    var key := "glow|%s|%.2f" % [hx, energy]
    if not _cache.has(key):
        var m := StandardMaterial3D.new()
        m.albedo_color = Color(hx)
        m.emission_enabled = true
        m.emission = Color(hx)
        m.emission_energy_multiplier = energy
        _cache[key] = m
    return _cache[key]

static func wood() -> ImageTexture:
    var im := blank(32, 32)
    noise(im, 0, 0, 32, 32, ["#5a3524", "#6b432d", "#744a31", "#845638"], 3, 0.25)
    for y in 32:
        for x in 32:
            var row := int(y / 8)
            if y % 8 == 7 or (x + row * 11) % 32 == 0: im.set_pixel(x, y, Color("#3a2218"))
    return tex(im)

static func cloth() -> ImageTexture:
    var im := blank(16, 16)
    noise(im, 0, 0, 16, 16, ["#8C2F27", "#a3342a", "#C0392B", "#b23629"], 5, 0.5)
    for y in 16:
        for x in 16:
            if (x + y) % 8 == 0 and h2(x, y) > 0.5: im.set_pixel(x, y, Color("#d4553f"))
    return tex(im)

static func wall() -> ImageTexture:
    var im := blank(32, 32)
    noise(im, 0, 0, 32, 32, ["#5e1f1a", "#6f231d", "#7a2720"], 7, 0.3)
    for y in 32:
        for x in 32:
            if (x % 16 == 8 and y % 16 == 8) or ((x + 8) % 16 == 8 and (y + 8) % 16 == 8): im.set_pixel(x, y, Color("#b0892e"))
    return tex(im)

static func drape() -> ImageTexture:
    var im := blank(16, 16)
    for y in 16:
        for x in 16:
            var band := x % 8
            var c := "#9c2e25" if band < 3 else ("#b8392c" if band < 6 else "#7a241e")
            im.set_pixel(x, y, Color(c))
    return tex(im)

static func lattice() -> ImageTexture:
    var im := blank(24, 24)
    noise(im, 0, 0, 24, 24, ["#4a2a1c", "#5a3524", "#6b432d"], 9, 0.4)
    for y in range(3, 21):
        for x in range(3, 21):
            var on := (x - 3) % 6 == 0 or (y - 3) % 6 == 0
            im.set_pixel(x, y, Color("#3a2218") if on else Color("#e8d6b0"))
    return tex(im)

static func gold() -> ImageTexture:
    var im := blank(16, 16)
    noise(im, 0, 0, 16, 16, ["#8A6410", "#b08a2a", "#D4AF37", "#F4D97A"], 11, 0.6)
    return tex(im)

static func carpet() -> ImageTexture:
    var im := blank(24, 24)
    noise(im, 0, 0, 24, 24, ["#8C2F27", "#9a3228", "#a8362b"], 13, 0.5)
    for y in 24:
        for x in 24:
            if x < 2 or x > 21: im.set_pixel(x, y, Color("#D4AF37"))
            elif x == 2 or x == 21: im.set_pixel(x, y, Color("#8A6410"))
            elif (x == 12 or x == 11) and y % 6 < 2: im.set_pixel(x, y, Color("#D4AF37"))
    return tex(im)

static func blob() -> ImageTexture:
    var im := blank(32, 32)
    for y in 32:
        for x in 32:
            var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
            im.set_pixel(x, y, Color(0.08, 0.04, 0.1, clampf(0.55 * (1.0 - d * d), 0.0, 0.55)))
    return ImageTexture.create_from_image(im)
