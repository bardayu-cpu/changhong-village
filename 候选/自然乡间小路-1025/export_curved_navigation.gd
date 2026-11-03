extends SceneTree
func _initialize():call_deferred("run")
func plain(polys:Array)->Array:
 var result:Array=[]
 for polygon in polys:
  var row:Array=[]
  for v in polygon:row.append([v.x,v.y])
  result.append(row)
 return result
func run():
 var cfg=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/village.json"))
 var g=load("res://ayu_home/v4/core/village_ground.gd").new();root.add_child(g);g.configure_path(str(cfg.ground_layers),str(cfg.background))
 cfg.field_navigation={"fields":[],"walk_surfaces":[],"margin":8,"route_on_surfaces":true}
 for f in g.field_tiles:cfg.field_navigation.fields.append(plain([f.polygon])[0])
 for kind in ["road","yard","entry_road"]:cfg.field_navigation.walk_surfaces.append_array(plain(g.polygons[kind]))
 cfg.erase("_field_nav_cache")
 FileAccess.open("res://ayu_home/v4/assets/village.json",FileAccess.WRITE).store_string(JSON.stringify(cfg,"  "))
 var rooms=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/rooms.json"));rooms.rooms.village=cfg
 FileAccess.open("res://ayu_home/v4/assets/rooms.json",FileAccess.WRITE).store_string(JSON.stringify(rooms,"  "))
 print("CURVED_SURFACES_AND_NAV_EXPORTED ",cfg.field_navigation.walk_surfaces.size());quit()
