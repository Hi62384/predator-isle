// Authored Beer-Lambert approximation,not measured mineral scans or ray tracing.
// UV width is a physical minimum cross-section from the actual prism emitter.
float mineral_clear_cap(int kind){
 return kind==0?.42:(kind==1?.28:(kind==2?.52:(kind==3?.18:(kind==4?.60:.04))));
}
float mineral_extinction(int kind){
 return kind==0?.15:(kind==1?.18:(kind==2?.18:(kind==3?.25:(kind==4?.12:.30))));
}
float mineral_ior(int kind){return kind==4?1.434:(kind==2?1.52:1.54);}
vec3 mineral_throughput(int kind,float thickness,float incidence,vec3 tint){
 float path=max(thickness,.01)/max(incidence,.2);
 return mineral_clear_cap(kind)*exp(-mineral_extinction(kind)*path)*exp(-(vec3(1)-clamp(tint,vec3(0),vec3(1)))*path*.035);
}
