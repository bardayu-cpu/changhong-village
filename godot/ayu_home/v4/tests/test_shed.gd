extends SceneTree
## 第六轮第 10 条：院子棚子一带，每个能站的地方人都看得见（脚底比棚子的前沿靠前，画在棚子前面）
const W=preload("res://ayu_home/v4/world.gd")
func _initialize() -> void:
	var w=W.new();w.load_room("exterior");var hid:=0;var n:=0
	var shed:Dictionary={}
	for p in w.cfg.props:
		if str(p.file).ends_with("exterior_shed.png"):shed=p
	var img:Image=load("res://ayu_home/v3/assets/exterior_shed.png").get_image() if ResourceLoader.exists("res://ayu_home/v3/assets/exterior_shed.png") else Image.load_from_file("res://ayu_home/v3/assets/exterior_shed.png")
	for y in range(560,700,4):
		for x in range(960,1200,4):
			var q:=Vector2(x,y)
			if not w.passable(q):continue
			n+=1
			# 人站在这里，脚底比棚子前沿靠后、身子落在棚子画着的地方，就会被盖住
			var lx:=int(x-shed.pos[0]);var ly:=int(y-20-shed.pos[1])
			if y<float(shed.foot) and lx>=0 and ly>=0 and lx<img.get_width() and ly<img.get_height() and img.get_pixel(lx,ly).a>0.2:hid+=1;print("会被盖住 ",q)
	print("RESULT ","PASS" if hid==0 else "FAIL"," 能站的点 %d 个，会被棚子盖住 %d 个"%[n,hid]);w.free();quit()
