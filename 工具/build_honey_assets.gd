extends SceneTree
func _initialize() -> void:
	var d:=ProjectSettings.globalize_path("res://../回执/第1轮/设计/凯凯蜂蜜小院/")
	var root_path:=ProjectSettings.globalize_path("res://ayu_home/v4/assets/")
	var room:=Image.load_from_file(d+"凯凯蜂蜜小院-专用整屋-source-v1.png");room.resize(508,600,Image.INTERPOLATE_NEAREST);room.save_png(root_path+"institutions/honey-v1.png")
	var sprite:=Image.load_from_file(d+"凯凯-现有形象84px.png");sprite.save_png(root_path+"residents/kaikai-v1.png")
	var source:=Image.load_from_file(d+"凯凯-现有身份头像-source-v1.png");var face:=source.get_region(source.get_used_rect());var ratio:=minf(112.0/face.get_width(),129.0/face.get_height());face.resize(roundi(face.get_width()*ratio),roundi(face.get_height()*ratio),Image.INTERPOLATE_NEAREST);face.save_png(root_path+"talk-faces/kaikai.png")
	print("HONEY_ASSETS room 508x600; original 16-frame 64x84 identity; portrait fitted to 112x129")
	quit()
