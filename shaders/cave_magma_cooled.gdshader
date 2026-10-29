shader_type spatial;
render_mode cull_back;
#include "res://shaders/cave_vertex_projection.gdshaderinc"
varying vec3 rock_position;
uniform sampler2D volcanic_color:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D volcanic_normal:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform float volcanic_weathering_strength:hint_range(0.0,1.0)=1.0;
varying vec3 rock_world_normal;
float volcanic_grain_hash(vec3 p,float period){return fract(sin(dot(mod(p,vec3(period)),vec3(127.1,311.7,74.7)))*43758.5453);}
float volcanic_grain(vec3 p,float period){
 vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);vec3 k=vec3(127.1,311.7,74.7);
 float a=volcanic_grain_hash(i,period),b=volcanic_grain_hash(i+vec3(1,0,0),period);
 float c=volcanic_grain_hash(i+vec3(0,1,0),period),d=volcanic_grain_hash(i+vec3(1,1,0),period);
 float e=volcanic_grain_hash(i+vec3(0,0,1),period),g=volcanic_grain_hash(i+vec3(1,0,1),period);
 float h=volcanic_grain_hash(i+vec3(0,1,1),period),j=volcanic_grain_hash(i+vec3(1),period);
 return mix(mix(mix(a,b,f.x),mix(c,d,f.x),f.y),mix(mix(e,g,f.x),mix(h,j,f.x),f.y),f.z);
}
void vertex(){rock_position=VERTEX+mod(MODEL_MATRIX[3].xyz,vec3(3840.0));rock_world_normal=normalize((MODEL_NORMAL_MATRIX*NORMAL));POSITION=cave_project_vertex(VERTEX,MODEL_MATRIX,VIEW_MATRIX,INV_VIEW_MATRIX,PROJECTION_MATRIX,MODELVIEW_MATRIX);}
vec3 normal_xy(vec2 p){vec2 xy=texture(volcanic_normal,p).rg*2.0-1.0;return vec3(xy,sqrt(max(.001,1.0-dot(xy,xy))));}
void fragment(){
	float family=floor(UV.x+.01);
	bool glass=family>1.5&&family<2.5;
	vec3 n=normalize(rock_world_normal),w=pow(abs(n),vec3(5.0));w/=max(dot(w,vec3(1.0)),.00001);
	vec3 p=rock_position*.25;
	vec4 detail=texture(volcanic_color,p.zy)*w.x+texture(volcanic_color,p.xz)*w.y+texture(volcanic_color,p.xy)*w.z;
	float grain=clamp(dot(detail.rgb,vec3(.3,.5,.2))*2.1,.38,1.35);
	float joints=pow(.5+.5*cos(rock_position.y*4.7+UV.y*6.0),24.0);
	ALBEDO=(glass?vec3(.022,.025,.027):COLOR.rgb)*grain*(1.0-(family<.5?.16:0.0)*joints);
	float weather=volcanic_grain(rock_position*2.0,7680.0),pores=volcanic_grain(rock_position*16.0,61440.0);
	float joint_phase=rock_position.y/.6+weather*.14;
	float fracture=pow(.5+.5*cos(joint_phase*6.28318530718),32.0);
	// Vertex tint is linear albedo. The old .13 grey read like pale concrete
	// beside dark volcanic host rock; cooled basalt has a dark fresh interior
	// with subdued iron weathering, irregular cross-joints and fine vesicles.
	vec3 basalt_tint=mix(COLOR.rgb*.27,COLOR.rgb*vec3(.48,.35,.27),smoothstep(.55,.85,weather));
	vec3 aged=basalt_tint*grain*(.8+weather*.35)*(1.0-(family<.5?.4:.12)*fracture);
	if(!glass)ALBEDO=mix(ALBEDO,aged,volcanic_weathering_strength);
	ROUGHNESS=glass?.24:clamp(detail.a,.65,.96);
	SPECULAR=glass?.47:.29;
	vec3 a=normal_xy(p.zy),b=normal_xy(p.xz),c=normal_xy(p.xy);
	vec3 mapped=normalize(vec3(a.z*sign(n.x),a.y,a.x)*w.x+vec3(b.x,b.z*sign(n.y),b.y)*w.y+vec3(c.x,c.y,c.z*sign(n.z))*w.z);
	NORMAL=normalize((VIEW_MATRIX*vec4(normalize(mix(n,mapped,glass?.13:.38)),0.0)).xyz);
	if(!glass){
	 float near_detail=1.0-smoothstep(48.0,160.0,length(VERTEX));
	 float height=(weather*.018+pores*.003-fracture*.004)*near_detail*volcanic_weathering_strength;
	 vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX),r1=cross(dy,NORMAL),r2=cross(NORMAL,dx);float determinant=dot(dx,r1);
	 if(abs(determinant)>.000001)NORMAL=normalize(NORMAL-clamp((r1*dFdx(height)+r2*dFdy(height))/determinant,vec3(-.3),vec3(.3)));
	}
}
