extends RefCounted
## The phone remains in Ayu's hands; the readable conversation is a compact overlay.
const Desk := preload("res://hongyuan/ui/desk_art.gd")
const Bubble := preload("res://hongyuan/ui/phone_shell.gd")
var r
var lines: Array = []
var li := 0
var phase := "chat"
var backdrop := "round1/people/group_shoulder.png"
var t := 0.0
var reveal := 0.0
var member_faces: Array[Texture2D] = []
func start(runner, beat: Dictionary) -> void:
	r = runner
	lines = beat.get("lines", [])
	backdrop = str(beat.get("backdrop",backdrop))
	r.hint = ""
	for i in range(3,8):
		var sheet: Texture2D = load("res://assets/characters/lm/chr_LM-GUEST-%02d.png"%i)
		member_faces.append(ImageTexture.create_from_image(sheet.get_image().get_region(Rect2i(16,0,32,32))))
func process(dt: float) -> bool:
	t += dt
	if li < lines.size(): reveal = minf(reveal + dt * 32, r.t_(lines[li].say).length())
	return phase == "done"
func input(kind: String, _at: Vector2) -> void:
	if kind != "tap" or phase != "chat" or t < 0.2: return
	if reveal < r.t_(lines[li].say).length():
		reveal = r.t_(lines[li].say).length(); return
	li += 1; t = 0; reveal = 0
	if li >= lines.size(): phase = "done"
func draw(ci) -> void:
	var bg: Texture2D = ci.texture(backdrop)
	if bg:
		Desk.cover(ci,bg,ci.view_rect)
		var k := maxf(ci.view_rect.size.x/bg.get_width(),ci.view_rect.size.y/bg.get_height())
		var origin: Vector2 = ci.view_rect.get_center()-bg.get_size()*k*0.5
		# Tiny message silhouettes follow the real iPhone in her hands;
		# the lower readable inset carries the exact script.
		for j in range(3):
			ci.draw_rect(Rect2(origin+Vector2(490,820+j*47)*k,Vector2(92,34)*k),Color("#b4dfa2") if j==2 else Color("#f8faf4"))

	Bubble._round_box(ci,Rect2(18,350,324,252),Color(0.96,0.97,0.94,0.95),12)
	ci.text_at(Vector2(30,376),ci.t_("A1-G0")+" · 23",16,ci.INK,300)
	for i in range(8):
		if i < 3:
			var face: Texture2D = ci.texture(["ayu_avatar.png","axiao_avatar.png","toretto_avatar.png"][i])
			if face: ci.draw_texture_rect(face,Rect2(31+i*24,387,18,18),false)
		else:
			ci.draw_texture_rect(member_faces[i-3],Rect2(31+i*24,387,18,18),false)
	ci.text_at(Vector2(232,401),"群成员 23",12,ci.WOOD,100)
	if lines.is_empty(): return
	var index := mini(li,lines.size()-1)
	var row: Dictionary = lines[index]
	var who := str(row.get("who","system"))
	var text: String = ci.t_(str(row.say))
	var avatar: Texture2D = ci.texture(ci.AVATARS.get(who,"")) if who in ci.AVATARS else null
	if avatar: ci.draw_texture_rect(avatar,Rect2(30,430,36,36),false)
	Bubble._round_box(ci,Rect2(76,425,248,132),Color("#d7ecc6") if who == "ayu" else Color.WHITE,8)
	ci.draw_multiline_string(ci.FONT,Vector2(88,452),ci.StoryCaption._display_text(text,"ayu",220,int(reveal)),HORIZONTAL_ALIGNMENT_LEFT,220,16,-1,ci.INK)
	ci.text_at(Vector2(30,584),"轻点阅读下一条",12,ci.WOOD,300)
