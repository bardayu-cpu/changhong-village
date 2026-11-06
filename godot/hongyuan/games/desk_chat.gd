extends RefCounted
## 生日桌旁的手机聊天；原稿五条消息按一次出一条。
var r
var lines: Array = []
var li := 0
var phase := "chat"
var t := 0.0

func start(runner, beat: Dictionary) -> void:
	r = runner
	lines = beat.get("lines", [])
	r.play("pop")

func process(dt: float) -> bool:
	t += dt
	return phase == "done"

func input(kind: String, _pos: Vector2) -> void:
	if kind != "tap" or phase != "chat" or t < 0.12: return
	li += 1
	t = 0.0
	if li >= lines.size():
		phase = "done"
	else:
		r.play("blip")

func draw(ci) -> void:
	ci.draw_rect(Rect2(0, 0, 360, 640), Color(0, 0, 0, 0.55))
	var frame: Texture2D = ci.texture("w2_ui/phone_frame_w2_r1.png")
	if frame:
		ci.draw_texture_rect(frame, Rect2(Vector2(14, 32), frame.get_size() * ci.S), false)
	ci.draw_rect(Rect2(34, 52, 292, 520), ci.PAPER)
	ci.text_at(Vector2(54, 88), ci.NAMES.ayu, 20, ci.INK, 252)
	ci.draw_line(Vector2(44, 104), Vector2(316, 104), ci.GOLD, 2)
	var y := 118.0
	for i in range(mini(li + 1, lines.size())):
		var who := str(lines[i].get("who", "toretto"))
		var message: String = ci.t_(str(lines[i].say))
		var paragraph := TextParagraph.new()
		paragraph.width = 190
		paragraph.add_string(message, ci.FONT, 14)
		var height := maxf(40, paragraph.get_size().y + 18)
		var x := 64.0 if who == "toretto" else 80.0
		var rect := Rect2(x, y, 218, height)
		ci.draw_rect(rect, Color("#eed5a6") if who == "toretto" else Color("#fffaf0"))
		ci.draw_rect(rect, ci.GOLD, false, 1)
		paragraph.draw(ci.get_canvas_item(), Vector2(x + 14, y + 9), ci.INK)
		var avatar: Texture2D = ci.texture(ci.AVATARS.get(who, ""))
		if avatar:
			ci.draw_texture_rect(avatar, Rect2(288 if who == "toretto" else 42, y + 3, 30, 30), false)
		y += height + 10
	ci.pill(Rect2(108, 582, 144, 32), ci.t_("G-19"), 15, ci.WOOD, ci.PAPER)
