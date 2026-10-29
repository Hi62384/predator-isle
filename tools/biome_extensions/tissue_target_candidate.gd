extends RefCounted
## Private compilation trial. Exactly the same two possible material targets
## and branch thresholds, but two call sites instead of four expanded copies.
const BEFORE="""
 if(a==b || blend<=.001){color=alien_tissue_color(a,detail,dx,dy,projection,n);rough=alien_tissue_roughness(a);}
 else if(blend>=.999){color=alien_tissue_color(b,detail,dx,dy,projection,n);rough=alien_tissue_roughness(b);}
 else{color=mix(alien_tissue_color(a,detail,dx,dy,projection,n),alien_tissue_color(b,detail,dx,dy,projection,n),blend);rough=mix(alien_tissue_roughness(a),alien_tissue_roughness(b),blend);}
"""
const AFTER="""
 if(a==b || blend<=.001)blend=0.0;
 else if(blend>=.999){a=b;blend=0.0;}
 color=alien_tissue_color(a,detail,dx,dy,projection,n);rough=alien_tissue_roughness(a);
 if(blend>0.0){color=mix(color,alien_tissue_color(b,detail,dx,dy,projection,n),blend);rough=mix(rough,alien_tissue_roughness(b),blend);}
"""
static func apply_to(source:String)->String:
	assert(source.count(BEFORE)==1,"Exact original regional target branch required")
	return source.replace(BEFORE,AFTER)
