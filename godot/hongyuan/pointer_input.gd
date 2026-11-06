extends RefCounted
## Normalize one real finger or a mouse. GUI positions are already canvas-local.
var touch_index := -1

func reset() -> void:
	touch_index = -1

func normalize(event: InputEvent) -> InputEvent:
	if event is InputEventScreenTouch:
		if event.pressed:
			# 同一根手指又按下：上一次松手丢了，别让输入永久卡住
			if touch_index != -1 and event.index != touch_index:
				return null
			touch_index = event.index
		elif event.index != touch_index:
			return null
		else:
			touch_index = -1
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.position = event.position
		button.pressed = event.pressed and not event.canceled
		button.set_meta("pointer_cancelled", event.canceled)
		return button
	if event is InputEventScreenDrag:
		if event.index != touch_index:
			return null
		var motion := InputEventMouseMotion.new()
		motion.position = event.position
		return motion
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		# Godot may also emit a mouse copy of the same touch; never trigger twice.
		if event.device != InputEvent.DEVICE_ID_EMULATION and touch_index == -1:
			return event
	return null
