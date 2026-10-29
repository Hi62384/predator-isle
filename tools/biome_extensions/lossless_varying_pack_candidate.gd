extends RefCounted
static func source_for(source:String)->String:
	# Preserve all72 smooth values and the original flat per-instance origin.
	var regex:=RegEx.new();assert(regex.compile("(?m)^varying (float|vec[234]) (\\w+);")==OK)
	var fields:Array=regex.search_all(source);var components:Array[String]=[];var declarations:String="";var aliases:String=""
	var start:int=source.find("void vertex() {");assert(start>=0);var end:int=start+"void vertex() {".length();var depth:int=1
	while depth>0:
		if source[end]=="{":depth+=1
		elif source[end]=="}":depth-=1
		end+=1
	var old:String=source.substr(start,end-start);var body:String=old.trim_prefix("void vertex() {").trim_suffix("}");var locals:String=""
	for match:RegExMatch in fields:
		var type:String=match.get_string(1);var name:String=match.get_string(2);var size:int=1 if type=="float" else int(type.right(1));var values:Array[String]=[]
		locals+=type+" v_"+name+";\n";var token:=RegEx.new();assert(token.compile("\\b"+name+"\\b")==OK);body=token.sub(body,"v_"+name,true)
		for i:int in range(size):
			var index:int=components.size();values.append("terrain_pack_%d.%s"%[index/4,["x","y","z","w"][index%4]]);components.append("v_"+name+("" if size==1 else "."+["x","y","z","w"][i]))
		aliases+="#define "+name+" ("+(values[0] if size==1 else type+"("+",".join(values)+")")+")\n"
	assert(components.size()==72)
	var writes:String=""
	for i:int in range(18):declarations+="varying vec4 terrain_pack_%d;\n"%i;writes+="terrain_pack_%d=vec4(%s);\n"%[i,",".join(components.slice(i*4,i*4+4))]
	source=source.replace(old,"void vertex() {\n"+locals+body+writes+"}\n")
	for i:int in range(fields.size()):source=source.replace(fields[i].get_string(),declarations+aliases if i==0 else "")
	return source
