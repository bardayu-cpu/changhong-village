extends RefCounted
## Geometry-only coverage mask. Every colour/detail comes from C4's raster tiles.
const Assets=preload("res://ayu_home/v2/assets.gd")
var mask:Texture2D
var road:Texture2D
var shoulder:Texture2D
var extent:=Vector2.ZERO
const CELL:=4.0
func setup(polygons:Array,world_size:Vector2,art:Dictionary) -> void:
	extent=world_size
	road=tile(art.road);shoulder=tile(art.shoulder)
	var width:=ceili(extent.x/CELL);var height:=ceili(extent.y/CELL)
	var data:=PackedByteArray();data.resize(width*height);data.fill(0)
	# Rasterize the union, so overlapping segment caps never create seams at forks.
	for poly in polygons:
		var low:=height;var high:=0
		for point in poly:low=mini(low,floori(point.y/CELL));high=maxi(high,ceili(point.y/CELL))
		for y in range(maxi(0,low),mini(height,high)):
			var scan:float=(y+.5)*CELL;var crossings:Array[float]=[]
			for i in poly.size():
				var a:Vector2=poly[i];var b:Vector2=poly[(i+1)%poly.size()]
				if (a.y<=scan and b.y>scan) or (b.y<=scan and a.y>scan):crossings.append(a.x+(scan-a.y)*(b.x-a.x)/(b.y-a.y))
			crossings.sort()
			for i in range(0,crossings.size()-1,2):
				for x in range(maxi(0,ceili(crossings[i]/CELL-.5)),mini(width,ceili(crossings[i+1]/CELL-.5))):data[y*width+x]=255
	mask=ImageTexture.create_from_image(Image.create_from_data(width,height,false,Image.FORMAT_R8,data))
func tile(value:Dictionary) -> Texture2D:
	var source:Texture2D=Assets.texture(str(value.file))
	if not value.has("region"):return source
	var r:Array=value.region
	return ImageTexture.create_from_image(source.get_image().get_region(Rect2i(r[0],r[1],r[2],r[3])))
func material(base:ShaderMaterial) -> ShaderMaterial:
	# Preserve the existing weather/season material instance registered by World.
	var shader:=Shader.new()
	var declaration:="""
uniform sampler2D road_coverage:filter_nearest,repeat_disable;
uniform sampler2D road_tile:filter_nearest,repeat_enable;
uniform sampler2D shoulder_tile:filter_nearest,repeat_enable;
uniform vec2 terrain_size;
varying vec2 terrain_point;
void vertex(){terrain_point=VERTEX;}
float covered(vec2 p){return texture(road_coverage,p/terrain_size).r;}
"""
	var surface:="""
vec2 p=floor(terrain_point/2.0)*2.0;
float inside=covered(p);
float sum=0.0;
float near_sum=0.0;
for(int ring=1;ring<=3;ring++){
  for(int side=0;side<8;side++){
    float angle=float(side)*0.7853981634;
    float sample_value=covered(p+vec2(cos(angle),sin(angle))*float(ring)*8.0);
    sum+=sample_value;
    if(ring==1){near_sum+=sample_value;}
  }
}
float coverage=max(inside,clamp(sum/12.0,0.0,1.0));
if(coverage<0.01){discard;}
vec4 verge=texture(shoulder_tile,p/256.0);
vec4 earth=texture(road_tile,p/256.0);
float worn=inside*clamp((near_sum-2.0)/6.0,0.0,1.0);
vec4 c=mix(verge,earth,worn);
c.a*=coverage;
"""
	shader.code=base.shader.code.replace("void fragment()",declaration+"void fragment()").replace("vec4 c=texture(TEXTURE,UV);",surface)
	base.shader=shader
	base.set_shader_parameter("road_coverage",mask);base.set_shader_parameter("road_tile",road);base.set_shader_parameter("shoulder_tile",shoulder);base.set_shader_parameter("terrain_size",extent)
	return base
func paint(canvas:CanvasItem) -> void:
	canvas.draw_texture_rect(road,Rect2(Vector2.ZERO,extent),true)
