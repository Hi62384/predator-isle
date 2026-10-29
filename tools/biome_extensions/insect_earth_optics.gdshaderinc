// Physical metre scales; a common signed period preserves chunk joins.
// Only apparent millimetre/centimetre relief, never metre-sized fake grooves.
float earth_hash(vec3 cell, float period){
 vec3 p=mod(cell,vec3(period));p=fract(p*.1031);p+=dot(p,p.yzx+33.33);
 return fract((p.x+p.y)*p.z);
}
float earth_noise(vec3 metres,float scale){
 vec3 p=metres/scale,i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);float period=3840.0/scale;
 return mix(mix(mix(earth_hash(i,period),earth_hash(i+vec3(1,0,0),period),f.x),mix(earth_hash(i+vec3(0,1,0),period),earth_hash(i+vec3(1,1,0),period),f.x),f.y),mix(mix(earth_hash(i+vec3(0,0,1),period),earth_hash(i+vec3(1,0,1),period),f.x),mix(earth_hash(i+vec3(0,1,1),period),earth_hash(i+vec3(1,1,1),period),f.x),f.y),f.z);
}
vec3 earth_working_color(vec3 srgb){
 if(OUTPUT_IS_SRGB)return srgb;
 return mix(srgb/12.92,pow((srgb+vec3(.055))/1.055,vec3(2.4)),step(vec3(.04045),srgb));
}
vec3 earth_unpack(vec2 value){vec2 xy=value*2.0-1.0;float z=sqrt(max(1.0-dot(xy,xy),.05));return vec3(xy/max(z,.35),1.0);}
