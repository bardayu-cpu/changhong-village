extends SceneTree
const State=preload("res://ayu_home/v4/core/state.gd")
const Interface=preload("res://ayu_home/v4/core/interface.gd")
class Host extends Node:
 var ui=Control.new()
 var player=Node2D.new()
 var area:="v_mayor"
 var cooldown:=0.0
 func _init():add_child(ui);add_child(player);player.position=Vector2(318,322)
 func close_modal():pass
var failures:Array=[]
var rows:Array=[]
var folder:String
func check(ok:bool,label:String):
 rows.append({"check":label,"pass":ok})
 if not ok:failures.append(label)
func _initialize():call_deferred("run")
func bind_ui(s):
 var h=Host.new();root.add_child(h)
 var ui=Interface.new();ui.home=h;ui.state=s;h.add_child(ui)
 return ui
func run():
 folder=ProjectSettings.globalize_path("res://../测试数据/玩法衔接-1017/")
 if DirAccess.make_dir_recursive_absolute(folder)!=OK:quit(1);return
 var path=folder+"links-"+str(Time.get_ticks_usec());var profile={"openid":"c2-links-only"}
 var s=State.new()
 if not s.open(profile,path):quit(1);return
 var ui=bind_ui(s);var initial=s.data.village.items.duplicate(true);var coins=s.data.wallet.coins;var relations=s.data.renqing.size()
 # Unified close callback during a normal civic session, without rewards.
 ui.open_institution_game("civic");await process_frame
 var game=ui.institution_game;game.begin();game.step(game.CIVIC_SEQUENCE[0])
 check(game.progress==1,"civic normal first step")
 ui.close();await process_frame
 check(not ui.opened and ui.home.ui.visible and ui.institution_game==null,"Interface.close restores room HUD")
 check(s.data.village.active_institution.is_empty() and s.data.village.items==initial and s.data.wallet.coins==coins and s.data.renqing.size()==relations,"close clears run without material or relationship reward")
 # Complete using the real three category inputs, collect, return, checkpoint, reopen.
 ui.open_institution_game("civic");await process_frame
 game=ui.institution_game;game.begin()
 for category in game.CIVIC_SEQUENCE:game.step(category)
 check(game.progress==3 and game.collect_button.visible,"normal civic steps unlock collect")
 game.collect();var run_id=game.run_id
 check(game.finished and s.count("bamboo")==int(initial.get("bamboo",0))+1,"normal collection adds exactly one bamboo")
 ui.close();await process_frame;ui.checkpoint()
 check(ui.home.ui.visible and not ui.opened and s.data.village.last_area=="v_mayor" and s.data.village.last_position==[318.0,322.0],"return then real Interface.checkpoint stores room and position")
 var loaded=State.new();check(loaded.open(profile,path),"reopen isolated completed save")
 check(loaded.count("bamboo")==s.count("bamboo") and loaded.data.village.last_area=="v_mayor" and loaded.data.village.last_position==[318.0,322.0],"reward and checkpoint survive reopen")
 check(not loaded.act("institution_complete",{"run":run_id}).ok and loaded.count("bamboo")==s.count("bamboo"),"old completed run cannot pay again")
 ui.home.queue_free();await process_frame
 # Persist a partial honey run via normal actions, discard UI, then reopen save.
 ui=bind_ui(loaded);ui.home.area="v_h5";ui.open_institution_game("honey");await process_frame
 game=ui.institution_game;game.begin();game.step(game.HONEY_SEQUENCE[0]);var old_run=game.run_id
 check(game.progress==1,"normal partial honey session persisted")
 var before=loaded.data.village.items.duplicate(true)
 ui.home.queue_free();await process_frame
 var resumed=State.new();check(resumed.open(profile,path) and int(resumed.data.village.active_institution.progress)==1,"partial state survives UI destruction and isolated reopen")
 ui=bind_ui(resumed);ui.home.area="v_h5";ui.open_institution_game("honey");await process_frame
 game=ui.institution_game;game.begin()
 check(not game.run_id.is_empty() and game.run_id!=old_run and game.progress==0,"normal begin replaces stale partial run and starts fresh")
 game.step(game.HONEY_SEQUENCE[0]);ui.close();await process_frame
 check(resumed.data.village.active_institution.is_empty() and resumed.data.village.items==before and ui.home.ui.visible,"reopened normal step then close leaves no reward or blocked run")
 ui.home.queue_free();await process_frame
 var f=FileAccess.open(folder+"result.json",FileAccess.WRITE)
 if f==null:quit(1);return
 f.store_string(JSON.stringify({"rows":rows,"failures":failures},"  "));f.close()
 print("INSTITUTION_LINKS checks=",rows.size()," failures=",failures.size());print(JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
