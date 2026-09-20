extends Control
## 果园的按钮和话（蓝图 3.6 交互说明）：走到垄间或树下——
##   到季节、今天还没摘：出「摘一颗」，点一下摘，说一句
##   没到季节：顶部「还没到时候」，按钮不出
##   今天摘过了：顶部「今天摘过一颗了」，按钮不出
## 话在 assets/orchard/lines.json，季节的月份表在 assets/orchard/seasons.json

const Copy = preload("res://scripts/court_copy.gd")
const KINDS := ["strawberry", "loquat"]

var m                      # main.gd
var act_btn: Button
var act_kind := ""         # 按钮现在对着哪种果子

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

## 走进、走出交互点（main 的 _on_orchard_spot 转过来）
func spot(id: String, inside: bool) -> void:
    if not id in KINDS:
        return
    if not inside:
        if act_kind == id:
            act_kind = ""
            act_btn.visible = false
        return
    var o = m.orchard
    if o.can_pick(id):
        act_kind = id
        act_btn.text = Copy.text("btn_pick", Copy.ORCHARD)
        act_btn.visible = true
        return
    act_kind = ""
    act_btn.visible = false
    var key := "picked_today" if o.picked_today(id) else "not_season"
    m._note(Copy.text(key, Copy.ORCHARD), 3.0)

func _on_act() -> void:
    if act_kind == "" or not m.orchard.pick(act_kind):
        return
    var key := act_kind + "_pick"
    m._say(Copy.text(key, Copy.ORCHARD), -1.0, Copy.who(key, Copy.ORCHARD))
    m.orchard.refresh_fruit()
    act_kind = ""
    act_btn.visible = false

## 离开果园：按钮收起来
func hide_all() -> void:
    act_kind = ""
    act_btn.visible = false
