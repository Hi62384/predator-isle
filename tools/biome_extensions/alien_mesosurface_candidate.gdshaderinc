// Private material trial. Not bound by the game. Both terrain and attached
// tissue use the same physical coordinates and finish; no geometry/lighting
// changes, texture replacement, or displacement are implied by this material.
uniform float alien_mesosurface_amount=0.0;
uniform float alien_detail_contrast=1.0;
#include "res://shaders/biological_sampling.gdshaderinc"
float alien_mesosurface_relief(vec3 p){
 float warp=field(p.xz*.018);
 float phase=p.x*.38+p.z*.19+p.y*.23+(warp-.5)*7.0;
 float folds=pow(.5+.5*sin(phase),8.0);
 return folds*.045;
}
void alien_mesosurface_finish(inout vec3 color,inout float rough){
 // Retain the existing, renderer-correct tissue images, but subordinate their
 // repeated micro-motifs to broad, irregular film/plate weathering. The new
 // fold relief is apparent shading only, never a traversal/collision feature.
 float patch=field(world_position.xz*.021);
 color*=mix(1.0,mix(.52,.78,smoothstep(.12,.88,patch)),alien_mesosurface_amount);
 rough=mix(rough,clamp(rough*.5+.36+(patch-.5)*.12,.52,.94),alien_mesosurface_amount);
}
float alien_mesosurface_height(vec3 tissue,float distance_to_view){
 float original=dot(tissue,vec3(.3,.5,.2))*.003;
 return original+alien_mesosurface_amount*alien_mesosurface_relief(world_position)*(1.0-smoothstep(150.0,900.0,distance_to_view));
}
