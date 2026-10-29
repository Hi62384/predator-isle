shader_type spatial;
uniform vec4 base_color:source_color=vec4(.21,.225,.22,1.0);
varying vec2 ground_point;
void vertex(){ground_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;}
void fragment(){
	vec2 uv=ground_point*2.0;
	vec2 edge=abs(fract(uv+.5)-.5)/max(fwidth(uv),vec2(.0001));
	float grid=1.0-clamp(min(edge.x,edge.y),0.0,1.0);
	ALBEDO=base_color.rgb*(1.0-grid*.16);ROUGHNESS=.94;
}
