extends RefCounted
static func apply_to(source:String)->String:
	var begin:int=source.find(" if(projection.x>.002)color+=biological_projected(")
	var end:int=source.find(" return color;",begin)
	assert(begin>=0 and end>begin)
	var loop:String="""
 for(int axis=0;axis<min(biological_projection_limit,3);axis++){
  float weight=projection[axis];if(weight<=.002)continue;
  vec2 uv=axis==0?vec2(p.z,-p.y*sign(n.x)):(axis==1?vec2(p.x,-p.z*sign(n.y)):vec2(p.x,p.y*sign(n.z)));
  vec2 ux=axis==0?vec2(dx.z,-dx.y*sign(n.x)):(axis==1?vec2(dx.x,-dx.z*sign(n.y)):vec2(dx.x,dx.y*sign(n.z)));
  vec2 uy=axis==0?vec2(dy.z,-dy.y*sign(n.x)):(axis==1?vec2(dy.x,-dy.z*sign(n.y)):vec2(dy.x,dy.y*sign(n.z)));
  vec2 reference=axis==0?world_position.zy:(axis==1?world_position.xz:world_position.xy);
  color+=biological_projected(layer,uv,ux,uy,reference)*weight;
 }
"""
	return "uniform int biological_projection_limit=3;\n"+source.substr(0,begin)+loop+source.substr(end)
