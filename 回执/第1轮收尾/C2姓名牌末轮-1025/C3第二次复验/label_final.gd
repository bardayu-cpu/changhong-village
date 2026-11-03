extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var h
var out:=""
var events:Array=[]
var snapshots:Array=[]
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 root.set_meta("player_profile",{"id":"c3-label-second","openid":"c3-label-second","avatar":2,"nick":"C3 label second"})
 call_deferred("run")
func input_event(e):
 if e is InputEventMouseButton:events.append({"type":"mouse","pressed":e.pressed,"button":e.button_index,"pos":[e.position.x,e.position.y],"frame":Engine.get_process_frames()})
 if e is InputEventKey and e.pressed and not e.echo:
  if e.keycode==KEY_F10:root.set_input_as_handled();snap("actual-click-result")
  if e.keycode==KEY_F9:root.set_input_as_handled();FileAccess.open(out+"/events.json",FileAccess.WRITE).store_string(JSON.stringify(events,"  "));quit()
func rectdata(r:Rect2):return [r.position.x,r.position.y,r.size.x,r.size.y]
func snap(name:String):
 for i in 10:await process_frame
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 var acts:Array=[h.player]+h.people.values()
 for sr in h.village_ui.street_actors:
  if not sr.actor in acts:acts.append(sr.actor)
 var bodies:Array=[];var tags:Array=[];var clashes:Array=[];var markers:Array=[]
 for a in acts:
  if a.is_visible_in_tree():
   var b:Rect2=a.get_global_transform_with_canvas()*a.visual_rect()
   bodies.append({"id":a.id,"action":a.action,"lift":a.lift,"rect":rectdata(b)})
   if is_instance_valid(a.nameplate) and a.nameplate.is_visible_in_tree():
    var t:Rect2=a.nameplate.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,a.nameplate.size)
    tags.append({"text":a.nameplate.text,"rect":rectdata(t),"mouse_filter":a.nameplate.mouse_filter})
 for t in tags:
  for b in bodies:
   if Rect2(t.rect[0],t.rect[1],t.rect[2],t.rect[3]).intersects(Rect2(b.rect[0],b.rect[1],b.rect[2],b.rect[3])):clashes.append(t.text+" / body")
 for m in h.marker_nodes:
  if not m.button.is_visible_in_tree():continue
  var rr:Rect2=m.button.get_global_rect();markers.append({"id":m.hot.id,"rect":rectdata(rr)})
  for b in bodies:
   if rr.intersects(Rect2(b.rect[0],b.rect[1],b.rect[2],b.rect[3])):clashes.append(str(m.hot.id)+" / body")
 var row={"name":name,"area":h.area,"hour":h.hour,"month":h.month,"scale":h.view_scale,"player":[h.player.position.x,h.player.position.y],"bodies":bodies,"tags":tags,"markers":markers,"clashes":clashes,"page_visible":h.village_ui.opened,"talk_visible":is_instance_valid(h.talk_ui),"events":events}
 FileAccess.open(out+"/"+name+".json",FileAccess.WRITE).store_string(JSON.stringify(row,"  "));snapshots.append(row)
 FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"OS_input":events.size()>0,"mode":"h6 native initial schedule; market actual four-leg street cycle accelerated time; no route/action forced","snapshots":snapshots},"  "))
func run():
 root.size=Vector2i(540,960);Engine.max_fps=30;root.title="C3 second seated label candidate"
 h=Home.new();root.add_child(h)
 var until=Time.get_ticks_msec()+30000
 while not h.bootstrapped and Time.get_ticks_msec()<until:await process_frame
 if not h.bootstrapped:quit(1);return
 var observer=Observer.new();observer.controller=self;root.add_child(observer)
 h.close_modal()
 for hour in [13,19]:
  h.set_test_clock(hour,10,"clear");await h.enter_room("v_h6",false)
  var n=h.village_ui.institution_room;n.set_process(false);n.greet_after=1e9;n.actor.freeze=true;n.actor.bubble_allowed=false
  h.player.position=h.world.nearest(n.actor.position-Vector2(0,n.actor.lift)+Vector2(65,60));h.camera=h.room_camera_target();h.layout()
  await snap("h6-native-"+str(hour))
 h.set_test_clock(13,10,"clear")
 h.village_ui.state.now_override=Time.get_unix_time_from_datetime_string("2026-10-25T13:00:00")-int(Time.get_time_zone_from_system().bias)*60
 await h.enter_room("village",false)
 var row:Dictionary={}
 for sr in h.village_ui.street_actors:
  if sr.id=="market":row=sr;break
 if row.is_empty():print("MARKET_MISSING");quit(2);return
 var actor=row.actor;var overlay=h.village_ui.overlay;overlay.set_process(false)
 for leg in 4:
  overlay.street_time=float(row.next)+.01;overlay._process(1.0/30)
  var ticks:=0
  while not actor.route.is_empty() and ticks<300:overlay._process(1.0/30);await process_frame;ticks+=1
 actor.freeze=true
 var hot:Dictionary=h.world.spot("market")
 h.player.position=h.world.nearest(Vector2(hot.approach[0],hot.approach[1]))
 h.camera=h.room_camera_target();h.layout()
 await snap("market-natural-seat-13")
 print("LABEL_SECOND_READY action=",actor.action," player=",h.player.position)
 root.close_requested.connect(func():quit())
class Observer extends Node:
 var controller
 func _input(e):controller.input_event(e)
