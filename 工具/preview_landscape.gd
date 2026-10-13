extends SceneTree
## Static source composition for artwork inspection; not a running-game screenshot.
func _initialize() -> void:
	var root_dir:=ProjectSettings.globalize_path("res://").path_join("..")
	var cfg:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/village.json"))
	var base:=Image.load_from_file(cfg.background);base.convert(Image.FORMAT_RGBA8)
	var ordered:Array=cfg.props.duplicate();ordered.sort_custom(func(a,b):return (0 if a.get("ground",false) else 1)<(0 if b.get("ground",false) else 1) if a.get("ground",false)!=b.get("ground",false) else float(a.foot)<float(b.foot))
	for p in ordered:
		var path:String=p.file if str(p.file).begins_with("res://") else str(cfg.asset_root)+str(p.file)
		var sprite:=Image.load_from_file(path);sprite.convert(Image.FORMAT_RGBA8)
		if p.has("atlas_region"):
			var r:Array=p.atlas_region;sprite=sprite.get_region(Rect2i(r[0],r[1],r[2],r[3]))
		if p.has("scale"):sprite.resize(roundi(sprite.get_width()*p.scale[0]),roundi(sprite.get_height()*p.scale[1]),Image.INTERPOLATE_NEAREST)
		base.blend_rect(sprite,Rect2i(Vector2i.ZERO,sprite.get_size()),Vector2i(p.pos[0],p.pos[1]))
	var out:=root_dir.path_join("回执/第1轮")
	base.get_region(Rect2i(2870,850,890,860)).save_png(out.path_join("村外追加-东田局部素材合成.png"))
	base.resize(1200,1175,Image.INTERPOLATE_NEAREST);base.save_png(out.path_join("村外追加-全村素材合成.png"));print("STATIC PREVIEW: composition only, not C3 gameplay evidence");quit()
