// Existing distinct photographed sediment/rock PBR sources, no generated bitmap.
uniform float badlands_strata_metres=84.0;
uniform float badlands_thickness_variation=.16;
uniform vec2 badlands_strata_dip=vec2(.018,.012);
uniform float badlands_fold_strength=1.0;
uniform float badlands_height_multiplier=1.0;
uniform float badlands_strata_strength=.75;
uniform float badlands_lamina_strength=.18;
uniform float badlands_regional_strength=.85;
uniform float badlands_weathering=.4;
uniform float badlands_gravel=.65;
uniform float badlands_ground_metres=2.0;
uniform float badlands_rock_metres=6.0;
uniform float badlands_normal_strength=.75;
uniform float badlands_gain=.8;
uniform int badlands_quality=3;
// Four regional material controls, not unique PBR imagery or an extra varying.
uniform bool badlands_palette_enabled=false;
uniform int badlands_palette_slot=0;
vec4 badlands_palette_controls(){
 ivec2 size=textureSize(extension_payload,0);float row=float(size.y);
 vec2 grid=clamp(forest_local_position.xz/chunk_size_metres,vec2(0),vec2(1))*(row-1.0);
 vec2 uv=vec2((float(badlands_palette_slot)*row+grid.x+.5)/float(size.x),(grid.y+.5)/row);
 return clamp(textureLod(extension_payload,uv,0.0),vec4(0),vec4(1));
}
float badlands_layer(int id){return id==0?4.0:(id==1?3.0:(id==2?6.0:7.0));}
vec4 badlands_texel(int id,vec2 uv,vec2 dx,vec2 dy){
 if(id<4)return textureGrad(savanna_colors,vec3(uv,badlands_layer(id)),dx,dy);
 if(id==4)return textureGrad(jungle_colors,vec3(uv,3.0),dx,dy);
 return textureGrad(mountain_colors,vec3(uv,1.0),dx,dy);
}
vec2 badlands_normal_texel(int id,vec2 uv,vec2 dx,vec2 dy){
 if(id<4)return textureGrad(savanna_normals,vec3(uv,badlands_layer(id)),dx,dy).rg;
 if(id==4)return textureGrad(jungle_normals,vec3(uv,3.0),dx,dy).rg;
 return textureGrad(mountain_normals,vec3(uv,1.0),dx,dy).rg;
}
vec4 badlands_average(int id){
 if(id<4)return textureLod(savanna_colors,vec3(.5,.5,badlands_layer(id)),11.0);
 if(id==4)return textureLod(jungle_colors,vec3(.5,.5,3.0),11.0);
 return textureLod(mountain_colors,vec3(.5,.5,1.0),11.0);
}
float badlands_coordinate(){
 vec2 p=world_position.xz;
 float geological_height=(world_position.y-water_level)/max(badlands_height_multiplier,.01);
 float beds=geological_height+dot(badlands_strata_dip,p)+(24.0*sin(p.x/5300.0+sin(p.y/7100.0))+17.0*sin(p.y/3900.0))*badlands_fold_strength;
 float unit=badlands_strata_metres*.35;
 float q=beds/unit+badlands_thickness_variation*sin(beds/(unit*1.7)+p.x/11000.0);
 return q;
}
float badlands_phase(){return mod(badlands_coordinate(),5.0);}
float badlands_hardness(float phase){
 return max(smoothstep(.48,.53,phase)*(1.0-smoothstep(.67,.74,phase)),smoothstep(3.57,3.63,phase)*(1.0-smoothstep(3.92,4.02,phase)));
}
vec3 badlands_working_color(vec3 srgb){
 // Compatibility accepts sRGB ALBEDO and performs the lighting conversion
 // itself. Forward+/Mobile use linear working colours, like source_color
 // textures. Unconditionally applying pow(2.2) darkened authored beds twice.
 if(OUTPUT_IS_SRGB)return srgb;
 return mix(srgb/12.92,pow((srgb+vec3(.055))/1.055,vec3(2.4)),step(vec3(.04045),srgb));
}
void badlands_projected(int id,vec2 uv,vec2 world_uv,vec2 dx,vec2 dy,float fine,out vec4 s,out vec3 t){
 float k=field(world_uv*.09+vec2(19.3,67.1))*8.0,index=floor(k),blend=smoothstep(.1,.9,fract(k));
 vec2 a=uv+sin(vec2(3,7)*index)*19.0,b=uv+sin(vec2(3,7)*(index+1.0))*19.0;
 s=mix(badlands_texel(id,a,dx,dy),badlands_texel(id,b,dx,dy),blend);t=vec3(0,0,1);
 if(fine>.001){t=normalize(mix(unpack_normal(badlands_normal_texel(id,a,dx,dy)),unpack_normal(badlands_normal_texel(id,b,dx,dy)),blend));t.xy/=max(t.z,.35);}
}
void badlands_sample(int id,float metres,vec3 dx,vec3 dy,vec3 projection,vec3 n,float fine,out vec4 surface,out vec3 gradient){
 metres=max(round(metres*4.0)*.25,.25);int period=int(round(metres*4.0));
 ivec3 q=ivec3(round(forest_origin*4.0)),r=abs(q)%ivec3(period);
 if(q.x<0 && r.x>0)r.x=period-r.x;
 if(q.y<0 && r.y>0)r.y=period-r.y;
 if(q.z<0 && r.z>0)r.z=period-r.z;
 vec3 p=forest_local_position/metres+vec3(r)*.25/metres,wp=world_position/metres;dx/=metres;dy/=metres;
 surface=vec4(0);gradient=vec3(0);
 if(projection.x>.002){vec4 s;vec3 t;badlands_projected(id,vec2(p.z,-p.y*sign(n.x)),vec2(wp.z,-wp.y*sign(n.x)),vec2(dx.z,-dx.y*sign(n.x)),vec2(dy.z,-dy.y*sign(n.x)),fine,s,t);surface+=s*projection.x;gradient+=vec3(0,-t.y*sign(n.x),t.x)*projection.x;}
 if(projection.y>.002){vec4 s;vec3 t;badlands_projected(id,vec2(p.x,-p.z*sign(n.y)),vec2(wp.x,-wp.z*sign(n.y)),vec2(dx.x,-dx.z*sign(n.y)),vec2(dy.x,-dy.z*sign(n.y)),fine,s,t);surface+=s*projection.y;gradient+=vec3(t.x,0,-t.y*sign(n.y))*projection.y;}
 if(projection.z>.002){vec4 s;vec3 t;badlands_projected(id,vec2(p.x,p.y*sign(n.z)),vec2(wp.x,wp.y*sign(n.z)),vec2(dx.x,dx.y*sign(n.z)),vec2(dy.x,dy.y*sign(n.z)),fine,s,t);surface+=s*projection.z;gradient+=vec3(t.x,t.y*sign(n.z),0)*projection.z;}
}
void shade_badlands(vec3 n,vec3 dx,vec3 dy,vec3 projection,float fine,out vec3 color,out float rough,out vec3 gradient,out vec3 materials,out vec3 masks){
 float coordinate=badlands_coordinate();
 float region=badlands_control.y*15.0,phase=mod(coordinate,5.0),slope=1.0-clamp(n.y,0.0,1.0);
 float hard=badlands_hardness(phase);
 float shale=max(smoothstep(1.66,1.72,phase)*(1.0-smoothstep(1.96,2.04,phase)),smoothstep(4.36,4.43,phase)*(1.0-smoothstep(4.67,4.75,phase)));
 float clay=clamp((1.0-smoothstep(.5,1.6,abs(region-2.0)))+(1.0-smoothstep(.5,1.6,abs(region-3.0))),0.0,1.0);
 float plain=clamp((1.0-smoothstep(.5,1.6,abs(region-8.0)))+(1.0-smoothstep(.5,1.6,abs(region-15.0))),0.0,1.0);
 float red=(1.0-smoothstep(.5,1.6,abs(region-1.0)))+(1.0-smoothstep(.5,1.6,abs(region-10.0)))*.5;
 float pale=1.0-smoothstep(.5,1.6,abs(region-11.0));
 if(badlands_palette_enabled){vec4 palette=badlands_palette_controls();clay=palette.x;plain=palette.y;red=palette.z;pale=palette.w;}
 float exposed=clamp(geology_control.x+smoothstep(.06,.45,slope)*.7,0.0,1.0);
 float deposit=clamp(geology_control.z*(1.0-smoothstep(.04,.25,slope)),0.0,1.0);
 float w[6];
 w[0]=(1.0-exposed*.85)*(1.0-deposit*.4);
 w[1]=(1.0-hard)*clamp(red+.2,0.0,1.0)*(1.0-clay)*(1.0-deposit)*(.25+exposed*.65);
 // A resistant cap is exposed rock even on its flat top. Soft steep rock
 // must also survive the top-three cutoff, rather than losing to soil.
 w[2]=exposed*(.35*(1.0-clay*.75)+hard*.65)*max(smoothstep(.04,.22,slope),hard*.8);
 w[3]=plain*(1.0-smoothstep(.015,.09,slope))*(1.0-deposit*.7)*1.1;
 w[4]=deposit*badlands_gravel;
 w[5]=smoothstep(.06,.2,slope)*(1.0-smoothstep(.3,.5,slope))*exposed*(1.0-hard*.8)*.45;
 int ids[3];float selected[3],total=0.0;
 for(int k=0;k<3;k++){int best=0;for(int j=1;j<6;j++){if(w[j]>w[best])best=j;}ids[k]=best;selected[k]=w[best];w[best]=-1.0;}
 float cutoff=0.0;for(int j=0;j<6;j++)cutoff=max(cutoff,w[j]);
 for(int k=0;k<3;k++){selected[k]=k>=badlands_quality?0.0:max(selected[k]-cutoff,0.0);total+=selected[k];}
 if(total<.00001){selected[0]=1.0;total=1.0;}
 float pale_bed=smoothstep(.9,1.02,phase)*(1.0-smoothstep(1.56,1.65,phase));
 float ochre_bed=smoothstep(2.25,2.4,phase)*(1.0-smoothstep(3.1,3.25,phase));
 vec3 band=mix(vec3(.48,.31,.24),vec3(.65,.56,.44),hard);
 band=mix(band,vec3(.63,.56,.49),pale_bed*.75);
 band=mix(band,vec3(.55,.43,.29),ochre_bed*.65);
 band=mix(band,vec3(.34,.33,.36),shale);
 band=mix(band,vec3(.4,.42,.46),clay*.96);
 band=mix(band,vec3(.65,.61,.53),pale*.9);
 // Finer, unequally spaced beds share the unwrapped geological coordinate,
 // so they continue through adjacent hills instead of becoming a separate
 // world-axis crack texture. Fade before a bed becomes smaller than a pixel.
 float bed_frequency=coordinate*9.3;
 float bed_filter=1.0-smoothstep(.3,1.0,fwidth(bed_frequency));
 float lamina=mix(.5,field(vec2(bed_frequency,17.1)),bed_filter);
 float lamination=badlands_lamina_strength*exposed*(1.0-deposit)*(.25+.75*smoothstep(.015,.2,slope));
 band=mix(band,vec3(.36,.34,.33),smoothstep(.57,.73,lamina)*lamination*(1.0-hard*.8));
 band=badlands_working_color(band);
 // Recolour geological strata, retaining different source normals/roughness:
 // this is not six variants of one rock image.
 color=vec3(0);rough=0.0;gradient=vec3(0);materials=vec3(0);
 for(int k=0;k<3;k++){
  float amount=selected[k]/total;if(amount<.003)continue;
  int id=ids[k];bool rock=id==2;float metres=rock?badlands_rock_metres:badlands_ground_metres;
  vec4 s=badlands_average(id);vec3 g=vec3(0);
  float detail=1.0-smoothstep(rock?1500.0:160.0,rock?6500.0:850.0,view_distance);
  if(detail>.003){vec4 near_surface;badlands_sample(id,metres,dx,dy,projection,n,fine,near_surface,g);s=mix(s,near_surface,detail);g*=detail;}
  // Do not magnify soil grains sixteen times over broad clay hills. Those
  // photograph shadows read as enormous soft boulders from a kilometre away.
  if(id==2){float meso=1.0-smoothstep(4500.0,18000.0,view_distance);if(meso>.003){vec4 broad;vec3 ignored;badlands_sample(id,metres*8.0,dx,dy,projection,n,0.0,broad,ignored);s=mix(s,broad,meso*.16);}}
  float luminance=dot(s.rgb,vec3(.3,.5,.2));
  vec3 geological=band*(.55+1.0*luminance);
  float band_exposure=mix(.28,1.0,smoothstep(.015,.2,slope));
  // Exposed resistant caps retain geological colour even on horizontal tops;
  // they must not inherit a soil/lichen tint just because their slope is zero.
  band_exposure=max(band_exposure,hard*exposed);
  float regional_grade=badlands_regional_strength*max(clay*.95,pale*.9);
  float geological_grade=max(badlands_strata_strength*band_exposure,regional_grade)*(1.0-deposit*.5);
  s.rgb=mix(s.rgb,geological,clamp(geological_grade,0.0,1.0));
  float moist=1.0-smoothstep(.2,2.5,abs(world_position.y-swamp_water_level));
  s.rgb*=badlands_gain*(1.0-moist*.12);
  color+=s.rgb*amount;rough+=mix(max(s.a,.72),.6,moist*.3)*amount;
  gradient+=g*badlands_normal_strength*amount;materials+=id_color(id)*amount;
 }
 float cliff_weathering=exposed*(1.0-clay)*smoothstep(.12,.42,slope);
 if(badlands_normal_strength>.001 && cliff_weathering>.01 && fine>.001 && enable_ambient_cliff_normals){vec3 a,b,ai,bi;float ac,bc;ambient_band(true,dx,dy,n,projection,a,ac,ai);ambient_band(false,dx,dy,n,projection,b,bc,bi);gradient+=(a*.15+b*.18)*cliff_weathering*badlands_normal_strength;}
 float weather=ground_field(world_position.xz/140.0);
 float fracture=field(world_position.xz*.023+vec2(field(world_position.zy*.014))*3.0);
 // Sub-metre weathering on exposed steep rock only. A four-metre isotropic
 // shading field made broad clay terrain look inflated despite flat geometry.
 float relief=fracture*.35*exposed*smoothstep(.10,.40,slope)*(.2+hard*.8)*(1.0-deposit)*(1.0-smoothstep(2000.0,6000.0,view_distance));
 relief+=(lamina-.5)*lamination*.06;
 vec3 r1=cross(dy,n),r2=cross(n,dx);float det=dot(dx,r1);
 // Procedural bedding/weathering obey the same detail/normal-off control as
 // the scanned normals. Otherwise debug 7 leaves relief active while a zero
 // strength correctly removes it, making the two controls disagree.
 if(abs(det)>.000001)gradient-=clamp((r1*dFdx(relief)+r2*dFdy(relief))/det,vec3(-.5),vec3(.5))*badlands_normal_strength*fine;
 color*=.88+fracture*.22;
 color*=1.0+(weather-.5)*badlands_weathering*.15;rough=clamp(rough,.6,1.0);masks=vec3(exposed,deposit,hard);
}
vec3 badlands_debug(vec3 n,vec3 mapped,vec3 materials,vec3 masks){
 if(debug_view==240)return id_color(int(round(badlands_control.y*15.0)));
 if(debug_view==241)return vec3(badlands_control.x);
 if(debug_view==242)return vec3(badlands_phase()/5.0,masks.z,0);
 if(debug_view==243)return geology_control;
 if(debug_view==244)return vec3(terrain_surface.y,geology_control.y,0);
 if(debug_view==245)return materials;
 if(debug_view==246)return mapped*.5+.5;
 return id_color(int(chunk_lod));
}

