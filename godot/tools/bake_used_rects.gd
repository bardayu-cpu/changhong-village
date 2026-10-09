extends SceneTree
## 图里不透明的那一块 → assets/used_rects.json（新人合照、厨房的图）。在 Godot 里量导入以后的图（有的厨房图导入时缩了），
## 跟游戏里拿到的纹理一个坐标；手机上照这份裁边、量大小，不从显卡读图（scripts/used_rects.gd）。
## tools/bake_used.py 会调这个；单独跑：Godot --headless --path . --script res://tools/bake_used_rects.gd [-- --check]

const OUT := "res://assets/used_rects.json"

func _initialize() -> void:
    var want: Array = ["res://assets/couple.png"]
    want.append_array(_files("res://assets/kitchen", ".png"))
    want.sort()
    var rects := {}
    for p in want:
        var tex: Texture2D = load(p)
        if tex == null:
            continue
        var im := tex.get_image()   # 在电脑上量，手机上不跑这个
        if im == null:
            continue
        if im.is_compressed():
            im.decompress()
        var u := im.get_used_rect()
        rects[p] = [u.position.x, u.position.y, u.size.x, u.size.y]
    var d := {"note": "tools/bake_used_rects.gd 生成，别手改：导入以后的图不透明的那块 [x, y, w, h]（跟 Image.get_used_rect 一样），手机上裁边、量大小照这份，不从显卡读图", "rects": rects}
    var text := JSON.stringify(d, " ", true) + "\n"
    if "--check" in OS.get_cmdline_user_args():
        var same := FileAccess.file_exists(OUT) and FileAccess.get_file_as_string(OUT) == text
        print("used_rects.json " + ("没变" if same else "变了"))
        quit(0 if same else 1)
        return
    var f := FileAccess.open(OUT, FileAccess.WRITE)
    f.store_string(text)
    f.close()
    print("used_rects.json：%d 张图" % rects.size())
    quit(0)

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
