extends RefCounted
## Alien layers are1..3. Their original nonzero-layer projection never rotates
## or mirrors;spell out that existing branch so the driver needn't expand the
## unreachable layer0 path at every regional target and projection.
const SPECIALIZED="""
vec3 alien_projected_nonzero(int layer,vec2 uv,vec2 dx,vec2 dy,vec2 reference){
 float k=field(reference/7.0)*6.0,index=floor(k),blend=smoothstep(.15,.85,fract(k));
 vec2 a=uv+sin(vec2(3,7)*index)*19.0,b=uv+sin(vec2(3,7)*(index+1.0))*19.0;
 return mix(textureGrad(biological_colors,vec3(a,float(layer)),dx,dy).rgb,textureGrad(biological_colors,vec3(b,float(layer)),dx,dy).rgb,blend);
}
"""
static func apply_to(source:String)->String:
	var start:int=source.find("vec3 biological_sample(");var end:int=source.find("int alien_tissue_layer(",start)
	assert(start>=0 and end>start)
	var sample:String=source.substr(start,end-start).replace("biological_sample(","alien_sample_nonzero(").replace("biological_projected(","alien_projected_nonzero(")
	var result:String=source.insert(end,SPECIALIZED+sample)
	assert(result.count("biological_sample(layer,layer==2?2.0:1.5,")==1)
	return result.replace("biological_sample(layer,layer==2?2.0:1.5,","alien_sample_nonzero(layer,layer==2?2.0:1.5,")
