shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx;
uniform sampler2D scene_color:hint_screen_texture,filter_linear_mipmap,repeat_disable;
uniform float index_of_refraction=1.54;
uniform float optical_thickness=8.0;
uniform int debug_view=0;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
 vec3 n=normalize(NORMAL),incident=-normalize(VIEW);float fresnel=.045+.955*pow(1.0-max(dot(-incident,n),0.0),5.0);
 vec3 ray=refract(incident,n,1.0/index_of_refraction);
 vec2 displacement=ray.xy/max(abs(ray.z),.35)*.025*clamp(optical_thickness/8.0,.25,2.0);
 vec2 uv=clamp(SCREEN_UV+displacement,vec2(.002),vec2(.998));
 vec3 behind=textureLod(scene_color,uv,.65).rgb;
 vec3 absorption=(vec3(1.0)-COLOR.rgb)*optical_thickness*.09;
 vec3 transmission=behind*exp(-absorption);
 float inclusion=pow(.5+.5*sin(world.y*1.4+sin(world.x*.31)*3.0+sin(world.z*.27)),22.0)*.08;
 ALBEDO=COLOR.rgb*.12+inclusion;EMISSION=transmission*(1.0-fresnel)*.72;
 ROUGHNESS=.12+inclusion;SPECULAR=.8;METALLIC=0.0;ALPHA=1.0;
 if(debug_view==4 || debug_view==8){vec3 geometric=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0)).xyz);ALBEDO=vec3(0);EMISSION=geometric*.5+.5;ROUGHNESS=1.0;SPECULAR=0.0;}
}
