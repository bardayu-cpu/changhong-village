extends SceneTree
## 合影海报「截出来是黑的」那条退路要的小图（wxgame/poster.js 的 drawPoster；可行性回执第 1 节）：
## 8 个形象朝前站着那一帧 me_0～7.png（有罗曼山庄宾客的图用图，没有就代码画的，跟相纸上一样的取法），加新人合照 couple.png。
## export-wechat.sh 导出时跑一遍，写进导出目录的 poster/，不进仓库（形象图换了下次导出自动跟上）。
## 用法：Godot --headless --path . --script res://tools/export_poster_assets.gd -- <输出目录>
const Spr = preload("res://scripts/sprites.gd")

func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    var out := args[0] if args.size() > 0 else "user://poster"
    DirAccess.make_dir_recursive_absolute(out)
    var n := 0
    for p in 8:
        var img := front_image(p)
        if img != null and img.save_png(out.path_join("me_%d.png" % p)) == OK:
            n += 1
    var cp: Texture2D = load("res://assets/couple.png")
    var ok_c := cp != null and cp.get_image().save_png(out.path_join("couple.png")) == OK
    print("海报小图：形象 %d/8，新人合照 %s → %s" % [n, ok_c, out])
    quit(0 if n == 8 and ok_c else 1)

## 形象朝前站着那一帧（court_ui._front_frame 一样的取法）
static func front_image(preset: int) -> Image:
    var gl := Spr.gpt_look(preset)
    if gl.is_empty():
        var s := Spr.sheet(preset)
        return s.get_region(Rect2i(0, 0, 16, 32))
    var tex: Texture2D = gl["tex"]
    var fw := int(gl["frame_w"])
    var fh := int(gl["frame_h"])
    var idle := int(gl["anim"]["down"]["idle"])
    var hf := maxi(1, tex.get_width() / fw)
    var im := tex.get_image()
    if im.is_compressed():
        im.decompress()
    return im.get_region(Rect2i((idle % hf) * fw, (idle / hf) * fh, fw, fh))
