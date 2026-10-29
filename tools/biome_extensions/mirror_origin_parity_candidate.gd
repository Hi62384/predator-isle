extends RefCounted
## Private functional texture correction; failed whole-scene resource gates.
static func apply_to(source:String)->String:
	var marker:String="vec3 p=forest_local_position/metres+vec3(r)*.25/metres;dx/=metres;dy/=metres;vec3 color=vec3(0);"
	assert(source.count(marker)==1 and not source.contains("biological_mirror_origin"))
	return '#include "res://tools/biome_extensions/mirror_origin_phase_candidate.gdshaderinc"\n'+source.replace(marker,marker+"\n if(layer==0)p+=biological_mirror_origin;")
