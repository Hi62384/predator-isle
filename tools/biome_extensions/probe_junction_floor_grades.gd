extends "res://tools/biome_extensions/check_all.gd"
func run()->void:
	var b=make_builder(7,92881);b.settings.alien_infected.feature_scale=.2;b._configure_noise();var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_custom_admission.json"));var site:Dictionary={}
	for item:Dictionary in manifest.cases:
		if int(item.seed)==92881 and item.feature_scale==.2:site=item
	var p:=Vector2(site.position[0],site.position[1]);var cell:=Vector2i(site.hive_cell[0],site.hive_cell[1]);var field=b._extras[7];var edges:PackedVector2Array=field.network_edges(cell);var d:Dictionary=field.descriptor(cell,4096*.2);var axis:Vector2=(edges[1]-p).normalized();var side:=Vector2(-axis.y,axis.x);var width:float=site.width
	var a:Vector2=p+axis*width*.6*sin(.65*PI*.65)+side*width*.07*sin(.65*PI+d.angle)*.65
	for parameter:float in [.3,.4,.5,.6,.7]:
		var q:Vector2=a*(1-parameter)*(1-parameter)+(p+axis*width*3)*2*(1-parameter)*parameter+(p+axis*width*3.6)*parameter*parameter
		var gx:int=floori(q.x/2);var gz:int=floori(q.y/2);var fx:float=q.x/2-gx;var fz:float=q.y/2-gz
		var v0:=Vector3(gx*2,b._get_height(gx*2,gz*2),gz*2);var v1:=Vector3((gx+1)*2,b._get_height((gx+1)*2,gz*2),gz*2);var v2:=Vector3(gx*2,b._get_height(gx*2,(gz+1)*2),(gz+1)*2);var v3:=Vector3((gx+1)*2,b._get_height((gx+1)*2,(gz+1)*2),(gz+1)*2)
		var normal:Vector3=(v2-v0).cross(v1-v0).normalized() if fx+fz<=1 else (v2-v1).cross(v3-v1).normalized()
		print("MIDPOINT_GROUND_DIAGNOSTIC t=",parameter," xz=",q," normal=",normal," degrees=",rad_to_deg(acos(clampf(normal.y,-1,1))))
	print("Scope: independent canonical 2m terrain-triangle grades, not native collision, route or acceptance.");quit()
