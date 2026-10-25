extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var h
var out:=""
var rows:Array=[]
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 root.set_meta("player_profile",{"id":"c3-label-road-final","openid":"c3-label-road-final","avatar":2,"nick":"C3 final narrow"})
 call_deferred("run")
func snap(name:String):
 for i in 8:await process_frame
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 var row:Dictionary={"name":name,"area":h.area,"hour":h.hour,"month":h.month,"scale":h.view_scale,"pos":[h.player.position.x,h.player.position.y],"fps":Engine.get_frames_per_second(),"bodies":[],"tags":[],"overlaps":[]}
 var actors:Array=[h.player]+h.people.values()
 var native=h.village_ui.institution_room
 if is_instance_valid(native) and is_instance_valid(native.actor):actors.append(native.actor)
 for a in actors:
  if not a.is_visible_in_tree():continue
  var rect:Rect2=a.get_global_transform_with_canvas()*a.visual_rect()
  row.bodies.append({"id":a.id,"action":a.action,"lift":a.lift,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
  for child in a.get_children():
   if child is Label and child!=a.bubble and child.is_visible_in_tree():
    var tag:Rect2=child.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,child.size)
    row.tags.append({"text":child.text,"rect":[tag.position.x,tag.position.y,tag.size.x,tag.size.y]})
    if tag.intersects(rect):row.overlaps.append(child.text)
 FileAccess.open(out+"/"+name+".json",FileAccess.WRITE).store_string(JSON.stringify(row,"  "))
 rows.append(row)
func run():
 root.size=Vector2i(540,960);Engine.max_fps=30;root.title="C3 road shoulder and label final review"
 h=Home.new();root.add_child(h)
 var until=Time.get_ticks_msec()+30000
 while not h.bootstrapped and Time.get_ticks_msec()<until:await process_frame
 if not h.bootstrapped:quit(1);return
 h.close_modal();h.set_test_clock(13,7,"clear")
 h.village_ui.state.now_override=Time.get_unix_time_from_datetime_string("2027-07-15T13:00:00")-int(Time.get_time_zone_from_system().bias)*60
 await h.enter_room("village",false)
 for pt in [{"name":"road-complaint-13","p":Vector2(3544,1960)},{"name":"road-south-13","p":Vector2(600,4100)}]:
  h.player.position=h.world.nearest(pt.p);h.camera=h.room_camera_target();h.layout();await snap(pt.name)
 await h.enter_room("living",false);h.player.position=h.world.nearest(Vector2(385,338));h.camera=h.room_camera_target();h.layout();await snap("Ayu-13")
 for hour in [13,19]:
  h.set_test_clock(hour,10,"clear");await h.enter_room("v_h6",false)
  var n=h.village_ui.institution_room;n.set_process(false);n.greet_after=1e9
  n.actor.freeze=true;n.actor.bubble_allowed=false
  h.player.position=h.world.nearest(n.actor.position-Vector2(0,n.actor.lift)+Vector2(65,60));h.camera=h.room_camera_target();h.layout()
  await snap("h6-native-"+str(hour))
 FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"OS_input":false,"scope":"C2 UI and C4 road material independent integration review; existing road geometry authored by C3 remains author self-test, geometry not rerun","full_village_pass":false},"  "))
 print("C3_FINAL_NARROW_DONE")
 h.queue_free();await process_frame;quit(0)
