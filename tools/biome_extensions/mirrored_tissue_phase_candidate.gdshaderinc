// Private unregistered sampling experiment; original files unchanged.
// Shared tissue projection for terrain and attached organic shells. Callers
// provide the same absolute position, local position and chunk origin so that
// a structure does not restart or change the texture at its buried margin.
uniform sampler2DArray biological_colors:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
vec2 biological_quarter_turn(vec2 p,int turns){
 if(turns==1)return vec2(-p.y,p.x);if(turns==2)return -p;if(turns==3)return vec2(p.y,-p.x);return p;
}
vec3 biological_lookup(int layer,vec2 uv,vec2 dx,vec2 dy){
 if(layer<=1){vec2 cell=mod(uv,vec2(2)),direction=mix(vec2(1),vec2(-1),step(vec2(1),cell));uv=vec2(1)-abs(cell-vec2(1));dx*=direction;dy*=direction;}
 return textureGrad(biological_colors,vec3(uv,float(layer)),dx,dy).rgb;
}
vec3 biological_projected(int layer,vec2 uv,vec2 dx,vec2 dy,vec2 reference){
 float k=field(reference/(layer==0?1.7:7.0))*6.0,index=floor(k),blend=smoothstep(.15,.85,fract(k));
 int ra=layer==0?int(index)%4:0,rb=layer==0?int(index+1.0)%4:0;
 vec2 a=biological_quarter_turn(uv,ra)+sin(vec2(3,7)*index)*19.0,b=biological_quarter_turn(uv,rb)+sin(vec2(3,7)*(index+1.0))*19.0;
 return mix(biological_lookup(layer,a,biological_quarter_turn(dx,ra),biological_quarter_turn(dy,ra)),biological_lookup(layer,b,biological_quarter_turn(dx,rb),biological_quarter_turn(dy,rb)),blend);
}
vec3 biological_sample(int layer,float metres,vec3 dx,vec3 dy,vec3 projection,vec3 n){
 metres=max(round(metres*4.0)*.25,.25);int period=int(round(metres*4.0))*2;ivec3 q=ivec3(round(forest_origin*4.0)),r=abs(q)%ivec3(period);
 if(q.x<0 && r.x>0)r.x=period-r.x;if(q.y<0 && r.y>0)r.y=period-r.y;if(q.z<0 && r.z>0)r.z=period-r.z;
 vec3 p=forest_local_position/metres+vec3(r)*.25/metres;dx/=metres;dy/=metres;vec3 color=vec3(0);
 if(projection.x>.002)color+=biological_projected(layer,vec2(p.z,-p.y*sign(n.x)),vec2(dx.z,-dx.y*sign(n.x)),vec2(dy.z,-dy.y*sign(n.x)),world_position.zy)*projection.x;
 if(projection.y>.002)color+=biological_projected(layer,vec2(p.x,-p.z*sign(n.y)),vec2(dx.x,-dx.z*sign(n.y)),vec2(dy.x,-dy.z*sign(n.y)),world_position.xz)*projection.y;
 if(projection.z>.002)color+=biological_projected(layer,vec2(p.x,p.y*sign(n.z)),vec2(dx.x,dx.y*sign(n.z)),vec2(dy.x,dy.y*sign(n.z)),world_position.xy)*projection.z;
 return color;
}
int alien_tissue_layer(int type){return type==2 || type==5?2:(type==3?3:1);}
float alien_tissue_roughness(int layer){return layer==2?.82:(layer==3?.48:.62);}
vec3 alien_tissue_color(int layer,float detail,vec3 dx,vec3 dy,vec3 projection,vec3 n){
 vec3 average=textureLod(biological_colors,vec3(.5,.5,float(layer)),11.0).rgb;
 if(detail<=.002)return average;
 return mix(average,biological_sample(layer,layer==2?2.0:1.5,dx,dy,projection,n),detail);
}
void alien_tissue_sample(float region,float distance_to_view,vec3 dx,vec3 dy,vec3 projection,vec3 n,out vec3 color,out float rough){
 // Same .25..75 regional interpolation as the canonical CPU landforms.
 // Rounding region here painted abrupt kilometre-long material stripes.
 int lower=int(clamp(floor(region),0.0,5.0));int a=alien_tissue_layer(lower),b=alien_tissue_layer(min(lower+1,5));
 float blend=smoothstep(.25,.75,fract(region));float detail=1.0-smoothstep(400.0,1800.0,distance_to_view);
 if(a==b || blend<=.001){color=alien_tissue_color(a,detail,dx,dy,projection,n);rough=alien_tissue_roughness(a);}
 else if(blend>=.999){color=alien_tissue_color(b,detail,dx,dy,projection,n);rough=alien_tissue_roughness(b);}
 else{color=mix(alien_tissue_color(a,detail,dx,dy,projection,n),alien_tissue_color(b,detail,dx,dy,projection,n),blend);rough=mix(alien_tissue_roughness(a),alien_tissue_roughness(b),blend);}
}

