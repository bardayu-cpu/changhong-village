extends RefCounted
const Assets=preload("res://ayu_home/v2/assets.gd")
static var cache:Dictionary={}
static func foliage(path:String,season:int,grass:=false)->Texture2D:
 var key=path+str(season)+str(grass)
 if cache.has(key):return cache[key]
 var img:Image=Assets.texture(path).get_image();img.convert(Image.FORMAT_RGBA8)
 if grass:img.resize(256,256,Image.INTERPOLATE_NEAREST)
 var data:=img.get_data()
 for i in range(0,data.size(),4):
  var c:=Color(data[i]/255.0,data[i+1]/255.0,data[i+2]/255.0)
  var y:float=c.r*.22+c.g*.63+c.b*.15
  var v:=clampf((y-.16)*1.13,.06,.96)
  var lo:=Color(.13,.27,.10);var hi:=Color(.52,.65,.34)
  if season==0 and not grass:
   if c.b>c.g*.9:lo=Color(.36,.48,.45);hi=Color(.58,.66,.59)
  elif season==2 and not grass:lo=Color(.48,.43,.24);hi=Color(.72,.65,.41)
  elif season==3:lo=Color(.40,.42,.36);hi=Color(.67,.69,.62)
  if grass:v=.12+y*.66;lo=Color(.24,.33,.16);hi=Color(.53,.59,.33)
  var result:Color=lo.lerp(hi,v)
  data[i]=int(result.r*255);data[i+1]=int(result.g*255);data[i+2]=int(result.b*255)
 var tex:=ImageTexture.create_from_image(Image.create_from_data(img.get_width(),img.get_height(),false,Image.FORMAT_RGBA8,data))
 cache[key]=tex;return tex
static func hash2(x:float,y:float)->float:return fposmod(sin(x*127.1+y*311.7)*43758.5453,1.0)
static func earth()->Texture2D:
 if cache.has("earth"):return cache.earth
 var img:=Image.create(256,256,false,Image.FORMAT_RGBA8)
 for y in 256:
  for x in 256:
   var broad:float=.5+sin(x*TAU/128)*.13+cos(y*TAU/128)*.13+sin((x+y)*TAU/64)*.05
   var grain:=hash2(floor(x/2.0),floor(y/2.0))-.5
   var c:Color=Color(.43,.36,.27).lerp(Color(.61,.53,.40),broad*.82+.06)
   c+=Color(grain*.052,grain*.052,grain*.052,0)
   var cx:float=floorf(x/32.0);var cy:float=floorf(y/32.0)
   var point:=Vector2(fposmod(x,32)-8-hash2(cx,cy)*16,fposmod(y,32)-8-hash2(cx+5,cy)*16)
   point.y*=1.4
   if point.length()<1.3+hash2(cx+7,cy)*1.8 and hash2(cx+9,cy)<.16:c=c.lerp(Color(.52,.50,.43),.65)
   img.set_pixel(x,y,c)
 var tex:=ImageTexture.create_from_image(img);cache.earth=tex;return tex
