shader_type spatial;
render_mode cull_disabled,diffuse_burley,specular_schlick_ggx;
uniform int kind=0;
varying vec3 world;
varying vec3 world_normal;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1)),f.x),f.y),f.z);}
void fragment(){
 vec3 n=normalize(world_normal);if(!FRONT_FACING)n=-n;
 float grain=noise(world*.8),macro=noise(world*.035),height=0.0;
 ALBEDO=COLOR.rgb*(.32+macro*.28+grain*.16);ROUGHNESS=.86;
 if(kind==0){height=noise(world*.28)*.22+grain*.025;AO=.65;}
 if(kind==1){
  vec3 p=world*.06+vec3(TIME*.011,0,TIME*.006);float crust=noise(p+noise(p*.41)*2.0),fold=abs(sin(world.x*.18+sin(world.z*.12)+TIME*.04));
  float molten=1.0-smoothstep(.39,.57,crust+fold*.12);
  ALBEDO=mix(vec3(.022,.018,.016),vec3(.1,.025,.004),molten);EMISSION=mix(vec3(.08,.012,.001),vec3(2.5,.34,.014),molten);ROUGHNESS=mix(.88,.24,molten);height=crust*.13;
 }
 if(kind==2){
  float ripple=sin(world.x*.23+TIME*.28+noise(world*.06)*6.0)*sin(world.z*.17-TIME*.18);
  ALBEDO=mix(vec3(.022,.036,.027),vec3(.065,.13,.075),macro);ROUGHNESS=.18;SPECULAR=.65;height=ripple*.025;
  EMISSION=vec3(.025,.12,.055)*smoothstep(.73,.91,noise(world*.11+vec3(TIME*.012)));
 }
 if(kind==3){
  float foam=smoothstep(.34,.68,noise(vec3(world.x*.7,world.y*.45+TIME*2.0,world.z*.17)));
  ALBEDO=mix(vec3(.12,.24,.25),vec3(.72,.8,.77),foam);ROUGHNESS=.24+foam*.48;SPECULAR=.5;height=foam*.035;
 }
 vec3 dx=dFdx(world),dy=dFdy(world),r1=cross(dy,n),r2=cross(n,dx);float det=dot(dx,r1);
 if(abs(det)>.000001)n=normalize(n-clamp((r1*dFdx(height)+r2*dFdy(height))/det,vec3(-.6),vec3(.6)));
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0)).xyz);
}
