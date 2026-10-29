// Version 4: smooth Cartesian fields; the CPU oracle uses the same equations.
uniform vec3 body_radii=vec3(1.0);
uniform float circulation=0.0;
uniform float compression=0.0;
uniform float body_height=1.0;
uniform mat3 pose_frame=mat3(1.0);
uniform vec3 strain=vec3(0.0);
uniform vec3 idle_shear=vec3(0.0);
uniform int pulse_count=0;
uniform vec4 pulse_cells[8];
uniform float pulse_values[8];
uniform int chain_count=0;
uniform vec4 chain_rest[128];
uniform vec4 chain_pose[128];
uniform vec4 chain_rest_normal[128];
uniform vec4 chain_pose_normal[128];
uniform bool debug_circulation=false;
uniform bool debug_features=false;
uniform bool rest_pose=false;
uniform bool debug_strain=false;
uniform float follow_through=.6;
uniform float wobble=.45;
vec3 base_deform(vec3 p){
	for(int i=0;i<pulse_count;i++){
		vec3 d=p-pulse_cells[i].xyz;
		p+=d*pulse_values[i]*exp(-2.0*dot(d,d)/(pulse_cells[i].w*pulse_cells[i].w));
	}
	float co=cos(-circulation),si=sin(-circulation);
	vec2 q=p.yz/body_radii.yz;
	p.yz=vec2(co*q.x-si*q.y,si*q.x+co*q.y)*body_radii.yz;
	for(int i=0;i<3;i++){
		float width=body_radii.z*.6;
		float center=(float(i)-1.0)*body_radii.z*.5;
		float th=tanh((p.z-center)/width);
		float a=clamp(strain[i],-.1,.22);
		float derivative=1.0-a*(1.0-th*th);
		p.z-=a*width*th;p.xy*=inversesqrt(derivative);
	}
	p.x+=body_radii.x*idle_shear.x*exp(-pow(p.y/body_radii.y,2.0)-pow(p.z/body_radii.z,2.0));
	p.z+=body_radii.z*idle_shear.z*exp(-pow(p.x/body_radii.x,2.0)-pow(p.y/body_radii.y,2.0));
	p.y+=body_radii.y*idle_shear.y*exp(-pow(p.x/body_radii.x,2.0)-pow(p.z/body_radii.z,2.0));
	float width=body_radii.y*.9;
	float v=(p.y+body_radii.y)/width;
	float derivative=1.0-2.0*compression*body_radii.y*v/width*exp(-v*v);
	p.y+=compression*body_radii.y*exp(-v*v);p.xz*=inversesqrt(derivative);
	return pose_frame*p;
}
vec3 chain_point(int id,float t,bool posed){
	float u=clamp(t,0.0,1.0)*7.0;int i=min(int(u),6);float f=u-float(i);int offset=id*8;
	vec3 a=posed?chain_pose[offset+max(i-1,0)].xyz:chain_rest[offset+max(i-1,0)].xyz;
	vec3 b=posed?chain_pose[offset+i].xyz:chain_rest[offset+i].xyz;
	vec3 c=posed?chain_pose[offset+i+1].xyz:chain_rest[offset+i+1].xyz;
	vec3 d=posed?chain_pose[offset+min(i+2,7)].xyz:chain_rest[offset+min(i+2,7)].xyz;
	float len=length(c-b);
	vec3 m0=(c-a)*.5,m1=(d-b)*.5;
	m0*=min(1.0,len*.75/max(length(m0),.00001));m1*=min(1.0,len*.75/max(length(m1),.00001));
	return b*(2.0*f*f*f-3.0*f*f+1.0)+m0*(f*f*f-2.0*f*f+f)+c*(-2.0*f*f*f+3.0*f*f)+m1*(f*f*f-f*f);
}
vec3 chain_tangent(int id,float t,bool posed){return normalize(chain_point(id,min(1.0,t+.001),posed)-chain_point(id,max(0.0,t-.001),posed));}
mat3 chain_frame(int id,float t,bool posed){
	float u=clamp(t,0.0,1.0)*7.0;int i=min(int(u),6);int offset=id*8;
	vec3 a=posed?chain_pose_normal[offset+i].xyz:chain_rest_normal[offset+i].xyz;
	vec3 b=posed?chain_pose_normal[offset+i+1].xyz:chain_rest_normal[offset+i+1].xyz;
	vec3 tangent=chain_tangent(id,t,posed);
	vec3 normal=mix(a,b,u-float(i));normal=normalize(normal-tangent*dot(normal,tangent));
	return mat3(normal,normalize(cross(tangent,normal)),tangent);
}
vec3 deform_vertex(vec3 rest,vec4 bind,vec4 chain,vec4 anchor){
	if(rest_pose)return rest;
	int id=int(chain.x+.1)-1;
	if(bind.z<-.5){
		int other=int(chain.z+.1)-1;
		if(id>=0&&other>=0&&id<chain_count&&other<chain_count){
			vec3 a=chain_point(id,chain.y,true),b=chain_point(other,chain.y,true);
			vec3 axis=chain_tangent(id,chain.y,true)+chain_tangent(other,chain.y,true);
			vec3 n=normalize(cross(b-a,axis));
			return mix(a,b,chain.w)+n*(anchor.x-anchor.y*4.0*chain.w*(1.0-chain.w));
		}
	}
	if(id>=0&&id<chain_count)return chain_point(id,chain.y,true)+chain_frame(id,chain.y,true)*anchor.xyz;
	return base_deform(rest);
}
mat3 sheet_frame(int first,int second,float t,bool posed){
	vec3 x=normalize(chain_point(second,t,posed)-chain_point(first,t,posed));
	vec3 y=chain_tangent(first,t,posed)+chain_tangent(second,t,posed);
	y=normalize(y-x*dot(x,y));
	return mat3(x,y,normalize(cross(x,y)));
}
vec3 deform_normal(vec3 rest,vec3 normal,vec4 bind,vec4 chain){
	if(rest_pose)return normal;
	int id=int(chain.x+.1)-1;
	if(bind.z<-.5){int other=int(chain.z+.1)-1;if(id>=0&&other>=0&&id<chain_count&&other<chain_count)return normalize(sheet_frame(id,other,chain.y,true)*transpose(sheet_frame(id,other,chain.y,false))*normal);}
	if(id>=0&&id<chain_count)return normalize(chain_frame(id,chain.y,true)*transpose(chain_frame(id,chain.y,false))*normal);
	float e=.0007;vec3 p=base_deform(rest);
	vec3 x=(base_deform(rest+vec3(e,0,0))-p)/e;
	vec3 y=(base_deform(rest+vec3(0,e,0))-p)/e;
	vec3 z=(base_deform(rest+vec3(0,0,e))-p)/e;
	return normalize(cross(y,z)*normal.x+cross(z,x)*normal.y+cross(x,y)*normal.z);
}
