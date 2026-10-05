extends Control
## 休息间的按钮、对话框、身份卡（docs/人物新做法-休息间样板-v0.1.md 第 3、4 节，01 F 10/4）：
##   「坐下 / 起来」：走到空座位跟前出「坐下」，坐着出「起来」（推摇杆也会站起来，按钮跟着变）
##   「跟 XX 聊聊」：走到 NPC 跟前（或坐在他旁边）出；点 NPC 本人也一样（backhall.tap → lounge_life 走过去）
##   对话框：屏幕下方，上面一块名字牌（右边「身份卡」），左边这个人的人物图截上半身，右边一句句的话，点一下下一句，说完收
##           每句的 pose 指定用哪张人物图；GPT 的人物图（第 27 件）到之前拿现在的小图放大顶着
##   身份卡：全身人物图 + 称呼（+ 跟阿鱼什么关系，没定的只写称呼）
## 话、按钮上的字在 assets/backhall/lounge.json（待校对）
## 10/4 接了对话插件 Dialogue Manager 4.1（addons/dialogue_manager，阿鱼点头下的）：lounge.json 里写了 dialogue 的那位（先是奶奶），
## 台词、选项分支走插件（那份 .dialogue），外观还是这个对话框——插件只管「下一句是什么、有哪些选项」，不用它自带的气泡；
## [#smile] 这种标签就是这句用哪张人物图。没写 dialogue 的照旧一句句念 talk

const LMPeople = preload("res://scripts/lm_people.gd")
## code 空着（新娘，HANDOFF §0.5：新人只用阿鱼审过的图，01 H 10/4 定）：对话框不放头像、身份卡不放图，等阿鱼点过头的新娘图再填 code。
## GPT 人物图到了照这个放：assets/characters/lm/pose_<编号>.json = {"png": "res://…", "poses": {"front": [x, y, w, h], "side": […], …}}，
## 每张是全身；对话框截上面 PORTRAIT_KEEP，身份卡用整张。没有这份就拿宾客小图的格子顶着（POSE_FRAME）
const POSE_DIR := "res://assets/characters/lm/pose_%s.json"
const POSE_FRAME := {"front": 0, "side": 4, "smile": 0, "surprise": 0, "talk": 0, "sit": 0}
const PORTRAIT_KEEP := 0.56
const NAME_BG := Color("#a8281f")
const DialogSkin = preload("res://scripts/ui/dialog_skin.gd")   # 冒泡、对话框长什么样（05 10/4）

var m                      # main.gd
var life                   # 后厅的 lounge_life.gd（休息间那份：座位、按钮上的字都在它）
var lives: Array = []      # 后厅每间屋的人（休息间、麻将室、化妆间，10/4 07 铺开）：点人、聊聊、对话框都认这几份
var near_life              # 「聊聊」按钮对着的人在哪间
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
var dm_res: Resource = null   # 走对话插件时：这段对话（.dialogue 导入后的 DialogueResource）
var dm_line = null            # 插件给的这一句（DialogueLine）；null 是没走插件
var dm_busy := false          # 正在等插件给下一句（await 里）
var choices: BoxContainer     # 选项按钮（05 10/4 起在对话框最后一行，一行排完；dialog_skin.gd）
var talk_info: Dictionary = {}  # 正在跟谁说：{id, title, code（人物图）, dialogue, talk, relation}
var talk_cv                     # 在哪块画布上说（说话时那块不能走，说完放开）
var line_raw := ""              # 这句的原文（没加引号）：对话框里人说的话一律用“”框起来（阿鱼 10/4），测试比字认原文

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
        if near_id != "" and near_life != null:
            near_life.request_talk(near_id))
    btn_row.add_child(talk_btn)
    _build_talk_box()

func _txt(k: String) -> String:
    if life == null:
        return k
    var b: Dictionary = life.data.get("buttons", {})
    if b.is_empty():   # 化妆间、麻将室那几份话没写按钮上的字：借休息间那份（10/4 02 F）
        if lounge_buttons.is_empty():
            var raw = JSON.parse_string(FileAccess.get_file_as_string("res://assets/backhall/lounge.json"))
            lounge_buttons = raw.get("buttons", {}) if raw is Dictionary else {}
        b = lounge_buttons
    return str(b.get(k, k))
var lounge_buttons: Dictionary = {}

## 后厅搭好以后（main.ensure_canvas）接上：点了的人走到了就开对话框
func attach(lounge) -> void:
    if life == lounge:
        return
    life = lounge
    lives = [lounge]
    var cv = lounge.get("c")
    if cv != null and cv.get("lives") is Array and not (cv.lives as Array).is_empty():
        lives = cv.lives
    for lf in lives:
        if not lf.talk_ready.is_connected(open_talk):   # 后厅、化妆间来回进出会再接一次（10/4 02 F）
            lf.talk_ready.connect(open_talk)

## 这位在哪间屋（lives 里哪份）；不在回 null
func life_of(id: String):
    for lf in lives:
        if lf.people.has(id):
            return lf
    return null

func _build_talk_box() -> void:
    # 长什么样交给 scripts/ui/dialog_skin.gd（05 10/4 重做样子，三种给阿鱼挑；行为照旧在这里）
    DialogSkin.build_talk(self, m.font)
    talk_box.gui_input.connect(func(e):
        if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
            next_line()
            talk_box.accept_event())
    card_btn.pressed.connect(func(): open_card(talk_id))

## 某位、某个 pose 的人物图：half 是对话框用的上半身，不然是身份卡用的全身
func pose_tex(code: String, pose: String, half: bool) -> AtlasTexture:
    if code == "":
        return null
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
## 休息间四位（lounge_life 的人）：点了、走到了。后厅几间、单独那间化妆间（10/4 02 F）都走这里：这位在哪块画布就在哪块开
func open_talk(id: String) -> void:
    var lf = life_of(id)
    if lf != null and lf.c == m.cv:
        _open(lf.person(id), lf.c)

## 别的画布上布局写了 dialogue 的 NPC（entrance.gd 的 talkers，10/4 起哪块画布都能挂）：点了、走到了
func open_npc(canvas, id: String) -> void:
    if canvas != m.cv or not canvas.talkers.has(id):
        return
    _open(canvas.talkers[id], canvas)

## 开对话框：台词有 dialogue（.dialogue 文件）就走对话插件，没有就念 talk 那几句
func _open(p: Dictionary, canvas) -> void:
    var lines: Array = p.get("talk", [])
    if p.is_empty() or (lines.is_empty() and str(p.get("dialogue", "")) == "") or is_open():
        return
    var id := str(p["id"])
    talk_info = p
    talk_cv = canvas
    talk_id = id
    line_i = 0
    var lf = life_of(id)
    if lf != null:
        lf.talking = id
    canvas.walking_enabled = false
    canvas.path.clear()
    canvas.stick = Vector2.ZERO
    m.dialog.visible = false
    name_label.text = str(p.get("title", ""))
    card_btn.text = _txt("card")
    hint_label.text = _txt("next")
    talk_box.visible = true
    name_plate.visible = true
    dm_line = null
    dm_res = null
    var path := str(p.get("dialogue", ""))
    var dm = get_node_or_null("/root/DialogueManager")
    if path != "" and dm != null and ResourceLoader.exists(path):
        dm_res = load(path)
        _set_line("")
        _dm_next("start")
    else:
        _show_line()
    print("[suqi] NPC 说话 ", id, " 走插件" if dm_res != null else "")

func _show_line() -> void:
    var p: Dictionary = talk_info
    var l: Dictionary = (p["talk"] as Array)[line_i]
    _set_line(str(l.get("text", "")))
    portrait.texture = pose_tex(str(p["code"]), str(l.get("pose", "front")), true)
    portrait.visible = portrait.texture != null
    portrait.set_meta("pose", str(l.get("pose", "front")))

## 对话框里都是人说的话：用“”框起来（阿鱼 10/4），原文另存 line_raw
func _set_line(t: String) -> void:
    line_raw = t
    line_label.text = m.quoted(t)

## 走插件：要下一句（key 是上一句的 next_id、或者选的那个选项的 next_id），到了就照这个对话框的样子摆出来；没了就收
func _dm_next(key: String) -> void:
    var dm = get_node_or_null("/root/DialogueManager")
    if dm == null or dm_res == null:
        close_talk()
        return
    dm_busy = true
    var line = await dm.get_next_dialogue_line(dm_res, key)
    dm_busy = false
    if talk_id == "":
        return   # 等的时候对话框已经收了（离开后厅）
    if line == null:
        close_talk()
        return
    dm_line = line
    line_i += 1
    var p: Dictionary = talk_info
    if str(line.character) != "":
        name_label.text = str(line.character)
    _set_line(str(line.text))
    var pose := "front"
    for tg in line.tags:
        if POSE_FRAME.has(str(tg)):
            pose = str(tg)
    portrait.texture = pose_tex(str(p["code"]), pose, true)
    portrait.visible = portrait.texture != null   # 没有人物图的（新娘：等阿鱼点过头的图）不放头像，字往左占满
    portrait.set_meta("pose", pose)
    for ch in choices.get_children():
        ch.queue_free()
    choices.visible = not line.responses.is_empty()
    hint_label.text = "" if choices.visible else _txt("next")
    for r in line.responses:
        var b := Button.new()
        b.text = str(r.text)
        b.custom_minimum_size = Vector2(0, 52)
        DialogSkin.style_choice(b, m.font)
        var nid := str(r.next_id)
        b.pressed.connect(func(): pick(nid))
        choices.add_child(b)

## 挑了一个选项
func pick(next_id: String) -> void:
    if dm_busy or dm_line == null:
        return
    choices.visible = false
    _dm_next(next_id)

func next_line() -> void:
    if talk_id == "" or card != null:
        return
    if DialogSkin.typing(talk_box):   # 字还在一个个出：这一下先把这一页出完（04 第 4 条）
        DialogSkin.finish(talk_box)
        return
    if not DialogSkin.last_page(talk_box):   # 一句超过 2 行分了页：翻页点右边的上下三角（阿鱼 10/5），点框不翻、也不跳到下一句
        return
    if dm_res != null:
        if dm_busy or dm_line == null or choices.visible:
            return   # 有选项的那句：得点选项，点对话框不往下走
        _dm_next(str(dm_line.next_id))
        return
    line_i += 1
    if line_i >= (talk_info["talk"] as Array).size():
        close_talk()
    else:
        _show_line()

func close_talk() -> void:
    close_card()
    talk_box.visible = false
    name_plate.visible = false
    choices.visible = false
    dm_res = null
    dm_line = null
    talk_id = ""
    talk_info = {}
    for lf in lives:
        lf.talking = ""
    if talk_cv != null and m.cv == talk_cv and m._in_scene():
        talk_cv.walking_enabled = true
    talk_cv = null

# ---------- 身份卡 ----------
## 全身人物图 + 称呼（+ 关系）；点「关上」或暗处收，回到对话框
func open_card(id: String) -> void:
    var lf = life_of(id)
    var p: Dictionary = talk_info if id == talk_id and not talk_info.is_empty() else (lf.person(id) if lf != null else {})
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
    if body.texture != null:
        v.add_child(body)   # 没有人物图的（新娘）身份卡只写称呼，不放图
    else:
        body.free()
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
    var c = life.c
    if c.seated:
        life.stand_up()
    else:
        life.sit(life.near_seat())
    sync()

## main 每帧调（后厅里）：坐下 / 起来、聊聊两个按钮该不该出、字对不对
func sync() -> void:
    if life == null:
        return
    var c = life.c   # 后厅，或单独那间化妆间（10/4 02 F）
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
    near_life = null
    if not busy:
        for lf in lives:
            near_id = lf.near_npc()
            if near_id != "":
                near_life = lf
                break
        if near_id == "" and c.seated:
            for id in life.people:
                if c.pos.distance_to(life.people[id]["foot"]) < 90.0:
                    near_id = id
                    near_life = life
    talk_btn.visible = near_id != ""
    if near_id != "":
        talk_btn.text = _txt("talk") % str(near_life.person(near_id).get("title", ""))
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
