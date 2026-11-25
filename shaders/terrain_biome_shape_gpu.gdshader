shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D numeric_inputs : filter_nearest, repeat_disable;
uniform int sample_count=0;
uniform int sample_columns=256;
uniform int sample_rows=2;
const int BANDS=16;
vec4 D(int record,int band){int index=record*BANDS+band;return texelFetch(numeric_inputs,ivec2(index%sample_columns,index/sample_columns),0);}
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
        float input = q.X + sin(q.Y / 3900.0) * 950.0 + a * 480.0 + 6500.0; float across = mod(input,13000.0); if (across < 0.0) across += 13000.0; across -= 6500.0;
        float ridge = exp(-pow(abs(across) / max(parameter_0 * .5, 400.0), 1.65));
        float saddles = .75 + .15 * sin(q.Y / 1800.0) + b * .25, mountain = parameter_1 * ridge * saddles;
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
        float input = q.Y + sin(q.X / 4700.0) * 750.0 + macro * 500.0 + 7000.0; float across = mod(input,14000.0); if (across < 0.0) across += 14000.0; across -= 7000.0;
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
        float input = q.X + sin(q.Y / 4300.0) * 1200.0 + a * 600.0 + 7000.0; float across = mod(input,14000.0); if (across < 0.0) across += 14000.0; across -= 7000.0;
        float belt = exp(-pow(abs(across) / 1500.0, 1.6)), peaks = .78 + .16 * sin(q.Y / 2200.0) + b * .22;
        float ridge = belt * parameter_0 * peaks, secondary = (1.0 - S(.02, .4, abs(b))) * belt * parameter_1 * 100.0;
        float hollow = 1.0 - S(.025, .24, abs(b + a * .2)), incision = hollow * belt * parameter_2 * parameter_3 * 70.0;
        float hills = 40.0 + b * 90.0 + a * 30.0 + sin(q.Y / 1700.0 + a) * 13.0, table = S(-.18, .3, a + b * .35), edge = S(.1, .8, table) * (1.0 - S(.8, 1.0, table));
        float h = w[0] * (24.0 + a * 11.0 + b * 3.0 + c * .5 - hollow * 1.8);
        h += w[1] * (35.0 + hills * 1.3) + w[2] * (45.0 + hills * .7 + abs(b) * 70.0 + kopje.X * .2);
        h += w[3] * (30.0 + a * 14.0 + b * 9.0) + w[4] * (65.0 + ridge * .45 + secondary - incision * .8);
        h += w[5] * (24.0 + a * 8.0 + b * 4.0 + kopje.X); h += w[6] * (110.0 + ridge + secondary - incision);
        h += w[7] * (32.0 + ridge * .18 - hollow * 22.0 * parameter_3);
        h += w[8] * (9.0 + a * 3.0 + b * .8) + w[9] * (25.0 + a * 18.0 + b * 5.0 + kopje.X * .12);
        h += w[10] * (48.0 + table * 100.0 + b * 14.0 - hollow * 18.0 * parameter_2);
        h += w[11] * (45.0 + table * 310.0 + b * 18.0 + ridge * .2 - incision * .5); h += w[12] * (18.0 + a * 6.0 + b * 2.0 - hollow * 5.0);
        float drain = clamp(hollow * (w[0] * .28 + w[1] * .32 + w[4] * .6 + w[6] + w[7] * .8 + w[10] * .3) + w[8] * .75 + w[12] * .4, 0.0, 1.0);
        float wet = clamp(.18 + w[3] * .45 + w[8] * .4 + w[12] * .22 + drain * .45 - w[0] * a * .25 - w[9] * .14 - belt * w[6] * .08, .03, .85);
        float exposure = clamp(w[2] * .6 + w[4] * belt * .8 + w[5] * kopje.Y + w[6] * belt * .9 + w[11] * edge * .95 + kopje.Z * w[5] * .25, 0.0, 1.0);
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

vec4 shape_at(int record){
 int kind=int(D(record,0).x);
 if(kind==1)return shape_1(record);
 if(kind==2)return shape_2(record);
 if(kind==3)return shape_3(record);
 if(kind==4)return shape_4(record);
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
