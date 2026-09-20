extends Control
## 湖边的按钮和那句话（蓝图 3.5 交互说明）：
##   长凳：走到旁边出「坐下」，点一下坐，再点起来；人自己站起来（推摇杆、点地面）时按钮也跟着变回「坐下」
##   亭子：走进去自动出一句，走出去收掉。阿鱼写好那句之前是「【待补】」

const Copy = preload("res://scripts/court_copy.gd")

var m                      # main.gd
var act_btn: Button
var near_bench := false
var said := -1             # 亭子那句是 main 的第几句（say_token）；说话框换了别人的话就不算这句了

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

## 走进、走出交互点（main 的 _on_lake_spot 转过来）
func spot(id: String, inside: bool) -> void:
    match id:
        "bench":
            near_bench = inside
            act_btn.visible = inside
            _refresh()
        "pavilion":
            if inside:
                m._say(Copy.text("pavilion", Copy.LAKE), 0.0, Copy.who("pavilion", Copy.LAKE))
                said = m.say_token
            else:
                _close_line()

func _on_act() -> void:
    if not near_bench:
        return
    if m.lake.seated:
        m.lake.stand_up()
    else:
        m.lake.sit()
    _refresh()

func _refresh() -> void:
    act_btn.text = Copy.text("btn_stand" if m.lake.seated else "btn_sit", Copy.LAKE)

## 人自己站起来了（推摇杆、点地面）：按钮的字跟着变回「坐下」。main 每帧调一次（不用这个节点自己的 _process，
## 测试里手动推帧也能跟上）
func sync() -> void:
    if act_btn != null and act_btn.visible:
        _refresh()

func line_open() -> bool:
    return said != -1 and said == m.say_token and m.dialog.visible

func _close_line() -> void:
    if line_open():
        m.dialog.visible = false
    said = -1

## 离开湖边：按钮收起来，亭子那句也收
func hide_all() -> void:
    _close_line()
    near_bench = false
    act_btn.visible = false
