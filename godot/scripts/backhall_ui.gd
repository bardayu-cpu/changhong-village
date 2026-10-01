extends Control
## 后厅的按钮（蓝图 3.3 交互说明）：走进四个房间的交互点半径，底下出按钮；点一下出一句话，再点关掉；没有面板。
## 话在 assets/backhall/lines.json，阿鱼定之前都是「【待补】」（蓝图 3.3 异常处理：不显示空白）

const Copy = preload("res://scripts/court_copy.gd")
const ROOMS := ["dress", "lounge", "mahjong", "pot"]

var m                      # main.gd
var act_btn: Button
var act_id := ""           # 按钮现在对着哪个点
var said := -1             # 这个按钮说出去的那句是 main 的第几句（say_token）；说话框换了别人的话就不算这个按钮的了

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

## 走进、走出交互点（main 的 _on_backhall_spot 转过来）：进了出按钮，出了按钮和那句话一起收
func spot(id: String, inside: bool) -> void:
    if not id in ROOMS:
        return
    if inside:
        _close_line()
        act_id = id
        act_btn.text = "穿上围裙 · 学做菜" if id == "pot" else Copy.text("btn_" + id, Copy.BACKHALL)
        act_btn.visible = true
    elif act_id == id:
        _close_line()
        act_id = ""
        act_btn.visible = false

## 点一下出这句话（不自己收），再点关掉
func _on_act() -> void:
    if act_id == "":
        return
    if act_id == "pot":
        m._open_kitchen()
        return
    if line_open():
        _close_line()
        return
    m._say(Copy.text(act_id, Copy.BACKHALL), 0.0, Copy.who(act_id, Copy.BACKHALL))
    said = m.say_token

## 说话框里现在是不是这个按钮说的那句
func line_open() -> bool:
    return said != -1 and said == m.say_token and m.dialog.visible

func _close_line() -> void:
    if line_open():
        m.dialog.visible = false
    said = -1

## 离开后厅：按钮收起来，这个按钮说的话也收
func hide_all() -> void:
    _close_line()
    act_id = ""
    act_btn.visible = false
