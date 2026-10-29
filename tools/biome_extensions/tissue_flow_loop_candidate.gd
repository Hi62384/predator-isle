extends RefCounted
## Runtime bounded loops prevent the driver expanding all16 path comparisons
## and nested triplanar texture paths. Default and maximum remain four groups.
static func apply_to(source:String)->String:
	assert(source.count("for(int i=0;i<4;i++){")==1)
	assert(source.count("for(int j=0;j<4;j++){")==1)
	return ("uniform int alien_flow_group_limit=4;\n"+source).replace("for(int i=0;i<4;i++){","for(int i=0;i<min(alien_flow_group_limit,4);i++){").replace("for(int j=0;j<4;j++){","for(int j=0;j<min(alien_flow_group_limit,4);j++){")
