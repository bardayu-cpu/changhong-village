extends SceneTree
const Actor=preload("res://ayu_home/v4/actor.gd")
const Residents=preload("res://ayu_home/v4/core/residents.gd")
func _initialize() -> void:
	var source:=ProjectSettings.globalize_path("res://../回执/第1轮/设计/小涛磨坊/小涛磨坊-整屋底图-source-v1.png")
	var background:=Image.load_from_file(source);background.convert(Image.FORMAT_RGBA8);background.resize(508,600,Image.INTERPOLATE_NEAREST)
	var out:=ProjectSettings.globalize_path("res://ayu_home/v4/assets/institutions/");DirAccess.make_dir_recursive_absolute(out)
	background.save_png(out+"mill-v1.png")
	var preview:Image=background.duplicate()
	for record in [{"identity":"xiaotao","at":Vector2i(106,280)},{"identity":"","at":Vector2i(254,480)}]:
		var actor:=Actor.new();actor.preset=2;actor.look_override=Residents.look(record.identity);actor.setup("visitor");actor.face="down";actor.pose()
		var frame:=actor.pose_texture.get_image();frame.resize(roundi(frame.get_width()*actor.sprite.scale.x),roundi(frame.get_height()*actor.sprite.scale.y),Image.INTERPOLATE_NEAREST)
		preview.blend_rect(frame,Rect2i(Vector2i.ZERO,frame.get_size()),record.at+Vector2i(actor.sprite.position))
		actor.free()
	var evidence:=ProjectSettings.globalize_path("res://../回执/第1轮/制作预检/");DirAccess.make_dir_recursive_absolute(evidence)
	preview.save_png(evidence+"小涛磨坊-84px人物比例预检.png")
	print("MILL_LAYOUT_PREVIEW 508x600 background, original visitor and male 小涛 both 84px contract; static composition, not playtest evidence")
	quit()
