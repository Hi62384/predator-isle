uniform sampler2DArray cave_frozen_colors:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2DArray cave_frozen_normals:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform float cave_frozen_texture_metres=6.0;
uniform float cave_frozen_normal_strength=.35;
vec2 cave_frozen_slope(vec2 encoded){vec2 xy=encoded*2.0-1.0;return xy/max(sqrt(max(1.0-dot(xy,xy),.001)),.3);}
vec2 cave_frozen_detail(vec2 uv,vec2 dx,vec2 dy,float frost){vec2 ice=cave_frozen_slope(textureGrad(cave_frozen_normals,vec3(uv,0),dx,dy).rg);vec2 snow=cave_frozen_slope(textureGrad(cave_frozen_normals,vec3(uv*3.0,1),dx*3.0,dy*3.0).rg);return mix(ice,snow*.35,frost);}
void cave_frozen_sample(vec3 position,vec3 texture_position,vec3 n,vec3 position_dx,vec3 position_dy,out vec3 base,out float rough,out vec3 mapped){
 vec3 p=texture_position/max(cave_frozen_texture_metres,.5),dx=position_dx/max(cave_frozen_texture_metres,.5),dy=position_dy/max(cave_frozen_texture_metres,.5);
 // Every macro frequency divides the common3840m world phase. Texture
 // phase is independent and uses the actual configurable repeat length.
 float crust=smoothstep(.35,.82,.5+.5*sin(position.x*(6.283185307179586/60.0)+position.z*(6.283185307179586/80.0)+sin(position.y*(6.283185307179586/96.0))))*mix(.32,.7,max(n.y,0.0));
 vec3 weights=pow(abs(n),vec3(6.0));weights/=max(dot(weights,vec3(1)),.0001);vec4 ice=vec4(0),frost=vec4(0);vec3 slope=vec3(0);
 if(weights.x>.002){vec2 uv=vec2(p.z,-p.y*sign(n.x)),gx=vec2(dx.z,-dx.y*sign(n.x)),gy=vec2(dy.z,-dy.y*sign(n.x));ice+=textureGrad(cave_frozen_colors,vec3(uv,0),gx,gy)*weights.x;frost+=textureGrad(cave_frozen_colors,vec3(uv*3.0,1),gx*3.0,gy*3.0)*weights.x;vec2 t=cave_frozen_detail(uv,gx,gy,crust);slope+=vec3(0,-t.y*sign(n.x),t.x)*weights.x;}
 if(weights.y>.002){vec2 uv=vec2(p.x,-p.z*sign(n.y)),gx=vec2(dx.x,-dx.z*sign(n.y)),gy=vec2(dy.x,-dy.z*sign(n.y));ice+=textureGrad(cave_frozen_colors,vec3(uv,0),gx,gy)*weights.y;frost+=textureGrad(cave_frozen_colors,vec3(uv*3.0,1),gx*3.0,gy*3.0)*weights.y;vec2 t=cave_frozen_detail(uv,gx,gy,crust);slope+=vec3(t.x,0,-t.y*sign(n.y))*weights.y;}
 if(weights.z>.002){vec2 uv=vec2(p.x,p.y*sign(n.z)),gx=vec2(dx.x,dx.y*sign(n.z)),gy=vec2(dy.x,dy.y*sign(n.z));ice+=textureGrad(cave_frozen_colors,vec3(uv,0),gx,gy)*weights.z;frost+=textureGrad(cave_frozen_colors,vec3(uv*3.0,1),gx*3.0,gy*3.0)*weights.z;vec2 t=cave_frozen_detail(uv,gx,gy,crust);slope+=vec3(t.x,t.y*sign(n.z),0)*weights.z;}
 // Broad optical thickness/frost proxies,not emission or a claimed measured
 // subsurface solution. Most ice is opaque;clear thin features are separate.
 float thickness=.5+.5*sin(position.x*(6.283185307179586/384.0)+sin(position.y*(6.283185307179586/480.0))+position.z*(6.283185307179586/320.0));
 // Compress the original ice scan/procedural colour contrast;its cracks
 // supply detail rather than a repeated field of dark tile-sized boulders.
 vec3 dense=mix(vec3(.48,.63,.71),ice.rgb*vec3(.8,.94,1.0),.24);
 dense*=mix(vec3(.88,.96,1.0),vec3(.50,.72,.85),thickness*.5);
 base=mix(dense,frost.rgb*vec3(.9,.96,1.0),crust);rough=mix(clamp(ice.a*.48,.13,.38),clamp(frost.a,.7,.97),crust);slope-=n*dot(slope,n);slope*=min(1.0,.30/max(length(slope),.0001));mapped=normalize(n+slope*cave_frozen_normal_strength);
}
