extends Node2D
## 灯光明暗呼吸，像素光（01 G 10/4：照画风页第 0 节「硬边……灯光不叠半透明，在同一色带里调暗调亮一档，边上用棋盘格点过渡」）：
##   每盏灯外面几圈整格的亮档，越往里越亮一档；圈和圈之间、最外圈的边上一格隔一格（棋盘格点）过渡；1 美术像素 = 1 画布像素。
##   「亮一档」是在底下的像素上整格加一个固定的暖色（加法混合，图是全不透明或全透明，没有半透明渐变）：
##   最亮那档正好把地面米色 (214,204,189) 提到灯罩里的奶白 (253,250,201)，中间几档等分，颜色都在这块画布原有的暖色带里。
##   一明一暗是在几种大小之间整档换（亮 → 中 → 暗 → 中），不连续调透明度；只在换档那一下重画。
## 所有灯在这一个节点里画，几种大小的光圈各一张小图，手机上多一两次绘制。档位见 ambient.gd：0 停在中档

var points: Array = []     # 每盏灯的光心（画布坐标，整数）
var tiers: Array = []      # 每档往上加多少（0～255），从外到里
var sizes: Array = []      # 几种大小：每种是从外到里每圈的半径（画布像素）
var cycle: Array = []      # 一圈换哪几种大小（sizes 的下标），比如 [0, 1, 2, 1] = 亮 → 中 → 暗 → 中
var steps: Array = []      # 每盏换一档隔几秒
var offsets: Array = []    # 每盏错开多少秒
var texs: Array = []       # 每种大小一张图
var half := 0              # 图的半边长
var _t := 0.0
var _shown: Array = []     # 每盏现在画的是哪种大小
var amb: Script            # ambient.gd（读档位）；互相 preload 会绕圈，这里搭的时候 load 一次

func setup(pts: Array, g: Dictionary) -> void:
    amb = load("res://scripts/ambient/ambient.gd")
    for p in pts:
        points.append(Vector2(roundf(p.x), roundf(p.y)))
    tiers = g.get("tiers", [[13, 15, 4], [26, 31, 8], [39, 46, 12]])
    sizes = g.get("sizes", [[26, 18, 11], [22, 15, 8], [18, 12, 5]])
    cycle = g.get("cycle", [0, 1, 2, 1])
    var st: Array = g.get("step", [0.8, 1.15])
    var rng := RandomNumberGenerator.new()
    rng.seed = 1004                      # 每次进来同一盏灯同一个节奏，截图对得上
    for i in points.size():
        var s := rng.randf_range(float(st[0]), float(st[1]))
        steps.append(s)
        offsets.append(rng.randf() * s * cycle.size())
        _shown.append(-1)
    for sz in sizes:
        half = maxi(half, int(sz[0]) + 1)
    for sz in sizes:
        texs.append(_ring_tex(sz))
    var m := CanvasItemMaterial.new()
    m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    material = m
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    z_index = int(g.get("z", 1))         # 压在零件、人上面一点点（光），在名牌、飘落下面

## 一种大小的光圈图：每格要么全不透明（加这一档的暖色）要么全透明；圈的交界、外边一格隔一格
func _ring_tex(radii: Array) -> ImageTexture:
    var n := half * 2 + 1
    var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
    for y in n:
        for x in n:
            var d := Vector2(x - half, y - half).length()
            var k := 0                   # 这格在第几档（0 = 不亮）
            for j in radii.size():
                var r := float(radii[j])
                if d < r - 0.5:
                    k = j + 1
                elif d < r + 0.5 and (x + y) % 2 == 0:
                    k = j + 1            # 交界那一格：棋盘格点，隔一格算里面那档
            if k > 0:
                var c: Array = tiers[mini(k, tiers.size()) - 1]
                img.set_pixel(x, y, Color8(int(c[0]), int(c[1]), int(c[2]), 255))
    return ImageTexture.create_from_image(img)

## 第 i 盏这一刻是哪种大小（sizes 的下标）。全关档停在中档
func size_of(i: int, t: float) -> int:
    if amb.level <= 0:
        return int(cycle[1 % cycle.size()])
    var k := int(floor((t + float(offsets[i])) / float(steps[i]))) % cycle.size()
    return int(cycle[k])

func _process(dt: float) -> void:
    _t += dt
    for i in points.size():
        if size_of(i, _t) != int(_shown[i]):
            queue_redraw()
            return

func _draw() -> void:
    var o := Vector2(half, half)
    for i in points.size():
        var s := size_of(i, _t)
        _shown[i] = s
        draw_texture(texs[s], points[i] - o)
