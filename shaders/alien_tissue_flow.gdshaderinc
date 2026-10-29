// Numeric RGBA32F material atlas: finite-path arc,side,alignment,local path ID.
// IDs are only compared within this tile;never quantize or blend them as angles.
uniform sampler2D alien_tissue_flow:filter_nearest,repeat_disable;
uniform bool alien_tissue_flow_enabled=false;
uniform vec2 alien_tissue_flow_span=vec2(256.0);
uniform vec2 alien_tissue_flow_offset=vec2(0);
// Independently bound by the configured world; generic shader users keep the
// original lookup unless they explicitly enable the registered variation.
uniform bool alien_tissue_variation_enabled=false;
vec3 alien_flow_mirrored(vec2 uv,vec2 dx,vec2 dy){
 vec2 cell=mod(uv,vec2(2));
 vec2 direction=mix(vec2(1),vec2(-1),step(vec2(1),cell));
 vec2 edge=vec2(.5)/vec2(textureSize(biological_colors,0).xy);
 vec2 folded=clamp(vec2(1)-abs(cell-vec2(1)),edge,vec2(1)-edge);
 return textureGrad(biological_colors,vec3(folded,1.0),dx*direction,dy*direction).rgb;
}
vec3 alien_flow_varied(vec2 uv,vec2 dx,vec2 dy){
 if(!alien_tissue_variation_enabled)return textureGrad(biological_colors,vec3(uv,1.0),dx,dy).rgb;
 // Canonical finite-path coordinates, not chunk origins or world float hashes.
 // No quarter-turns: longitudinal fibres keep their actual hive-path axis.
 float k=field(uv/vec2(2.7,3.9))*6.0,index=floor(k);
 float blend=smoothstep(.15,.85,fract(k));
 vec2 a=sin(vec2(3,7)*index)*19.0,b=sin(vec2(3,7)*(index+1.0))*19.0;
 // Modest continuous growth strain breaks mirror-pair motifs without random
 // rotations or independently changing the physical trunk direction. Apply
 // its analytic Jacobian to BOTH footprints, never screen-derive grouped UVs.
 vec2 jx=vec2(1.0+.074*cos(uv.x*.37),.0918*cos(uv.x*.51));
 vec2 jy=vec2(.3285*cos(uv.y*.73),1.0+.0664*cos(uv.y*.83));
 vec2 warped_dx=jx*dx.x+jy*dx.y,warped_dy=jx*dy.x+jy*dy.y;
 uv+=vec2(.45*sin(uv.y*.73)+.2*sin(uv.x*.37),.18*sin(uv.x*.51)+.08*sin(uv.y*.83));
 dx=warped_dx;dy=warped_dy;
 return mix(alien_flow_mirrored(uv+a,dx,dy),alien_flow_mirrored(uv+b,dx,dy),blend);
}
vec3 alien_flow_color(vec3 base,vec3 n,vec3 position_dx,vec3 position_dy){
 ivec2 size=textureSize(alien_tissue_flow,0);
 vec2 relative=(forest_local_position.xz-alien_tissue_flow_offset)/max(alien_tissue_flow_span,vec2(1));
 float inside=step(0.0,relative.x)*step(0.0,relative.y)*step(relative.x,1.0)*step(relative.y,1.0);
 vec2 grid=clamp(relative,vec2(0),vec2(1))*vec2(size-ivec2(1));
 ivec2 cell=ivec2(floor(grid));vec2 f=fract(grid);
 vec4 data[4];float weights[4];vec2 weight_derivative[4];
 data[0]=texelFetch(alien_tissue_flow,cell,0);
 data[1]=texelFetch(alien_tissue_flow,min(cell+ivec2(1,0),size-ivec2(1)),0);
 data[2]=texelFetch(alien_tissue_flow,min(cell+ivec2(0,1),size-ivec2(1)),0);
 data[3]=texelFetch(alien_tissue_flow,min(cell+ivec2(1),size-ivec2(1)),0);
 weights[0]=(1.0-f.x)*(1.0-f.y);weights[1]=f.x*(1.0-f.y);weights[2]=(1.0-f.x)*f.y;weights[3]=f.x*f.y;
 weight_derivative[0]=vec2(-(1.0-f.y),-(1.0-f.x));weight_derivative[1]=vec2(1.0-f.y,-f.x);
 weight_derivative[2]=vec2(-f.y,1.0-f.x);weight_derivative[3]=vec2(f.y,f.x);
 vec2 grid_dx=position_dx.xz/max(alien_tissue_flow_span,vec2(1))*vec2(size-ivec2(1));
 vec2 grid_dy=position_dy.xz/max(alien_tissue_flow_span,vec2(1))*vec2(size-ivec2(1));
 vec3 result=base;
 // Group by actual path before interpolating coordinates. Interpolating arc
 // values from different paths produces long stretched textures at junctions.
 // Differentiate the normalized bilinear map analytically. GPU derivatives
 // of reconstructed UVs change group/cell across a2x2 fragment quad and can
 // sample an unrelated path/empty group,creating single-pixel dark streaks.
 // The real caller's already-computed SMALL local derivatives are shared by
 // all groups,including near material/triangle boundaries.
 for(int i=0;i<4;i++){
  float first=step(.5,data[i].w),sum=0.0,strength=0.0;vec2 uv=vec2(0),sum_derivative=vec2(0),ux=vec2(0),uy=vec2(0);
  for(int j=0;j<4;j++){
   float same=data[i].w==data[j].w?1.0:0.0;
   if(j<i && same>.5)first=0.0;
   float w=weights[j]*same;uv+=data[j].xy*w;sum+=w;strength+=data[j].z*w;
   vec2 wd=weight_derivative[j]*same;sum_derivative+=wd;ux+=data[j].xy*wd.x;uy+=data[j].xy*wd.y;
  }
  // The footprint is analytic now;no GPU derivative depends on executing
  // empty/duplicate groups. Most fragments therefore need one sample,not4.
  if(first<.5 || strength<=0.0)continue;
  float denominator=max(sum,.000001);
  ux=(ux*denominator-uv*sum_derivative.x)/(denominator*denominator*1.5);
  uy=(uy*denominator-uv*sum_derivative.y)/(denominator*denominator*1.5);
  uv/=denominator*1.5;
  vec3 tissue=alien_flow_varied(uv,ux*grid_dx.x+uy*grid_dx.y,ux*grid_dy.x+uy*grid_dy.y);
  result+=(tissue-base)*strength*first*smoothstep(.35,.85,n.y);
 }
 return mix(base,result,inside);
}
