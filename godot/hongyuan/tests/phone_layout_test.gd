extends SceneTree
class Harness extends "res://hongyuan/player.gd":
	func _save() -> void:
		pass
var failures := 0
func check(ok: bool, label: String) -> void:
	if ok: print("PASS ",label)
	else:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var p := Harness.new()
	root.add_child(p)
	p.set_process(false)
	p._enter_step(p.step_indices["shanghai/chat_ayu"])
	check(p.title.text == p.copy["A1-G0"], "Group header uses locked title")
	check(p.stage.chat_rows.size() == 4, "Four original messages retained in order")
	var visible_messages: Array[String] = []
	for child in p.slots.get_children():
		if child is Label: visible_messages.append(child.text)
	check(visible_messages == [p.copy["A1-3a"],p.copy["A1-3b"],p.copy["A1-3c"],p.copy["A1-3d"]], "Chat body matches original copy and order exactly")
	var screen: Rect2 = p.stage.phone_screen_rect()
	for row: Dictionary in p.stage.chat_rows:
		print("ROW ",row.speaker," ",row.bubble)
		check(row.visible and screen.encloses(row.bubble), "Original message remains visible inside phone")
	check(is_equal_approx(screen.size.x,316.0), "Phone opening fills the 360px layout")
	p._enter_step(p.step_indices["chengdu/chengdu_ping"])
	var notification: Button
	for child in p.slots.get_children():
		if child is Button: notification = child
	check(notification != null and notification.text == p.copy["A2-2"] and screen.encloses(Rect2(notification.position,notification.size)), "Chengdu notification retains copy and fits new phone")
	# 来电已改成场景（call/night_call），长按接听的覆盖见 call_hold_test.gd。
	for key in ["w2_phone_frame","w2_phone_header","w2_phone_screen_paper","w2_bubble_left","w2_bubble_right","w2_bubble_system","w2_call_accept","w2_call_end"]:
		check(p.stage.image_asset(key) != null, "Skin loads: " + key)
	print("FAILURES ",failures)
	p.queue_free()
	await process_frame
	quit(failures)
