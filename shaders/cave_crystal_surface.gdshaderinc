// Authored regional mineral replacement of the existing host-rock PBR.
// Coherent physical joint coordinates are shared by real attached vein forms.
uniform bool cave_crystal_localized_veins=true;
float cave_crystal_sediment(vec3 p){
 float patch=.5+.5*sin(p.x*(6.283185307179586/24.0)+sin(p.z*(6.283185307179586/32.0)))*sin(p.z*(6.283185307179586/48.0));
 float phase=dot(p,vec3(6.283185307179586/.04,0.0,6.283185307179586/.06));
 float grains=.5+.5*sin(phase)*(1.0-smoothstep(.5,2.0,fwidth(phase)));
 return smoothstep(.25,.8,patch)*(.7+.3*grains);
}
float cave_crystal_vein(vec3 p){
 float a=sin(p.y*(6.283185307179586/12.0)+.3*sin(p.x*(6.283185307179586/96.0))+.25*sin(p.z*(6.283185307179586/120.0)));
 float b=sin(p.z*(6.283185307179586/120.0)-p.y*(6.283185307179586/192.0)+.3*sin(p.x*(6.283185307179586/384.0)));
 float width=max(fwidth(a),fwidth(b));float exposure=1.0;
 if(cave_crystal_localized_veins){float patch=.5+.5*sin(p.x*(6.283185307179586/48.0)+.7*sin(p.z*(6.283185307179586/32.0)))*sin(p.z*(6.283185307179586/60.0)-p.y*(6.283185307179586/48.0));exposure=smoothstep(.60,.82,patch);}
 return (1.0-smoothstep(.035,.09+width,min(abs(a),abs(b))))*exposure;
}
