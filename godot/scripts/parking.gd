extends "res://scripts/entrance.gd"
## 罗曼山庄 · 停车场和大门（灰盒，01 F 10/3 派；玩家说明 docs/停车场和大门-玩家说明-v0.1.md 第 1、2、3、6 节，阿鱼点头）：
## 路西边是露天停车场，路东边一条湖（只露一条当风景，不能走），路往北通到山庄门楼，进门洞就是迎宾院。
## 搭法、走路、交互点和迎宾院一样（entrance.gd，布局 assets/layered/scene_luoman_parking/layout.json，tools/layout_court/make_parking.py 出）。
## 这里多的是一个指路的金箭头（跟签到台、东侧门、果园路口同一种，不写字），浮在人前面一点、指着要去的地方：
##   gate_hint：开头从自己车上下来，指门楼门洞；进过一次迎宾院就不再出（main 管开关）
##   car_hint：吃完席（大门开了）从迎宾院出来，指自己的车；走到车旁就收（main 管开关、接结束那两句）

const GUIDE_AHEAD := 64.0      # 箭头离人多远（朝要去的方向）
const GUIDE_UP := 46.0         # 箭头浮在人身上多高（腰那儿，不压头顶的东西）
const GUIDE_NEAR := 110.0      # 离目标这么近就不用指了

var gate_hint := false
var car_hint := false
var guide_arrow: Polygon2D
var FROM_COURT := Vector2.ZERO

func _init() -> void:
    layout_path = "res://assets/layered/scene_luoman_parking/layout.json"

func build(preset: int, nickname: String, f: Font) -> void:
    super(preset, nickname, f)
    FROM_COURT = Vector2(cfg["from_court"][0], cfg["from_court"][1])
    guide_arrow = edge_arrow()
    guide_arrow.name = "guide_arrow"
    add_child(guide_arrow)

## 箭头现在指着谁：车优先（出来的时候），再是大门（进来的时候）；都不用指回 ZERO
func guide_target() -> Vector2:
    if car_hint and points.has("my_car"):
        return points["my_car"]["pos"]
    if gate_hint and points.has("to_court"):
        return points["to_court"]["pos"]
    return Vector2.ZERO

func _process(dt: float) -> void:
    super(dt)
    _guide_tick()

func _guide_tick() -> void:
    if guide_arrow == null:
        return
    var target := guide_target()
    var from := pos - Vector2(0, GUIDE_UP)
    var show := target != Vector2.ZERO and pos.distance_to(target) > GUIDE_NEAR and visible
    guide_arrow.visible = show
    if not show:
        return
    var dir := (target - from).normalized()
    guide_arrow.rotation = dir.angle()
    guide_arrow.position = from + dir * (GUIDE_AHEAD + absf(sin(t * 3.0)) * 6.0)
    guide_arrow.modulate.a = 0.75 + sin(t * 5.0) * 0.25
