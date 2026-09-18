extends RefCounted
## 宾客形象：美术生图包里的 8 个预设，全部是占位像素
## 同一套 16×32 模板，换发型、衣服颜色和体型；每人一张 9 帧的图：
## 下 0-2、上 3-5、侧 6-8（侧面朝右，朝左用翻转）

const FRONT := [
    "................", "......oooo......", "....ooHHHHoo....", "...oHHHiiHHHo...", "..oHHHHHHHHHHo..", "..oHHhhhhhhHHo..",
    "..oHhsssssshHo..", "..oHssssssssHo..", "..oHsessssesHo..", "..oHsessssesHo..", "..oHbssmmssbHo..", "..oHgSssssSgHo..",
    "...oHHoSSoHHo...", "...okkkkkkkko...", "..okkkkkkkkkko..", "..oKkkkkkkkkKo..", "..oKkkkkkkkkKo..", "..oKkKkkkkKkKo..",
    "..oKkKkkkkKkKo..", "..osKKKKKKKKso..", "...oppppppppo...", "...oppppppppo...", "...opppPPpppo...", "...opppPPpppo...",
    "...opppoopppo...", "...opppoopppo...", "...opppoopppo...", "...oPPPooPPPo...", "...oPPPooPPPo...", "...offfoofffo...",
    "..offffooffffo..", "...oooo..oooo...",
]
const SIDE := [
    "................", "......oooo......", "....ooHHHHo.....", "...oHHHiiHHo....", "..oHHHHHHHHHo...", "..oHHHHHHHhhho..",
    "..oHHHHHHhssso..", "..oHHHHHHsssso..", "..oHHHHHHsseso..", "..oHHHHHHsseso..", "..oHHHHHgbssso..", "..oHHHHHHsSSo...",
    "...oHHHHoSSo....", "....okkkkkko....", "...okkkkkkkko...", "...okkKKkkkko...", "...okkKKkkkko...", "...okkKKkkkko...",
    "...okkKKkkkko...", "...oKKsKKKKKo...", "....oppppppo....",
]
const BASE := {
    "o": "#2C2438", "H": "#4a3226", "h": "#3a261d", "i": "#6d4a38", "s": "#f1c9a1", "S": "#d7a17c", "e": "#1E1A2A",
    "m": "#b4574a", "b": "#E8746A", "g": "#D4AF37", "k": "#E8DDD0", "K": "#B8A88E", "p": "#3A6491", "P": "#1F3A5C",
    "f": "#5A4E68", "r": "#C0392B", "R": "#8C2F27", "W": "#f4f1ea",
}
## 按美术生图包 3.1 的 8 个宾客描述
const PRESETS := [
    {"hair": "short", "bow": true, "scale": Vector2(0.94, 1.07), "pal": {"H": "#26202c", "h": "#1b1620", "i": "#3d3446", "g": "#26202c", "k": "#3a3547", "K": "#26222f", "p": "#2c2836", "P": "#1d1a24", "f": "#1d1a24"}},
    {"hair": "long", "scale": Vector2(0.94, 1.07), "pal": {"H": "#3b2a26", "h": "#2c1f1c", "i": "#5e4038", "g": "#D4AF37", "k": "#C0392B", "K": "#8C2F27", "p": "#C0392B", "P": "#8C2F27", "f": "#2C2438"}},
    {"hair": "long", "scale": Vector2(1.0, 1.0), "pal": {}},
    {"hair": "short", "scale": Vector2(1.0, 1.0), "pal": {"H": "#34303a", "h": "#28242e", "i": "#4a4552", "g": "#34303a", "k": "#f4f1ea", "K": "#d4cec2", "p": "#2C2438", "P": "#1E1A2A"}},
    {"hair": "curly", "scale": Vector2(1.12, 0.92), "pal": {"H": "#5a3a2a", "h": "#442a1e", "i": "#8a6048", "g": "#5a3a2a", "k": "#e99ab0", "K": "#c0587a", "p": "#5A4E68", "P": "#3e3548"}},
    {"hair": "short", "glasses": true, "scale": Vector2(1.12, 0.92), "pal": {"H": "#2b2230", "h": "#1d1722", "i": "#453a4f", "g": "#2b2230", "k": "#4A6FA5", "K": "#2E4A7A", "p": "#3E3160", "P": "#2b2143"}},
    {"hair": "bald", "scale": Vector2(1.12, 1.05), "pal": {"k": "#8C2F27", "K": "#5e1f1a", "p": "#2C2438", "P": "#1E1A2A", "g": "#f1c9a1"}},
    {"hair": "tails", "straps": true, "scale": Vector2(0.9, 0.9), "pal": {"H": "#3a261d", "h": "#2a1a14", "k": "#f4f1ea", "K": "#d4cec2", "p": "#4A6FA5", "P": "#2E4A7A", "g": "#E8746A"}},
]

static func set_ch(s: String, i: int, c: String) -> String:
    return s.substr(0, i) + c + s.substr(i + 1)

static func palette(preset: int) -> Dictionary:
    return palette_of(PRESETS[preset])

## 下面几个 _of 版本收一个形象字典（和 PRESETS 里一项同样的键），厅里的 NPC 用；按编号的老接口照旧
static func palette_of(pr: Dictionary) -> Dictionary:
    var p := {}
    for k in BASE: p[k] = Color(BASE[k])
    for k in pr["pal"]: p[k] = Color(pr["pal"][k])
    if pr["hair"] == "bald":
        p["H"] = Color("#f1c9a1"); p["h"] = Color("#e3b48c"); p["i"] = Color("#ffe3c8")
    return p

static func front_rows(preset: int) -> Array:
    return front_rows_of(PRESETS[preset])

static func front_rows_of(pr: Dictionary) -> Array:
    var r: Array = FRONT.duplicate()
    var style: String = pr["hair"]
    if style == "short" or style == "bald":
        r[7] = "...o" + "ssssssss" + "o..."
        r[8] = "...o" + "sesssses" + "o..."
        r[9] = "...o" + "sesssses" + "o..."
        r[10] = "...o" + "bssmmssb" + "o..."
        r[11] = "....o" + "SssssS" + "o...."
        r[12] = "......oSSo......"
    if style == "curly":
        r[3] = "...o" + "HiHiiHiH" + "o..."
        r[4] = "..o" + "HiHHiHHiHH" + "o.."
        r[5] = "..o" + "HHhihhihHH" + "o.."
    if style == "tails":
        for y in range(5, 12):
            r[y] = set_ch(set_ch(r[y], 1, "H"), 14, "H")
            r[y] = set_ch(set_ch(r[y], 0, "o"), 15, "o")
        r[4] = set_ch(set_ch(r[4], 1, "o"), 14, "o")
        r[12] = set_ch(set_ch(r[12], 1, "o"), 14, "o")
    if pr.get("glasses", false):
        for x in [4, 6, 9, 11]: r[8] = set_ch(r[8], x, "o")
    if pr.get("bow", false):
        r[13] = set_ch(set_ch(set_ch(set_ch(r[13], 6, "r"), 7, "R"), 8, "R"), 9, "r")
    if pr.get("straps", false):
        for y in range(13, 20):
            r[y] = set_ch(set_ch(r[y], 5, "p"), 10, "p")
        for y in range(17, 20):
            for x in range(5, 11): r[y] = set_ch(r[y], x, "p")
    if pr.get("tux", false):
        # 黑西装白衬衫（乐手）：领口两点白、中间领结用描边色，胸前一道白衬衫
        r[13] = set_ch(set_ch(set_ch(set_ch(r[13], 6, "W"), 7, "o"), 8, "o"), 9, "W")
        for y in [14, 15, 16]:
            r[y] = set_ch(set_ch(r[y], 7, "W"), 8, "W")
    return r

static func back_rows(front: Array, preset: int) -> Array:
    return back_rows_of(front, PRESETS[preset])

static func back_rows_of(front: Array, pr: Dictionary) -> Array:
    var style: String = pr["hair"]
    var r: Array = front.duplicate()
    if pr.get("tux", false):
        for y in [13, 14, 15, 16]: r[y] = FRONT[y]   # 背后看不到白衬衫
    if style == "short" or style == "bald":
        for y in [5, 6]: r[y] = "..oHHHHHHHHHHo.."
        for y in [7, 8, 9, 10]: r[y] = "...oHHHHHHHHo..."
        r[11] = "....oHHHHHHo...."
    else:
        for y in range(5, 12): r[y] = "..oHHHHHHHHHHo.."
        r[12] = "...oHHHHHHHHo..."
        if style == "tails":
            for y in range(5, 12):
                r[y] = set_ch(set_ch(set_ch(set_ch(r[y], 1, "H"), 14, "H"), 0, "o"), 15, "o")
    return r

static func lift_leg(rows: Array, x0: int, x1: int) -> Array:
    # 抬 2 行，步子才看得出来（原来 1 行，手机上像滑行）
    var out: Array = rows.duplicate()
    for y in range(24, 32):
        for x in range(x0, x1 + 1):
            var c: String = rows[y + 2][x] if y < 30 else "."
            out[y] = set_ch(out[y], x, c)
    return out

static func draw_rows(im: Image, ox: int, rows: Array, pal: Dictionary) -> void:
    for j in rows.size():
        var row: String = rows[j]
        for i in row.length():
            var ch := row[i]
            if ch != "." and pal.has(ch):
                im.set_pixel(ox + i, j, pal[ch])

static func side_legs(im: Image, ox: int, phase: int, pal: Dictionary) -> void:
    var legs := [[0, "P", 6], [0, "p", 7]]
    if phase == 1: legs = [[-1, "P", 6], [1, "p", 7]]
    elif phase == 2: legs = [[1, "P", 6], [-1, "p", 7]]
    for L in legs:
        var dir: int = L[0]
        var col: Color = pal[L[1]]
        var bx: int = L[2]
        for y in range(21, 29):
            var x := bx + int(round(dir * (y - 21) / 1.9))   # 摆腿到脚踝差约 3～4 像素，两腿分得开
            im.set_pixel(ox + x - 1, y, pal["o"])
            for k in 3: im.set_pixel(ox + x + k, y, col)
            im.set_pixel(ox + x + 3, y, pal["o"])
        var fx := bx + dir * 4
        for i in range(-1, 5): im.set_pixel(ox + fx + i, 29, pal["o"] if (i == -1 or i == 4) else pal["f"])
        for i in range(-1, 6): im.set_pixel(ox + fx + i, 30, pal["o"] if (i == -1 or i == 5) else pal["f"])
        for i in range(-1, 6): im.set_pixel(ox + fx + i, 31, pal["o"])

## 9 帧横排：下 0-2、上 3-5、侧 6-8
static func sheet(preset: int) -> Image:
    return sheet_of(PRESETS[preset])

static func sheet_of(pr: Dictionary) -> Image:
    var pal := palette_of(pr)
    var fr := front_rows_of(pr)
    var bk := back_rows_of(fr, pr)
    var im := Image.create_empty(16 * 9, 32, false, Image.FORMAT_RGBA8)
    var fronts := [fr, lift_leg(fr, 8, 12), lift_leg(fr, 3, 7)]
    var backs := [bk, lift_leg(bk, 8, 12), lift_leg(bk, 3, 7)]
    for k in 3: draw_rows(im, k * 16, fronts[k], pal)
    for k in 3: draw_rows(im, (3 + k) * 16, backs[k], pal)
    for k in 3:
        side_legs(im, (6 + k) * 16, k, pal)
        draw_rows(im, (6 + k) * 16, SIDE, pal)
    return im

## 代码画的 9 帧图的走路动画：每个方向的走路帧、站着的帧、要不要左右翻（侧面图朝右画的）
const PROC_ANIM := {
    "down": {"walk": [1, 0, 2, 0], "idle": 0, "flip": false},
    "up": {"walk": [4, 3, 5, 3], "idle": 3, "flip": false},
    "right": {"walk": [7, 6, 8, 6], "idle": 6, "flip": false},
    "left": {"walk": [7, 6, 8, 6], "idle": 6, "flip": true},
}

## GPT 画的宾客图集（assets/characters/chr_guestNN.png 和 .json，NN 从 01 起，对应形象 0 起）。
## 有就用它，没有返回空字典，照旧用代码画的
static func gpt_look(preset: int) -> Dictionary:
    var base := "res://assets/characters/chr_guest%02d" % (preset + 1)
    if not ResourceLoader.exists(base + ".png") or not FileAccess.file_exists(base + ".json"):
        return {}
    var meta = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
    if typeof(meta) != TYPE_DICTIONARY:
        return {}
    var tex: Texture2D = load(base + ".png")
    var fw: int = int(meta["frame"][0])
    var fh: int = int(meta["frame"][1])
    var anim := {}
    for dir in ["down", "up", "left", "right"]:
        var fr: Array = meta["frames"][dir]
        anim[dir] = {"walk": fr, "idle": fr[0], "flip": false}
    return {"tex": tex, "hframes": tex.get_width() / fw, "frame_w": fw, "frame_h": fh,
        "anim": anim, "fps": float(meta.get("fps", 8)), "height_m": float(meta.get("height_m", 1.75))}

## 选形象界面用的正面大图
static func portrait(preset: int, zoom := 5) -> ImageTexture:
    var s := sheet(preset)
    var one := s.get_region(Rect2i(0, 0, 16, 32))
    one.resize(16 * zoom, 32 * zoom, Image.INTERPOLATE_NEAREST)
    return ImageTexture.create_from_image(one)

# ---------- 厅里的 NPC（阿鱼 9/18 宴会厅氛围，hall_life.gd 用）：不进选形象界面 ----------
## 服务员：白衬衫、黑背带黑裤子、红领结
const WAITERS := [
    {"hair": "short", "bow": true, "straps": true, "scale": Vector2.ONE, "pal": {"H": "#26202c", "h": "#1b1620", "i": "#3d3446", "k": "#f4f1ea", "K": "#d4cec2", "p": "#26222f", "P": "#1a1720", "f": "#1d1a24"}},
    {"hair": "long", "bow": true, "straps": true, "scale": Vector2.ONE, "pal": {"H": "#3b2a26", "h": "#2c1f1c", "i": "#5e4038", "g": "#D4AF37", "k": "#f4f1ea", "K": "#d4cec2", "p": "#26222f", "P": "#1a1720", "f": "#1d1a24"}},
    {"hair": "short", "bow": true, "straps": true, "scale": Vector2.ONE, "pal": {"H": "#4a3226", "h": "#3a261d", "i": "#6d4a38", "k": "#f4f1ea", "K": "#d4cec2", "p": "#26222f", "P": "#1a1720", "f": "#1d1a24"}},
]
## 乐手：弹钢琴的、拉大提琴的穿黑西装，两个拉小提琴的一个红裙子、一个黑西装
const MUSICIANS := {
    "piano": {"hair": "short", "tux": true, "scale": Vector2.ONE, "pal": {"H": "#26202c", "h": "#1b1620", "i": "#3d3446", "k": "#2b2833", "K": "#1c1a22", "p": "#2b2833", "P": "#1c1a22", "f": "#15131a"}},
    "cello": {"hair": "short", "tux": true, "glasses": true, "scale": Vector2.ONE, "pal": {"H": "#8a8790", "h": "#6c6972", "i": "#b0adb5", "k": "#2b2833", "K": "#1c1a22", "p": "#2b2833", "P": "#1c1a22", "f": "#15131a"}},
    "violin1": {"hair": "long", "scale": Vector2.ONE, "pal": {"H": "#26202c", "h": "#1b1620", "i": "#3d3446", "g": "#D4AF37", "k": "#C0392B", "K": "#8C2F27", "p": "#C0392B", "P": "#8C2F27", "f": "#2C2438"}},
    "violin2": {"hair": "short", "tux": true, "scale": Vector2.ONE, "pal": {"H": "#3b2a26", "h": "#2c1f1c", "i": "#5e4038", "k": "#2b2833", "K": "#1c1a22", "p": "#2b2833", "P": "#1c1a22", "f": "#15131a"}},
}
const GUEST_HAIR := ["short", "long", "curly", "short", "long", "bald", "tails", "short", "long"]
const GUEST_HAIR_COL := [
    ["#26202c", "#1b1620", "#3d3446"], ["#3b2a26", "#2c1f1c", "#5e4038"], ["#4a3226", "#3a261d", "#6d4a38"],
    ["#5a3a2a", "#442a1e", "#8a6048"], ["#8a8790", "#6c6972", "#b0adb5"],   # 最后一个是长辈的灰头发
]
const GUEST_TOPS := [
    ["#C0392B", "#8C2F27"], ["#4A6FA5", "#2E4A7A"], ["#3a3547", "#26222f"], ["#e99ab0", "#c0587a"], ["#f4f1ea", "#d4cec2"],
    ["#8C2F27", "#5e1f1a"], ["#5c8a6a", "#3f6a50"], ["#d4af37", "#a8862a"], ["#7a5c9e", "#57407a"], ["#e0a458", "#b87a36"],
]
const GUEST_BOTTOMS := [["#2C2438", "#1E1A2A"], ["#3A6491", "#1F3A5C"], ["#4a4552", "#34303a"], ["#5a3a2a", "#3e281c"], ["#26222f", "#1a1720"]]

## 别桌的宾客：按编号固定生成（同一个编号每次一样，所有人看到的是同一群人）
static func guest_look(i: int) -> Dictionary:
    var r := RandomNumberGenerator.new()
    r.seed = 9180 + i * 7919
    var hair: String = GUEST_HAIR[r.randi() % GUEST_HAIR.size()]
    var hc: Array = GUEST_HAIR_COL[r.randi() % GUEST_HAIR_COL.size()]
    var top: Array = GUEST_TOPS[r.randi() % GUEST_TOPS.size()]
    var bot: Array = GUEST_BOTTOMS[r.randi() % GUEST_BOTTOMS.size()]
    var pal := {"H": hc[0], "h": hc[1], "i": hc[2], "g": "#D4AF37" if r.randf() < 0.4 else hc[0],
        "k": top[0], "K": top[1], "p": bot[0], "P": bot[1]}
    return {"hair": hair, "glasses": r.randf() < 0.2, "bow": r.randf() < 0.12, "scale": Vector2.ONE, "pal": pal}
