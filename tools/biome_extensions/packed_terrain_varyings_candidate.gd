extends RefCounted
static func source_for(source:String)->String:
	# Same72 smoothly interpolated floats in17 vec4 locations plus COLOR.
	# Per-instance chunk translation is bound explicitly by the private host.
	source=source.replace("varying flat vec3 forest_origin;","instance uniform vec3 terrain_instance_origin;\n#define forest_origin terrain_instance_origin").replace(" forest_origin=MODEL_MATRIX[3].xyz;","")
	var badlands:String=FileAccess.get_file_as_string("res://shaders/badlands_material.gdshaderinc")
	badlands=badlands.replace("vec3 badlands_debug(vec3 n,vec3 mapped,vec3 materials,vec3 masks){","vec3 badlands_debug(vec3 n,vec3 mapped,vec3 materials,vec3 masks,vec2 supplied_surface){").replace("terrain_surface.y","supplied_surface.y")
	var debug_calls:=RegEx.new();assert(debug_calls.compile("badlands_debug\\(([^()]*)\\)")==OK)
	source=debug_calls.sub(source,"badlands_debug($1,terrain_surface)",true)
	source=source.replace('#include "res://shaders/badlands_material.gdshaderinc"',badlands)
	var regex:=RegEx.new();assert(regex.compile("(?m)^varying (float|vec[234]) (\\w+);")==OK)
	var matches:Array[RegExMatch]=regex.search_all(source);var fields:Array=[];var components:Array[String]=[];var declarations:String="";var aliases:String=""
	var start:int=source.find("void vertex() {");assert(start>=0)
	var end:int=start+"void vertex() {".length();var depth:int=1
	while depth>0:
		if source[end]=="{":depth+=1
		elif source[end]=="}":depth-=1
		end+=1
	var old_vertex:String=source.substr(start,end-start);var body:String=old_vertex.trim_prefix("void vertex() {").trim_suffix("}");var locals:String=""
	for match:RegExMatch in matches:
		var type:String=match.get_string(1);var name:String=match.get_string(2);var size:int=1 if type=="float" else int(type.right(1));var values:Array[String]=[]
		fields.append({"declaration":match.get_string(),"name":name,"type":type})
		locals+=type+" v_"+name+";\n"
		var identifier:=RegEx.new();assert(identifier.compile("\\b"+name+"\\b")==OK);body=identifier.sub(body,"v_"+name,true)
		for i:int in range(size):
			if name=="world_normal":values.append("COLOR."+["x","y","z"][i]);continue
			if name=="terrain_surface" and i==0:values.append("COLOR.w");continue
			var index:int=components.size();values.append("terrain_pack_%d.%s"%[index/4,["x","y","z","w"][index%4]])
			components.append("v_"+name+("" if size==1 else "."+["x","y","z","w"][i]))
		aliases+="#define "+name+" ("+(values[0] if size==1 else type+"("+",".join(values)+")")+")\n"
	assert(components.size()==68 and fields.size()==28)
	var writes:String="COLOR=vec4(v_world_normal,v_terrain_surface.x);\n"
	for i:int in range(17):
		declarations+="varying vec4 terrain_pack_%d;\n"%i
		writes+="terrain_pack_%d=vec4(%s);\n"%[i,",".join(components.slice(i*4,i*4+4))]
	source=source.replace(old_vertex,"void vertex() {\n"+locals+body+writes+"}\n")
	for i:int in range(fields.size()):source=source.replace(fields[i].declaration,declarations+aliases if i==0 else "")
	return source
