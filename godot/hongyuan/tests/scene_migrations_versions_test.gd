extends SceneTree
const Migration = preload("res://hongyuan/scene_migrations.gd")
const Runner = preload("res://hongyuan/scene_runner.gd")
var failures := 0
var baseline: Dictionary
var copy: Dictionary
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func shot(chapter: String) -> Dictionary:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/chapters/"+chapter+".json"))
	var value: Dictionary=data.steps[0].duplicate(true)
	value.fullId=chapter+"/"+str(value.id);value.chapterId=chapter;return value
func checkpoint(beats: Array,index: int,game: Dictionary={}) -> Dictionary:
	return JSON.parse_string(JSON.stringify({"sceneSig":str(JSON.stringify(beats).hash()),"sceneBeat":index,"materials":{"pen":"applied","paper":"applied"},"sceneMaterials":{"stamp":true},"guest":{"name":"旧朋友","look":"06"},"sceneSnapshot":{"beat":index,"mode":"game","game":game,"result":{"name":"旧朋友","look":"06"},"feet":[122,440]}}))
func restore(value: Dictionary,state: Dictionary):
	var r:=Runner.new();r.setup(value.scene,copy,{});root.add_child(r);r.set_process(false);r.begin(int(state.sceneBeat));r.restore(state.sceneSnapshot);return r
func run() -> void:
	baseline=JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/scene_migrations.json"))
	copy=JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/copy.json"))
	for chapter in ["call","shizuoka","hongkong"]:
		var value:=shot(chapter)
		var versions: Array=[baseline[value.fullId]]
		for archive: Dictionary in baseline._versions[value.fullId]:versions.append(archive.beats)
		for v in range(versions.size()):
			var beats: Array=versions[v]
			for i in range(beats.size()):
				if not beats[i].has("game"):continue
				var name: String=beats[i].game
				var state:=checkpoint(beats,i,{"phase":"reply" if name=="call" else "show" if name=="photo" else "letter" if name=="offer" else "wait","li":5,"reveal":3.0,"t":0.3,"ayu_x":168,"toretto_x":224,"scroll":36})
				check(Migration.migrate(state,value),chapter+" version "+str(v)+" maps "+name)
				check(value.scene.beats[int(state.sceneBeat)].get("game","")==name,"snapshot cannot land in another game: "+name)
				check(state.guest.name=="旧朋友" and state.materials.paper=="applied" and state.sceneMaterials.stamp,"migration keeps identity and collected tokens")
				if name in ["call","offer","photo"]:
					state=JSON.parse_string(JSON.stringify(state))
					var r=restore(value,state)
					if name=="call":check(r.game.li==5 and r.game.phase=="reply","call current original sentence survives JSON/runner restore")
					if name=="offer":check(r.game.phase=="letter" and r.game.scroll==minf(36,r.game.max_scroll) and r.game._built,"offer letter progress survives JSON/runner restore")
					if name=="photo":check(r.game.phase=="prep" and r.game.toretto_x==224,"photo restores same photo with both people; texture recaptures")
					r.free()
		for i in range(versions[1].size()):
			var all_state:=checkpoint(versions[1],i,{"phase":"old-sentinel"})
			if not versions[1][i].has("game"):all_state.sceneSnapshot.erase("game");all_state.sceneSnapshot.mode="say"
			check(Migration.migrate(all_state,value),"042c367 all beats have a safe semantic destination "+chapter+"/"+str(i))
			if all_state.sceneSnapshot.has("game"):
				check(versions[1][i].has("game") and value.scene.beats[int(all_state.sceneBeat)].get("game","")==versions[1][i].get("game",""),"game state retained only for same game "+chapter+"/"+str(i))
		var unknown:=checkpoint(versions[1],5);unknown.sceneSig="unrecognized-script-signature"
		var before:=JSON.stringify(unknown)
		check(not Migration.migrate(unknown,value) and before==JSON.stringify(unknown),"unknown "+chapter+" signature safely refuses without erasing data")
	var call:=shot("call");var old_call: Array=baseline._versions[call.fullId][0].beats
	var state:=checkpoint(old_call,21,{"phase":"done"})
	check(Migration.migrate(state,call) and call.scene.beats[int(state.sceneBeat)].has("goal") and not state.sceneSnapshot.has("game"),"late old call returns before newly required care/balance, no foreign game state")
	var shizuoka:=shot("shizuoka");var old_shizuoka: Array=baseline._versions[shizuoka.fullId][0].beats
	for i in [17,18,19]:
		state=checkpoint(old_shizuoka,i,{"phase":"done"})
		check(Migration.migrate(state,shizuoka) and shizuoka.scene.beats[int(state.sceneBeat)].get("game","")=="registration" and not state.sceneSnapshot.has("game"),"old registry memory/reward requires new registration "+str(i))
	var hk:=shot("hongkong");var old_hk: Array=baseline._versions[hk.fullId][0].beats
	for i in [12,14]:
		state=checkpoint(old_hk,i,{"phase":"show"})
		check(Migration.migrate(state,hk) and int(state.sceneBeat)==Migration._find_key(hk.scene.beats,"game:photo")+1 and not state.sceneSnapshot.has("game"),"old HK reward/exit starts new Disney memories "+str(i))
	state=checkpoint(old_hk,8,{})
	check(Migration.migrate(state,hk) and hk.scene.beats[int(state.sceneBeat)].get("go","")=="security","old airport exit starts added security interaction")
	state=checkpoint(old_shizuoka,9,{})
	check(Migration.migrate(state,shizuoka) and shizuoka.scene.beats[int(state.sceneBeat)].get("go","")=="gangway_foot","old seat starts added boarding approach")
	var finale:=shot("finale")
	state={"sceneBeat":2,"guest":{"name":"旧朋友","look":"06"},"materials":{"pen":"applied"},"sceneSnapshot":{"beat":2,"mode":"game","game":{"phase":"look","name":"旧朋友","look":5}}}
	check(Migration.migrate(state,finale) and state.sceneSnapshot.game.name=="旧朋友" and state.materials.pen=="applied","pre-signature finale retains name and token compatibility")
	print("FAILURES ",failures);quit(failures)
