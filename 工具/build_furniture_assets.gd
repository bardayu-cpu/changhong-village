extends SceneTree
func _initialize() -> void:
	var dir:=ProjectSettings.globalize_path("res://../回执/第1轮/设计/可制作家具/")
	var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(dir+"切片与脚锚-v1.json"))
	var source:=Image.load_from_file(dir+spec.source)
	var output:=ProjectSettings.globalize_path("res://ayu_home/v4/assets/craft/");DirAccess.make_dir_recursive_absolute(output)
	for entry in spec.items:
		var b:Array=entry.alpha_bbox_xyxy;var img:=source.get_region(Rect2i(b[0],b[1],b[2]-b[0],b[3]-b[1]))
		var size:Array=entry.suggested_canvas;var ratio:=minf(float(size[0])/img.get_width(),float(size[1])/img.get_height());img.resize(roundi(img.get_width()*ratio),roundi(img.get_height()*ratio),Image.INTERPOLATE_NEAREST)
		var canvas:=Image.create(size[0],size[1],false,Image.FORMAT_RGBA8);canvas.fill(Color.TRANSPARENT);canvas.blit_rect(img,Rect2i(Vector2i.ZERO,img.get_size()),Vector2i((size[0]-img.get_width())/2,size[1]-img.get_height()));canvas.save_png(output+str(entry.key)+".png")
	print("CRAFT_ASSETS 9 distinct transparent cutouts; uniform nearest fit, bottom foot anchors")
	quit()
