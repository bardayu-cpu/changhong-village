extends SceneTree
const State=preload("res://ayu_home/v4/core/state.gd")
const Interface=preload("res://ayu_home/v4/core/interface.gd")
const C=preload("res://ayu_home/v4/core/config.gd")
class Player extends RefCounted:
 var face:=""
 var spoken:=""
 func say(text:String):spoken=text
class Host extends RefCounted:
 var player=Player.new()
 var note:=""
var failures:Array=[]
var rows:Array=[]
func _initialize():call_deferred("run")
func verify(ok:bool,label:String):
 if not ok:failures.append(label)
func run():
 var folder=ProjectSettings.globalize_path("res://../测试数据/村路连通-1017/")
 if DirAccess.make_dir_recursive_absolute(folder)!=OK:
  push_error("Cannot create isolated test directory");quit(1);return
 var s=State.new()
 if not s.open({"openid":"c2-notice-only"},folder+"notice-"+str(Time.get_ticks_usec())):
  push_error("Cannot open isolated test save");quit(1);return
 var ui=Interface.new();var host=Host.new();ui.home=host;ui.state=s
 var cfg:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/village.json"))
 var items=s.data.village.items.duplicate(true);var coins=s.data.wallet.coins
 var count_before=s.data.renqing.size()
 for spot in cfg.hotspots:
  if spot.get("kind","")!="door_chore":continue
  var chore:Dictionary=C.DOOR_CHORES[spot.house]
  for attempt in [0,1]:
   var before=s.data.renqing.size();verify(ui.interact(spot),"handled "+spot.id)
   var expected:String=chore.response if attempt==0 else chore.owner+"记着你的帮助。"+chore.closed+"，明天再来走走。"
   var ok=host.note=="今日不便拜访，下次再来。\n"+expected and host.player.spoken==host.note and s.data.renqing.size()==before+(1 if attempt==0 else 0)
   verify(ok,str(spot.id)+" "+str(attempt));rows.append({"house":spot.house,"attempt":attempt+1,"pass":ok,"display":host.note})
 verify(rows.size()==28,"28 normal branches")
 verify(s.data.renqing.size()==count_before+14 and s.data.wallet.coins==coins and s.data.village.items==items,"only original 14 relationships")
 for door in cfg.doors:
  host.note="untouched";host.player.spoken="untouched"
  verify(not ui.interact(door) and host.note=="untouched" and host.player.spoken=="untouched","open door unaffected "+door.id)
 verify(cfg.doors.size()==6,"six open doors")
 var f=FileAccess.open(folder+"notice-result.json",FileAccess.WRITE)
 if f==null:
  push_error("Cannot write test report");ui.free();quit(1);return
 f.store_string(JSON.stringify({"rows":rows,"failures":failures,"doors":cfg.doors.size()},"  "));f.close()
 print("DOOR_NOTICE 28 branches, 6 doors, failures=",failures.size());print(JSON.stringify(failures));ui.free();quit(0 if failures.is_empty() else 1)
