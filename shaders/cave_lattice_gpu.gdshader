shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D numeric_inputs : filter_nearest, repeat_disable;
uniform int sample_count=0;
uniform int sample_columns=256;
uniform int sample_rows=2;

vec4 data_at(int i){return texelFetch(numeric_inputs,ivec2(i%sample_columns,i/sample_columns),0);}
vec4 numeric_bytes(float value){
 uint bits=floatBitsToUint(value);
 return vec4(float(bits&255u),float((bits>>8u)&255u),float((bits>>16u)&255u),float((bits>>24u)&255u))/255.0;
}
float field_value(int index){
 vec4 header=data_at(0),limits=data_at(1),options=data_at(2);
 int row=int(limits.x),plane=row*row;
 ivec3 lattice=ivec3(index%row,index/row%row,index/plane);
 vec3 p=vec3(lattice)*header.w,world=p+header.xyz;
 ivec3 bin=lattice/int(16.0/header.w);
 vec4 range=data_at(3+bin.x+bin.y*5+bin.z*25);
 vec4 column=data_at(int(options.x)+lattice.x+lattice.z*row);
 if(options.y>0.5&&column.w<0.5)return 4.0;
 float closed_value=4.0,opening=4.0;
 float wall=sin(world.x*.71+sin(world.y*.23))*sin(world.z*.53+world.y*.41)*.12;
 for(int i=0;i<64;i++){
  if(i>=int(range.y))break;
  int at=int(range.x)+i*5;
  vec4 a=data_at(at),b=data_at(at+1),shape=data_at(at+2),direction=data_at(at+3),grades=data_at(at+4);
  int kind=int(a.w),style=int(b.w);
  float floor_y=a.y,radius=0.0;
  vec2 q=p.xz-a.xz;
  if(kind==4){
   if(options.z>0.5&&abs(p.y-a.y)<=5.01)return 5.0;
   float minor=direction.w,roof=grades.x;
   vec2 axis=direction.xy/minor;
   float u=dot(q,axis)/shape.x,v=dot(q,vec2(-axis.y,axis.x))/minor;
   float y=p.y-a.y,phase=axis.x*2.3+axis.y*3.7+float(style)*.73+shape.x*.019+minor*.031+roof*.023;
   float layer=clamp(y/roof,0.0,1.0);
   float twist=.46*sin(phase*1.7)*(layer-.5);
   float cu=u*cos(twist)-v*sin(twist),cv=u*sin(twist)+v*cos(twist);
   cu-=.15*sin(layer*5.0+phase)*layer;cv-=.13*cos(layer*4.0-phase)*layer;
   float r=length(vec2(cu,cv));
   float warp=.68+.16*sin(cu*5.0+cv*3.0+phase)+.10*sin(cv*7.0-cu*2.0+phase*1.7)+.06*cos(layer*11.0+cu*4.0-phase);
   float rise=smoothstep(.25,.85,r)*min(roof*.20,7.0)*(.5+.5*sin(u*5.0-v*3.0+phase));
   float ceiling=roof*(.56+.44*(.5+.5*sin(u*3.0+v*4.0+phase)));
   float h=max(1.0,ceiling-rise);
   vec2 normalized=vec2(r/max(.34,warp),(y-rise-h*.45)/(h*.55));
   float exponent=2.0+2.6*(.5+.5*sin(phase));
   vec2 powers=pow(abs(normalized),vec2(exponent));
   float arch=(pow(powers.x+powers.y,1.0/exponent)-1.0)*min(minor,h*.55);
   float value=max(max(rise-y,arch+wall),(length(vec2(u,v))-.98)*min(shape.x,minor));
   if(shape.x>=15.0&&roof>=20.0){
    float ru=u-(.53+.09*sin(phase+y*.13));
    float rv=v-(.28+.07*cos(phase-y*.11));
    float rib=(length(vec2(ru,rv))-(.07+.055*abs(sin(phase+y*.17))))*minor;
    if(cos(phase)>0.0)value=max(value,-rib);
    float shelf_width=.16+.12*(.5+.5*sin(phase*1.9));
    float shelf_y=roof*(.36+.12*sin(phase*1.3));
    float shelf=max((abs(u-.58)-shelf_width)*shape.x,abs(y-shelf_y)-max(1.0,roof*.055));
    shelf=max(shelf,(abs(v+.12)-.42)*minor);
    if(sin(phase*1.4)>.12)value=max(value,-shelf);
   }
   closed_value=min(closed_value,value);
   continue;
  }
  if(kind==2){
   if(options.z>0.5&&abs(p.y-a.y)<=5.01)return 5.0;
   radius=length(q);
  }else{
   float along=dot(q,direction.xy)/direction.z;
   radius=length(q-direction.xy*clamp(along,0.0,1.0));
   floor_y=a.y+(b.y-a.y)*along;
   if(along<0.0&&grades.z>0.5)floor_y=a.y+along*direction.w*grades.x;
   else if(along>1.0&&grades.w>0.5)floor_y=b.y+(along-1.0)*direction.w*grades.y;
  }
  float y=p.y-floor_y;
  vec2 normalized=vec2(radius/shape.x,(y-shape.z)/shape.y);
  float arch=(length(normalized)-1.0)*shape.w;
  if(style==1||style==2||style==3||style==5){
   float exponent=style==1?4.0:style==2?3.4:style==3?2.8:2.5;
   vec2 powers=pow(abs(normalized),vec2(exponent));
   arch=(pow(powers.x+powers.y,1.0/exponent)-1.0)*shape.w;
  }
  if(style==2||style==3||style==4){
   float joint=.5+.5*sin(world.y*(style==2?.61:.19)+world.x*.013+world.z*.017);
   arch-=joint*(style==3?.24:.12)*smoothstep(0.0,1.0,y);
  }
  if(style==7){
   float phase=kind==2?atan(q.y,q.x)*9.0:radius*.37+world.x*.08+world.z*.11;
   // At the center atan(0,0) is undefined on some graphics devices.
   if(kind==2&&q==vec2(0.0))phase=0.0;
   float fold=.5+.5*sin(phase+y*.43+sin(world.y*.13)*.8);
   arch-=fold*fold*.65*smoothstep(1.0,4.0,y);
  }
  float value=max(-y,arch+wall);
  if(kind==1)opening=min(opening,value);else closed_value=min(closed_value,value);
 }
 float result=4.0;
 if(min(closed_value,opening)<4.0&&column.z>0.5){
  float depth=column.x-p.y;
  if(limits.w>0.0)opening=max(opening,limits.w-depth);
  result=min(4.0,max(min(max(closed_value,limits.z-depth),opening),depth-limits.y));
 }
 if(options.y>0.5)result=min(result,column.y-p.y);
 return result;
}
void fragment(){
 ivec2 pixel=ivec2(FRAGCOORD.xy);
 int index=pixel.y*sample_columns+pixel.x;
 if(index>=sample_count)COLOR=numeric_bytes(0.0);
 else COLOR=numeric_bytes(field_value(index));
}
