extends SceneTree
## 验收：手机上不从显卡读图（README：纹理的 get_image 在微信里调 getBufferSubData，不支持，第 5、6 版就这么崩的；电脑上测不出来）
## 1 scripts 里除了截图那一处，没有 get_image(
## 2 电脑上先算好的跟图对得上（这个测试在电脑上，可以读图来核）：
##   lm_index.json 每个人「画了多高」「朝前那帧不透明的那块」、sha1；guest_atlas.png 拼的就是现在这几位、一像素不差；
##   used_rects.json 每张图不透明的那块，新人合照、厨房的图一张不漏
##   图换了没重跑 tools/bake_used.py，这里就不过
## 3 宾客从拼好的大图里取（AtlasTexture），别桌宾客那套也是那张大图
## 用法：Godot --headless --path . --script res://tools/test_no_readback.gd ；最后一行 RESULT PASS 才算过

const LMPeople = preload("res://scripts/lm_people.gd")
const UsedRects = preload("res://scripts/used_rects.gd")
const LM := "res://assets/characters/lm/"

var ok := true

func check(name: String, cond: bool) -> void:
    print(("  好 " if cond else "  不行 ") + name)
    ok = ok and cond

func _initialize() -> void:
    LMPeople.dir = LM
    LMPeople.clear_cache()
    print("1 不读显卡")
    var hits: Array = []
    for f in _files("res://scripts", ".gd"):
        var n := 0
        for line in FileAccess.get_file_as_string(f).split("\n"):
            n += 1
            if line.contains("get_image(") and not line.strip_edges().begins_with("#"):
                if f.ends_with("/main.gd") and line.contains("get_viewport().get_texture().get_image()"):
                    continue   # 截图工具（只在电脑上 --capture 时跑）
                hits.append("%s:%d" % [f.get_file(), n])
    check("scripts 里除了截图没有 get_image(（%s）" % [hits], hits.is_empty())

    print("2 先算好的跟图对得上")
    var idx: Dictionary = LMPeople.index()
    var looks: Dictionary = idx.get("looks", {})
    var bad: Array = []
    var pngs := _files(LM.trim_suffix("/"), ".png").filter(func(p): return p.get_file().begins_with("chr_LM-"))
    for p in pngs:
        var code: String = p.get_file().trim_prefix("chr_").trim_suffix(".png")
        if not FileAccess.file_exists(p.trim_suffix(".png") + ".json"):
            continue
        var ix: Dictionary = looks.get(code, {})
        if ix.is_empty():
            bad.append("%s 没在 lm_index" % code)
            continue
        var j = JSON.parse_string(FileAccess.get_file_as_string(p.trim_suffix(".png") + ".json"))
        var fw := int(j["frame"][0])
        var fh := int(j["frame"][1])
        var img := (load(p) as Texture2D).get_image()   # 测试在电脑上，可以读
        if img.is_compressed():
            img.decompress()
        var hf := maxi(1, img.get_width() / fw)
        var first := 0
        for k in ["down", "play"]:
            if (j["frames"] as Dictionary).has(k) and not (j["frames"][k] as Array).is_empty():
                first = int(j["frames"][k][0])
                break
        var box := LMPeople._content(img, Rect2i((first % hf) * fw, (first / hf) * fh, fw, fh))
        var idle := int(j["frames"]["down"][0]) if (j["frames"] as Dictionary).has("down") else first
        var u := img.get_region(Rect2i((idle % hf) * fw, (idle / hf) * fh, fw, fh)).get_used_rect()
        var front := Rect2i(int(ix["front"][0]), int(ix["front"][1]), int(ix["front"][2]), int(ix["front"][3]))
        var hc := HashingContext.new()
        hc.start(HashingContext.HASH_SHA1)
        hc.update(FileAccess.get_file_as_bytes(p))
        if box != Vector2i(int(ix["top"]), int(ix["h"])) or u != front or hc.finish().hex_encode() != str(ix["sha1"]):
            bad.append("%s：算的 %s %s，表里 %s %s" % [code, box, u, Vector2i(int(ix["top"]), int(ix["h"])), front])
    check("lm_index 跟 %d 张图对得上（不对的 %s）" % [pngs.size(), bad], bad.is_empty() and pngs.size() > 0)
    var ga: Dictionary = idx.get("guest_atlas", {})
    var present: Array = []
    for p in pngs:
        var c: String = p.get_file().trim_prefix("chr_").trim_suffix(".png")
        if c.begins_with("LM-GUEST-") and looks.has(c):
            present.append(c)
    present.sort()
    check("宾客大图拼的是现在这几位 %s" % [ga.get("codes", [])], ga.get("codes", []) == present)
    var atlas_img := (load(LM + str(ga.get("file", "guest_atlas.png"))) as Texture2D).get_image()
    if atlas_img.is_compressed():
        atlas_img.decompress()
    atlas_img.convert(Image.FORMAT_RGBA8)
    var same := atlas_img.get_height() == int(ga.get("fh", 0)) * present.size()
    for i in present.size():
        if not same:
            break
        var src := (load(LM + "chr_%s.png" % present[i]) as Texture2D).get_image()
        if src.is_compressed():
            src.decompress()
        src.convert(Image.FORMAT_RGBA8)
        # 只比看得见的像素：全透明的地方导入时会改颜色（fix_alpha_border），看不见，不算
        var oy := i * int(ga["fh"])
        for y in int(ga["fh"]):
            for x in src.get_width():
                var c1 := src.get_pixel(x, y)
                var c2 := atlas_img.get_pixel(x, oy + y)
                if (c1.a > 0.0 or c2.a > 0.0) and not c1.is_equal_approx(c2):
                    same = false
                    break
            if not same:
                break
    check("宾客大图一行一行跟单张的图一像素不差", same)
    var miss: Array = []
    var wrong: Array = []
    var want: Array = ["res://assets/couple.png"]
    want.append_array(_files("res://assets/kitchen", ".png"))
    for p in want:
        var r := UsedRects.rect(p)
        if r.size == Vector2i.ZERO:
            miss.append(p.get_file())
            continue
        var im := (load(p) as Texture2D).get_image()
        if im.is_compressed():
            im.decompress()
        if im.get_used_rect() != r:
            wrong.append("%s %s≠%s" % [p.get_file(), im.get_used_rect(), r])
    check("used_rects：新人合照和厨房 %d 张图都在、都对（漏的 %s，不对的 %s）" % [want.size(), miss.slice(0, 5), wrong.slice(0, 5)], miss.is_empty() and wrong.is_empty())

    print("3 宾客从大图里取")
    var l: Dictionary = LMPeople.look("LM-GUEST-01")
    check("宾客 01 的图是大图里的一行（%s）、没留读出来的图像" % (l["tex"] as Object).get_class(), l["tex"] is AtlasTexture and l["img"] == null)
    var a := LMPeople.guest_atlas(present)
    check("别桌宾客那套用的就是那张大图", not a.is_empty() and a["tex"] == LMPeople._atlas())

    print("RESULT PASS" if ok else "RESULT FAIL")
    quit(0 if ok else 1)

func _files(root: String, ext: String) -> Array:
    var out: Array = []
    var d := DirAccess.open(root)
    if d == null:
        return out
    for f in d.get_files():
        if f.ends_with(ext):
            out.append(root + "/" + f)
    for sub in d.get_directories():
        out.append_array(_files(root + "/" + sub, ext))
    return out
