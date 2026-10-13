extends SceneTree
## 只做已审核原图的裁切、等比 nearest 缩放和坐标规范化，不重画素材。
func _initialize() -> void:
	var design:=ProjectSettings.globalize_path("res://../回执/第1轮/设计/")
	var out:=ProjectSettings.globalize_path("res://ayu_home/v4/assets/institutions/")
	DirAccess.make_dir_recursive_absolute(out)
	var base:=Image.load_from_file(out+"mill-v1.png");base.convert(Image.FORMAT_RGBA8)
	var clean:=Image.load_from_file(design+"小涛磨坊/小涛磨坊-无杆无谷流-source-v2.png");clean.convert(Image.FORMAT_RGBA8);clean.resize(508,600,Image.INTERPOLATE_NEAREST)
	var region:=Rect2i(188,68,155,180);base.blit_rect(clean,region,region.position);base.save_png(out+"mill-v2.png")
	var source:=Image.load_from_file(design+"小涛磨坊/独立透明磨杆-source-v1.png")
	var rod:=source.get_region(Rect2i(261,226,1061,689));rod.convert(Image.FORMAT_RGBA8);rod.resize(70,45,Image.INTERPOLATE_NEAREST)
	var canvas:=Image.create(70,48,false,Image.FORMAT_RGBA8);canvas.blit_rect(rod,Rect2i(0,0,70,45),Vector2i.ZERO);canvas.save_png(out+"mill-rod-v1.png")
	var upstairs:=Image.load_from_file(design+"附属二楼/v_h3_up-休息储物专用底图-source-v2.png");upstairs.resize(508,600,Image.INTERPOLATE_NEAREST);upstairs.save_png(out+"mill-up-v2.png")
	print("MILL_ASSETS: mill-v2 508x600 clean local patch; alpha rod 70x48, pivot (6,17); dedicated upstairs 508x600")
	quit()
