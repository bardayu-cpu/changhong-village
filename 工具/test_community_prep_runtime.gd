extends SceneTree
## A03 focused component/transaction check; GUI acceptance remains independent.
const Game=preload("res://ayu_home/v4/core/institution_game.gd")
const State=preload("res://ayu_home/v4/core/state.gd")
class Owner extends RefCounted:
	var state
var failed:=false
var checks:=0
func check(ok:bool,label:String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label);failed=failed or not ok
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var folder:=ProjectSettings.globalize_path("res://../测试数据/A03预览-1017/runtime/")
	DirAccess.make_dir_recursive_absolute(folder)
	var owner:=Owner.new();owner.state=State.new()
	check(owner.state.open({"openid":"c2-a03-component"},folder+str(Time.get_ticks_usec())),"isolated state opens")
	owner.state.put("radish",2);owner.state.put("pepper",2)
	var meal_before:int=owner.state.count("meal")
	var game:=Game.new();root.add_child(game);game.setup(owner,"community")
	await process_frame
	var sprite=game.board.ingredients
	var params:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../回执/第1轮返工/A03接入-1017/唯一修正预览参数.json"))
	for stage in 3:
		var i:=0
		for item in params.stages[stage].items:
			for part in item.parts:
				var s:Array=part.source;var t:Array=part.target
				check(sprite.STAGES[stage][i][0]==Rect2(s[0],s[1],s[2],s[3]) and sprite.STAGES[stage][i][1]==Rect2(t[0],t[1],t[2],t[3]),"reviewed rectangle "+str(stage)+":"+str(i));i+=1
	check(Game.Assets.texture(sprite.TEXTURE_PATH).get_size()==Vector2(1859,846),"original atlas decodes at expected size")
	check(sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST and sprite.material!=null,"local nearest and alpha material")
	game.begin();check(not game.run_id.is_empty(),"normal begin accepted")
	for step in 3:
		check(game.progress==step and sprite.visible and not game.board.steps[step].disabled,"stage and active button "+str(step))
		game.step(step);await process_frame
	check(game.progress==3 and not sprite.visible and game.collect_button.visible,"completed meal replaces preparation sprites")
	game.collect()
	check(game.finished and owner.state.count("radish")==1 and owner.state.count("pepper")==1 and owner.state.count("meal")==meal_before+1,"collect consumes one of each and grants one meal")
	game.collect();check(owner.state.count("meal")==meal_before+1,"repeat collect grants nothing")
	game.queue_free();await process_frame
	print("A03_COMPONENT "+("FAIL" if failed else "PASS")+" "+str(checks));quit(1 if failed else 0)
