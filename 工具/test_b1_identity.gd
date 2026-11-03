extends SceneTree
const Actor=preload("res://ayu_home/v4/actor.gd")
const Residents=preload("res://ayu_home/v4/core/residents.gd")
var failed:=false
func check(ok:bool,label:String) -> void:
	print(("PASS " if ok else "FAIL ")+label);failed=failed or not ok
func _initialize() -> void:
	for room in ["village","v_h3"]:
		var cfg:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/"+room+".json"))
		var found:=false
		for record in cfg.get("npcs",[cfg.get("npc",{})]):
			if record.get("name","")!="小涛":continue
			found=true;check(record.get("character_id","")=="xiaotao" and record.get("portrait","")=="xiaotao",room+" same explicit male identity and portrait")
		check(found,room+" contains 小涛")
	var actor:=Actor.new();actor.look_override=Residents.look("xiaotao");actor.setup("visitor")
	check(actor.sheet.get_size()==Vector2(576,84),"nine 64x84 frames")
	for direction in ["down","up","right","left"]:
		actor.face=direction;actor.walking=true
		for tick in 4:
			actor.elapsed=tick/8.0;actor.pose()
			check(actor.pose_texture.region.size==Vector2(64,84) and actor.sprite.scale==Vector2.ONE,"84px unchanged "+direction+" "+str(tick))
	check(actor.sprite.flip_h,"left mirrors right frame")
	var portrait:=Image.load_from_file("res://ayu_home/v4/assets/talk-faces/xiaotao.png")
	check(portrait.get_width()<=112 and portrait.get_height()<=129 and not portrait.is_empty(),"portrait fits existing dialogue frame")
	actor.free();print("B1_IDENTITY "+("FAIL" if failed else "PASS"));quit(1 if failed else 0)
