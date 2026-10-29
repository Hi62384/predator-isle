shader_type canvas_item;
render_mode unshaded;
uniform int channel = 0;
// Original salt-specific surface, not recolored soil or downloaded content.
// Periodic raised evaporite ridges and encrusting grains over a 2 metre tile.
vec2 hash2(vec2 p) {
 p=mod(p,6.0);
 return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);
}
float grain(vec2 p,float period) {
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 vec4 a=fract(sin(vec4(dot(mod(i,period),vec2(127.1,311.7)),dot(mod(i+vec2(1,0),period),vec2(127.1,311.7)),dot(mod(i+vec2(0,1),period),vec2(127.1,311.7)),dot(mod(i+1.0,period),vec2(127.1,311.7))))*43758.5453);
 return mix(mix(a.x,a.y,f.x),mix(a.z,a.w,f.x),f.y);
}
vec3 crust(vec2 uv) {
 vec2 p=uv*6.0+vec2(sin(uv.y*6.283185*2.0),sin(uv.x*6.283185*3.0))*0.12;
 vec2 cell=floor(p),f=fract(p);
 float first=100.0,second=100.0;
 for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++) {
  vec2 o=vec2(float(x),float(y));
  vec2 d=o+0.15+hash2(cell+o)*0.7-f;
  float q=dot(d,d);
  if(q<first){second=first;first=q;}else second=min(second,q);
 }
 float edge=sqrt(second)-sqrt(first);
 float crystals=grain(uv*240.0,240.0);
 float granules=grain(uv*610.0,610.0);
 float mantle=grain(uv*31.0,31.0);
 float rim=(1.0-smoothstep(0.015,0.13,edge))*(0.6+0.4*mantle);
 float height=rim*0.009+crystals*crystals*0.0018+granules*0.0005+mantle*0.002;
 return vec3(height,rim,crystals);
}
void fragment() {
 vec3 c=crust(UV);
 float rough=clamp(0.90+c.y*0.06-(c.z-0.5)*0.13,0.78,0.98);
 vec3 base=mix(vec3(0.67,0.65,0.59),vec3(0.91,0.90,0.86),clamp(0.55+c.y*0.4+c.z*0.15,0.0,1.0));
 if(channel==0)COLOR=vec4(base,1.0);
 if(channel==1){float e=1.0/2048.0;float hx=(crust(UV+vec2(e,0)).x-crust(UV-vec2(e,0)).x)/(4.0*e);float hy=(crust(UV+vec2(0,e)).x-crust(UV-vec2(0,e)).x)/(4.0*e);COLOR=vec4(normalize(vec3(-hx,-hy,1.0))*0.5+0.5,1.0);}
 if(channel==2)COLOR=vec4(vec3(rough),1.0);
 if(channel==3)COLOR=vec4(vec3(c.x/0.014),1.0);
}
