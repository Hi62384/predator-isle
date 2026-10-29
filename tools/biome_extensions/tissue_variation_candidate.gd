extends RefCounted
# Private material-only candidate. Production files and physical fields stay fixed.
const BASE="res://shaders/alien_tissue_flow.gdshaderinc"
const LOOKUP="textureGrad(biological_colors,vec3(uv,1.0),ux*grid_dx.x+uy*grid_dx.y,ux*grid_dy.x+uy*grid_dy.y).rgb"
const FUNCTIONS="""
uniform bool alien_tissue_variation_enabled=true;
vec3 alien_flow_mirrored(vec2 uv,vec2 dx,vec2 dy){
 vec2 cell=mod(uv,vec2(2));
 vec2 direction=mix(vec2(1),vec2(-1),step(vec2(1),cell));
 vec2 edge=vec2(.5)/vec2(textureSize(biological_colors,0).xy);
 vec2 folded=clamp(vec2(1)-abs(cell-vec2(1)),edge,vec2(1)-edge);
 return textureGrad(biological_colors,vec3(folded,1.0),dx*direction,dy*direction).rgb;
}
vec3 alien_flow_varied(vec2 uv,vec2 dx,vec2 dy){
 if(!alien_tissue_variation_enabled)return textureGrad(biological_colors,vec3(uv,1.0),dx,dy).rgb;
 // Canonical finite-path coordinates, not chunk origins or world float hashes.
 // No quarter-turns: longitudinal fibres keep their actual hive-path axis.
 float k=field(uv/vec2(2.7,3.9))*6.0,index=floor(k);
 float blend=smoothstep(.15,.85,fract(k));
 vec2 a=sin(vec2(3,7)*index)*19.0,b=sin(vec2(3,7)*(index+1.0))*19.0;
 // Modest continuous growth strain breaks mirror-pair motifs without random
 // rotations or independently changing the physical trunk direction. Apply
 // its analytic Jacobian to BOTH footprints, never screen-derive grouped UVs.
 vec2 jx=vec2(1.0+.074*cos(uv.x*.37),.0918*cos(uv.x*.51));
 vec2 jy=vec2(.3285*cos(uv.y*.73),1.0+.0664*cos(uv.y*.83));
 vec2 warped_dx=jx*dx.x+jy*dx.y,warped_dy=jx*dy.x+jy*dy.y;
 uv+=vec2(.45*sin(uv.y*.73)+.2*sin(uv.x*.37),.18*sin(uv.x*.51)+.08*sin(uv.y*.83));
 dx=warped_dx;dy=warped_dy;
 return mix(alien_flow_mirrored(uv+a,dx,dy),alien_flow_mirrored(uv+b,dx,dy),blend);
}
"""
static func source_for(base:String)->String:
	assert(base.count(LOOKUP)==1 and not base.contains("alien_flow_varied"))
	return base.replace("vec3 alien_flow_color(",FUNCTIONS+"\nvec3 alien_flow_color(").replace(LOOKUP,"alien_flow_varied(uv,ux*grid_dx.x+uy*grid_dx.y,ux*grid_dy.x+uy*grid_dy.y)")
