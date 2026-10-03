extends Control
## 休息间的按钮、对话框、身份卡（docs/人物新做法-休息间样板-v0.1.md 第 3、4 节，01 F 10/4）：
##   「坐下 / 起来」：走到空座位跟前出「坐下」，坐着出「起来」（推摇杆也会站起来，按钮跟着变）
##   「跟 XX 聊聊」：走到 NPC 跟前（或坐在他旁边）出；点 NPC 本人也一样（backhall.tap → lounge_life 走过去）
##   对话框：屏幕下方，上面一块名字牌（右边「身份卡」），左边这个人的人物图截上半身，右边一句句的话，点一下下一句，说完收
##           每句的 pose 指定用哪张人物图；GPT 的人物图（第 27 件）到之前拿现在的小图放大顶着
##   身份卡：全身人物图 + 称呼（+ 跟阿鱼什么关系，没定的只写称呼）
## 话、按钮上的字在 assets/backhall/lounge.json（待校对）

const LMPeople = preload("res://scripts/lm_people.gd")
## GPT 人物图到了照这个放：assets/characters/lm/pose_<编号>.json = {"png": "res://…", "poses": {"front": [x, y, w, h], "side": […], …}}，
## 每张是全身；对话框截上面 PORTRAIT_KEEP，身份卡用整张。没有这份就拿宾客小图的格子顶着（POSE_FRAME）
const POSE_DIR := "res://assets/characters/lm/pose_%s.json"
const POSE_FRAME := {"front": 0, "side": 4, "smile": 0, "surprise": 0, "talk": 0, "sit": 0}
const PORTRAIT_KEEP := 0.56
const NAME_BG := Color("#a8281f")

var m                      # main.gd
var life                   # 后厅的 lounge_life.gd
var btn_row: HBoxContainer
var seat_btn: Button
var talk_btn: Button
var talk_box: PanelContainer
var name_plate: PanelContainer
var name_label: Label
var card_btn: Button
var portrait: TextureRect
var line_label: Label
var hint_label: Label
var talk_id := ""          # 正在跟谁说
var line_i := 0
var card: Control          # 身份卡（开着才有）
var near_id := ""          # 「聊聊」按钮对着谁

func setup(main_ref) -> void:
    m = main_ref
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    btn_row = HBoxContainer.new()
    btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
    btn_row.add_theme_constant_override("separation", 16)
    btn_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    btn_row.offset_left = -260
    btn_row.offset_right = 260
    btn_row.offset_top = -170
    btn_row.offset_bottom = -120
    btn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(btn_row)
    seat_btn = Button.new()
    seat_btn.custom_minimum_size = Vector2(150, 50)
    seat_btn.visible = false
    seat_btn.pressed.connect(_on_seat)
    btn_row.add_child(seat_btn)
    talk_btn = Button.new()
    talk_btn.custom_minimum_size = Vector2(200, 50)
    talk_btn.visible = false
    talk_btn.pressed.connect(func():
        if near_id != "":
            life.request_talk(near_id))
    btn_row.add_child(talk_btn)
    _build_talk_box()

func _txt(k: String) -> String:
    return str((life.data.get("buttons", {}) as Dictionary).get(k, k)) if life != null else k

## 后厅搭好以后（main.ensure_canvas）接上：点了的人走到了就开对话框
func attach(lounge) -> void:
    if life == lounge:
        return
    life = lounge
    life.talk_ready.connect(open_talk)

func _build_talk_box() -> void:
    talk_box = PanelContainer.new()
    talk_box.name = "lounge_talk"
    talk_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    talk_box.offset_left = 14
    talk_box.offset_right = -14
    talk_box.offset_top = -300
    talk_box.offset_bottom = -40
    talk_box.add_theme_stylebox_override("panel", m._sb(Color(0.12, 0.07, 0.06, 1.0), m.GOLD, 3, 10, 16))   # 不透：底下「点地面走路」那块别透出来
    talk_box.mouse_filter = Control.MOUSE_FILTER_STOP
    talk_box.gui_input.connect(func(e):
        if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
            next_line()
            talk_box.accept_event())
    talk_box.visible = false
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 16)
    h.mouse_filter = Control.MOUSE_FILTER_IGNORE
    talk_box.add_child(h)
    portrait = TextureRect.new()
    portrait.custom_minimum_size = Vector2(180, 0)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    h.add_child(portrait)
    var v := VBoxContainer.new()
    v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    v.mouse_filter = Control.MOUSE_FILTER_IGNORE
    h.add_child(v)
    line_label = m._label("", 26, m.PAPER, HORIZONTAL_ALIGNMENT_LEFT)
    line_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    line_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_child(line_label)
    hint_label = m._label("", 18, m.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
    hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_child(hint_label)
    add_child(talk_box)
    # 名字牌：压在对话框左上角上沿，红底金边（跟门口名字牌一家）；右边「身份卡」
    name_plate = PanelContainer.new()
    name_plate.name = "lounge_name"
    name_plate.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    name_plate.offset_left = 30
    name_plate.offset_top = -340
    name_plate.offset_bottom = -290
    name_plate.add_theme_stylebox_override("panel", m._sb(NAME_BG, m.GOLD, 2, 6, 8))
    name_plate.visible = false
    var nh := HBoxContainer.new()
    nh.add_theme_constant_override("separation", 12)
    name_plate.add_child(nh)
    name_label = m._label("", 24, m.GOLD1, HORIZONTAL_ALIGNMENT_LEFT, false)
    nh.add_child(name_label)
    card_btn = Button.new()
    card_btn.pressed.connect(func(): open_card(talk_id))
    nh.add_child(card_btn)
    add_child(name_plate)

## 某位、某个 pose 的人物图：half 是对话框用的上半身，不然是身份卡用的全身
func pose_tex(code: String, pose: String, half: bool) -> AtlasTexture:
    var tex: Texture2D = null
    var r := Rect2()
    var pj := POSE_DIR % code
    if FileAccess.file_exists(pj):
        var d = JSON.parse_string(FileAccess.get_file_as_string(pj))
        if d is Dictionary:
            var poses: Dictionary = d.get("poses", {})
            var a: Array = poses.get(pose, poses.get("front", []))
            if a.size() == 4:
                tex = load(str(d["png"]))
                r = Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
    if tex == null:
        var l: Dictionary = LMPeople.look(code)
        if l.is_empty():
            return null
        var fw := float(l["fw"])
        var fh := float(l["fh"])
        var hf := int(l["hframes"])
        var fr := int(POSE_FRAME.get(pose, 0))
        tex = l["tex"]
        var top := float(l.get("top", 0))
        r = Rect2(float(fr % hf) * fw, float(fr / hf) * fh + top, fw, fh - top)
    if half:
        r.size.y = roundf(r.size.y * PORTRAIT_KEEP)
    var at := AtlasTexture.new()
    at.atlas = tex
    at.region = r
    return at

func is_open() -> bool:
    return talk_box.visible or card != null

# ---------- 对话框 ----------
func open_talk(id: String) -> void:
    var p: Dictionary = life.person(id)
    var lines: Array = p.get("talk", [])
    if lines.is_empty() or m.state != "backhall":
        return
    talk_id = id
    line_i = 0
    life.talking = id
    m.backhall.walking_enabled = false
    m.backhall.path.clear()
    m.backhall.stick = Vector2.ZERO
    m.dialog.visible = false
    name_label.text = str(p.get("title", ""))
    card_btn.text = _txt("card")
    hint_label.text = _txt("next")
    talk_box.visible = true
    name_plate.visible = true
    _show_line()
    print("[suqi] 休息间说话 ", id)

func _show_line() -> void:
    var p: Dictionary = life.person(talk_id)
    var l: Dictionary = (p["talk"] as Array)[line_i]
    line_label.text = str(l.get("text", ""))
    portrait.texture = pose_tex(str(p["code"]), str(l.get("pose", "front")), true)
    portrait.set_meta("pose", str(l.get("pose", "front")))

func next_line() -> void:
    if talk_id == "" or card != null:
        return
    line_i += 1
    if line_i >= (life.person(talk_id)["talk"] as Array).size():
        close_talk()
    else:
        _show_line()

func close_talk() -> void:
    close_card()
    talk_box.visible = false
    name_plate.visible = false
    talk_id = ""
    if life != null:
        life.talking = ""
    if m.state == "backhall":
        m.backhall.walking_enabled = true

# ---------- 身份卡 ----------
## 全身人物图 + 称呼（+ 关系）；点「关上」或暗处收，回到对话框
func open_card(id: String) -> void:
    var p: Dictionary = life.person(id)
    if p.is_empty() or card != null:
        return
    card = Control.new()
    card.name = "lounge_card"
    card.set_anchors_preset(Control.PRESET_FULL_RECT)
    card.mouse_filter = Control.MOUSE_FILTER_STOP
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.5)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    dim.gui_input.connect(func(e):
        if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
            close_card())
    card.add_child(dim)
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", m._sb(Color(0.12, 0.07, 0.06, 0.97), m.GOLD, 2, 10, 18))
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.custom_minimum_size = Vector2(380, 0)
    panel.position = Vector2(-190, -280)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 10)
    panel.add_child(v)
    var body := TextureRect.new()
    body.name = "full_body"
    body.texture = pose_tex(str(p["code"]), "front", false)
    body.custom_minimum_size = Vector2(0, 336)
    body.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    body.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    v.add_child(body)
    v.add_child(m._label(str(p.get("title", "")), 30, m.GOLD1))
    if str(p.get("relation", "")) != "":
        var rel: Label = m._label(str(p["relation"]), 22, m.PAPER)
        rel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        v.add_child(rel)
    var close := Button.new()
    close.text = _txt("close")
    close.pressed.connect(close_card)
    v.add_child(close)
    card.add_child(panel)
    add_child(card)
    print("[suqi] 休息间身份卡 ", id)

func close_card() -> void:
    if card != null:
        card.queue_free()
        card = null

# ---------- 按钮 ----------
func _on_seat() -> void:
    var c = m.backhall
    if c.seated:
        life.stand_up()
    else:
        life.sit(life.near_seat())
    sync()

## main 每帧调（后厅里）：坐下 / 起来、聊聊两个按钮该不该出、字对不对
func sync() -> void:
    if life == null:
        return
    var c = m.backhall
    var busy: bool = is_open() or not c.walking_enabled
    var seat_txt := ""
    if not busy:
        if c.seated and life.my_seat != "":
            seat_txt = _txt("stand")
        elif not life.near_seat().is_empty():
            seat_txt = _txt("sit")
    seat_btn.visible = seat_txt != ""
    seat_btn.text = seat_txt
    near_id = ""
    if not busy:
        near_id = life.near_npc()
        if near_id == "" and c.seated:
            for id in life.people:
                if c.pos.distance_to(life.people[id]["foot"]) < 90.0:
                    near_id = id
    talk_btn.visible = near_id != ""
    if near_id != "":
        talk_btn.text = _txt("talk") % str(life.person(near_id).get("title", ""))
    # 后厅房间那个按钮在同一排：它出着就把这一排往上让一格
    var up: bool = m.backhall_ui != null and m.backhall_ui.act_btn.visible
    btn_row.offset_top = -230 if up else -170
    btn_row.offset_bottom = -180 if up else -120

## 离开后厅：按钮、对话框、身份卡都收
func hide_all() -> void:
    if talk_id != "":
        close_talk()
    close_card()
    seat_btn.visible = false
    talk_btn.visible = false
