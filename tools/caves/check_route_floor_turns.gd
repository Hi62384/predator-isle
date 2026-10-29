extends "res://tools/biome_extensions/check_all.gd"
const Field=preload("res://scripts/caves/portal_field.gd")
const Shapes=preload("res://scripts/caves/formations.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://scripts/caves/field.gd","res://scripts/caves/formations.gd","res://scripts/caves/portal_field.gd"]:guards[path]=FileAccess.get_sha256(path)
	var height:Callable=func(_x:float,_z:float)->float:return 200.0
	var shapes=Shapes.new();var cases:int=0;var old_violations:int=0;var maximum_error:float=0;var maximum_old_error:float=0;var records:Array=[]
	for style in range(8):
		for angle:float in [0.0,.4,1.2]:
			for offset:float in [0.0,9600.0,-9600.0]:
				for grade:float in [.1,.2]:
					for sign_value:float in [-1.0,1.0]:
						var axis:=Vector3(cos(angle),0,sin(angle));var origin:=Vector3(offset,20,-offset);var points:=PackedVector3Array()
						for station:float in [-24.0,-8.0,0.0,8.0,24.0]:points.append(origin+axis*station+Vector3.UP*absf(station)*grade*sign_value)
						var edge:Dictionary={"from":"A","to":"B","points":points,"half_width":4.0,"headroom":8.0,"entrance":false};var region:Dictionary={"valid":true,"id":Vector2i.ZERO,"nodes":[],"edges":[edge],"cross_section_style":style};var field=Field.new();field.include_surface_air=false;var original=Field.new();original.continuous_route_floors=false;original.include_surface_air=false;check(field.compile([region],height) and original.compile([region],height),"Same solved grade-turn graph compiles with independent old cap control")
						var worst:float=0;var worst_old:float=0
						for station in range(-40,41):
							var along:float=station*.25;var p:Vector3=origin+axis*along;var expected:float=origin.y+absf(along)*grade*sign_value;var a:=Vector3(p.x,expected-2,p.z);var b:=Vector3(p.x,expected+2,p.z);var current:Vector3=shapes.boundary(field,a,b);var old:Vector3=shapes.boundary(original,a,b);var error:float=absf(current.y-expected);var old_error:float=absf(old.y-expected);worst=maxf(worst,error);worst_old=maxf(worst_old,old_error)
							check(error<.002,"Continuous solved floor survives both signed grade turns/all8geologies/positive and negative world coordinates;predeclared2mm scalar-bisection bound")
						maximum_error=maxf(maximum_error,worst);maximum_old_error=maxf(maximum_old_error,worst_old)
						if worst_old>.1:old_violations+=1
						cases+=1;records.append({"style":style,"angle":angle,"origin_xz_m":offset,"grade":grade,"valley":sign_value>0,"maximum_current_floor_error_m":worst,"maximum_old_cap_error_m":worst_old})
	check(cases==288 and old_violations>72 and maximum_old_error>.4,"All288fixed geometric cases retained and original wrong cap planes are positive physical negatives")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable shared cap-floor scalar source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_route_floor_turns.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":records,"maximum_current_error_m":maximum_error,"maximum_old_error_m":maximum_old_error,"positive_old_error_cases":old_violations,"scope":"288predeclared equal-grade peaks/valleys,8existing geological cross-sections,3rotations,3signed world offsets,10/20percent slopes,same graph coordinates,independent complete old cap scalar.81dense vertical bisection probes per case at2mm bound. Scalar-floor proof,not native full live traversal,entire world art or FPS."},"  "));print("ROUTE_FLOOR_TURNS ",checks," cases=",cases," current=",maximum_error," old=",maximum_old_error," positive_old=",old_violations," failures=",failures.slice(0,5));quit(0 if failures.is_empty() else 1)
