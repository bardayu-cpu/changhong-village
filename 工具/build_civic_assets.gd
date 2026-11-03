extends SceneTree
func _initialize() -> void:
	var d:=ProjectSettings.globalize_path("res://../回执/第1轮/设计/")
	var output:=ProjectSettings.globalize_path("res://ayu_home/v4/assets/")
	for entry in [["村委会/村委会-专用整屋-source-v1.png","civic-v1.png"],["附属二楼/v_mayor_up-资料室专用底图-source-v2.png","civic-up-v2.png"]]:
		var room:=Image.load_from_file(d+entry[0]);room.resize(508,600,Image.INTERPOLATE_NEAREST);room.save_png(output+"institutions/"+entry[1])
	var actor:=Image.load_from_file(d+"村委会/林伯-老人形象84px.png");actor.save_png(output+"residents/linbo-v1.png")
	var source:=Image.load_from_file(d+"村委会/林伯-老人头像-source-v1.png");var face:=source.get_region(source.get_used_rect());var ratio:=minf(112.0/face.get_width(),129.0/face.get_height());face.resize(roundi(face.get_width()*ratio),roundi(face.get_height()*ratio),Image.INTERPOLATE_NEAREST);face.save_png(output+"talk-faces/linbo.png")
	print("CIVIC_ASSETS two dedicated 508x600 floors; 64x84 Linbo; portrait fit112x129")
	quit()
