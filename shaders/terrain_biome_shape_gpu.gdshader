shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D numeric_inputs : filter_nearest, repeat_disable;
uniform int sample_count=0;
uniform int sample_columns=256;
uniform int sample_rows=2;
vec4 read_input(int index){return texelFetch(numeric_inputs,ivec2(index%sample_columns,index/sample_columns),0);}
vec4 D(int record,int band){return read_input(record+band);}
float L(float a,float b,float t){return a+(b-a)*t;}
float S(float a,float b,float x){float t=clamp((x-a)/(b-a),0.0,1.0);return t*t*(3.0-2.0*t);}
vec4 shape_1(int record){
 vec4 n=D(record,1); float a=n.x,b=n.y,c=n.z;
 vec2 q=D(record,6).xy;
 vec4 wa=D(record,2),wb=D(record,3),wc=D(record,4),wd=D(record,5);
 float w[16]=float[](wa.x,wa.y,wa.z,wa.w,wb.x,wb.y,wb.z,wb.w,wc.x,wc.y,wc.z,wc.w,wd.x,wd.y,wd.z,wd.w);
 float parameter_0=D(record,8).x;
 float parameter_1=D(record,8).y;
 float parameter_2=D(record,8).z;
 float parameter_3=D(record,8).w;
 float parameter_4=D(record,9).x;
 float parameter_5=D(record,9).y;
 float parameter_6=D(record,9).z;
 float parameter_7=D(record,9).w;
        float ridge_input = q.x + sin(q.y / 3900.0) * 950.0 + a * 480.0 + 6500.0; float across = mod(ridge_input,13000.0); if (across < 0.0) across += 13000.0; across -= 6500.0;
        float ridge = exp(-pow(abs(across) / max(parameter_0 * .5, 400.0), 1.65));
        float saddles = .75 + .15 * sin(q.y / 1800.0) + b * .25, mountain = parameter_1 * ridge * saddles;
        float hollow = 1.0 - S(.03, .24, abs(b + a * .3)), low = 1.0 - parameter_2 * .6, rolling = (35.0 + b * 65.0 + a * 20.0) * parameter_3;
        float h = w[0] * (22.0 + a * 12.0 + b * 5.0) * low + w[1] * (65.0 + rolling * 1.3 + ridge * 130.0);
        h += w[2] * (35.0 + rolling + a * 10.0) + w[3] * (28.0 + a * 10.0 + b * 4.0 + c * 1.5);
        h += w[4] * (55.0 + rolling * 2.5 + ridge * 65.0) + w[5] * (55.0 + ridge * 240.0 + abs(b) * 100.0 + c * 8.0 * parameter_4);
        h += w[6] * (80.0 + mountain - hollow * ridge * parameter_5 * parameter_6);
        h += w[7] * (40.0 + mountain * .35 - hollow * parameter_5 * .4) + w[8] * (12.0 + a * 4.0 + b * 1.2) + w[9] * (25.0 + a * 12.0 + b * 3.0);
        float drain = clamp(hollow * (w[5] * .3 + w[6] * .65 + w[7]) + w[8] * .7 + w[3] * .25, 0.0, 1.0);
        float wet = clamp(.2 + parameter_7 * .35 + a * .1 + drain * .3 + w[3] * .12 - ridge * w[6] * .12, .05, .9);
        float exposure = clamp(w[5] * .85 + w[6] * ridge * .7 + w[7] * .45 + w[1] * .18, 0.0, 1.0);
        return vec4(max(h, 4.0), wet, drain, exposure);
}

vec4 shape_4(int record){
 vec4 n=D(record,1); float macro=n.x,meso=n.y,structure=n.z;
 vec2 q=D(record,6).xy;
 vec4 wa=D(record,2),wb=D(record,3),wc=D(record,4),wd=D(record,5);
 float w[16]=float[](wa.x,wa.y,wa.z,wa.w,wb.x,wb.y,wb.z,wb.w,wc.x,wc.y,wc.z,wc.w,wd.x,wd.y,wd.z,wd.w);
 float parameter_0=D(record,8).x;
 float parameter_1=D(record,8).y;
 float parameter_2=D(record,8).z;
 float parameter_3=D(record,8).w;
 float parameter_4=D(record,9).x;
 float parameter_5=D(record,9).y;
 float parameter_6=D(record,9).z;
        float ridge_input = q.y + sin(q.x / 4700.0) * 750.0 + macro * 500.0 + 7000.0; float across = mod(ridge_input,14000.0); if (across < 0.0) across += 14000.0; across -= 7000.0;
        float ridge = exp(-pow(abs(across) / 1500.0, 1.45)), hills = (.5 + meso * .65) * parameter_0;
        float mountain = parameter_1 * ridge * (.7 + structure * .45);
        mountain += pow(1.0 - abs(structure), 4.0) * ridge * parameter_1 * .15 * parameter_2;
        float gully = (1.0 - S(.025, .16, abs(meso + structure * .2))) * parameter_3;
        float incision = gully * ridge * parameter_4 * parameter_5, karst = pow(1.0 - abs(structure), 5.0) * 330.0 + meso * 20.0;
        float plateau = S(-.13, .18, macro) * 300.0 + meso * 9.0, gorge = 1.0 - S(.04, .30, abs(structure));
        float h = w[0] * (24.0 + macro * 9.0 + meso * 1.6) + w[1] * (40.0 + hills * 95.0) + w[2] * (65.0 + hills * 200.0 + ridge * 75.0);
        h += w[3] * (65.0 + mountain * .45) + w[4] * (70.0 + mountain - incision) + w[5] * (15.0 + macro * 5.0 + meso * 2.0);
        h += w[6] * (9.0 + macro * 3.0 + meso * .6) + w[7] * (65.0 + mountain * .55 + structure * 35.0);
        h += w[8] * (45.0 + karst) + w[9] * (65.0 + plateau) + w[10] * (80.0 + mountain * .4 - gorge * parameter_5);
        h += w[11] * (16.0 + macro * 5.0 + meso * 1.5) + w[12] * (130.0 + hills * 90.0 + ridge * 120.0); h = max(h, 3.0);
        float drain = clamp(gully * (w[2] + w[3] + w[4]) + gorge * w[10] + w[5] * .4 + w[6] * .65 + w[11] * .5, 0.0, 1.0);
        float wet = clamp(.35 + (macro * .2 + meso * .1) * parameter_6 + drain * .45 + (w[0] + w[11]) * .15 - ridge * (w[4] + w[7]) * .2, .1, .95);
        float exposed = clamp(w[7] * .7 + w[8] * .85 + w[4] * .55 + w[10] * .6 + w[9] * .45 + w[2] * .2, 0.0, 1.0);
        return vec4(h, wet, drain, exposed);
}

vec4 shape_2(int record){
 vec4 n=D(record,1); float a=n.x,b=n.y,c=n.z;
 vec2 q=D(record,6).xy;
 vec4 wa=D(record,2),wb=D(record,3),wc=D(record,4),wd=D(record,5);
 float w[16]=float[](wa.x,wa.y,wa.z,wa.w,wb.x,wb.y,wb.z,wb.w,wc.x,wc.y,wc.z,wc.w,wd.x,wd.y,wd.z,wd.w);
 float parameter_0=D(record,8).x;
 float parameter_1=D(record,8).y;
 float parameter_2=D(record,8).z;
 float parameter_3=D(record,8).w;
 vec3 kopje=D(record,7).xyz;
        float ridge_input = q.x + sin(q.y / 4300.0) * 1200.0 + a * 600.0 + 7000.0; float across = mod(ridge_input,14000.0); if (across < 0.0) across += 14000.0; across -= 7000.0;
        float belt = exp(-pow(abs(across) / 1500.0, 1.6)), peaks = .78 + .16 * sin(q.y / 2200.0) + b * .22;
        float ridge = belt * parameter_0 * peaks, secondary = (1.0 - S(.02, .4, abs(b))) * belt * parameter_1 * 100.0;
        float hollow = 1.0 - S(.025, .24, abs(b + a * .2)), incision = hollow * belt * parameter_2 * parameter_3 * 70.0;
        float hills = 40.0 + b * 90.0 + a * 30.0 + sin(q.y / 1700.0 + a) * 13.0, table = S(-.18, .3, a + b * .35), edge = S(.1, .8, table) * (1.0 - S(.8, 1.0, table));
        float h = w[0] * (24.0 + a * 11.0 + b * 3.0 + c * .5 - hollow * 1.8);
        h += w[1] * (35.0 + hills * 1.3) + w[2] * (45.0 + hills * .7 + abs(b) * 70.0 + kopje.x * .2);
        h += w[3] * (30.0 + a * 14.0 + b * 9.0) + w[4] * (65.0 + ridge * .45 + secondary - incision * .8);
        h += w[5] * (24.0 + a * 8.0 + b * 4.0 + kopje.x); h += w[6] * (110.0 + ridge + secondary - incision);
        h += w[7] * (32.0 + ridge * .18 - hollow * 22.0 * parameter_3);
        h += w[8] * (9.0 + a * 3.0 + b * .8) + w[9] * (25.0 + a * 18.0 + b * 5.0 + kopje.x * .12);
        h += w[10] * (48.0 + table * 100.0 + b * 14.0 - hollow * 18.0 * parameter_2);
        h += w[11] * (45.0 + table * 310.0 + b * 18.0 + ridge * .2 - incision * .5); h += w[12] * (18.0 + a * 6.0 + b * 2.0 - hollow * 5.0);
        float drain = clamp(hollow * (w[0] * .28 + w[1] * .32 + w[4] * .6 + w[6] + w[7] * .8 + w[10] * .3) + w[8] * .75 + w[12] * .4, 0.0, 1.0);
        float wet = clamp(.18 + w[3] * .45 + w[8] * .4 + w[12] * .22 + drain * .45 - w[0] * a * .25 - w[9] * .14 - belt * w[6] * .08, .03, .85);
        float exposure = clamp(w[2] * .6 + w[4] * belt * .8 + w[5] * kopje.y + w[6] * belt * .9 + w[11] * edge * .95 + kopje.z * w[5] * .25, 0.0, 1.0);
        return vec4(max(h, 3.0), wet, drain, exposure);
}

vec4 shape_3(int record){
 vec4 n=D(record,1);float a=n.x,b=n.y,c=n.z;
 vec4 wa=D(record,2),wb=D(record,3),wc=D(record,4),wd=D(record,5);
 float w[16]=float[](wa.x,wa.y,wa.z,wa.w,wb.x,wb.y,wb.z,wb.w,wc.x,wc.y,wc.z,wc.w,wd.x,wd.y,wd.z,wd.w);
 float parameter_0=D(record,8).x;
 float parameter_1=D(record,8).y;
 float parameter_2=D(record,8).z;
 float parameter_3=D(record,8).w;
 float parameter_4=D(record,9).x;
 float parameter_5=D(record,9).y;
 float parameter_6=D(record,9).z;
        float raised = S(-.18, .22, b + a * .2), ridge = 1.0 - S(.03, .18, abs(b + c * .15));
        float offset = w[0] * -.5 + w[1] * -.9 + w[2] * .65 + w[3] * .3 + w[4] * -.3 + w[5] * .7 + w[6] * -.6 + w[7] * .25 + w[8] * .15 + w[9] * .6 - w[10] * 1.7 - w[11] * 1.2 + w[12] * 2.5 + w[13] * -.2 + w[14] * 5.0;
        offset += (.55 - parameter_0) * 4.0; float land = offset + (b * 2.2 + a * .6) * parameter_1;
        land += raised * parameter_2 * parameter_3 * (w[0] * .8 + w[1] * .6 + w[6] * 1.8 + w[10] * .7 + w[11] * .5 + w[13]);
        land += ridge * parameter_2 * parameter_4 * (w[3] + w[6] + w[7] + w[9]);
        land += c * parameter_5 * (w[5] + w[9] * 1.7 + w[14] * .4);
        float hollow = 1.0 - S(.025, .15, abs(c + b * .2)); land -= hollow * parameter_6 * (w[5] * .7 + w[9] + w[8] * .4);

 return vec4(land,raised,0.0,0.0);
}

vec4 shape_8(int record){
 vec4 n=D(record,1),a=D(record,2),b=D(record,3),c=D(record,4);
 float r=a.x,age=a.y,depth=a.z,natural=280.0+n.x*100.0+pow(max(0.0,1.0-abs(n.z)),3.0)*a.w+n.y*6.0;
 float excavation=(1.0-S(.95,1.25,r))*b.w;
 float roof=280.0+b.x*100.0+pow(max(0.0,1.0-abs(b.y)),3.0)*60.0,level=max(25.0,roof-depth);
 float t=clamp((r-.18)/.85,0.0,1.0),bench=0.0;
 for(int i=1;i<=10;i++){if(i>int(b.z))break;float threshold=float(i)/(b.z+1.0)+.024*sin(float(i)*2.31);bench+=S(threshold-.012-age*.012,threshold+.012+age*.018,t)/b.z;}
 float floor_height=level+n.y*2.0+(n.w+.5)*3.0,cut=floor_height+bench*depth;
 float h=L(natural,min(natural,cut),excavation),water=0.0;
 if(c.x>.5&&excavation>0.0)water=(level+depth*.15)*(1.0-S(.84,1.1,r));
 return vec4(h,water,clamp(.25+excavation*.4,0.0,1.0),excavation);
}
vec4 shape_9(int record){
 vec4 header=D(record,0),warp=D(record,1),n=D(record,2),b=D(record,3),c=D(record,4),d=D(record,5);
 int id=int(header.y);float width=warp.z;
 float a=warp.x,v=warp.y,joint=min(a,v),column=S(.10,.24,joint);
 float uplift=d.x*(.5+n.y*.8+n.z*.3),h=55.0+n.x*35.0,peak=0.0;
 if(id==0)peak=column*uplift*(.88+b.x*.08)+column*b.y*12.0;
 else if(id==1)peak=pow(max(0.0,1.0-abs(b.z)),4.0)*uplift*(.6+abs(b.w));
 else if(id==2)peak=pow(S(.17,.53,a*v),.45)*uplift*.7;
 else if(id==3)peak=(.3+c.x)*.6*uplift+n.w*50.0;
 else if(id==4)peak=S(.08,.23,joint)*uplift*.8;
 else peak=column*uplift*S(.3,.8,abs(c.y));
 float distance=d.y,valley=1.0-S(80.0,(id==2||id==5)?520.0:180.0,distance);
 h+=peak;h=L(h,10.0+c.z*1.4,valley);h=L(h,-3.0,1.0-S(25.0,50.0,distance));
 h+=(1.0-valley)*column*(sin(header.w/67.0+sin(header.z/370.0)*.6)*4.0+c.w*7.0);
 float water=4.0*(1.0-S(90.0,170.0,distance));
 if(d.w>0.0){h=L(h,min(h,d.z-3.0),d.w);water=max(water,d.z*d.w);}
 return vec4(h,water,clamp(.4+max(valley,d.w)*.6,0.0,1.0),column);
}
vec4 shape_10(int record){
 int id=int(D(record,0).y);vec4 n=D(record,1),a=D(record,2),b=D(record,3),c=D(record,4);
 float r=a.x,angle=a.y,age=a.z,height=a.w,edifice=0.0,crater=0.0;
 if(id==0){edifice=height*pow(max(0.0,1.0-r*.45),2.0)*.65;crater=(1.0-S(.12,.3,r))*height*.18;}
 else if(id==1){edifice=height*pow(max(0.0,1.0-r*.7),1.25);crater=(1.0-S(.1,.26,r))*height*.32;}
 else if(id==2){edifice=height*.65*(1.0-S(.9,1.5,r));crater=height*.5*(1.0-S(.61,.79,r));}
 else if(id==3){edifice=height*.18*pow(max(0.0,1.0-r),1.1);crater=height*.075*(1.0-S(.12,.28,r));}
 else if(id==4)edifice=22.0+n.x*38.0;
 else edifice=height*.25*pow(max(0.0,1.0-abs(n.x)),3.0);
 float drainage=pow(.5+.5*sin(angle*11.0+n.z*2.0),5.0)*S(.28,.7,r)*(1.0-S(1.0,1.6,r))*age;
 float flow=(1.0-S(.09,.2,abs(sin(angle*3.0+sin(r*3.0)*.25+b.x))))*S(.2,.4,r)*(1.0-S(1.2,1.8,r))*b.y;
 float rough=L(n.y*2.0,abs(n.w)*15.0,b.z),h=45.0+n.x*35.0+edifice-crater-drainage*height*.12+flow*(8.0+rough);
 if(id<3&&b.w>.5)h-=(1.0-S(.05,.24,r))*min(height*.18,130.0);
 if(id==5)h-=35.0*(1.0-S(40.0,130.0,abs(c.y+sin(c.x/700.0)*130.0)));
 float water=id==2&&c.z>.5?(45.0+height*.23)*(1.0-S(.82,1.05,r)):0.0;
 return vec4(h,water,clamp(age*.7,0.0,1.0),flow);
}
vec4 shape_11(int record){
 int id=int(D(record,0).y);vec4 n=D(record,1),a=D(record,2),b=D(record,3);
 float colony=a.z,h=40.0+n.x*a.x+n.y*a.y;
 if(id==1)h+=a.w;if(id==2)h+=colony*6.0;if(id==3)h-=colony*22.0;
 if(id==4)h+=pow(max(0.0,1.0-abs(n.z)),3.0)*120.0;
 float wet=clamp(.35+colony*.4+(id==3?.2:0.0)-(id==5?.3:0.0),0.0,1.0),water=0.0;
 if(id==3&&b.y>.5){water=27.0*(1.0-S(.65,1.2,n.w));h=L(h,19.0+n.y,1.0-S(.5,.8,n.w));}
 return vec4(h,water,wet,.5*colony+.5*b.x);
}
vec4 shape_12(int record){
 int id=int(D(record,0).y);vec4 n=D(record,1),a=D(record,2),b=D(record,3),channel=D(record,4);
 float r=n.w,damage=a.z,h=70.0+n.x*a.x+n.y*a.y;
 if(id==1||id==2){float bowl=1.0-S(.15,.95,r),rim=S(.65,.92,r)*(1.0-S(.94,1.2,r));h+=damage*b.x*(-bowl+rim*.24)*(1.0-b.y*.25);}
 if(id==3)h+=pow(max(0.0,1.0-abs(n.z)),4.0)*180.0;if(id==4)h+=a.w*8.0;if(id==5)h=L(h,26.0+n.y*.7,1.0-S(.45,1.4,r));
 float cut=(1.0-S(16.0,160.0,channel.x))*b.z*(.25+b.y*.75);
 h=L(h,min(h,channel.y+pow(max(0.0,channel.x/160.0),1.4)*100.0),cut);h+=channel.z*(1.0-cut)*a.w*2.0;
 float water=0.0;if((id==1||id==5)&&b.w>.5)water=(id==5?30.0:70.0-b.x*.65)*(1.0-S(.75,1.2,r));
 return vec4(h,water,.15+max(0.0,water-h)*.02,id<3?damage:a.w);
}
vec4 shape_13(int record){
 int id=int(D(record,0).y);vec4 n=D(record,1),a=D(record,2),b=D(record,3);
 float growth=(1.0-S(.4,1.6,n.w+n.y*.15))*a.z,ridge=pow(max(0.0,1.0-abs(n.z)),5.0);
 float h=65.0+n.x*b.x+n.y*b.y+ridge*b.z,vein=1.0-S(22.0,80.0,abs(a.y+sin(a.x/700.0)*90.0));h+=vein*growth*18.0;
 float water=0.0;if(id==5){float basin=1.0-S(.4,1.2,n.w);h=L(h,24.0+n.y,basin);if(a.w>.5)water=32.0*(1.0-S(.8,1.4,n.w));}
 return vec4(h,water,.2,growth);
}
vec4 shape_14(int record){
 int id=int(D(record,0).y);vec4 n=D(record,1),a=D(record,2),b=D(record,3);
 float r=n.z,foundation=1.0-S(.15,.9,r),distance=(r-.94)/.24,excavation=exp(-distance*distance)*n.w;
 float h=65.0+n.x*b.x+n.y*2.0;
 h+=foundation*((id==1||id==3)?40.0:18.0)+a.x*12.0+excavation*10.0-a.y*2.0;
 if(id==1){float q=r/.2;h-=exp(-q*q)*28.0;}if(id==4)h-=foundation*8.0;
 float water=0.0;if(id==4&&a.w>.5){water=48.0*(1.0-S(.35,.8,r));h=L(h,40.0,foundation);}
 return vec4(h,water,.2+a.z*.3,clamp(foundation+a.x*.7+a.y*.6,0.0,1.0));
}
vec4 shape_15(int record){
 int id=int(D(record,0).y);vec4 n=D(record,1),a=D(record,2),b=D(record,3),c=D(record,4);
 float trunk=a.x/100.0,branch=a.y/42.0,ridge=exp(-trunk*trunk)+exp(-branch*branch)*.35,core=1.0-S(160.0,650.0,a.z);
 float h=60.0+n.x*b.x+n.y*b.y;h+=ridge*b.z*(.7+a.w*.6);
 if(id==2)h+=pow(max(0.0,1.0-abs(n.z)),4.0)*160.0;
 if(id==3)h+=50.0-core*75.0-ridge*b.z*(.7+a.w*.6)*core;
 if(id==4)h+=core*45.0-core*core*b.w;if(id==1)h+=c.x;
 return vec4(h,0.0,.25+n.w*.5,n.w);
}

vec4 shape_5(int record){
 vec4 n=D(record,1),parameters=D(record,2),extra=D(record,3);
 float b=n.x,spacing=n.y,gain=n.z,mountain=n.w,cliff=parameters.x,span=extra.x;
 float height=0.0,ridge=0.0,secondary=0.0,peak=0.0;
 for(int k=0;k<3;k++){
  vec4 lane=D(record,4+k);if(lane.w<.5)continue;
  float across=lane.x,width=lane.y,shoulder=1.0-S(spacing*.42,spacing*.65,abs(across));
  float asym=.7+.6*S(-500.0,500.0,across+b*250.0),d=abs(across)/max(width*asym,cliff);
  float rounded=exp(-d*d*.75),sharp=exp(-pow(d,parameters.y)*1.5);
  float shape=L(sharp,rounded,parameters.z)*shoulder,summits=0.0;
  for(int j=0;j<3;j++){
   vec4 site=D(record,7+k*3+j);
   float prominence=exp(-pow(max(site.x,0.0),1.6))*(.55+site.y*.65);
   summits=max(summits,prominence);
  }
  float core=shape*(.55+summits*.65),branch_distance=min(lane.z,1.0-lane.z)*span;
  float q=branch_distance/max(150.0,span*.11);
  float branches=exp(-q*q)*shoulder*(1.0-S(width*.2,spacing*.6,abs(across)));
  branches*=parameters.w*(.3+.7*shape);
  float value=core*mountain*gain;value+=branches*mountain*.22;
  float shelf=(1.0-S(cliff,cliff*2.0,abs(across)-width*.45))*extra.z;
  value+=shelf*mountain*extra.y;
  height=max(height,value);ridge=max(ridge,shape);secondary=max(secondary,branches);peak=max(peak,summits*shape);
 }
 return vec4(height,ridge,secondary,peak);
}
vec4 shape_6(int record){
 vec4 n=D(record,1),parameters=D(record,2);
 float a=n.x,b=n.y,calm=n.z,rugged=n.w,water=parameters.x,hills=parameters.y;
 float h=water+30.0+a*18.0+(b*.5+.25)*hills*(1.0-calm)*(1.0-rugged*.3),ridge=0.0,branches=0.0;
 for(int k=0;k<2;k++){
  vec4 lane=D(record,3+k);if(lane.w<.5)continue;
  float across=lane.x,width=lane.y,shape=exp(-pow(abs(across)/(width*(.9+b*.2)),1.8)),summits=0.0;
  for(int j=0;j<3;j++){
   vec4 site=D(record,5+k*3+j);
   summits=max(summits,exp(-site.x*site.x)*(.55+site.y*.55));
  }
  float phase=lane.z,q=min(phase,2100.0-phase)/220.0;
  float branch=exp(-q*q)*shape*(1.0-S(100.0,600.0,abs(across)));
  branches=max(branches,branch);ridge=max(ridge,shape*(.45+summits*.65));
 }
 if(rugged>.001)h+=(ridge+branches*.14)*parameters.w*parameters.z;
 return vec4(h,ridge,branches,0.0);
}
vec4 shape_7(int record){
 vec4 n=D(record,1),a=D(record,2),b=D(record,3);
 float relief=n.w,primary=a.x,fine=a.y,clay=a.z,width=a.w;
 float upland=1.0-exp(-pow(max(primary-width,0.0)/(900.0+clay*500.0+b.x*700.0),1.6));
 float plateau=S(.35,.72,upland+n.x*.3),mass_height=relief*(.82+n.x*.3)*upland;
 if(b.z>0.0){
  float lobes=pow(clamp(.5+n.y*.8+n.z*.35,0.0,1.0),1.35);
  float height=relief*(.15+.95*lobes+n.x*.08)*upland;mass_height=L(mass_height,height,b.z);
 }
 float h=28.0+(mass_height+relief*.25*plateau*b.y),main=1.0-S(width*.5,width*2.0,fine);
 h=L(h,min(h,25.0+n.y*.8),main);return vec4(h,upland,plateau,main);
}

vec4 shape_at(int record){
 int offset=int(read_input(record/4)[record%4]);
 int kind=int(D(offset,0).x);
 if(kind==1)return shape_1(offset);
 if(kind==2)return shape_2(offset);
 if(kind==3)return shape_3(offset);
 if(kind==4)return shape_4(offset);
 if(kind==5)return shape_5(offset);
 if(kind==6)return shape_6(offset);
 if(kind==7)return shape_7(offset);
 if(kind==8)return shape_8(offset);
 if(kind==9)return shape_9(offset);
 if(kind==10)return shape_10(offset);
 if(kind==11)return shape_11(offset);
 if(kind==12)return shape_12(offset);
 if(kind==13)return shape_13(offset);
 if(kind==14)return shape_14(offset);
 if(kind==15)return shape_15(offset);
 return vec4(0.0);
}
vec4 numeric_bytes(float v){
 uint bits=floatBitsToUint(v);
 return vec4(float(bits&255u),float((bits>>8u)&255u),float((bits>>16u)&255u),float((bits>>24u)&255u))/255.0;
}
void fragment(){
 ivec2 pixel=ivec2(FRAGCOORD.xy);
 int index=pixel.y*sample_columns+pixel.x;
 if(index>=sample_count)COLOR=numeric_bytes(0.0);
 else{vec4 v=shape_at(index/4);COLOR=numeric_bytes(v[index%4]);}
}
