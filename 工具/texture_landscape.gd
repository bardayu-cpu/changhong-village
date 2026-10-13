extends SceneTree
## Mechanical material sampling over the existing procedural ground. No window or new artwork generation.
const BASE:="res://ayu_home/v4/assets/village/"
func _initialize() -> void:
	var ground:=Image.load_from_file(BASE+"ground.png");ground.resize(1600,1566,Image.INTERPOLATE_NEAREST)
	var atlas:=Image.load_from_file(BASE+"landscape-atlas-v1.png")
	var concrete:=atlas.get_region(Rect2i(119,125,209,209));concrete.resize(64,64,Image.INTERPOLATE_NEAREST)
	var grass:=atlas.get_region(Rect2i(522,125,209,209));grass.resize(64,64,Image.INTERPOLATE_NEAREST)
	var road_colors:Array[Color]=[Color("cfb17b"),Color("ddc08a"),Color("d9bb85"),Color("c4a373")]
	var grass_colors:Array[Color]=[Color("8aaa5a"),Color("8baa5d"),Color("8faf61"),Color("7fa355"),Color("99b564"),Color("83a753"),Color("91ac5b")]
	var soil:=atlas.get_region(Rect2i(925,125,209,209));soil.resize(64,64,Image.INTERPOLATE_NEAREST)
	var road_count:=0;var grass_count:=0
	for y in ground.get_height():
		for x in ground.get_width():
			var old:=ground.get_pixel(x,y)
			if old==Color("986940"):
				ground.set_pixel(x,y,sample(soil,x,y))
			elif old in road_colors:
				ground.set_pixel(x,y,old.lerp(sample(concrete,x,y),.73));road_count+=1
			elif old in grass_colors:
				ground.set_pixel(x,y,old.lerp(sample(grass,x,y),.38));grass_count+=1
	ground.resize(4800,4700,Image.INTERPOLATE_NEAREST);ground.save_png(BASE+"ground.png")
	print("LANDSCAPE_MATERIAL continuous mirrored world sampling: ",road_count," road + ",grass_count," grass pixels; source bounds and water preserved");quit()
func mirror(value:int) -> int:
	var p:=posmod(value,128);return p if p<64 else 127-p
func sample(texture:Image,x:int,y:int) -> Color:
	# Edge pixels meet themselves across the reflection, avoiding rectangular sample seams.
	return texture.get_pixel(mirror(x),mirror(y)).lerp(texture.get_pixel(mirror(x/2+37),mirror(y/2+19)),.27)
