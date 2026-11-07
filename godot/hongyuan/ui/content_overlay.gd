extends Control
signal retry
signal return_to_desk
const FONT := preload("res://hongyuan/fonts/dialogue_font.tres")
var heading: Label
var detail: Label
var progress_bar: ProgressBar
var retry_button: Button
var desk_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color("#2b211d", 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 390
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	heading = _label(box, 27)
	detail = _label(box, 21)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(390, 16)
	progress_bar.show_percentage = false
	box.add_child(progress_bar)
	retry_button = _button(box, "重试", func(): retry.emit())
	desk_button = _button(box, "回到书桌", func(): return_to_desk.emit())
	retry_button.hide()
	desk_button.hide()

func _label(box: Control, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#fff1d5"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	return label

func _button(box: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 66
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(action)
	box.add_child(button)
	return button

func waiting(chapter_title: String) -> void:
	heading.text = chapter_title
	detail.text = "正在准备这段回忆…"
	progress_bar.value = 0
	progress_bar.show()
	retry_button.hide()
	desk_button.hide()
	show()

func update_progress(value: Dictionary) -> void:
	if bool(value.get("background", false)) or str(value.get("state", "")) == "error":
		return
	var received := int(value.get("received", 0))
	var total := int(value.get("total", 0))
	progress_bar.value = minf(100, float(received) * 100.0 / maxf(total, 1))
	detail.text = "%.1f / %.1f MB" % [received / 1000000.0, total / 1000000.0]

func failed(reason: String) -> void:
	heading.text = "这段回忆还没有加载好"
	detail.text = reason
	progress_bar.hide()
	retry_button.show()
	desk_button.show()
	retry_button.grab_focus()
