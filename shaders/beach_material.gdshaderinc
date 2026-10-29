// Four photographed CC0 sand surfaces, sampled offline and shared by all leaves.
uniform sampler2DArray beach_colors:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2DArray beach_normals:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform float beach_gain=.65;
uniform float beach_wetness=.9;
uniform float beach_metres=1.5;
uniform float beach_normal_strength=.55;
uniform float beach_ripples=.35;
uniform float beach_coarse=.4;
uniform float beach_macro=.3;
uniform float beach_intertidal=2.5;
uniform float beach_swash=.5;
uniform float beach_wind=-.61;
uniform float beach_wind_variation=.43;
float beach_angle(){return beach_wind+beach_wind_variation*sin(world_position.x/18000.0+sin(world_position.z/21000.0));}
float beach_wet(){
 float h=world_position.y-water_level;
 // Mean sea level owns geometry. Bounded swash changes appearance only.
 float swash=sin(TIME*.8+world_position.x*.017+world_position.z*.011)*beach_swash;
 return (1.0-smoothstep(-.4,beach_intertidal,h-swash*exp(-abs(h)/3.0)))*beach_wetness;
}
void beach_plane(int id,vec2 uv,vec2 wp,vec2 dx,vec2 dy,float fine,out vec4 s,out vec3 t){
 float index=field(wp*.08+vec2(53,91))*8.0;
 float cell=floor(index),blend=smoothstep(.1,.9,fract(index));
 vec2 a=uv+sin(vec2(3,7)*cell)*19.0,b=uv+sin(vec2(3,7)*(cell+1.0))*19.0;
 s=mix(textureGrad(beach_colors,vec3(a,float(id)),dx,dy),textureGrad(beach_colors,vec3(b,float(id)),dx,dy),blend);
 t=vec3(0,0,1);
 if(fine>.001){t=normalize(mix(unpack_normal(textureGrad(beach_normals,vec3(a,float(id)),dx,dy).rg),unpack_normal(textureGrad(beach_normals,vec3(b,float(id)),dx,dy).rg),blend));t.xy/=max(t.z,.4);}
}
void beach_sample(int id,float metres,float angle,vec3 dx,vec3 dy,vec3 projection,vec3 n,float fine,out vec4 s,out vec3 g){
 metres=max(round(metres*4.0)*.25,.25);
 int period=int(round(metres*4.0));ivec3 q=ivec3(round(forest_origin*4.0)),r=abs(q)%ivec3(period);
 if(q.x<0 && r.x>0)r.x=period-r.x;if(q.y<0 && r.y>0)r.y=period-r.y;if(q.z<0 && r.z>0)r.z=period-r.z;
 vec3 p=(forest_local_position+vec3(r)*.25)/metres,wp=world_position/metres;dx/=metres;dy/=metres;
 s=vec4(0);g=vec3(0);
 if(projection.x>.002){vec4 a;vec3 t;beach_plane(id,vec2(p.z,-p.y*sign(n.x)),vec2(wp.z,-wp.y*sign(n.x)),vec2(dx.z,-dx.y*sign(n.x)),vec2(dy.z,-dy.y*sign(n.x)),fine,a,t);s+=a*projection.x;g+=vec3(0,-t.y*sign(n.x),t.x)*projection.x;}
 if(projection.y>.002){
  float orientation=id==3?beach_wind:0.0;
  mat2 rotation=mat2(vec2(cos(orientation),sin(orientation)),vec2(-sin(orientation),cos(orientation)));
  // Rotated metre-scale ripple overlay uses continuous world UV, not a rotated
  // modulo origin (which would create a seam at every wrapped chunk origin).
  vec2 uv=id==3?vec2(wp.x,-wp.z*sign(n.y)):vec2(p.x,-p.z*sign(n.y));
  vec4 a;vec3 t;beach_plane(id,rotation*uv,rotation*vec2(wp.x,-wp.z*sign(n.y)),rotation*vec2(dx.x,-dx.z*sign(n.y)),rotation*vec2(dy.x,-dy.z*sign(n.y)),fine,a,t);
  vec2 unrotated=transpose(rotation)*t.xy;s+=a*projection.y;g+=vec3(unrotated.x,0,-unrotated.y*sign(n.y))*projection.y;
 }
 if(projection.z>.002){vec4 a;vec3 t;beach_plane(id,vec2(p.x,p.y*sign(n.z)),vec2(wp.x,wp.y*sign(n.z)),vec2(dx.x,dx.y*sign(n.z)),vec2(dy.x,dy.y*sign(n.z)),fine,a,t);s+=a*projection.z;g+=vec3(t.x,t.y*sign(n.z),0)*projection.z;}
}
void shade_beach(vec3 n,vec3 dx,vec3 dy,vec3 projection,float fine,out vec3 color,out float rough,out vec3 gradient,out vec3 mixture){
 float wet=beach_wet(),region=beach_control.y*15.0,angle=beach_angle();
 float coarse=(1.0-smoothstep(.5,1.5,abs(region-14.0))+.4*(1.0-smoothstep(.5,1.5,abs(region-1.0))))*beach_coarse;
 int dry=coarse>.2?2:0;float ripple=beach_ripples*(1.0-wet)*(1.0-smoothstep(.12,.3,1.0-n.y));
 vec4 a=textureLod(beach_colors,vec3(.5,.5,float(dry)),8.0),b=textureLod(beach_colors,vec3(.5,.5,1),8.0);vec3 ga=vec3(0),gb=vec3(0);
 float detail=1.0-smoothstep(100.0,900.0,view_distance);
 if(detail>.001){
  vec4 sa,sb;beach_sample(dry,beach_metres,angle,dx,dy,projection,n,fine,sa,ga);
  // Compacted wet photograph is not merely darkened dry sand.
  beach_sample(1,1.75,angle+1.5708,dx,dy,projection,n,fine,sb,gb);
  a=mix(a,sa,detail);b=mix(b,sb,detail);ga*=detail;gb*=detail;
  if(ripple>.005){vec4 sr;vec3 gr;beach_sample(3,3.5,angle,dx,dy,projection,n,fine,sr,gr);a=mix(a,sr,ripple*.5);ga=mix(ga,gr,ripple);}
 }
 float macro=(field(world_position.xz*.0007+vec2(13,41))-.5)*beach_macro;
 float lee=dot(n,vec3(cos(angle),0,sin(angle)));
 float pale=1.0-smoothstep(.5,1.5,abs(region-6.0));
 vec3 mineral=mix(vec3(1.02,.82,.56),vec3(1.0,.96,.82),pale);
 color=mix(a.rgb,b.rgb,wet)*beach_gain*mineral*(1.0+macro+lee*.06);
 rough=clamp(mix(a.a,b.a*.65,wet),.32,.96);
 gradient=mix(ga,gb*.45,wet)*beach_normal_strength;
 mixture=mix(id_color(dry),id_color(1),wet);
}
vec3 beach_debug(vec3 n,vec3 mapped,vec3 mixture){
 int mode=debug_view-200;float h=world_position.y-water_level;
 if(mode==0)return id_color(int(round(beach_control.y*15.0)));
 if(mode==1)return vec3(beach_control.x);
 if(mode==2)return vec3(beach_wet());
 if(mode==3)return vec3(1.0-smoothstep(0.0,beach_intertidal,abs(h)));
 if(mode==4)return vec3(clamp(h/120.0,0.0,1.0));
 if(mode==5)return vec3(smoothstep(.005,.15,1.0-n.y));
 if(mode==6)return vec3(cos(beach_angle())*.5+.5,0,sin(beach_angle())*.5+.5);
 if(mode==7)return vec3(clamp(-h/20.0,0.0,1.0));
 if(mode==8)return mixture;
 if(mode==9)return mapped*.5+.5;
 if(mode==10)return id_color(int(chunk_lod));
 vec2 edge=min(forest_local_position.xz,vec2(chunk_size_metres)-forest_local_position.xz);return vec3(1.0-smoothstep(0.0,2.0,min(edge.x,edge.y)));
}
