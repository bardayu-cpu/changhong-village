extends SceneTree
const Game=preload("res://ayu_home/v4/core/institution_game.gd")
const Assets=preload("res://ayu_home/v2/assets.gd")
var failures:Array[String]=[]
func require(ok:bool,label:String) -> void:
	if not ok:failures.append(label)
func rect(values:Array) -> Rect2:
	return Rect2(values[0],values[1],values[2],values[3])
func near_rect(a:Rect2,b:Rect2) -> bool:
	return a.position.distance_to(b.position)<0.001 and a.size.distance_to(b.size)<0.001
func packed(r:Rect2) -> Array:
	return [r.position.x,r.position.y,r.size.x,r.size.y]
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var args:=OS.get_cmdline_user_args()
	var approved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var owner:=Game.new();owner.game_id="honey"
	var board:=Game.HoneyBoard.new();board.game=owner;board.size=Vector2(492,380)
	root.add_child(board);await process_frame
	require(board.jar_art.material is ShaderMaterial,"jar material present")
	require(board.material==null,"alpha test not on board")
	require(board.jar_art.mouse_filter==Control.MOUSE_FILTER_IGNORE,"jar does not intercept clicks")
	require(board.jar_art.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"nearest filtering")
	require(board.cells.size()==6,"six original buttons")
	for b in board.cells:
		require(b.material==null,"buttons retain original material")
		require(b.disabled,"before begin buttons disabled")
	var texture:=Assets.texture(Game.HoneyJar.TEXTURE_PATH)
	require(texture!=null and texture.get_size()==Vector2(1536,1024),"source atlas loaded at original size")
	var results:Array=[]
	for state in approved.states:
		owner.progress=int(state.progress);owner.finished=bool(state.finished);owner.run_id="isolated-art-widget"
		board.refresh()
		require(board.jar_art.progress==owner.progress and board.jar_art.sealed==owner.finished,"refresh passes visual state")
		require(board.jar_art.position==Vector2(204,280),"existing jar placement")
		var actual:=Game.HoneyJar.layers_for_state(owner.progress,owner.finished)
		var names:Array=[];var layer_report:Array=[]
		for layer in actual:
			names.append(layer.kind)
			var expected:Dictionary
			match str(layer.kind):
				"frame":expected=approved.layers[0]
				"honey":expected=approved.layers[1]
				_:expected=approved.layers[2]
			var er:=rect(expected.destination);var es:=rect(expected.source)
			if layer.kind=="honey":
				var ratio:float=owner.progress/6.0
				er.position.y+=er.size.y*(1.0-ratio);er.size.y*=ratio
				es.position.y+=es.size.y*(1.0-ratio);es.size.y*=ratio
			require(near_rect(layer.target,er) and near_rect(layer.source,es),"matches independently reviewed preview "+str(layer.kind))
			require(Rect2(0,0,1536,1024).encloses(layer.source),"atlas region inside source")
			require(absf(layer.target.size.x/layer.source.size.x-layer.target.size.y/layer.source.size.y)<0.00001,"uniform source scale")
			layer_report.append({"kind":layer.kind,"source":packed(layer.source),"target":packed(layer.target)})
		require(names.has("honey")==(owner.progress>0),"empty versus filled")
		require(names.has("seal")==(owner.progress==6 and owner.finished),"seal only after successful collection state")
		results.append({"progress":owner.progress,"finished":owner.finished,"layers":layer_report})
	var previous_height:=0.0
	for step in range(1,7):
		var fill:Dictionary=Game.HoneyJar.layers_for_state(step,false)[0]
		require(fill.target.size.y>previous_height,"six steps increase fill")
		require(absf(fill.target.end.y-68.0)<0.001,"honey bottom anchor fixed")
		previous_height=fill.target.size.y
	var result:Dictionary={"passed":failures.is_empty(),"failures":failures,"four_state_layout_cases":results,"six_step_fill_anchor_check":true,"scope":"Headless component and resource checks only; no GUI input, save file, or full regression. Godot visual confirmation belongs to C3."}
	var f:=FileAccess.open(args[0],FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ")+"\n");f.close()
	board.free();owner.free();Assets.textures.clear();await process_frame
	print("HONEY_ART_COMPONENT ", "PASS" if failures.is_empty() else "FAIL", " states=4 ",failures)
	quit(0 if failures.is_empty() else 1)
