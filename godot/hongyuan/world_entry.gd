extends Node
## A single host for the estate and village, sharing the invitation identity.
const Checkpoint := preload("res://hongyuan/checkpoint.gd")
const Wedding := preload("res://hongyuan/wedding.gd")
const FONT := preload("res://hongyuan/fonts/dialogue_font.tres")
var destination := ""
var content: Node
var game: Node
var profile: Dictionary = {}
var state: Dictionary = {}
var loading: Label
var navigation: VBoxContainer
var busy := false
var save_elapsed := 0.0

func _ready() -> void:
    state = Checkpoint.read()
    var guest: Dictionary = state.get("guest", {})
    profile = state.get("worldProfile", {}).duplicate(true)
    if profile.is_empty():
        profile = {
            "id": "hongyuan_" + str(state.get("runId", "guest")),
            "nick": str(guest.get("name", "来做客的你")),
            "avatar": clampi(int(str(guest.get("look", "01"))) - 1, 0, 7)
        }
    profile["nick"] = str(guest.get("name", profile.get("nick", "来做客的你")))
    profile["avatar"] = clampi(int(str(guest.get("look", int(profile.get("avatar", 0)) + 1))) - 1, 0, 7)
    get_tree().root.set_meta("player_profile", profile.duplicate(true))
    var layer := CanvasLayer.new()
    layer.layer = 100
    add_child(layer)
    loading = Label.new()
    loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    loading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    loading.add_theme_font_override("font", FONT)
    loading.add_theme_font_size_override("font_size", 20)
    loading.add_theme_color_override("font_color", Color("#f5e7ca"))
    var backdrop := StyleBoxFlat.new()
    backdrop.bg_color = Color("#2f1c19")
    loading.add_theme_stylebox_override("normal", backdrop)
    loading.mouse_filter = Control.MOUSE_FILTER_STOP
    layer.add_child(loading)
    navigation = VBoxContainer.new()
    navigation.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    navigation.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    navigation.offset_left = -166
    navigation.offset_right = -12
    navigation.offset_top = 140
    navigation.add_theme_constant_override("separation", 8)
    layer.add_child(navigation)
    await travel(str(state.get("worldRoute", "wedding")))

func _process(dt: float) -> void:
    if busy:
        return
    save_elapsed += dt
    if save_elapsed >= 5.0:
        save_elapsed = 0.0
        save_world()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED and not busy:
        save_world()

func save_world() -> void:
    if not is_instance_valid(game) or destination == "":
        return
    if destination == "village":
        game.village_ui.checkpoint()
        game.save_journal()
    else:
        var at: Dictionary = game.location()
        if not at.is_empty():
            state["weddingLocation"] = at
    state["worldProfile"] = profile.duplicate(true)
    state["worldRoute"] = destination
    state["revision"] = int(state.get("revision", 0)) + 1
    if not Checkpoint.write(state):
        state["revision"] = int(state["revision"]) - 1
        push_warning("World progress could not be saved.")

func travel(where: String) -> void:
    if busy:
        return
    busy = true
    save_world()
    navigation.hide()
    loading.text = "正在前往村子…" if where == "village" else "正在前往罗曼山庄…"
    loading.show()
    if is_instance_valid(content):
        content.queue_free()
        await get_tree().process_frame
    destination = "village" if where == "village" else "wedding"
    var window := get_window()
    window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    window.content_scale_size = Vector2i(540, 960)
    if destination == "village":
        game = load("res://ayu_home/v4/home.tscn").instantiate()
        game.town_profile = profile.duplicate(true)
        content = game
        add_child(content)
        while not game.bootstrapped:
            await get_tree().process_frame
    else:
        game = Wedding.new()
        game.guest_profile = profile.duplicate(true)
        game.resume_location = state.get("weddingLocation", {}).duplicate(true)
        content = game
        add_child(content)
        await game.venue_ready
    for child in navigation.get_children():
        child.queue_free()
    add_button("去婚礼现场" if destination == "village" else "去村子入住",
        func(): travel("wedding" if destination == "village" else "village"))
    if destination == "wedding":
        add_button("直接入席", func(): game.enter_banquet())
    navigation.show()
    loading.hide()
    busy = false
    save_world()
    print("WORLD_READY route=", destination, " nick=", profile.nick, " avatar=", profile.avatar)

func add_button(label: String, action: Callable) -> void:
    var button := Button.new()
    button.text = label
    button.custom_minimum_size = Vector2(154, 66)
    button.add_theme_font_override("font", FONT)
    button.add_theme_font_size_override("font_size", 24)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#473329")
    style.border_color = Color("#be974d")
    style.set_border_width_all(2)
    button.add_theme_stylebox_override("normal", style)
    var hover := style.duplicate()
    hover.bg_color = Color("#694a35")
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    button.pressed.connect(action)
    navigation.add_child(button)
