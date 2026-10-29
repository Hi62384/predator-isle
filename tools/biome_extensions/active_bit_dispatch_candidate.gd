extends RefCounted
## Private: preserve the original ascending family order and floating-point
## accumulation, while giving the compiler a data-dependent finite loop.
static func source_for(source:String)->String:
	var search:int=0
	for unused:int in range(2):
		var begin:int=source.find("for(int i=0;i<8;i++){",search);assert(begin>=0)
		var body_start:int=begin+"for(int i=0;i<8;i++){".length();var end:int=body_start;var depth:int=1
		while depth>0:
			if source[end]=="{":depth+=1
			elif source[end]=="}":depth-=1
			end+=1
		var body:String=source.substr(body_start,end-body_start-1)
		var replacement:String="int active_family_index=0;int remaining_family_bits=extension_active_mask & 255;\n while(remaining_family_bits>0){\n int i=active_family_index;int active_family_bit=remaining_family_bits & 1;remaining_family_bits=remaining_family_bits>>1;active_family_index++;if(active_family_bit==0)continue;\n"+body+"\n}"
		source=source.substr(0,begin)+replacement+source.substr(end);search=begin+replacement.length()
	return source
