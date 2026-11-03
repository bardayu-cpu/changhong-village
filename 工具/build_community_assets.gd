extends SceneTree
func _initialize() -> void:
	var d:=ProjectSettings.globalize_path("res://../回执/第1轮/设计/村民活动中心/")
	var output:=ProjectSettings.globalize_path("res://ayu_home/v4/assets/")
	var room:=Image.load_from_file(d+"村民活动中心-共桌专用整屋-source-v1.png");room.resize(508,600,Image.INTERPOLATE_NEAREST);room.save_png(output+"institutions/community-v1.png")
	var actor:=Image.load_from_file(d+"方婆婆-值日形象84px.png");actor.save_png(output+"residents/fang-v1.png")
	var source:=Image.load_from_file(d+"方婆婆-值日头像-source-v1.png");var face:=source.get_region(source.get_used_rect());var ratio:=minf(112.0/face.get_width(),129.0/face.get_height());face.resize(roundi(face.get_width()*ratio),roundi(face.get_height()*ratio),Image.INTERPOLATE_NEAREST);face.save_png(output+"talk-faces/fang.png")
	print("COMMUNITY_ASSETS dedicated 508x600 public room; 64x84 Fang; portrait fit112x129")
	quit()
