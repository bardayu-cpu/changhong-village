extends SceneTree
const Ground=preload("res://ayu_home/v4/core/village_ground.gd")
var out:=""
var surfaces:Array=[]
var bins:Dictionary={}
var rows:Array=[]
var reports:Array=[]
const FOOT:=3.0
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 call_deferred("run")
func check(ok:bool,name:String,info:Dictionary={}):rows.append({"pass":ok,"check":name,"details":info})
func rect_poly(r:Rect2) -> PackedVector2Array:return PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
func area(p:PackedVector2Array) -> float:
 var sum:=0.0
 for i in p.size():sum+=p[i].cross(p[(i+1)%p.size()])
 return absf(sum)*.5
func outside_area(at:Vector2,polys:Array) -> float:
 var foot:=Rect2(at-Vector2(FOOT,FOOT),Vector2(FOOT*2,FOOT*2))
 var remains:Array=[rect_poly(foot)]
 for poly in polys:
  var next:Array=[]
  for piece in remains:next.append_array(Geometry2D.clip_polygons(piece,poly))
  remains=next
  if remains.is_empty():return 0
 var sum:=0.0
 for piece in remains:sum+=area(piece)
 return sum
func visible_surfaces(at:Vector2) -> Array:
 var ids:Dictionary={}
 for delta in [Vector2(-FOOT,-FOOT),Vector2(FOOT,FOOT),Vector2(-FOOT,FOOT),Vector2(FOOT,-FOOT)]:
  var key:=Vector2i(floori((at.x+delta.x)/64),floori((at.y+delta.y)/64))
  for id in bins.get(key,[]):ids[id]=true
 var result:Array=[]
 for id in ids:result.append(surfaces[id])
 return result
func segment_ok(a:Vector2,b:Vector2,polys:Array,solid:Rect2=Rect2(),water:PackedVector2Array=PackedVector2Array()) -> bool:
 var steps:=maxi(1,ceili(a.distance_to(b)/.5))
 for i in range(steps+1):
  var point:=a.lerp(b,float(i)/steps)
  var foot:=Rect2(point-Vector2(FOOT,FOOT),Vector2(FOOT*2,FOOT*2))
  if solid.size!=Vector2.ZERO and foot.intersects(solid):return false
  if water.size()>0 and not Geometry2D.intersect_polygons(rect_poly(foot),water).is_empty():return false
  if outside_area(point,polys)>.01:return false
 return true
func run():
 var base:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(out+"/result.json"))
 var cfg:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/village.json"))
 var g=Ground.new();root.add_child(g);g.configure_path(str(cfg.ground_layers),str(cfg.background))
 surfaces=g.polygons.road+g.polygons.yard+g.polygons.entry_road
 for idx in surfaces.size():
  var bounds:=Rect2(surfaces[idx][0],Vector2.ZERO)
  for point in surfaces[idx]:bounds=bounds.expand(point)
  for y in range(floori(bounds.position.y/64),floori(bounds.end.y/64)+1):
   for x in range(floori(bounds.position.x/64),floori(bounds.end.x/64)+1):
    var key:=Vector2i(x,y)
    if not bins.has(key):bins[key]=[]
    bins[key].append(idx)
 var broad:Array=[rect_poly(Rect2(-100,-100,400,400))]
 var straight:Array=[rect_poly(Rect2(0,0,200,56))]
 var lshape:Array=[rect_poly(Rect2(0,0,56,120)),rect_poly(Rect2(0,64,120,56))]
 check(not segment_ok(Vector2(48,56),Vector2(64,72),lshape),"negative L corner: safe endpoints cannot certify footprint between")
 check(not segment_ok(Vector2(20,2),Vector2(80,2),straight),"negative road edge: centre inside but 3px footprint outside")
 check(not segment_ok(Vector2(42,42),Vector2(68,68),broad,Rect2(50,50,10,10)),"negative wall edge: original 3px footprint retained")
 check(not segment_ok(Vector2(98.5,20),Vector2(98.5,80),broad,Rect2(),rect_poly(Rect2(100,0,100,200))),"negative river bank: centre land-side is insufficient")
 check(segment_ok(Vector2(20,4),Vector2(80,4),straight),"positive road-edge point with 3px room passes; no duplicate 8px inset")
 check(segment_ok(Vector2(20,28),Vector2(80,28),straight),"positive straight road")
 var total_bad:=0;var total_samples:=0
 for route in base.routes:
  var points:Array=route.path_points
  var bad:=0;var examples:Array=[];var count:=0
  for segment in range(1,points.size()):
   var a:=Vector2(points[segment-1][0],points[segment-1][1]);var b:=Vector2(points[segment][0],points[segment][1])
   var steps:=maxi(1,ceili(a.distance_to(b)/2))
   for i in range(steps+1):
    var point:=a.lerp(b,float(i)/steps);count+=1
    var missing:=outside_area(point,visible_surfaces(point))
    if missing>.01:
     bad+=1
     if examples.size()<5:examples.append({"point":[point.x,point.y],"outside_area":missing})
  total_bad+=bad;total_samples+=count
  reports.append({"id":route.id,"samples":count,"bad_samples":bad,"examples":examples})
  check(bad==0,"full 3px foot square on visible surface "+str(route.id),{"bad":bad,"samples":count,"examples":examples})
 FileAccess.open(out+"/\u811a\u5370\u8865\u5145\u7ed3\u679c.json",FileAccess.WRITE).store_string(JSON.stringify({"mode":"non-OS exact polygon subtraction of 6x6 foot square at <=2px segment sampling; original wall grow(3) interpretation, no duplicate 8px inset; separate from unchanged original centre/path checks","foot_half_extent":FOOT,"negative_and_positive_controls":6,"rows":rows,"routes":reports,"total_samples":total_samples,"bad_samples":total_bad,"original_result_sha256":FileAccess.get_file_as_string(out+"/result.json").sha256_text()},"  "))
 print(JSON.stringify({"footprint_samples":total_samples,"bad_samples":total_bad,"checks":rows.size(),"failures":rows.filter(func(r):return not r.pass).size()}));g.queue_free();await process_frame;quit(0)
