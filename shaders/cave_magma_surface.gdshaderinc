// All lattice periods divide the shared 3840m material wrap. Adjacent cave
// cells therefore agree even when their local coordinates cross that wrap.
float magma_hash(vec3 p,float period){p=mod(p,vec3(period));return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float magma_field(vec3 p,float period){
 vec3 i=floor(p),f=fract(p),u=f*f*(3.0-2.0*f);
 return mix(mix(mix(magma_hash(i,period),magma_hash(i+vec3(1,0,0),period),u.x),mix(magma_hash(i+vec3(0,1,0),period),magma_hash(i+vec3(1,1,0),period),u.x),u.y),mix(mix(magma_hash(i+vec3(0,0,1),period),magma_hash(i+vec3(1,0,1),period),u.x),mix(magma_hash(i+vec3(0,1,1),period),magma_hash(i+vec3(1,1,1),period),u.x),u.y),u.z);
}
void magma_cooled_surface(vec3 p,float amount,vec3 view_position,inout vec3 color,inout vec3 normal,inout float roughness,inout float specular,inout vec3 emission){
 float province=magma_field(p/192.0,20.0),meso=magma_field(p/24.0,160.0);
 float rough_flow=smoothstep(.42,.62,province);
 float ash=smoothstep(.63,.79,magma_field(p/96.0+vec3(3,7,2),40.0));
 float flow=magma_field(p/6.0,640.0);
 float rope=sin(6.28318530718*(p.x/12.0+p.z/24.0)+flow*5.0);
 float pores=smoothstep(.59,.77,magma_field(p*2.0,7680.0));
 float dike=(1.0-smoothstep(.22,.9,abs(sin(6.28318530718*(p.x/96.0+p.z/192.0+p.y/384.0)))*14.0))*smoothstep(.48,.7,meso);
 float sill=(1.0-smoothstep(.18,.75,abs(sin(6.28318530718*p.y/24.0))*7.0))*smoothstep(.55,.72,province);
 float host_detail=clamp(dot(color,vec3(.3,.5,.2))*1.7,.4,1.25);
 vec3 basalt=mix(vec3(.035,.043,.048),vec3(.105,.078,.06),rough_flow*.45)*( .72+meso*.5);
 basalt=mix(basalt,vec3(.19,.18,.165),ash*.65);
 basalt=mix(basalt,vec3(.028,.032,.035),max(dike,sill)*.75);
 color=mix(color,basalt*host_detail,amount);
 roughness=mix(roughness,mix(mix(.31,.72,flow),.94,max(rough_flow,ash)),amount);
 specular=mix(specular,mix(.43,.28,max(rough_flow,ash)),amount);
 float fine=1.0-smoothstep(96.0,256.0,length(view_position));
 float relief=mix(rope*.055+flow*.12,pores*.065+meso*.13,rough_flow)*(1.0-ash*.65);
 vec3 dx=dFdx(view_position),dy=dFdy(view_position),r1=cross(dy,normal),r2=cross(normal,dx);float determinant=dot(dx,r1);
 if(abs(determinant)>.000001)normal=normalize(normal-clamp((r1*dFdx(relief)+r2*dFdy(relief))/determinant,vec3(-.45),vec3(.45))*fine*amount);
 emission*=1.0-amount;
}
