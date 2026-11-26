// Gradient of smoothly interpolated noise gives short ripples with varying directions.
float ripple_hash(vec2 cell){
 vec3 q=fract(cell.xyx*vec3(.1031,.1030,.0973));
 q+=dot(q,q.yzx+33.33);
 return fract((q.x+q.y)*q.z);
}
vec2 ripple_slope(vec2 p){
 vec2 cell=floor(p),f=fract(p),w=f*f*(3.0-2.0*f);
 float a=ripple_hash(cell),b=ripple_hash(cell+vec2(1,0));
 float c=ripple_hash(cell+vec2(0,1)),d=ripple_hash(cell+vec2(1,1));
 vec2 gradient=6.0*f*(1.0-f)*vec2(mix(b-a,d-c,w.y),mix(c-a,d-b,w.x));
 return gradient*(1.0-smoothstep(.15,.8,max(fwidth(p.x),fwidth(p.y))));
}
vec2 water_ripples(vec2 world,float time){
 return .65*ripple_slope(world*.17+vec2(.12,.08)*time)
       +.35*ripple_slope(world*.47+vec2(-.09,.18)*time);
}
