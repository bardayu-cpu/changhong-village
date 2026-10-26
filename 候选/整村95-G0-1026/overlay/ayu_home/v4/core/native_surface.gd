extends RefCounted
## C4 texels are copied, never resized. Generated pixels are geometry coverage only.
const Assets=preload("res://ayu_home/v2/assets.gd")
const ROLES=["grass","soil","shoulder","paddy","bank","shallow","deep"]
var textures:Dictionary={}
var counts:Dictionary={}
var errors:Array[String]=[]
var region:=Rect2()
var north_y:=520.0
var coverage:Texture2D
var ready_art:=false
var node:Node2D
func configure(ground,meta:Dictionary,art:Dictionary) -> bool:
	errors.clear();textures.clear();counts.clear();ready_art=false
	var box:Array=meta.region;region=Rect2(box[0],box[1],box[2],box[3]);north_y=float(meta.north_y)
	for role in ROLES:
		var cells:Array=art.get("surfaces",{}).get(role,[])
		if cells.is_empty():errors.append("missing native C4 material: "+role);continue
		var strip:=Image.create(cells.size()*64,64,false,Image.FORMAT_RGBA8)
		for i in cells.size():
			var cell:Dictionary=cells[i];var file:=str(cell.get("file",""));var r:Array=cell.get("region",[])
			if not FileAccess.file_exists(file) or r.size()!=4:errors.append("missing source/region: "+role);continue
			var image:Image=Assets.texture(file).get_image()
			var clip:=Rect2i(r[0],r[1],r[2],r[3])
			if clip.size!=Vector2i(64,64) or not Rect2i(Vector2i.ZERO,image.get_size()).encloses(clip):errors.append("non-native cell: "+role);continue
			strip.blit_rect(image,clip,Vector2i(i*64,0))
		if role in ["shallow","deep"] and cells.size()!=4:errors.append("water must have four synchronized native frames: "+role)
		textures[role]=ImageTexture.create_from_image(strip);counts[role]=cells.size()
	if not errors.is_empty():return false
	build_coverage(ground,meta.shore_knots)
	ready_art=true;return true
func raster(data:PackedByteArray,polygons:Array,channel:int) -> void:
	var width:=int(region.size.x);var height:=int(region.size.y)
	for polygon in polygons:
		var low:=height;var high:=0
		for point in polygon:low=mini(low,floori(point.y-region.position.y));high=maxi(high,ceili(point.y-region.position.y))
		for y in range(maxi(0,low),mini(height,high)):
			var scan:float=region.position.y+y+.5;var crossings:Array[float]=[]
			for i in polygon.size():
				var a:Vector2=polygon[i];var b:Vector2=polygon[(i+1)%polygon.size()]
				if (a.y<=scan and b.y>scan) or (b.y<=scan and a.y>scan):crossings.append(a.x+(scan-a.y)*(b.x-a.x)/(b.y-a.y))
			crossings.sort()
			for i in range(0,crossings.size()-1,2):
				for x in range(maxi(0,ceili(crossings[i]-region.position.x-.5)),mini(width,ceili(crossings[i+1]-region.position.x-.5))):data[(y*width+x)*4+channel]=255
func build_coverage(ground,knots:Array) -> void:
	var width:=int(region.size.x);var height:=int(region.size.y)
	var data:=PackedByteArray();data.resize(width*height*4);data.fill(0)
	raster(data,ground.polygons.road+ground.polygons.yard+ground.polygons.entry_road,0)
	var fields:Array=[]
	for field in ground.field_tiles:fields.append(field.polygon)
	raster(data,fields,3)
	var yards:Array=[]
	for values in ground.layout.get("yards",[]):yards.append(ground.points_of(values))
	raster(data,yards,2)
	var segment:=0
	for y in height:
		var world_y:float=region.position.y+y+.5
		while segment+1<knots.size()-1 and world_y>float(knots[segment+1][1]):segment+=1
		var a:Vector2=Vector2(knots[segment][0],knots[segment][1]);var b:Vector2=Vector2(knots[mini(segment+1,knots.size()-1)][0],knots[mini(segment+1,knots.size()-1)][1])
		var bank:float=lerpf(a.x,b.x,clampf((world_y-a.y)/maxf(1,b.y-a.y),0,1))
		for x in width:data[(y*width+x)*4+1]=clampi(floori(region.position.x+x+.5-bank)+64,0,255)
	coverage=ImageTexture.create_from_image(Image.create_from_data(width,height,false,Image.FORMAT_RGBA8,data))
func mount(parent:Node) -> void:
	if not ready_art:return
	node=Node2D.new();node.name="G0NativeSurface";node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var material:=ShaderMaterial.new();var shader:=Shader.new();shader.code=shader_source();material.shader=shader
	material.set_shader_parameter("coverage",coverage)
	material.set_shader_parameter("origin",region.position);material.set_shader_parameter("extent",region.size);material.set_shader_parameter("north_y",north_y)
	for role in ROLES:
		material.set_shader_parameter(role+"_art",textures[role]);material.set_shader_parameter(role+"_count",counts[role])
	node.material=material;parent.add_child(node)
	node.draw.connect(func():node.draw_texture_rect(textures.grass,region,false))
func shader_source() -> String:
	return """shader_type canvas_item;
uniform sampler2D coverage:filter_nearest,repeat_disable;
uniform sampler2D grass_art:filter_nearest,repeat_disable;
uniform sampler2D soil_art:filter_nearest,repeat_disable;
uniform sampler2D shoulder_art:filter_nearest,repeat_disable;
uniform sampler2D paddy_art:filter_nearest,repeat_disable;
uniform sampler2D bank_art:filter_nearest,repeat_disable;
uniform sampler2D shallow_art:filter_nearest,repeat_disable;
uniform sampler2D deep_art:filter_nearest,repeat_disable;
uniform int grass_count; uniform int soil_count; uniform int shoulder_count;
uniform int paddy_count; uniform int bank_count; uniform int shallow_count; uniform int deep_count;
uniform vec2 origin; uniform vec2 extent; uniform float north_y;
varying vec2 point;
void vertex(){point=VERTEX;}
float variant(vec2 p,int count){return mod(floor(p.x/64.0)*7.0+floor(p.y/64.0)*11.0,float(count));}
vec4 cell(sampler2D art,vec2 p,int count,float which){
 vec2 local=mod(floor(p),64.0)+vec2(0.5);
 return texture(art,vec2((which*64.0+local.x)/(64.0*float(count)),local.y/64.0));
}
float road(vec2 p){return texture(coverage,(p-origin+vec2(0.5))/extent).r;}
void fragment(){
 vec2 p=floor(point);
 if(p.y<north_y){discard;}
 vec4 masks=texture(coverage,(p-origin+vec2(0.5))/extent);
 vec4 ground=cell(grass_art,p,grass_count,variant(p,grass_count));
 if(masks.a>0.5){ground=cell(paddy_art,p,paddy_count,variant(p,paddy_count));}
 if(masks.b>0.5){ground=cell(soil_art,p,soil_count,variant(p,soil_count));}
 float neighbours=0.0;
 for(int side=0;side<8;side++){
  float angle=float(side)*0.7853981634;
  neighbours+=road(p+round(vec2(cos(angle),sin(angle))*6.0));
 }
 vec4 earth=cell(soil_art,p,soil_count,variant(p,soil_count));
 vec4 verge=cell(shoulder_art,p,shoulder_count,variant(p,shoulder_count));
 vec4 lane=mix(verge,earth,masks.r*clamp(neighbours/8.0,0.0,1.0));
 ground=mix(ground,lane,max(masks.r,neighbours/16.0)*lane.a);
 float depth=masks.g*255.0-64.0;
 vec4 mud=cell(bank_art,p,bank_count,variant(p,bank_count));
 if(depth>=-24.0 && depth<0.0){ground=mix(ground,mud,clamp((depth+24.0)/16.0,0.0,1.0)*mud.a);}
 if(depth>=0.0){
  float phase=mod(floor(TIME*3.0),4.0);
  vec4 shallow=cell(shallow_art,p,shallow_count,phase);
  vec4 deep=cell(deep_art,p,deep_count,phase);
  ground=mix(shallow,deep,clamp(depth/32.0,0.0,1.0));
 }
 COLOR=ground;
}
"""
