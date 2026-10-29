uniform sampler2DArray cave_entry_colors:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2DArray cave_entry_normals:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform int cave_entry_geology=0;
uniform bool cave_entry_compact_palette=false;
vec2 entry_rock_slope(vec2 encoded){vec2 xy=encoded*2.0-1.0;return xy/max(sqrt(max(1.0-dot(xy,xy),.001)),.3);}
void shade_cave_entry(vec3 position,vec3 n,vec3 position_dx,vec3 position_dy,out vec3 base,out float rough,out vec3 mapped){
 float wall_layer=0.0,floor_layer=6.0;if(cave_entry_geology==1){wall_layer=1.0;floor_layer=5.0;}if(cave_entry_geology==2){wall_layer=2.0;floor_layer=7.0;}if(cave_entry_geology==3){wall_layer=3.0;floor_layer=4.0;}if(cave_entry_geology==4){wall_layer=0.0;floor_layer=5.0;}if(cave_entry_geology==5){wall_layer=3.0;floor_layer=6.0;}
 if(cave_entry_geology==6){wall_layer=7.0;floor_layer=7.0;}
 if(cave_entry_compact_palette){wall_layer=0.0;floor_layer=0.0;}
 vec3 p=position/4.0,dx=position_dx/4.0,dy=position_dy/4.0,weights=pow(abs(n),vec3(6));weights/=max(dot(weights,vec3(1)),.0001);float layer=n.y>.7?floor_layer:wall_layer;vec4 surface=vec4(0);vec3 slope=vec3(0);
 if(weights.x>.002){vec2 uv=vec2(p.z,-p.y*sign(n.x)),gx=vec2(dx.z,-dx.y*sign(n.x)),gy=vec2(dy.z,-dy.y*sign(n.x));surface+=textureGrad(cave_entry_colors,vec3(uv,layer),gx,gy)*weights.x;vec2 t=entry_rock_slope(textureGrad(cave_entry_normals,vec3(uv,layer),gx,gy).rg);slope+=vec3(0,-t.y*sign(n.x),t.x)*weights.x;}
 if(weights.y>.002){vec2 uv=vec2(p.x,-p.z*sign(n.y)),gx=vec2(dx.x,-dx.z*sign(n.y)),gy=vec2(dy.x,-dy.z*sign(n.y));surface+=textureGrad(cave_entry_colors,vec3(uv,layer),gx,gy)*weights.y;vec2 t=entry_rock_slope(textureGrad(cave_entry_normals,vec3(uv,layer),gx,gy).rg);slope+=vec3(t.x,0,-t.y*sign(n.y))*weights.y;}
 if(weights.z>.002){vec2 uv=vec2(p.x,p.y*sign(n.z)),gx=vec2(dx.x,dx.y*sign(n.z)),gy=vec2(dy.x,dy.y*sign(n.z));surface+=textureGrad(cave_entry_colors,vec3(uv,layer),gx,gy)*weights.z;vec2 t=entry_rock_slope(textureGrad(cave_entry_normals,vec3(uv,layer),gx,gy).rg);slope+=vec3(t.x,t.y*sign(n.z),0)*weights.z;}
 vec3 tint=vec3(1);if(cave_entry_geology==0)tint=vec3(1.10,1.04,.91);if(cave_entry_geology==1)tint=vec3(.94,.97,1.02);if(cave_entry_geology==2)tint=vec3(1.03,.96,.88);if(cave_entry_geology==3)tint=vec3(.96,.94,.90);if(cave_entry_geology==4)tint=vec3(.87,.94,.98);if(cave_entry_geology==5)tint=vec3(.96,.87,.79);
 if(cave_entry_geology==6)tint=vec3(.91,.77,.61);
 float broad=.96+.04*sin(position.x*.016362462)*sin(position.z*.016362462);float strata=cave_entry_geology==2?1.0-.06*smoothstep(.75,.95,.5+.5*sin(position.y*1.5707963+position.x*.016362462)):1.0;slope-=n*dot(slope,n);slope*=min(1.0,.8/max(length(slope),.0001));mapped=normalize(n+slope*.7);base=surface.rgb*tint*broad*strata;rough=clamp(surface.a,.68,.98);
}
