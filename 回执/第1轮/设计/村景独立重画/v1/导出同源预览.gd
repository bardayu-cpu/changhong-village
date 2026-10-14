extends SceneTree
const ROOT="/Users/kayra_ayu/Desktop/苏七镇奇缘/cursor-claude-1010/裳泓村/回执/第1轮/设计/村景独立重画/v1/"
func _initialize():
	var master=Image.load_from_file(ROOT+"盛夏村落-独立新画总图-v1.png")
	if master == null or master.get_size() != Vector2i(1536,1024):
		push_error("Unexpected master image size")
		quit(1)
		return
	var parcel=master.get_region(Rect2i(0,380,960,520))
	parcel.resize(1920,1040,Image.INTERPOLATE_NEAREST)
	var result=parcel.save_png(ROOT+"阿鱼地块-同源近看预览-v1.png")
	print("Same-master parcel viewport export: ",result)
	quit(0 if result == OK else 1)
