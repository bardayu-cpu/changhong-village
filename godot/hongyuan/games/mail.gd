extends RefCounted
const PhoneShell := preload("res://hongyuan/ui/phone_shell.gd")
## 邮件：手机里有一封未读邮件（发件人 + 标题），玩家亲手点开；只显示发件人和标题，不显示正文。

var r
var phase := "list"   # list → open → done
var t := 0.0


func start(runner, _beat: Dictionary) -> void:
	r = runner
	r.play("blip")


func process(dt: float) -> bool:
	t += dt
	return phase == "done"


func _row() -> Rect2:
	return Rect2(40, 150, 280, 70)


func input(kind: String, pos: Vector2) -> void:
	if kind != "tap":
		return
	if phase == "list" and _row().grow(8).has_point(pos):
		phase = "open"
		t = 0.0
		r.play("pop")
	elif phase == "open" and t > 0.8:
		phase = "done"


func draw(ci) -> void:
	ci.draw_rect(Rect2(0, 0, 360, 640), Color(0, 0, 0, 0.55))
	PhoneShell.draw_shell(ci)
	if phase == "list":
		var row := _row()
		var glow := 0.25 + 0.2 * sin(t * 5.0)
		ci.draw_rect(row, Color(1, 0.85, 0.5, glow))
		ci.draw_rect(row, ci.WOOD, false, 2.0)
		ci.draw_circle(row.position + Vector2(18, 35), 5, Color("#d63c3c"))
		ci.text_at(row.position + Vector2(34, 28), ci.t_("A6-M1"), 16, ci.INK, 230, HORIZONTAL_ALIGNMENT_LEFT)
		ci.text_at(row.position + Vector2(34, 54), ci.t_("A6-M2"), 14, ci.WOOD, 230, HORIZONTAL_ALIGNMENT_LEFT)
	else:
		var k := clampf(t / 0.4, 0.0, 1.0)
		ci.text_at(Vector2(40, 170), ci.t_("A6-M1"), 18, Color(ci.WOOD, k), 280, HORIZONTAL_ALIGNMENT_LEFT)
		ci.draw_line(Vector2(40, 186), Vector2(320, 186), Color(ci.WOOD, 0.4 * k), 1.0)
		ci.text_at(Vector2(30, 300), ci.t_("A6-M2"), 30, Color(ci.RED, k), 300)
		for i in range(3):
			var a := TAU * i / 3.0 + t
			ci.draw_rect(Rect2(Vector2(180, 340) + Vector2(cos(a), sin(a)) * 60.0, Vector2(4, 4)), Color(ci.GOLD, k))
