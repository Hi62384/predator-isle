shader_type spatial;
render_mode cull_back;
#include "res://shaders/cave_vertex_projection.gdshaderinc"
varying vec2 lava_position;
varying float lava_wall;
uniform float lava_time_override=-1.0;
uniform float lava_emission_strength=1.9;
uniform float lava_animation_speed=1.0;
uniform float lava_crust_strength=1.0;
uniform float lava_normal_strength=1.0;
uniform int lava_detail_quality=1;
void vertex(){lava_wall=1.0-abs(NORMAL.y);lava_position=abs(NORMAL.y)>.6?VERTEX.xz:(abs(NORMAL.x)>abs(NORMAL.z)?VERTEX.zy:VERTEX.xy);POSITION=cave_project_vertex(VERTEX,MODEL_MATRIX,VIEW_MATRIX,INV_VIEW_MATRIX,PROJECTION_MATRIX,MODELVIEW_MATRIX);}
vec2 lava_hash(vec2 p){return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);}
float lava_noise(vec2 p){vec2 i=floor(p),f=fract(p);vec2 u=f*f*(3.0-2.0*f);return mix(mix(lava_hash(i).x,lava_hash(i+vec2(1,0)).x,u.x),mix(lava_hash(i+vec2(0,1)).x,lava_hash(i+vec2(1,1)).x,u.x),u.y);}
float lava_folds(vec2 p){if(lava_detail_quality==0)return lava_noise(p);float value=lava_noise(p)*.57+lava_noise(p*2.07+vec2(7,3))*.28+lava_noise(p*4.13+vec2(2,9))*.15;if(lava_detail_quality>1)value=value*.93+lava_noise(p*8.29+vec2(19,7))*.07;return value;}
float lava_plate_gap(vec2 p){
	vec2 i=floor(p),f=fract(p);float first=8.0,second=8.0;
	for(int y=-1;y<=1;y++){for(int x=-1;x<=1;x++){
		vec2 cell=vec2(float(x),float(y));vec2 delta=cell+.15+.7*lava_hash(i+cell)-f;float d=dot(delta,delta);
		if(d<first){second=first;first=d;}else if(d<second){second=d;}
	}}
	return sqrt(second)-sqrt(first);
}
void fragment(){
	float flow_time=(lava_time_override<0.0?TIME:lava_time_override)*lava_animation_speed;
	vec2 flow=mix(vec2(.8,.35),vec2(cos(UV2.x),sin(UV2.x)),clamp(COLOR.a,0.0,1.0));
	float falling=smoothstep(.4,.85,lava_wall);
	vec2 p=lava_position*vec2(.95,mix(.95,.32,falling))+flow*flow_time*mix(.008,.035,falling);
	vec2 warped=p+vec2(lava_folds(p*.37),lava_folds(p*.37+vec2(14,5)))*1.6;
	float detail=lava_folds(warped*3.5),gap=lava_plate_gap(warped);
	float cracks=1.0-smoothstep(.022,.09+detail*.035,gap);
	float folded=pow(lava_folds(warped*2.0+vec2(4,11)),2.0);
	float warmth=smoothstep(.24,.76,lava_folds(warped*.73+vec2(9,4)));
	float molten=cracks*(.3+.7*warmth)*(.68+.32*detail);
	molten=mix(molten,clamp(molten*.45+smoothstep(.28,.7,detail)*.65,0.0,1.0),falling);
	molten=mix(1.0,molten,clamp(lava_crust_strength,0.0,1.0));
	vec3 hot=mix(vec3(.62,.045,.002),vec3(1.0,.32,.022),detail);
	float grain=lava_detail_quality>0?lava_noise(warped*22.0):.5;
	vec3 crust=mix(vec3(.038,.032,.029),vec3(.14,.105,.073),clamp(folded*1.5+grain*.18,0.0,1.0));
	ALBEDO=mix(crust,hot*.42,molten);
	EMISSION=hot*molten*lava_emission_strength;
	ROUGHNESS=mix(.78+.16*folded,.44,molten);
	SPECULAR=.3;
	float height=(folded*.07+grain*.007)*(1.0-molten);
	vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX),r1=cross(dy,NORMAL),r2=cross(NORMAL,dx);float determinant=dot(dx,r1);
	if(abs(determinant)>.000001)NORMAL=normalize(NORMAL-clamp((r1*dFdx(height)+r2*dFdy(height))/determinant,vec3(-.35),vec3(.35))*lava_normal_strength);
}
