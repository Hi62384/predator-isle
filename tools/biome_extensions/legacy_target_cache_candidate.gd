extends RefCounted
## One existing material evaluation per owner, reused by the fast and blended
## output paths. Preserve the original priority/threshold invocation domain.
const OWNERS:Array[String]=["badlands","tropical","mountain","swamp","savanna","forest","jungle"]
static func apply_to(source:String)->String:
	var result:String=source;var prelude:String="\n";var higher:String="coast_control.x<=.999 && dot(extension_weights_a,vec4(1))+dot(extension_weights_b,vec4(1))<=.999"
	for owner:String in OWNERS:
		var control:String=owner+"_control."+("x" if owner in ["badlands","tropical"] else "z")
		var dx:String="position_dx,position_dy" if owner=="jungle" else "forest_dx,forest_dy"
		var pure_tail:String="weights" if owner=="jungle" else ("materials,overlays" if owner=="mountain" else ("materials,diagnostics" if owner=="forest" else "materials,masks"))
		var cache:String="cache_"+owner+"_"
		prelude+="vec3 "+cache+"color=vec3(0),"+cache+"gradient=vec3(0),"+cache+"materials=vec3(0),"+cache+"extra=vec3(0);float "+cache+"rough=1.0;\n"
		var inputs:String="shade_"+owner+"(n,"+dx+",projection,fine,"
		var outputs:String=cache+"color,"+cache+"rough,"+cache+"gradient,"+cache+"materials"+("" if owner=="jungle" else ","+cache+"extra")
		prelude+="if(.001<"+control+" && "+higher+"){"+inputs+outputs+");}\n"
		var before:String=inputs+"color,rough,gradient,"+pure_tail+");"
		assert(result.count(before)==1,"Exact original pure owner call "+owner)
		var assignments:String="color="+cache+"color;rough="+cache+"rough;gradient="+cache+"gradient;"
		if owner=="jungle":assignments+="weights="+cache+"materials;"
		else:
			assignments+="materials="+cache+"materials;"+("overlays" if owner=="mountain" else ("diagnostics" if owner=="forest" else "masks"))+"="+cache+"extra;"
		result=result.replace(before,assignments)
		var pattern:=RegEx.new();assert(pattern.compile("shade_"+owner+"\\(n,"+dx+",projection,fine,([^;]+)\\);")==OK)
		var calls:Array[RegExMatch]=pattern.search_all(result);assert(calls.size()==1,"Exact original mixed owner call "+owner)
		var targets:PackedStringArray=calls[0].get_string(1).split(",");var values:Array[String]=[cache+"color",cache+"rough",cache+"gradient",cache+"materials",cache+"extra"];assignments=""
		for index in range(targets.size()):assignments+=targets[index]+"="+values[index]+";"
		result=result.replace(calls[0].get_string(),assignments)
		higher+=" && "+control+"<=.999"
	var anchor:String=" if(coast_control.x>.999){"
	assert(result.count(anchor)==1);return result.replace(anchor,prelude+anchor)
