extends RefCounted
## 图里不透明的那一块 [x, y, w, h]：电脑上 tools/bake_used.py 算好存在 assets/used_rects.json，手机上照这份，不从显卡读图
## （README：纹理的 get_image 在微信里调 WebGL 的 getBufferSubData，不支持，第 5、6 版就这么崩的）。
## 新人合照（相纸、海报量新人多高）、厨房的图（菜图裁空白边）在里面；没在里面的回空的 Rect2i，调用的地方就不裁、照原样摆

const PATH := "res://assets/used_rects.json"
static var _d := {}

static func rect(res_path: String) -> Rect2i:
    if _d.is_empty() and FileAccess.file_exists(PATH):
        var j = JSON.parse_string(FileAccess.get_file_as_string(PATH))
        _d = j.get("rects", {}) if j is Dictionary else {}
    var r = _d.get(res_path, null)
    if r is Array and r.size() == 4:
        return Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
    return Rect2i()
