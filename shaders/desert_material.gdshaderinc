// Dedicated Desert layer. All source maps are prepared offline; no runtime HTTP.
uniform sampler2DArray desert_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray desert_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool desert_palette_ready = false;
uniform bool desert_extra_rock_ready = false;
uniform sampler2D desert_fracture_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool desert_fracture_ready = false;
uniform float desert_fracture_strength = 0.6;
// The optional scanned-clay palette uses its source's physical 2 m repeat.
// Until prepared offline, preserve the original Ground031 scale.
uniform float desert_clay_metres = 2.3;
uniform float desert_color_variation = 0.45;
uniform float desert_albedo_gain = 0.55;
uniform float desert_ripple_strength = 0.32;
uniform float desert_ripple_wavelength = 0.24;
uniform float desert_gravel_coverage = 0.6;
uniform float desert_weathering = 0.65;
uniform float desert_macro_strength = 0.65;
uniform float desert_rock_form_strength = 0.65;
uniform float desert_normal_strength = 0.65;
uniform float desert_salt_coverage = 0.55;
uniform float desert_sediment_variation = 0.55;
uniform float desert_wind_angle = 0.418879;
uniform float desert_wind_variation = 0.65;
// CPU-reduced seed phase, preserving signed remainder and large integer seeds.
// Default matches seed 73921; ChunkTerrain binds it before duplicating LOD materials.
uniform float desert_wind_phase = 50.336;
// XY tilt, Z mean bed height, W bounded seed phase. Shared with CPU shelves.
uniform vec4 desert_bedding_frame = vec4(0.009,0.0,24.0,0.0);
uniform float desert_height_scale = 1.0;

float desert_strata_phase(float uniform_bed) {
 // Identical monotone layer-thickness warp to DesertSampler._strata_phase.
 return uniform_bed+sin(uniform_bed*0.73+desert_bedding_frame.w*0.41)*0.18+sin(uniform_bed*1.17-desert_bedding_frame.w*0.29)*0.07;
}
float desert_strata_hardness(float bed,float footprint) {
 float hardness=0.5+sin(bed*0.91+desert_bedding_frame.w*0.23)*0.5;
 // Fine bands converge to their mean rather than flickering at distance.
 return mix(0.5,hardness,1.0-smoothstep(0.3,1.0,footprint));
}

float desert_bedding_coordinate(vec3 p) {
 // Transport the pre-shelf coordinate through canonical mesh samples. It
 // follows coast compression and mixed-biome blending without dividing by
 // a vanishing coast/biome weight or changing pure Grass geometry.
 return desert_strata_phase(desert_bedding);
}

// Derivative-free variant: the caller passes a conservative world footprint.
// Safe inside biome/material branches; no dFdx/dFdy in divergent control flow.
float desert_field(vec2 p,float footprint) {
 p=mat2(vec2(0.8,0.6),vec2(-0.6,0.8))*p;
 vec2 i=floor(p),f=fract(p);
 vec2 u=f*f*f*(f*(f*6.0-15.0)+10.0);
 vec4 a=fract(sin(vec4(dot(i,vec2(127.1,311.7)),dot(i+vec2(1,0),vec2(127.1,311.7)),dot(i+vec2(0,1),vec2(127.1,311.7)),dot(i+vec2(1,1),vec2(127.1,311.7))))*43758.5453)*6.283185;
 vec4 v=vec4(dot(vec2(cos(a.x),sin(a.x)),f),dot(vec2(cos(a.y),sin(a.y)),f-vec2(1,0)),dot(vec2(cos(a.z),sin(a.z)),f-vec2(0,1)),dot(vec2(cos(a.w),sin(a.w)),f-vec2(1,1)));
 return clamp(0.5+mix(mix(v.x,v.y,u.x),mix(v.z,v.w,u.x),u.y)*0.7*(1.0-smoothstep(0.3,1.0,footprint)),0.0,1.0);
}
// Value and analytic derivative in the caller's coordinates. Used only by
// close ripples; regular broad material fields keep their cheaper value path.
// The footprint envelope is constant for this local surface derivative.
vec3 desert_field_differential(vec2 p,float footprint) {
 mat2 rotation=mat2(vec2(0.8,0.6),vec2(-0.6,0.8));
 p=rotation*p;
 vec2 i=floor(p),f=fract(p);
 vec2 u=f*f*f*(f*(f*6.0-15.0)+10.0);
 vec2 du=30.0*f*f*(f-1.0)*(f-1.0);
 vec4 a=fract(sin(vec4(dot(i,vec2(127.1,311.7)),dot(i+vec2(1,0),vec2(127.1,311.7)),dot(i+vec2(0,1),vec2(127.1,311.7)),dot(i+vec2(1,1),vec2(127.1,311.7))))*43758.5453)*6.283185;
 vec2 g00=vec2(cos(a.x),sin(a.x)),g10=vec2(cos(a.y),sin(a.y));
 vec2 g01=vec2(cos(a.z),sin(a.z)),g11=vec2(cos(a.w),sin(a.w));
 vec4 v=vec4(dot(g00,f),dot(g10,f-vec2(1,0)),dot(g01,f-vec2(0,1)),dot(g11,f-vec2(1,1)));
 float lower=mix(v.x,v.y,u.x),upper=mix(v.z,v.w,u.x);
 vec2 lower_gradient=mix(g00,g10,u.x)+vec2(du.x*(v.y-v.x),0.0);
 vec2 upper_gradient=mix(g01,g11,u.x)+vec2(du.x*(v.w-v.z),0.0);
 vec2 local_gradient=mix(lower_gradient,upper_gradient,u.y)+vec2(0.0,du.y*(upper-lower));
 float attenuation=0.7*(1.0-smoothstep(0.3,1.0,footprint));
 float value=0.5+mix(lower,upper,u.y)*attenuation;
 vec2 derivative=transpose(rotation)*local_gradient*attenuation;
 if(value<=0.0 || value>=1.0)derivative=vec2(0.0);
 return vec3(clamp(value,0.0,1.0),derivative);
}
// Dropping negligible projections must not darken color/roughness or weaken
// the normal. Apply the same retained weights to micro and macro projections.
vec3 desert_projection_weights(vec3 weights) {
 weights=vec3(weights.x>0.003?weights.x:0.0,weights.y>0.003?weights.y:0.0,weights.z>0.003?weights.z:0.0);
 float total=dot(weights,vec3(1.0));
 return total>0.0?weights/total:vec3(0.0,1.0,0.0);
}
// Exact Jacobian of the same bounded world-space phase used by CPU dunes.
// Ground092A has ripple ridges along texture U, so its texture V follows wind U.
void desert_wind_frame(vec2 p,out vec2 q,out vec2 along,out vec2 across) {
 float phase=desert_wind_phase;
 float strength=desert_wind_variation*1600.0;
 float c=cos(desert_wind_angle),s=sin(desert_wind_angle);
 float ax=p.x/9100.0+phase,az=p.y/11700.0-phase*0.71;
 float bx=p.x/13700.0-phase*0.43,bz=p.y/8300.0+phase;
 float sax=sin(ax),cax=cos(ax),saz=sin(az),caz=cos(az);
 float sbx=sin(bx),cbx=cos(bx),sbz=sin(bz),cbz=cos(bz);
 q=vec2(p.x*c+p.y*s,-p.x*s+p.y*c)+vec2(sax*caz,cbx*sbz)*strength;
 along=vec2(c+cax*caz*strength/9100.0,s-sax*saz*strength/11700.0);
 across=vec2(-s-sbx*sbz*strength/13700.0,c+cbx*cbz*strength/8300.0);
}
int desert_fallback(int id) {
 if(id==0 || id==5) return 1;
 if(id==1 || id==4) return 5;
 if(id==2) return 6;
 return 8;
}
// Debug view 48: categorical weighted coverage, never a surface-color tint.
// Loose red, compact yellow, gravel cyan, rock green, mud blue, pale deposit magenta.
vec3 desert_family_debug(int id) {
 if(id==0)return vec3(1.0,0.15,0.05);
 if(id==1)return vec3(1.0,0.8,0.05);
 if(id==2)return vec3(0.05,0.8,1.0);
 if(id==3)return vec3(0.1,1.0,0.1);
 if(id==4)return vec3(0.12,0.22,1.0);
 return vec3(1.0,0.2,0.85);
}
void desert_projected(int id,vec2 uv,vec2 dx,vec2 dy,float near_detail,out vec4 s,out vec3 t) {
 t=vec3(0,0,1);
 vec2 alternate=vec2(-uv.y,uv.x)*0.731+vec2(7.137,19.731);
 vec2 ax=vec2(-dx.y,dx.x)*0.731, ay=vec2(-dy.y,dy.x)*0.731;
 // Directional source ripples must not be crossed by quarter-turn anti-tiling.
 // Unequal frequency and translated phase break repeats without rotating wind.
 if(id==0){alternate=uv*0.731+vec2(7.137,19.731);ax=dx*0.731;ay=dy*0.731;}

 if(desert_palette_ready) {
  s=textureGrad(desert_color,vec3(uv,float(id)),dx,dy);
  if(near_detail>0.001) {
   s=mix(s,textureGrad(desert_color,vec3(alternate,float(id)),ax,ay),0.24*near_detail);
   t=unpack_normal(textureGrad(desert_normal,vec3(uv,float(id)),dx,dy).rg);
   vec3 other=unpack_normal(textureGrad(desert_normal,vec3(alternate,float(id)),ax,ay).rg);
   vec3 aligned_other=id==0?other:vec3(other.y,-other.x,other.z);
   t=normalize(mix(t,aligned_other,0.24*near_detail));
  }
 } else {
  projected_surface(desert_fallback(id),uv,dx,dy,near_detail,s,t);
  // projected_surface already converted XY to slope; do not divide by Z twice.
  t.z=1.0;
 }
 t.xy/=max(t.z,0.3);
}
void desert_layer(int id,vec3 p,vec3 dx,vec3 dy,vec3 projection,vec3 n,float near_detail,out vec4 surface,out vec3 gradient) {
 surface=vec4(0.0);gradient=vec3(0.0);
 if(id==0) {
  // Repose-limited loose sand uses one coherent world-plane projection, not
  // three competing ripple directions. Sand does not form vertical walls.
  vec2 q;vec2 along;vec2 across;vec3 t;
  desert_wind_frame(world_position.xz,q,along,across);
  float sy=sign(n.y);
  vec2 uv=vec2(q.y,-q.x*sy)/3.5;
  vec2 ux=vec2(dot(across,dx.xz),-dot(along,dx.xz)*sy);
  vec2 uy=vec2(dot(across,dy.xz),-dot(along,dy.xz)*sy);
  desert_projected(id,uv,ux,uy,near_detail,surface,t);
  // Pull the tangent slope back through both Jacobian rows, then the caller
  // projects onto the actual surface tangent plane. UV-only rotation is wrong.
  vec2 world_slope=across*t.x-along*t.y*sy;
  gradient=vec3(world_slope.x,0.0,world_slope.y);
  return;
 }
 // Same signed surface-gradient projection as the established Grass shader.
 if(projection.x>0.0) {
  vec4 s;vec3 t;
  desert_projected(id,vec2(p.z,-p.y*sign(n.x)),vec2(dx.z,-dx.y*sign(n.x)),vec2(dy.z,-dy.y*sign(n.x)),near_detail,s,t);
  surface+=s*projection.x;gradient+=vec3(0,-t.y*sign(n.x),t.x)*projection.x;
 }
 if(projection.y>0.0) {
  vec4 s;vec3 t;
  desert_projected(id,vec2(p.x,-p.z*sign(n.y)),vec2(dx.x,-dx.z*sign(n.y)),vec2(dy.x,-dy.z*sign(n.y)),near_detail,s,t);
  gradient+=vec3(t.x,0,-t.y*sign(n.y))*projection.y;
  surface+=s*projection.y;
 }
 if(projection.z>0.0) {
  vec4 s;vec3 t;
  desert_projected(id,vec2(p.x,p.y*sign(n.z)),vec2(dx.x,dx.y*sign(n.z)),vec2(dy.x,dy.y*sign(n.z)),near_detail,s,t);
  surface+=s*projection.z;gradient+=vec3(t.x,t.y*sign(n.z),0)*projection.z;
 }
}
// Independent licensed fracture normal at medium/broad scales. Older incomplete
// installations retain the original sandstone source as a safe fallback.
vec3 desert_rock_normal(vec2 uv,vec2 dx,vec2 dy) {
 vec2 encoded;
 if(desert_fracture_ready)encoded=textureGrad(desert_fracture_normal,uv,dx,dy).rg;
 else if(desert_palette_ready)encoded=textureGrad(desert_normal,vec3(uv,3.0),dx,dy).rg;
 else encoded=textureGrad(palette_normal,vec3(uv,float(desert_fallback(3))),dx,dy).rg;
 vec3 normal=unpack_normal(encoded);
 return vec3(normal.xy/max(normal.z,0.4),1.0);
}
vec3 desert_rock_gradient(vec3 p,vec3 dx,vec3 dy,vec3 projection,vec3 n) {
 vec3 g=vec3(0.0);
 if(projection.x>0.0){vec3 t=desert_rock_normal(vec2(p.z,-p.y*sign(n.x)),vec2(dx.z,-dx.y*sign(n.x)),vec2(dy.z,-dy.y*sign(n.x)));g+=vec3(0,-t.y*sign(n.x),t.x)*projection.x;}
 if(projection.y>0.0){vec3 t=desert_rock_normal(vec2(p.x,-p.z*sign(n.y)),vec2(dx.x,-dx.z*sign(n.y)),vec2(dy.x,-dy.z*sign(n.y)));g+=vec3(t.x,0,-t.y*sign(n.y))*projection.y;}
 if(projection.z>0.0){vec3 t=desert_rock_normal(vec2(p.x,p.y*sign(n.z)),vec2(dx.x,dx.y*sign(n.z)),vec2(dy.x,dy.y*sign(n.z)));g+=vec3(t.x,t.y*sign(n.z),0)*projection.z;}
 return g;
}
void shade_desert(vec3 n,vec3 dx,vec3 dy,vec3 projection,float near_detail,float curvature,float desert_bedding_footprint,out vec3 color,out float rough,out vec3 gradient,out vec3 weights_debug) {
 // The canonical 32 m normal field is intentionally smooth and shared by
 // LODs. It can point upward on a much steeper *rendered* mesa triangle.
 // Project onto the actual surface, otherwise its top projection stretches
 // albedo and normals into long dark ribbons down the escarpment. Derivatives
 // arrive from the unconditional fragment path; no divergent derivatives.
 vec3 face=cross(dx,dy);
 face=dot(face,face)>0.000000000001?normalize(face):n;
 if(dot(face,n)<0.0)face=-face;
 // Only correct an under-projected escarpment. Ordinary differences between
 // smooth vertex normals and coarse triangles must NOT rotate the texture
 // basis per triangle: that made distant slopes look like faceted patches.
 float projection_correction=smoothstep(0.18,0.45,abs(n.y)-abs(face.y))*smoothstep(0.12,0.35,1.0-abs(face.y));
 vec3 texture_normal=normalize(mix(n,face,projection_correction));
 if(diagnostic_surface==3)texture_normal=n;
 else projection=pow(abs(texture_normal),vec3(4.0));
 // Diagnostic 3 reproduces the old smooth-normal projection, with all other
 // settings identical, for a repeatable before/after artifact regression.
 projection=desert_projection_weights(projection/dot(projection,vec3(1.0)));
 vec2 p=world_position.xz;
 float pixel=max(length(dx),length(dy));
 float slope=1.0-n.y;
 float dune=clamp(desert_region.a,0.0,1.0);
 float rock_context=desert_surface.x;
 float drainage=desert_surface.y;
 float wet=desert_wind.w*(1.0-smoothstep(0.0,4.0,world_position.y-water_level));
 // Supported oasis sediment is independent of the dry-lakebed frequency.
 // The height gate keeps high/dry terrain out of the wet basin material family.
 float basin=max(desert_surface.z,wet);
 float accumulation=desert_surface.w;
 // Reuse the transported canonical wind; no second phase/noise evaluation to
 // classify faces. Positive normal projection is a descending lee surface.
 vec2 wind_vector=desert_wind.xy*2.0-1.0;
 vec2 wind_direction=wind_vector/max(length(wind_vector),0.001);
 float wind_facing=dot(n.xz,wind_direction);
 float lee_face=smoothstep(0.10,0.40,wind_facing);
 float stoss_face=smoothstep(0.02,0.22,-wind_facing);
 // Curvature comes from the shared 32 m normal stencil, not from a physical
 // depositional map. Thresholding it painted compact sand into tiny islands.
 // The transported canonical dune-height proxy instead follows whole dune
 // troughs and crests, consistently across LODs and camera distances.
 float dune_elevation=clamp(desert_dune_b.z,0.0,1.0);
 float interdune=(1.0-smoothstep(0.04,0.2,slope))*(1.0-smoothstep(0.16,0.48,dune_elevation))*dune;
 float crest=(1.0-smoothstep(0.08,0.28,slope))*smoothstep(0.55,0.95,dune_elevation)*dune;
 // Geometry, geology and deposition lead; boundary noise is a small perturbation.
 float macro=desert_field(p/1400.0+vec2(211,79),pixel/1400.0);
 // Sand interiors do not need rock/salt boundary perturbation.
 float meso=0.5;
 if(rock_context>0.001 || basin>0.001)meso=desert_field(p/27.0+vec2(37,113),pixel/27.0);
 // Canonical accumulation already contains the upwind/valley deposition.
 // Adding the coarse curvature stencil here made every little convexity a
 // separate sand-colored island. Keep broad, continuous depositional aprons.
 float shelter=clamp(accumulation,0.0,1.0);
 float deposition=smoothstep(0.08,0.82,shelter);
 // Trough/crest proxies modulate fine relief, not the albedo-family mask.
 // Thresholding an interpolated crest proxy into a new material produced
 // large pale islands on sparse distant meshes. Compaction instead follows
 // the canonical drainage/basin/deposition controls below at every distance.
 float loose=clamp(dune+deposition*0.8,0.0,1.0);
 float rock=clamp(rock_context+smoothstep(0.18,0.5,slope)*rock_context,0.0,1.0);
 rock*=1.0-deposition*(1.0-smoothstep(0.1,0.35,slope))*0.85;
 rock=clamp(rock+(meso-0.5)*0.035*rock_context,0.0,1.0)*(1.0-basin*0.95);
 float gravel=desert_gravel_coverage*clamp(rock_context*(1.0-rock)+drainage*0.75+shelter*0.25,0.0,1.0)*(1.0-loose*0.65)*(1.0-basin*0.8);
 float salt=clamp(desert_wind.z*desert_salt_coverage*1.7,0.0,1.0);
 // Boundary variation cannot create mineral deposits outside their canonical
 // mask, or when coverage is disabled. Preserve exact zero/full endpoints.
 salt=clamp(salt+(meso-0.5)*0.24*salt*(1.0-salt),0.0,1.0);
 float compact=clamp(basin*0.75+drainage*0.35+(1.0-loose)*(1.0-rock)*0.4,0.0,1.0);
 float w[6];
 w[0]=max(0.05,loose)*(1.0-rock)*(1.0-basin*0.8)*(1.0-smoothstep(0.35,0.65,slope));
 w[1]=compact*(1.0-basin*0.65)*(1.0-rock);
 w[2]=gravel;
 w[3]=rock;
 w[4]=basin*(1.0-salt);
 w[5]=basin*salt;
 // Normalize the continuous physical weights directly. Subtracting a ranked
 // cutoff amplified nearly tied weights into isolated flat-colored islands.
 // Most pixels have only 2–4 active families; exact zeros never fetch maps.
 int ids[6];float selected[6];
 float selected_rock=0.0;
 float total=0.0;for(int k=0;k<6;k++){ids[k]=k;selected[k]=max(0.0,w[k]);total+=selected[k];}
 if(total<0.0001){selected[1]=1.0;total=1.0;}
 // Renormalize after removing
 // sub-threshold contributors. Every shaded pixel retains unit total weight.
 float retained_total=0.0;
 for(int k=0;k<6;k++){if(selected[k]/total<0.004)selected[k]=0.0;retained_total+=selected[k];}
 total=retained_total;
 color=vec3(0.0);rough=0.0;gradient=vec3(0.0);weights_debug=vec3(0.0);
 for(int k=0;k<6;k++) {
  float weight=selected[k]/total;
  if(weight<=0.0) continue;
  int id=ids[k];float metres=3.5;
  if(id==3)selected_rock=weight;
  // Catalogued physical widths: Ground054 is 3.5 m, Gravel020 is 0.8 m.
  // Unspecified widths retain the existing artistic scale.
  if(id==1)metres=3.5;if(id==2)metres=0.8;if(id==3)metres=5.0;if(id==4)metres=max(desert_clay_metres,0.1);if(id==5)metres=2.0;
  float footprint=max(length(dx),length(dy))/metres;
  float micro=(1.0-smoothstep(0.15,0.85,footprint))*near_detail;
  vec4 s;vec3 g;
  // Mipmapped source albedo remains at distance, normal/anti-tile fetches fade.
  // Independent rock provinces blend only on their broad shared boundary;
  // interiors use one source. No extra source is sampled outside its support.
  float rock_variant=id==3 && desert_extra_rock_ready ? smoothstep(0.43,0.65,macro) : 0.0;
  int source_id=rock_variant>=0.996 ? 6 : id;
  // Projection weights AND signed UV orientation must use the same normal.
  // A canonical n.x==0 paired with a nonzero face projection otherwise
  // collapses its vertical UV axis to zero, recreating the ribbon artifact.
  desert_layer(source_id,world_position/metres,dx/metres,dy/metres,projection,texture_normal,micro,s,g);
  if(rock_variant>0.004 && rock_variant<0.996){vec4 other;vec3 other_gradient;desert_layer(6,world_position/metres,dx/metres,dy/metres,projection,texture_normal,micro,other,other_gradient);s=mix(s,other,rock_variant);g=mix(g,other_gradient,rock_variant);}
  // The source sand map contains directional ripple relief as well as grains.
  // Attenuate it on avalanching lee faces and compacted floors, just as the
  // analytic ripple layer is attenuated. Windward faces keep gentler detail.
  if(id==0)g*=mix(1.0,0.28,lee_face)*(1.0-interdune*0.70)*mix(1.0,0.85,stoss_face)*(1.0-crest*0.18);
  vec3 tint=vec3(1.0);
  float lithology_roughness=0.0;
  if(id==0) tint=mix(vec3(1.12,0.99,0.77),vec3(1.15,0.86,0.62),macro*desert_color_variation);
  if(id==0)tint*=1.0+crest*0.025;
  if(id==1)tint=vec3(1.04,0.97,0.86);
  if(id==2)tint=vec3(0.91,0.85,0.73);
  if(id==3) {
   tint=mix(vec3(1.12,0.94,0.79),vec3(1.17,0.75,0.54),clamp(desert_region.r-desert_region.g,0.0,1.0)*1.7);
   // Only exposed rock receives bedding/weathering. Applying this after the
   // family blend also painted sandstone bands onto sand drifts and dry clay.
   // The band coordinate shares the CPU shelf frame, across region boundaries.
   // 1.22 bounds the new phase derivative (maximum 1.2133).
   // Derivatives are transported from the canonical coordinate before this
   // divergent material branch; steep/coastal compression filters correctly.
   float bed_footprint=desert_bedding_footprint*1.22;
   float hardness=0.5;
   float strata=0.5;
   // Both filtered fields are exactly their mean beyond this footprint.
   // Do not evaluate layer warping/hardness for imperceptible distant bands.
   if(bed_footprint<1.0) {
    float bed=desert_bedding_coordinate(world_position);
    hardness=desert_strata_hardness(bed,bed_footprint);
    strata=desert_field(vec2(bed,desert_bedding_frame.w*0.031),bed_footprint);
   }
   float interruption=desert_field(p/160.0+vec2(world_position.y/370.0,19.0),pixel/160.0);
   float weather=desert_field(p/75.0+vec2(world_position.y/95.0,31.0),pixel/75.0);
   vec3 strata_tint=mix(vec3(0.80,0.71,0.64),vec3(1.12,1.08,0.96),strata);
   tint*=mix(vec3(1.0),strata_tint,desert_macro_strength*(0.35+interruption*0.65));
   tint*=1.0-(weather-0.5)*desert_weathering*0.16;
   // Resistive beds use the same sequence as stronger geometric shelves;
   // keep the PBR structure and regional hue, with restrained tone/roughness.
   float lithology_strength=clamp(desert_macro_strength,0.0,1.0);
   tint*=mix(1.0,mix(1.035,0.965,hardness),lithology_strength);
   lithology_roughness=mix(0.025,-0.025,hardness)*lithology_strength;
  }
  if(id==4)tint=vec3(1.07,0.97,0.81);
  if(id==5)tint=vec3(1.08,1.06,0.98);
  if(!desert_palette_ready && id==5)s.rgb=mix(s.rgb,vec3(0.78,0.75,0.65),0.8);
  color+=s.rgb*tint*weight;
  float surface_roughness=clamp(s.a+0.14+lithology_roughness,0.7,1.0);
  if(id==0)surface_roughness=clamp(surface_roughness+lee_face*0.025-stoss_face*0.02,0.7,1.0);
  rough+=surface_roughness*weight;
  gradient+=g*weight*micro;
  if(debug_view==1 || debug_view==48)weights_debug+=desert_family_debug(id)*weight;
 }
 // Macro normals remain readable beyond the micro-detail radius, then mip-fade.
 // Only the selected rock family pays these fetches; albedo never becomes flat.
 if(selected_rock>0.02 && desert_macro_strength>0.0 && desert_fracture_strength>0.0 && debug_view!=7 && diagnostic_surface!=2) {
  float medium=1.0-smoothstep(0.2,0.9,pixel/28.0);
  float broad=1.0-smoothstep(0.2,0.9,pixel/95.0);
  if(medium>0.002)gradient+=desert_rock_gradient(world_position/28.0+vec3(17,31,71),dx/28.0,dy/28.0,projection,texture_normal)*selected_rock*medium*desert_macro_strength*desert_fracture_strength*1.2;
  if(broad>0.002)gradient+=desert_rock_gradient(world_position/95.0+vec3(83,19,43),dx/95.0,dy/95.0,projection,texture_normal)*selected_rock*broad*desert_macro_strength*desert_fracture_strength*0.75;
  // A separate hundreds-of-metres relief band remains readable when the
  // 28/95 m detail is subpixel. This is shading only, never grain geometry or
  // a different distant height function; pure Grass never pays these fetches.
  float regional=1.0-smoothstep(0.2,0.9,pixel/380.0);
  if(regional>0.002)gradient+=desert_rock_gradient(world_position/380.0+vec3(37,89,13),dx/380.0,dy/380.0,projection,texture_normal)*selected_rock*regional*desert_macro_strength*desert_fracture_strength*0.65;
 }
 // Enlarging a source normal tile does not enlarge its underlying grain;
 // mip filtering can still average it to neutral. These analytic surface
 // gradients supply genuinely broad, continuous exposed-rock forms. The
 // tilted vertical coordinate also works on walls, not just top projections.
 // No camera/LOD seed, extra geometry, albedo mask or divergent derivative.
 if(selected_rock>0.02 && desert_rock_form_strength>0.0 && pixel<620.0 && debug_view!=7 && diagnostic_surface!=2) {
  vec3 u=vec3(0.8,0.0,0.6),v=vec3(-0.09,0.65,0.12);
  vec2 rock_p=vec2(dot(world_position,u),dot(world_position,v));
  vec3 medium_form=vec3(0.5,0.0,0.0);
  if(pixel<180.0)medium_form=desert_field_differential(rock_p/180.0+vec2(13,47),pixel/180.0);
  vec3 broad_form=desert_field_differential(rock_p/620.0+vec2(71,29),pixel/620.0);
  vec2 form=medium_form.yz*0.70+broad_form.yz*0.45;
  gradient+=(u*form.x+v*form.y)*selected_rock*desert_rock_form_strength;
 }
 color*=desert_albedo_gain*mix(1.0,mix(0.94,1.06,macro),desert_sediment_variation)*(1.0-wet*0.35);
 rough=mix(rough,0.55,wet*0.75);
 // Wind-driven sub-metre ripples: shader-only, derivative filtered, loose sand only.
 // The global bounded phase exactly matches DesertSampler.wind_coordinates.
 float wavelength=max(desert_ripple_wavelength,0.08);
 gradient*=desert_normal_strength;
 // Beyond the ripple footprint cutoff its contribution is exactly zero.
 // Avoid all phase/noise/trigonometry work in inactive sand/water/rock pixels.
 if(desert_ripple_strength>0.0 && near_detail>0.001 && pixel<wavelength*0.22 && loose>0.001 && rock<0.999 && basin<0.999 && wet<0.999) {
  vec2 wind_uv;vec2 along;vec2 across;
  desert_wind_frame(p,wind_uv,along,across);
  vec2 wind=normalize(along);
  vec3 warp=desert_field_differential(wind_uv/vec2(4.7,1.9),pixel/1.9);
  float phase=wind_uv.x/wavelength+warp.x*1.35;
  // Chain rule for the actual warped carrier, including both wind coordinates.
  // Multiplication by wavelength preserves the existing artistic slope scale.
  vec2 phase_slope=along+wavelength*1.35*(along*warp.y/4.7+across*warp.z/1.9);
  float phase_dx=dot(phase_slope,dx.xz)/wavelength;
  float phase_dy=dot(phase_slope,dy.xz)/wavelength;
  // Keep the conservative cutoff envelope so the outer early-out remains
  // continuous even when projection makes the exact carrier footprint smaller.
  float cutoff_width=pixel/wavelength*2.5;
  float phase_width=max(cutoff_width,max(abs(phase_dx),abs(phase_dy))*2.5);
  float secondary_width=max(cutoff_width,max(abs(phase_dx*11.791+dot(across,dx.xz)/1.1),abs(phase_dy*11.791+dot(across,dy.xz)/1.1))/6.283185*2.5);
  float ripple_fade=(1.0-smoothstep(0.16,0.55,phase_width))*near_detail;
  float secondary_fade=(1.0-smoothstep(0.16,0.55,secondary_width))*near_detail;
  float breakup=0.55+0.45*desert_field(p/3.7+vec2(71,29),pixel/3.7);
  float lee=clamp(dot(n.xz,wind)*3.0,0.0,1.0);
  float first=cos(phase*6.283185)*ripple_fade;
  float second=0.28*cos(phase*11.791+wind_uv.y/1.1)*secondary_fade*(1.0-stoss_face*0.6);
  float amplitude=desert_ripple_strength*loose*(1.0-rock)*(1.0-basin)*(1.0-wet)*(1.0-lee*0.65)*(1.0-interdune*0.7)*breakup;
  vec2 ripple_slope=phase_slope*(first+second)+across*(second*wavelength/(11.791*1.1));
  gradient+=vec3(ripple_slope.x,0.0,ripple_slope.y)*amplitude;
 }
 gradient-=n*dot(gradient,n);
 // Summed multi-scale maps must not tip the lighting toward a black tangent
 // at grazing angles. Retain visible relief with a bounded ~48-degree tilt.
 gradient*=min(1.0,1.1/max(length(gradient),0.00001));
 if(debug_view==7 || diagnostic_surface==2)gradient=vec3(0.0);
}
