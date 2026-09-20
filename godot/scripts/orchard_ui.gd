extends Control
## 果园的按钮和话（阿鱼 9/20 定的种田玩法）：
##   走到垄间、树下：有熟的出「收草莓（3 垄熟了）」，点一下把熟了的一次收完，进果篮；
##                   没熟顶部报「草莓还有 2 分 10 秒」；季节开关打开又不在季节，才是老话「还没到时候」
##   走到山庄收购处：果篮有东西出「卖给山庄（14 金）」，点了加金币、说一句；空着顶部报「果篮是空的」
##   farm.json 里 sell_mode = auto：收完直接折钱，不用跑收购处
## 话在 assets/orchard/lines.json，数在 assets/orchard/farm.json

const Copy = preload("res://scripts/court_copy.gd")
const KINDS := ["strawberry", "loquat"]

var m                      # main.gd
var act_btn: Button
var act_kind := ""         # 按钮现在对着哪种果子（空串表示对着收购处或者没按钮）
var at_shop := false       # 人是不是站在收购处

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
    if id == "shop":
        at_shop = inside
        if not inside and act_kind == "":
            act_btn.visible = false
        sync()
        if inside and m.orchard.save.basket_total() <= 0:
            # 山庄直接收的时候果篮本来就空，别让人以为摊子坏了
            m._note(Copy.text("shop_auto" if m.orchard.auto_sell() else "basket_empty", Copy.ORCHARD), 3.0)
        return
    if not id in KINDS:
        return
    if not inside:
        if act_kind == id:
            act_kind = ""
            act_btn.visible = false
        return
    var o = m.orchard
    if o.ripe_count(id) > 0:
        act_kind = id
        sync()
        return
    act_kind = ""
    act_btn.visible = false
    # 季节开关打开、又不在季节，才是蓝图 3.6 那句；平常报还有多久熟
    if not o.kind_on(id):
        m._note(Copy.text("not_season", Copy.ORCHARD), 3.0)
    else:
        m._note(Copy.text("growing", Copy.ORCHARD).format(
            {"fruit": o.fruit_name(id), "left": o.left_text(o.secs_left(id))}), 3.0)

## 每帧由 main 叫一次（人站着不动地也在长，按钮上的数要跟着变）
func sync() -> void:
    var o = m.orchard
    if act_kind != "":
        var n: int = o.ripe_count(act_kind)
        if n <= 0:                      # 刚收完：按钮收起来，改成报还有多久
            act_kind = ""
            act_btn.visible = false
            if not at_shop:
                return
        else:
            act_btn.text = Copy.text("btn_harvest", Copy.ORCHARD).format(
                {"fruit": o.fruit_name(act_kind), "n": n, "plot": o.plot_word(act_kind)})
            act_btn.visible = true
            return
    if at_shop and o.save.basket_total() > 0:
        act_btn.text = Copy.text("btn_sell", Copy.ORCHARD).format({"coins": o.basket_coins()})
        act_btn.visible = true
        return
    if act_kind == "":
        act_btn.visible = false

func _on_act() -> void:
    var o = m.orchard
    if act_kind != "":
        var got: int = o.harvest(act_kind)
        if got <= 0:
            return
        var kind := act_kind
        act_kind = ""
        act_btn.visible = false
        if o.auto_sell():               # 山庄直接收走折钱
            _sell()
        else:
            m._say(Copy.text("harvested", Copy.ORCHARD).format(
                {"fruit": o.fruit_name(kind), "n": got, "unit": o.basket_unit(kind)}), -1.0, "")
        sync()
        return
    if at_shop:
        _sell()
        sync()

func _sell() -> void:
    var o = m.orchard
    var r: Dictionary = o.sell()
    if int(r["coins"]) <= 0:
        return
    m.games_save.earn(int(r["coins"]))
    m._say(Copy.text("sold", Copy.ORCHARD).format(
        {"what": r["text"], "coins": r["coins"], "total": m.games_save.coins}), -1.0, "")

## 离开果园：按钮收起来
func hide_all() -> void:
    act_kind = ""
    at_shop = false
    act_btn.visible = false
