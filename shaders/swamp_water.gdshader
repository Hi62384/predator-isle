shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;
// One shared material for every streamed Swamp tile, never one per pond.
uniform float ocean_level=0.0;
uniform float swamp_water_opacity=.88;
uniform float swamp_ripple=.015;
uniform float swamp_flood_stage=0.0;
uniform int swamp_water_debug=0;
varying vec3 water_world;
uniform float flight_cell_size=0.0;
uniform sampler2D flight_coverage : filter_nearest, repeat_disable;
uniform sampler2D middle_coverage : filter_nearest, repeat_disable;
varying flat float water_ring;

void vertex(){
 water_ring=CUSTOM0.x;
 VERTEX.y+=swamp_flood_stage*COLOR.b;
 water_world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 // Ripple normals only: waves must not push water through a shallow shoreline.
}
#include "res://shaders/water_ripples.gdshaderinc"
void fragment(){
 vec2 local_phase=water_world.xz;
 if(flight_cell_size>0.0 && water_ring!=0.0){
  vec2 cell=floor(water_world.xz/flight_cell_size);
  vec4 fine=texelFetch(flight_coverage,ivec2(mod(cell,8.0)),0);
  vec4 mid=texelFetch(middle_coverage,ivec2(mod(cell,64.0)),0);
  bool covered=mid.a>0.5 && all(equal(cell,mid.xy));
  if(fine.a>0.5 && all(equal(cell,fine.xy)))discard;
  if(water_ring<0.0 ? (!covered || mid.z!=-water_ring) : (covered && mid.z<water_ring))discard;
 }
 float depth=water_world.y-UV.x;
 float mountain=clamp(-UV2.y,0.0,1.0);
 float coast=clamp(-UV2.x,0.0,1.0);
 // Interpolate wetland ownership through mixed shoreline triangles.
 float coverage=smoothstep(.01,.25,COLOR.b+mountain);
 // The ocean already covers sea-level channels. Fade inland water in as its surface rises.
 coverage*=smoothstep(0.0,0.35,water_world.y-ocean_level);
 if(depth<=.015 || coverage<=0.0)discard;
 float sediment=clamp(COLOR.r,0.0,1.0),organic=clamp(COLOR.g,0.0,1.0);
 vec3 silt=vec3(.19,.145,.09),blackwater=vec3(.055,.047,.032),neutral=vec3(.10,.13,.115);
 vec3 tint=mix(neutral,silt,sediment*.8);
 tint=mix(tint,blackwater,organic*.8);
 tint=mix(tint,mix(vec3(.035,.13,.15),vec3(.13,.16,.145),sediment*.6),mountain);
 tint=mix(tint,vec3(.045,.16,.17),coast);
 float deep=1.0-exp(-depth*(.55+organic+sediment*.6));
 ALBEDO=tint*mix(1.3,.5,deep);
 float ripple=swamp_ripple*(1.0-smoothstep(1000.0,5000.0,length(VERTEX)));
 vec2 r=water_ripples(local_phase,TIME*.55)*ripple;
 NORMAL_MAP=vec3(.5+r.x,.5+r.y,1);
 NORMAL_MAP_DEPTH=.7;
 ROUGHNESS=mix(.22,.4,sediment);
 SPECULAR=.4;
 ALPHA=clamp((.25+deep*.75)*swamp_water_opacity,.12,.98)*smoothstep(.015,.10,depth)*coverage;
 if(swamp_water_debug>=140 && swamp_water_debug<=159){
  ALBEDO=vec3(0);EMISSION=vec3(.04,.06,.07);ALPHA=.85;
  if(swamp_water_debug==142)EMISSION=vec3(clamp(UV.y/20.0,0.0,1.0));
  if(swamp_water_debug==144)EMISSION=vec3(clamp(depth/5.0,0.0,1.0));
  if(swamp_water_debug==145)EMISSION=vec3(UV2.x,COLOR.a,UV2.y);
 }
 if(swamp_water_debug>=160 && swamp_water_debug<=199){
  ALBEDO=vec3(0);EMISSION=vec3(.04,.08,.09);ALPHA=.9;
  if(swamp_water_debug==172 || swamp_water_debug==189)EMISSION=vec3(clamp(depth/2.0,0.0,1.0));
 }
}
