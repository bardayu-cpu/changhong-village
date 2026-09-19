extends Control
## 草坪的按钮（蓝图 3.4 交互说明）：走到球旁出「踢一脚」，点了球朝人面朝的方向滚出去。
## 球在滚、喜多在叼的时候不出（lawn.gd 发 spot("ball", false)），喜多把球放回脚边又出

const Copy = preload("res://scripts/court_copy.gd")

var m                      # main.gd
var act_btn: Button

func setup(main_ref) -> void:
    m = main_ref
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    act_btn = Button.new()
    act_btn.visible = false
    act_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    act_btn.offset_top = -170
    act_btn.offset_bottom = -120
    act_btn.offset_left = -220
    act_btn.offset_right = 220
    act_btn.pressed.connect(_on_act)
    add_child(act_btn)

## 走近、走开球（main 的 _on_lawn_spot 转过来）
func spot(id: String, inside: bool) -> void:
    if id != "ball":
        return
    act_btn.text = Copy.text("btn_kick", Copy.LAWN)
    act_btn.visible = inside

func _on_act() -> void:
    m.lawn.kick()

## 离开草坪：按钮收起来
func hide_all() -> void:
    act_btn.visible = false
