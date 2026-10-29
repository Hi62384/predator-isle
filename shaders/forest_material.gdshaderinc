// Terrain only. Scan-driven surfaces; environmental masks select at most three roles.
uniform sampler2DArray forest_colors:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2DArray forest_normals:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform float forest_gain=.72;
uniform float forest_leaves=.85;
uniform float forest_needles=.9;
uniform float forest_soil=.4;
uniform float forest_moss=.55;
uniform float forest_wetness=.5;
uniform float forest_rock=.65;
uniform float forest_macro=.12;
uniform float forest_litter_metres=3.0;
uniform float forest_soil_metres=3.5;
uniform float forest_moss_metres=3.0;
uniform float forest_rock_metres=10.0;
uniform float forest_normal_strength=.85;
uniform float forest_rock_normal=.8;
uniform float forest_path_coverage=.55;
uniform float forest_path_width=2.8;
uniform float forest_path_falloff=1.4;
uniform float forest_path_spacing=650.0;
int forest_shared_id(int id){return id==2?1:(id==3?6:(id==4?2:(id==5?3:(id==6?4:5))));}
vec4 forest_texel(int id,vec2 uv,vec2 dx,vec2 dy){
 if(id==0)return mix(textureGrad(jungle_colors,vec3(uv,0),dx,dy),textureGrad(forest_colors,vec3(uv,0),dx,dy),.18);
 if(id==1)return textureGrad(forest_colors,vec3(uv,1),dx,dy);
 if(id==8){vec4 s=textureGrad(palette_color,vec3(uv,0),dx,dy);s.rgb*=vec3(.58,.72,.44);return s;}
 return textureGrad(jungle_colors,vec3(uv,float(forest_shared_id(id))),dx,dy);
}
vec2 forest_normal_texel(int id,vec2 uv,vec2 dx,vec2 dy){
 if(id==0)return mix(textureGrad(jungle_normals,vec3(uv,0),dx,dy).rg,textureGrad(forest_normals,vec3(uv,0),dx,dy).rg,.18);
 if(id==1)return textureGrad(forest_normals,vec3(uv,1),dx,dy).rg;
 if(id==8)return textureGrad(palette_normal,vec3(uv,0),dx,dy).rg;
 return textureGrad(jungle_normals,vec3(uv,float(forest_shared_id(id))),dx,dy).rg;
}
void forest_projected(int id,vec2 uv,vec2 world_uv,vec2 dx,vec2 dy,float fine,out vec4 surface,out vec3 t){
 // Texture phase uses local coordinates + wrapped chunk origin. Only the broad
 // anti-repeat selector uses world UV: no quarter-metre texel quantization at
 // multi-million-metre saved-world starts, and no chunk-local noise resets.
 float k=field(world_uv*.19+vec2(63.7,11.3))*8.0;
 float index=floor(k),blend=smoothstep(.1,.9,fract(k));
 vec2 a=uv+sin(vec2(3,7)*index)*19.0,b=uv+sin(vec2(3,7)*(index+1.0))*19.0;
 surface=mix(forest_texel(id,a,dx,dy),forest_texel(id,b,dx,dy),blend);
 t=vec3(0,0,1);
 if(fine>.001){t=normalize(mix(unpack_normal(forest_normal_texel(id,a,dx,dy)),unpack_normal(forest_normal_texel(id,b,dx,dy)),blend));t.xy/=max(t.z,.35);}
}
vec4 forest_average(int id){
 if(id==0)return mix(textureLod(jungle_colors,vec3(0,0,0),11.0),textureLod(forest_colors,vec3(0,0,0),11.0),.18);
 if(id==1)return textureLod(forest_colors,vec3(0,0,1),11.0);
 if(id==8){vec4 s=textureLod(palette_color,vec3(0,0,0),12.0);s.rgb*=vec3(.58,.72,.44);return s;}
 int shared_id=id==2?1:(id==3?6:(id==4?2:(id==5?3:(id==6?4:5))));
 return textureLod(jungle_colors,vec3(0,0,float(shared_id)),11.0);
}
void forest_sample(int id,float metres,vec3 dx,vec3 dy,vec3 projection,vec3 n,float fine,out vec4 surface,out vec3 gradient){
 // Quarter-metre repeats keep the origin remainder exactly representable at
 // the saved world's multi-million-metre integer chunk coordinates.
 metres=max(round(metres*4.0)*.25,.25);
 int quarter_period=int(round(metres*4.0));
 ivec3 q=ivec3(round(forest_origin*4.0));
 ivec3 period=ivec3(quarter_period);
 // GLSL signed remainder is not portable for negative operands. Divide only
 // positive magnitudes, then reflect the phase explicitly on negative axes.
 ivec3 r=abs(q)%period;
 if(q.x<0 && r.x>0)r.x=quarter_period-r.x;
 if(q.y<0 && r.y>0)r.y=quarter_period-r.y;
 if(q.z<0 && r.z>0)r.z=quarter_period-r.z;
 vec3 remainder=vec3(r)*.25;
 vec3 p=forest_local_position/metres+remainder/metres;
 vec3 wp=world_position/metres;dx/=metres;dy/=metres;
 surface=vec4(0);gradient=vec3(0);
 if(projection.x>.002){vec4 s;vec3 t;forest_projected(id,vec2(p.z,-p.y*sign(n.x)),vec2(wp.z,-wp.y*sign(n.x)),vec2(dx.z,-dx.y*sign(n.x)),vec2(dy.z,-dy.y*sign(n.x)),fine,s,t);surface+=s*projection.x;gradient+=vec3(0,-t.y*sign(n.x),t.x)*projection.x;}
 if(projection.y>.002){vec4 s;vec3 t;forest_projected(id,vec2(p.x,-p.z*sign(n.y)),vec2(wp.x,-wp.z*sign(n.y)),vec2(dx.x,-dx.z*sign(n.y)),vec2(dy.x,-dy.z*sign(n.y)),fine,s,t);surface+=s*projection.y;gradient+=vec3(t.x,0,-t.y*sign(n.y))*projection.y;}
 if(projection.z>.002){vec4 s;vec3 t;forest_projected(id,vec2(p.x,p.y*sign(n.z)),vec2(wp.x,wp.y*sign(n.z)),vec2(dx.x,dx.y*sign(n.z)),vec2(dy.x,dy.y*sign(n.z)),fine,s,t);surface+=s*projection.z;gradient+=vec3(t.x,t.y*sign(n.z),0)*projection.z;}
}
void shade_forest(vec3 n,vec3 dx,vec3 dy,vec3 projection,float fine,out vec3 color,out float rough,out vec3 gradient,out vec3 material_mix,out vec3 diagnostics){
 float wet=forest_control.x,drain=forest_control.y,conifer=forest_ecology.x,clearing=forest_ecology.y;
 float slope=1.0-clamp(n.y,0.0,1.0);
 float broad=ground_field(world_position.xz/270.0+vec2(17,79));
 float sheltered=(1.0-smoothstep(.25,.65,slope))*mix(.7,1.0,drain);
 float rock=clamp(smoothstep(.12,.5,slope)*forest_geology.x*1.9*forest_rock,0.0,1.0);
 float bank=(1.0-smoothstep(1.5,8.0,abs(world_position.y-water_level)))*smoothstep(.35,.7,wet);
 float mud=clamp(smoothstep(.5,.9,wet)*drain*forest_wetness+bank*.55,0.0,.85)*(1.0-rock);
 float moss=clamp(smoothstep(.35,.8,wet)*sheltered*forest_moss*(.65+broad*.35),0.0,.65)*(1.0-clearing*.6);
 float soil=clamp(forest_soil*(slope*.9+(1.0-wet)*.15)+bank*.15,0.0,.65);
 float path=0.0;
 if(slope<.22 && forest_path_coverage>.001){
  vec2 wear=ground_trail(world_position.xz,forest_path_spacing,forest_path_width,max(length(dx.xz),length(dy.xz)),forest_path_falloff);
  path=(wear.x+wear.y*.2)*forest_path_coverage*(1.0-smoothstep(.08,.22,slope))*(1.0-forest_geology.y);
 }
 float w[9];
 w[0]=(1.0-conifer)*forest_leaves*(1.0-soil)*(1.0-clearing)*(1.0-moss)*(1.0-mud)*(1.0-rock);
 w[1]=conifer*forest_needles*(1.0-soil)*(1.0-clearing)*(1.0-moss)*(1.0-mud)*(1.0-rock);
 w[2]=(soil+path*.8)*(1.0-rock)*(1.0-mud);
 w[3]=moss*(1.0-rock)*(1.0-mud)*(1.0-path*.65);
 w[4]=(mud+path*wet*.25)*(1.0-rock);
 w[5]=(bank*.35+path*.32*forest_geology.x)*(1.0-mud)*(1.0-rock);
 w[6]=rock*(1.0-moss*.8);
 w[7]=rock*moss*.8;
 w[8]=clearing*(1.0-soil*.5)*(1.0-rock)*(1.0-mud)*(1.0-path);
 int ids[3];float selected[3];float total=0.0;
 for(int k=0;k<3;k++){int best=0;for(int j=1;j<9;j++){if(w[j]>w[best])best=j;}ids[k]=best;selected[k]=w[best];w[best]=-1.0;}
 float cutoff=0.0;for(int j=0;j<9;j++)cutoff=max(cutoff,w[j]);
 for(int k=0;k<3;k++){selected[k]=max(selected[k]-cutoff,0.0);total+=selected[k];}
 if(total<.00001){selected[0]=1.0;total=1.0;}
 color=vec3(0);gradient=vec3(0);rough=0.0;material_mix=vec3(0);
 float leaf=0.0,needle=0.0,moss_selected=0.0;
 for(int k=0;k<3;k++){
  float amount=selected[k]/total;if(amount<.003)continue;
  int id=ids[k];float metres=forest_soil_metres;
  if(id<2)metres=forest_litter_metres;
  if(id==3)metres=forest_moss_metres;
  if(id==6 || id==7)metres=forest_rock_metres;
  if(id==5)metres=forest_soil_metres*.45;
  if(id==8)metres=1.4;
  vec4 s;vec3 g;
  float distant=smoothstep(100.0,650.0,view_distance);
  if(distant>.999){s=forest_average(id);g=vec3(0);}else{forest_sample(id,metres,dx,dy,projection,n,fine,s,g);if(distant>.001)s=mix(s,forest_average(id),distant);}
  color+=s.rgb*amount;rough+=max(s.a,id==4?.5:.7)*amount;
  gradient+=g*amount*(id==6 || id==7?forest_rock_normal:forest_normal_strength);
  if(id==0)leaf+=amount;if(id==1)needle+=amount;if(id==3 || id==7)moss_selected+=amount;
  material_mix+=id_color(id)*amount;
 }
 color*=forest_gain*mix(1.0,.85,wet*forest_wetness)*(1.0+(broad-.5)*forest_macro);
 rough=clamp(rough,.45,.98);gradient-=n*dot(n,gradient);
 if(debug_view==7 || diagnostic_surface==2)gradient=vec3(0);
 diagnostics=vec3(leaf,needle,moss_selected);
 if(debug_view==107)material_mix=vec3(rock);
 if(debug_view==108)material_mix=vec3(path);
}
vec3 forest_debug(vec3 mapped,vec3 materials,vec3 diagnostics){
 vec3 result=vec3(.5)+.42*cos(vec3(0,2.1,4.2)+forest_ecology.z*9.0*2.4);
 if(debug_view==101)result=vec3(forest_ecology.x);
 if(debug_view==102)result=vec3(forest_ecology.y);
 if(debug_view==103)result=vec3(forest_control.x);
 if(debug_view==104)result=vec3(diagnostics.x);
 if(debug_view==105)result=vec3(diagnostics.y);
 if(debug_view==106)result=vec3(diagnostics.z);
 if(debug_view>=107 && debug_view<=109)result=materials;
 if(debug_view==110)result=mapped*.5+.5;
 return result*forest_control.z;
}
