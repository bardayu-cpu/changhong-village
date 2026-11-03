extends RefCounted
var layout:Dictionary
var surfaces:Array
var bins:Dictionary={}
var tufts:Array=[]
func noise(n:float)->float:return fposmod(sin(n*12.9898+78.233)*43758.5453,1.0)
func setup(data:Dictionary,paths:Array):
 layout=data;surfaces=paths
 for i in surfaces.size():
  var box:=Rect2(surfaces[i][0],Vector2.ZERO)
  for pt in surfaces[i]:box=box.expand(pt)
  for y in range(floori(box.position.y/64),floori(box.end.y/64)+1):
   for x in range(floori(box.position.x/64),floori(box.end.x/64)+1):
    var key:=Vector2i(x,y)
    if not bins.has(key):bins[key]=[]
    bins[key].append(i)
 var seed:=0
 for line in layout.roads+layout.field_paths:
  var carried:=0.0
  for i in range(1,line.points.size()):
   var a:=Vector2(line.points[i-1][0],line.points[i-1][1]);var b:=Vector2(line.points[i][0],line.points[i][1])
   carried+=a.distance_to(b)
   if carried<23:continue
   carried=0
   var tangent:Vector2=(b-a).normalized();var normal:=Vector2(-tangent.y,tangent.x)
   for side in [-1,1]:
    seed+=1
    if noise(seed)>.65:continue
    var p:Vector2=b+normal*side*(float(line.get("width",56))*.5+2+noise(seed+13)*21)
    var okay:=p.x>15 and p.x<4630 and p.y>540 and p.y<4660
    if not okay:continue
    for box in layout.surface_obstacles:
     if Rect2(box[0],box[1],box[2],box[3]).grow(9).has_point(p):okay=false;break
    if not okay:continue
    for idx in bins.get(Vector2i(floori(p.x/64),floori(p.y/64)),[]):
     if Geometry2D.is_point_in_polygon(p,surfaces[idx]):okay=false;break
    if okay:tufts.append({"point":p,"seed":seed,"flower":noise(seed+31)<.28,"height":6+noise(seed+27)*9})
func paint(canvas:CanvasItem,factor:float,offset:Vector2,season:int):
 for c in layout.get("irrigation_channels",[]):
  var poly:=PackedVector2Array()
  for v in c.polygon:poly.append(offset+Vector2(v[0],v[1])*factor)
  canvas.draw_colored_polygon(poly,Color("506e61"))
  canvas.draw_polyline(poly,Color("6b7351"),maxf(.7,2.2*factor),true)
  var line:=PackedVector2Array()
  for v in c.centre:line.append(offset+Vector2(v[0],v[1])*factor)
  if line.size()>1:
   for i in range(2,line.size(),5):
    var tangent:Vector2=(line[i]-line[i-1]).normalized()
    var normal:=Vector2(-tangent.y,tangent.x)
    var mid:Vector2=line[i]+normal*sin(i*3.1)*factor*2
    canvas.draw_line(mid-normal*factor*2,mid+normal*factor*2+tangent*factor,Color("7c9580"),maxf(.4,factor))
 if factor<.3:return # Small map keeps quiet fields, not confetti.
 for item in tufts:
  var p:Vector2=offset+item.point*factor
  var height:float=item.height*factor
  var green:Color=[Color("536a39"),Color("7b8c50"),Color("3e5b2d")][int(item.seed)%3]
  if season==3:green=Color("8b8d71")
  if int(item.seed)%3!=0 and season!=3:
   var texture=preload("res://ayu_home/v2/assets.gd").texture("res://ayu_home/v4/assets/village/natural-verge-1025/roadside-atlas.png")
   var choices:Array=[1,3,4,6,7,8,10,11];var idx:int=choices[int(item.seed)%choices.size()]
   var cell:Vector2=texture.get_size()/Vector2(4,3)
   var region:=Rect2(Vector2(idx%4,idx/4)*cell,cell)
   var width:float=(28+noise(item.seed)*23)*factor
   var extent:=Vector2(width,width*.78)
   canvas.draw_texture_rect_region(texture,Rect2(p-Vector2(extent.x*.5,extent.y*.90),extent),region)
   continue
  canvas.draw_line(p,p+Vector2(-3*factor,-height),green,maxf(1,factor))
  canvas.draw_line(p,p+Vector2(factor,-height*1.2),green,maxf(1,factor))
  canvas.draw_line(p,p+Vector2(4*factor,-height*.6),green,maxf(1,factor))
  var leaf:=PackedVector2Array([p+Vector2(0,-height*.35),p+Vector2(-5*factor,-height*.7),p+Vector2(-2*factor,-height*.2)])
  canvas.draw_colored_polygon(leaf,green.lightened(.06))
  if item.flower and season!=3:
   var tip:Vector2=p+Vector2(factor,-height*1.2)
   var col:Color=[Color("ddd8bd"),Color("bcb1c0"),Color("cbb573"),Color("c99e95")][int(item.seed)%4]
   var unit:=maxf(1,factor)
   for arm in [Vector2(-2,0),Vector2(2,0),Vector2(0,-2),Vector2(0,2)]:
    canvas.draw_rect(Rect2((tip+arm*factor).round(),Vector2(unit*2.2,unit*2.2)),col)
   canvas.draw_rect(Rect2(tip.round(),Vector2(unit*1.5,unit*1.5)),Color("b59956"))
