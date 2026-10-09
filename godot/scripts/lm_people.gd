extends RefCounted
## 罗曼山庄的人（docs/零件总表.md「罗曼山庄的人」；GPT 照 ASSETS §3 画，任务 claude-任务-宴会厅人物.md）：
## 按身份编号，全山庄共用——宾客 LM-GUEST-01～12、服务员 LM-WAITER-01～40、乐手 LM-BAND-01～04。
## 图放 assets/characters/lm/，名字去掉版本号：chr_LM-GUEST-03.png + 同名 .json（接图的时候照这个名字放进来）。
## 到一个用一个：哪个编号的图在，游戏就用它；不在的照旧（代码画的人、没乐手）。
## json（照 ASSETS §3）：{"frame":[64,84],"frames":{"down":[0..3],"left":[4..7],"right":[8..11],"up":[12..15]},"fps":8,"height_m":1.75}
##   服务员多一行端托盘：整张 1024×168，"frames_tray"（同样四个朝向）、"tray":[x,y]（托盘中心在格子里的位置，菜挂在这）
##   乐手：{"frame":[w,h],"frames":{"play":[0,1,2,3]},"fps":6,"foot":[x,y]（脚点在格子里哪一点，没写就是下沿正中）}
## 量高：每个人在格子里实际画了多高（第一帧最上面一行不透明的到最下面一行），坐下截上半身、按 height_m 缩放都照这个量，
## 所以小孩（height_m 1.1）不管画满格子还是只画下面一截都对

static var dir := "res://assets/characters/lm/"   # 测试、截图可以指到 user:// 下一套假图
static var _cache := {}

const GUESTS := 12
const WAITERS := 40
const BANDS := 4
const ADULT_M := 1.75
# 宾客 01～08 是选人界面能选的（玩家形象 0～7），09～12（奶奶、爷爷、两个小孩）只给 NPC
const PICKABLE := 8
const KIDS := ["LM-GUEST-11", "LM-GUEST-12"]

static func guest_code(i: int) -> String:
    return "LM-GUEST-%02d" % i

static func waiter_code(i: int) -> String:
    return "LM-WAITER-%02d" % i

static func band_code(i: int) -> String:
    return "LM-BAND-%02d" % i

static func clear_cache() -> void:
    _cache.clear()
    _names = {}
    _index = {}
    _atlas_tex = null

## 服务员的名字（assets/characters/waiter_names.json，阿鱼 10/2 要每位有个中文名）；没有回 ""
const WAITER_NAMES := "res://assets/characters/waiter_names.json"
static var _names := {}
static func waiter_name(code: String) -> String:
    if _names.is_empty() and FileAccess.file_exists(WAITER_NAMES):
        var j = JSON.parse_string(FileAccess.get_file_as_string(WAITER_NAMES))
        if j is Dictionary:
            _names = j.get("names", {})
    return str(_names.get(code, ""))

static func has(code: String) -> bool:
    return not look(code).is_empty()

## 一个人的图和数：{code, tex, img, fw, fh, hframes, frames, fps, height_m, top, h, tray, frames_tray, foot}；没有图回 {}
## 手机上不从显卡读图（README：纹理的 get_image 在微信里崩）：res:// 下的图「画了多高」「朝前那帧不透明的那块」照
## lm_index.json（tools/bake_used.py 在电脑上算好的）；宾客不一张张读，都从拼好的 guest_atlas.png 里取自己那一行（一张图，导出时单张的宾客图不进包）。
## 测试、截图指到 user:// 的一套图（dir 不是 res://）照旧自己读文件算
const INDEX := "lm_index.json"
static var _index := {}
static var _atlas_tex: Texture2D = null

static func index() -> Dictionary:
    if _index.is_empty() and dir.begins_with("res://") and FileAccess.file_exists(dir + INDEX):
        var j = JSON.parse_string(FileAccess.get_file_as_string(dir + INDEX))
        _index = j if j is Dictionary else {"looks": {}, "guest_atlas": {}}
    return _index

## 拼好的宾客大图里这位在第几行；不在大图里回 -1
static func atlas_row(code: String) -> int:
    var ga: Dictionary = index().get("guest_atlas", {})
    return (ga.get("codes", []) as Array).find(code)

static func _atlas() -> Texture2D:
    if _atlas_tex == null:
        var p := dir + str(index().get("guest_atlas", {}).get("file", "guest_atlas.png"))
        if ResourceLoader.exists(p):
            _atlas_tex = load(p)
    return _atlas_tex

static func look(code: String) -> Dictionary:
    if _cache.has(code):
        return _cache[code]
    var out := {}
    var js := dir + "chr_%s.json" % code
    var j = JSON.parse_string(FileAccess.get_file_as_string(js)) if FileAccess.file_exists(js) else null
    if not (j is Dictionary and j.has("frame") and j.has("frames")):
        _cache[code] = out
        return out
    var fw := int(j["frame"][0])
    var fh := int(j["frame"][1])
    var frames: Dictionary = j["frames"]
    var tex: Texture2D = null
    var img: Image = null
    var top := 0
    var h := fh
    var front := Rect2i(0, 0, fw, fh)
    if dir.begins_with("res://"):
        var ix: Dictionary = index().get("looks", {}).get(code, {})
        if ix.is_empty():
            push_warning("罗曼山庄的人 %s 没在 lm_index.json 里（图拷进来以后没跑 tools/bake_used.py），先不用" % code)
            _cache[code] = out
            return out
        top = int(ix["top"])
        h = int(ix["h"])
        var fr: Array = ix.get("front", [0, 0, fw, fh])
        front = Rect2i(int(fr[0]), int(fr[1]), int(fr[2]), int(fr[3]))
        var row := atlas_row(code)
        if row >= 0 and _atlas() != null:
            var ga: Dictionary = index()["guest_atlas"]
            var at := AtlasTexture.new()
            at.atlas = _atlas()
            at.region = Rect2(0, row * int(ga["fh"]), int(ga["fw"]) * int(ga["hframes"]), int(ga["fh"]))
            tex = at
        else:
            var png := dir + "chr_%s.png" % code
            if ResourceLoader.exists(png):
                tex = load(png)
    else:
        var png2 := dir + "chr_%s.png" % code
        if FileAccess.file_exists(png2):
            img = Image.load_from_file(ProjectSettings.globalize_path(png2))
            if img != null:
                if img.is_compressed():
                    img.decompress()
                tex = ImageTexture.create_from_image(img)
    if tex == null:
        _cache[code] = out
        return out
    var hf := maxi(1, int(tex.get_width()) / fw)
    if img != null:
        var first := 0
        for k in ["down", "play"]:
            if frames.has(k) and not (frames[k] as Array).is_empty():
                first = int(frames[k][0])
                break
        var box := _content(img, Rect2i((first % hf) * fw, (first / hf) * fh, fw, fh))
        top = box.x
        h = box.y
        var idle := int((frames.get("down", [first]) as Array)[0]) if frames.has("down") else first
        var u := img.get_region(Rect2i((idle % hf) * fw, (idle / hf) * fh, fw, fh)).get_used_rect()
        front = u
    out = {"code": code, "tex": tex, "img": img, "fw": fw, "fh": fh, "hframes": hf,
        "vframes": maxi(1, int(tex.get_height()) / fh), "frames": frames, "fps": float(j.get("fps", 8)),
        "height_m": float(j.get("height_m", ADULT_M)), "top": top, "h": h, "front": front,
        "frames_tray": j.get("frames_tray", {}), "tray": j.get("tray", []),
        "foot": j.get("foot", [fw / 2.0, fh])}
    _cache[code] = out
    return out

## 一格里画的人从哪一行到哪一行：回 (最上面不透明的那一行, 画了多高)
static func _content(img: Image, r: Rect2i) -> Vector2i:
    var top := -1
    var bottom := -1
    for y in r.size.y:
        for x in r.size.x:
            if img.get_pixel(r.position.x + x, r.position.y + y).a > 0.5:
                if top < 0:
                    top = y
                bottom = y
                break
    if top < 0:
        return Vector2i(0, r.size.y)
    return Vector2i(top, bottom - top + 1)

## 有哪些宾客的图（编号 01～12 里在的）
static func guests_present() -> Array:
    var out: Array = []
    for i in range(1, GUESTS + 1):
        if has(guest_code(i)):
            out.append(guest_code(i))
    return out

## 有哪些服务员的图：只看在不在，不把图读进来（厅里同时只有几位上场，40 张都读进来白占显存，02 10/3 量过满配多 12 MB 左右）
static func waiters_present() -> Array:
    var out: Array = []
    for i in range(1, WAITERS + 1):
        if _exists(waiter_code(i)):
            out.append(waiter_code(i))
    return out

## 这个编号的图在不在（不读图）：res:// 下看 lm_index 里有没有、图在不在；测试那套看文件
static func _exists(code: String) -> bool:
    if not FileAccess.file_exists(dir + "chr_%s.json" % code):
        return false
    if dir.begins_with("res://"):
        return (index().get("looks", {}) as Dictionary).has(code) and (atlas_row(code) >= 0 or ResourceLoader.exists(dir + "chr_%s.png" % code))
    return FileAccess.file_exists(dir + "chr_%s.png" % code)

## 一个朝向的帧：frames 里 down/left/right/up；没有的朝向借 down
static func dir_frames(l: Dictionary, face: String, tray := false) -> Array:
    var src: Dictionary = l["frames_tray"] if tray and not (l["frames_tray"] as Dictionary).is_empty() else l["frames"]
    var f: Array = src.get(face, src.get("down", [0]))
    if tray and not (l["frames_tray"] as Dictionary).is_empty():
        # 端托盘那行：json 里写的是第二行的格号（16～31）或者行内的格号（0～15），都认
        f = f.map(func(x): return int(x) if int(x) >= int(l["hframes"]) else int(x) + int(l["hframes"]))
    return f

## 托盘中心在格子里的位置（一个点，或者按朝向写的四个点）
static func tray_point(l: Dictionary, face: String) -> Vector2:
    var t = l.get("tray", [])
    if t is Dictionary:
        t = t.get(face, t.get("down", []))
    if t is Array and t.size() >= 2:
        return Vector2(float(t[0]), float(t[1]))
    return Vector2(l["fw"] * 0.5, l["fh"] * 0.45)

## 宾客拼一张图（一个人一行，所有宾客共用这一张：550 个人只换一次图，手机上少切图）。codes 是要拼的编号
## 回 {tex, rows: [{code, top, h, height_m, kid}], fw, fh, hframes}
static func guest_atlas(codes: Array) -> Dictionary:
    if codes.is_empty():
        return {}
    var first: Dictionary = look(codes[0])
    var fw: int = first["fw"]
    var fh: int = first["fh"]
    var hf: int = first["hframes"]
    var rows: Array = []
    # res:// 下有拼好的大图（bake_used.py）、拼的正好是这几位：直接用，不在手机上拼（拼要读图，微信里不行）
    var ga: Dictionary = index().get("guest_atlas", {})
    if dir.begins_with("res://") and ga.get("codes", []) == codes and _atlas() != null:
        for c in codes:
            var lc: Dictionary = look(c)
            rows.append({"code": c, "top": int(lc["top"]), "h": int(lc["h"]), "height_m": float(lc["height_m"]), "kid": c in KIDS})
        return {"tex": _atlas(), "rows": rows, "fw": fw, "fh": fh, "hframes": hf, "frames": first["frames"]}
    var im := Image.create_empty(fw * hf, fh * codes.size(), false, Image.FORMAT_RGBA8)
    for i in codes.size():
        var l: Dictionary = look(codes[i])
        if l.get("img") == null:
            push_warning("宾客大图拼不了：%s 没有图像数据（res:// 下要先跑 tools/bake_used.py）" % codes[i])
            return {}
        var src: Image = l["img"]
        if src.get_format() != Image.FORMAT_RGBA8:
            src = src.duplicate()
            src.convert(Image.FORMAT_RGBA8)
        im.blit_rect(src, Rect2i(0, 0, mini(src.get_width(), fw * hf), mini(src.get_height(), fh)), Vector2i(0, i * fh))
        rows.append({"code": codes[i], "top": int(l["top"]), "h": int(l["h"]), "height_m": float(l["height_m"]), "kid": codes[i] in KIDS})
    return {"tex": ImageTexture.create_from_image(im), "rows": rows, "fw": fw, "fh": fh, "hframes": hf, "frames": first["frames"]}
