extends "res://scripts/entrance.gd"
## 罗曼山庄新加的几块灰盒（10/4 连图，01 G 派；蓝图 v0.3 第 1.0 节）：儿童乐园、小卖部、休息厅 2、西餐厨房、后花园、前门、后门。
## 都是同一种做法：布局 assets/layered/scene_luoman_<名字>/layout.json（tools/layout_court/make_areas.py 出），搭法、走路、口、
## 走到头提示都是 entrance.gd 那套；口写了 to 的 main 照着切，写了 say 的走进去说一句（还在布置），话在 assets/areas/lines.json

func setup_area(id: String) -> void:
    layout_path = "res://assets/layered/scene_luoman_%s/layout.json" % id

## 屋里的人活起来（10/4 02 F：化妆间三位连同第 67 版的冒泡、点人说话、助理走一圈从后厅长条搬进单独那间）：
## 布局写了 "life": {"room", "data"} 就挂一份 lounge_life.gd（跟后厅那几间同一套）；npcs 写 life: <room> 的归它管
const LoungeLife = preload("res://scripts/lounge_life.gd")
var lives: Array = []

func build(preset: int, nickname: String, f: Font) -> void:
    super(preset, nickname, f)
    var lc: Dictionary = cfg.get("life", {})
    if not lc.is_empty():
        var lf = LoungeLife.new()
        add_child(lf)
        lf.setup(self, str(lc["data"]), str(lc["room"]))
        lives.append(lf)

func _process(dt: float) -> void:
    super(dt)
    for lf in lives:
        lf.step(dt)

## 点了屋里能说话的人：走过去，到了弹对话框（lounge_ui.gd）；别的照旧
func tap(screen: Vector2) -> void:
    if not walking_enabled:
        return
    var at := get_viewport().get_canvas_transform().affine_inverse() * screen
    for lf in lives:
        var who: String = lf.npc_at(at)
        if who != "":
            for other in lives:
                other.pending_talk = ""
            lf.request_talk(who)
            return
    super(screen)
