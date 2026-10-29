// Seven shared CC0 scans. Noise selects environmental mixtures, never surface detail.
uniform sampler2DArray jungle_colors:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2DArray jungle_normals:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform float jungle_organic=.65;
uniform float jungle_albedo_gain=.9;
// Explicit linear RGB; Inspector tint is converted once on binding.
uniform vec3 jungle_green_tint=vec3(.03955,.27384,.00657);
uniform float jungle_green_coverage=.96;
uniform float jungle_litter=.75;
uniform float jungle_mud=.55;
uniform float jungle_moss=.65;
uniform float jungle_rock=.65;
uniform float jungle_macro=.12;
uniform float jungle_ground_metres=3.0;
uniform float jungle_rock_metres=12.0;
uniform float jungle_normal_strength=.9;
uniform float jungle_rock_normal=.8;
uniform float jungle_canopy=.8;
uniform float jungle_clearing=.12;
void jungle_projected(int id,vec2 uv,vec2 dx,vec2 dy,float fine,out vec4 surface,out vec3 t){
 float k=field(uv*.19+vec2(63.7,11.3))*8.0;
 float index=floor(k),blend=smoothstep(.1,.9,fract(k));
 vec2 a=uv+sin(vec2(3,7)*index)*19.0,b=uv+sin(vec2(3,7)*(index+1.0))*19.0;
 surface=mix(textureGrad(jungle_colors,vec3(a,float(id)),dx,dy),textureGrad(jungle_colors,vec3(b,float(id)),dx,dy),blend);
 t=vec3(0,0,1);
 if(fine>.001){t=normalize(mix(unpack_normal(textureGrad(jungle_normals,vec3(a,float(id)),dx,dy).rg),unpack_normal(textureGrad(jungle_normals,vec3(b,float(id)),dx,dy).rg),blend));t.xy/=max(t.z,.35);}
}
void jungle_sample(int id,float metres,vec3 dx,vec3 dy,vec3 projection,vec3 n,float fine,out vec4 surface,out vec3 gradient){
 vec3 p=world_position/max(metres,.1);dx/=max(metres,.1);dy/=max(metres,.1);
 surface=vec4(0);gradient=vec3(0);
 if(projection.x>.002){vec4 s;vec3 t;jungle_projected(id,vec2(p.z,-p.y*sign(n.x)),vec2(dx.z,-dx.y*sign(n.x)),vec2(dy.z,-dy.y*sign(n.x)),fine,s,t);surface+=s*projection.x;gradient+=vec3(0,-t.y*sign(n.x),t.x)*projection.x;}
 if(projection.y>.002){vec4 s;vec3 t;jungle_projected(id,vec2(p.x,-p.z*sign(n.y)),vec2(dx.x,-dx.z*sign(n.y)),vec2(dy.x,-dy.z*sign(n.y)),fine,s,t);surface+=s*projection.y;gradient+=vec3(t.x,0,-t.y*sign(n.y))*projection.y;}
 if(projection.z>.002){vec4 s;vec3 t;jungle_projected(id,vec2(p.x,p.y*sign(n.z)),vec2(dx.x,dx.y*sign(n.z)),vec2(dy.x,dy.y*sign(n.z)),fine,s,t);surface+=s*projection.z;gradient+=vec3(t.x,t.y*sign(n.z),0)*projection.z;}
}
void shade_jungle(vec3 n,vec3 dx,vec3 dy,vec3 projection,float fine,out vec3 color,out float rough,out vec3 gradient,out vec3 weights){
 float wet=jungle_control.x,drain=jungle_control.y,slope=1.0-clamp(n.y,0.0,1.0);
 float macro=field(world_position.xz/430.0+vec2(17,83));
 float rock=smoothstep(.19,.57,slope)*clamp(geology_control.y*1.7*jungle_rock,0.0,1.0);
 float bank=(1.0-smoothstep(1.0,9.0,abs(world_position.y-water_level)))*smoothstep(.25,.75,wet);
 float mud=clamp(smoothstep(.46,.9,wet)*drain*jungle_mud+bank*.65,0.0,.95)*(1.0-rock);
 float litter=clamp(jungle_litter/(jungle_litter+jungle_organic+.001)*(1.0-mud*.8),0.0,1.0);
 vec4 soil;vec3 sg;jungle_sample(1,jungle_ground_metres,dx,dy,projection,n,fine,soil,sg);
 vec4 leaves=soil;vec3 lg=sg;
 if(litter>.001)jungle_sample(0,jungle_ground_metres*1.2,dx,dy,projection,n,fine,leaves,lg);
 color=mix(soil.rgb,leaves.rgb,litter);rough=mix(soil.a,leaves.a,litter);gradient=mix(sg,lg,litter)*jungle_normal_strength;
 vec4 cover;vec3 cover_g;jungle_sample(6,jungle_ground_metres,dx,dy,projection,n,fine,cover,cover_g);
 float cover_luma=dot(cover.rgb,vec3(.2126,.7152,.0722));
 vec3 living_cover=mix(cover.rgb,jungle_green_tint*clamp(cover_luma/.42,.35,1.8),.85);
 float living_amount=jungle_green_coverage*(1.0-mud*.7);
 color=mix(color,living_cover,living_amount);rough=mix(rough,max(cover.a,.78),living_amount);gradient=mix(gradient,cover_g*jungle_normal_strength,living_amount);
 if(mud>.001){vec4 s;vec3 g;jungle_sample(2,jungle_ground_metres*1.7,dx,dy,projection,n,fine,s,g);color=mix(color,s.rgb,mud);rough=mix(rough,max(s.a,.48),mud);gradient=mix(gradient,g*jungle_normal_strength*.65,mud);}
 float gravel=bank*(1.0-mud*.6)*(1.0-rock)*.65;
 if(gravel>.001){vec4 s;vec3 g;jungle_sample(3,jungle_ground_metres,dx,dy,projection,n,fine,s,g);color=mix(color,s.rgb,gravel);rough=mix(rough,s.a,gravel);gradient=mix(gradient,g*jungle_normal_strength,gravel);}
 // Scanned moss already contains its own organic edge shapes. Shelter and
 // moisture choose the scan, not a high-frequency green paint mask.
 float moss=clamp(wet*jungle_moss*(.65-n.y*.15)*(1.0-smoothstep(.65,.9,slope)),0.0,.7);
 if(rock>.001){
  vec4 s;vec3 g;jungle_sample(4,jungle_rock_metres,dx,dy,projection,n,fine,s,g);
  if(moss>.001){vec4 ms;vec3 mg;jungle_sample(5,jungle_rock_metres,dx,dy,projection,n,fine,ms,mg);s=mix(s,ms,moss);g=mix(g,mg,moss);}
  color=mix(color,s.rgb,rock);rough=mix(rough,s.a,rock);gradient=mix(gradient,g*jungle_rock_normal,rock);
 }
 float ground_moss=smoothstep(.7,.94,wet)*jungle_moss*(1.0-mud)*(1.0-rock)*.3;
 if(ground_moss>.001){vec4 s;vec3 g;jungle_sample(6,jungle_ground_metres,dx,dy,projection,n,fine,s,g);color=mix(color,s.rgb,ground_moss);gradient=mix(gradient,g*jungle_normal_strength,ground_moss);rough=mix(rough,s.a,ground_moss);}
 color*=jungle_albedo_gain*mix(1.0,.88,wet*.6)*(1.0+(macro-.5)*jungle_macro);
 rough=clamp(rough,.45,.98);gradient-=n*dot(n,gradient);
 if(debug_view==7 || diagnostic_surface==2)gradient=vec3(0);
 weights=vec3((1.0-rock)*(1.0-mud),mud,rock);
}
vec3 jungle_debug(vec3 n,vec3 weights){
 vec3 result=vec3(.5)+.42*cos(vec3(0,2.1,4.2)+geology_control.x*12.0*2.4);
 if(debug_view==81)result=vec3(jungle_control.x);
 if(debug_view==82)result=vec3(jungle_control.y);
 if(debug_view==83)result=vec3(weights.z);
 if(debug_view==84)result=vec3(geology_control.z);
 if(debug_view==85)result=weights;
 if(debug_view==86)result=n*.5+.5;
 if(debug_view==87)result=vec3(jungle_canopy*(1.0-weights.z)*(1.0-geology_control.z)*(1.0-jungle_clearing*field(world_position.xz/300.0)));
 return result*jungle_control.z;
}
