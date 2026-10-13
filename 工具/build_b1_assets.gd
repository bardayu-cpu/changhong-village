extends SceneTree
## 将已生成的透明九帧源稿规范化为引擎图集：仅裁格、同倍率 nearest 缩放、脚线对齐。
func _initialize() -> void:
	var source:=ProjectSettings.globalize_path("res://../回执/第1轮/设计/小涛磨坊/")
	var out:=ProjectSettings.globalize_path("res://ayu_home/v4/assets/residents/")
	DirAccess.make_dir_recursive_absolute(out)
	var src:=Image.load_from_file(source+"小涛-男性九帧-source-v1.png")
	var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source+"九帧源图测量-v1.json"))
	var strip:=Image.create(576,84,false,Image.FORMAT_RGBA8);strip.fill(Color.TRANSPARENT)
	var scale_factor:=84.0/384.0
	for frame in spec.frames:
		var cell:Array=frame.cell_xywh;var box:Array=frame.local_alpha_bbox_128
		var crop:=src.get_region(Rect2i(cell[0]+box[0],cell[1]+box[1],box[2]-box[0],box[3]-box[1]))
		crop.resize(roundi(crop.get_width()*scale_factor),roundi(crop.get_height()*scale_factor),Image.INTERPOLATE_NEAREST)
		strip.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(int(frame.index)*64+32-crop.get_width()/2,84-crop.get_height()))
	strip.save_png(out+"xiaotao-v1.png")
	var portrait:=Image.load_from_file(source+"小涛-男性头像-source-v1.png")
	portrait=portrait.get_region(portrait.get_used_rect())
	var portrait_scale:=minf(112.0/portrait.get_width(),129.0/portrait.get_height())
	portrait.resize(roundi(portrait.get_width()*portrait_scale),roundi(portrait.get_height()*portrait_scale),Image.INTERPOLATE_NEAREST)
	portrait.save_png(ProjectSettings.globalize_path("res://ayu_home/v4/assets/talk-faces/xiaotao.png"))
	print("B1_ASSETS normalized 576x84; each frame shares scale ",scale_factor," and foot y84; portrait ",portrait.get_size())
	quit()
