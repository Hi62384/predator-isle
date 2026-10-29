 vec3 color,gradient,emission;float rough;
 shade_extension(7,extension_control(7),n,forest_dx,forest_dy,projection,fine,color,rough,gradient,emission);
 vec3 mapped=normalize(n+gradient);
 ALBEDO=color;ROUGHNESS=rough;SPECULAR=.2;EMISSION=emission;
 NORMAL=normalize((VIEW_MATRIX*vec4(mapped,0)).xyz);
 if(debug_view==3){ALBEDO=vec3(0);EMISSION=color;}
 if(debug_view==4 || debug_view==8){ALBEDO=vec3(0);EMISSION=(debug_view==4?n:mapped)*.5+.5;}
