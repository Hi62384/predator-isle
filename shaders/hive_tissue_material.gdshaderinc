// Shared actual cave/breach response. Callers provide the existing biological
// sampling coordinate frame;the surface texture does not restart at a portal.
void shade_hive_tissue(float region,float hive_view_range,vec3 n,vec3 dx,vec3 dy,float strength,out vec3 base,out float rough,out vec3 mapped){
 n=normalize(n);vec3 weights=pow(abs(n),vec3(6));weights/=max(dot(weights,vec3(1)),.0001);vec3 tissue;
 alien_tissue_sample(region,hive_view_range,dx,dy,weights,n,tissue,rough);
 base=tissue*.5;mapped=n;
 // Reuse the existing restrained3mm apparent relief. This is generated
 // albedo-derived detail,not a measured normal scan or collision displacement.
 float height=dot(tissue,vec3(.3,.5,.2))*.003;vec3 r1=cross(dy,n),r2=cross(n,dx);float determinant=dot(dx,r1);
 if(strength>.001 && abs(determinant)>.000001){vec3 gradient=-clamp((r1*dFdx(height)+r2*dFdy(height))/determinant,vec3(-.25),vec3(.25));mapped=normalize(n+gradient*strength);}
 rough=clamp(rough,.48,.9);
}
