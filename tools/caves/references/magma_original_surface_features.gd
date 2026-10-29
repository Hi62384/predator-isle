extends RefCounted
## Finite, worker-owned supplementary geometry. Surface portals are shared with
## the ground shader and heightfield collision; they are not black decals.
const Geometry=preload("res://scripts/biome_extension_structures.gd")
var g=Geometry.new()
var origin:=Vector3.ZERO
var builder
var surfaces:Array=[]
var interior_reference:=Vector3.ZERO
func reset()->void:
	g.vertices=PackedVector3Array();g.normals=PackedVector3Array();g.colors=PackedColorArray();g.uvs=PackedVector2Array();g.origin=origin
func arrays()->Array:
	if g.vertices.is_empty():return []
	var a:Array=[];a.resize(Mesh.ARRAY_MAX);a[Mesh.ARRAY_VERTEX]=g.vertices;a[Mesh.ARRAY_NORMAL]=g.normals;a[Mesh.ARRAY_COLOR]=g.colors;a[Mesh.ARRAY_TEX_UV]=g.uvs;return a
func portal_sites(bounds:Rect2)->Array:
	var sites:Array=[]
	for family_id:int in [1,2,6,7]:
		var sampler=builder._extras[family_id]
		if sampler==null or not sampler.settings.caves_enabled:continue
		var span:float=8192*sampler.settings.feature_scale
		var first:=Vector2i(floori((bounds.position.x-320)/span)-1,floori((bounds.position.y-320)/span)-1)
		var last:=Vector2i(ceili((bounds.end.x+320)/span),ceili((bounds.end.y+320)/span))
		for z in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				var d:Dictionary=sampler.descriptor(Vector2i(x,z),span)
				if d.chance>sampler.settings.cave_frequency:continue
				var p:Vector2=(d.position/32).round()*32
				if not bounds.grow(320).has_point(p):continue
				builder._biome_weights(p.x,p.y)
				if builder._extra_weights[family_id]<.92 or builder._island_mask(p.x,p.y)<.1:continue
				var roof:float=INF;var high:float=-INF;var dry:bool=true
				for dz:int in [-1,0,1]:
					for dx:int in [-1,0,1]:
						var q:Vector2=p+Vector2(dx*256,dz*128);var h:float=builder._get_height(q.x,q.y)
						roof=minf(roof,h);high=maxf(high,h);dry=dry and h>maxf(builder.water_level,builder.get_water_surface_height(q.x,q.y))+14
				if not dry or high-roof>170:continue
				var floor_h:float=maxf(builder.water_level+8,roof-72)
				if roof-floor_h<24:continue
				sites.append({"id":d.id,"family":family_id,"position":p,"half":96.0,"phase":d.angle,"floor":floor_h,"top":high+2,"roof":floor_h+20,"owner":p,"kind":"lava_tube" if family_id==2 else ("burrow" if family_id==6 else ("hive_chamber" if family_id==7 else "rock_cavern"))})
	return sites
func interior_quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3,color:Color)->void:
	# Two-sided rendering is used for cavity walls. Physics is explicitly backface-enabled.
	if (c-a).cross(b-a).dot(interior_reference-(a+b+c+d)*.25)>0:g.quad(a,b,c,d,color)
	else:g.quad(a,d,c,b,color)
func cavern(site:Dictionary)->void:
	var p:Vector2=site.position;var r:float=site.half;var bottom:float=site.floor;var ceiling:float=site.roof
	interior_reference=Vector3(p.x,bottom+5,p.y)
	var color:=Color(.4,.34,.28) if site.family!=7 else Color(.24,.18,.19)
	var ring:Array[Vector2]=[]
	var ring_count:int=192
	for i in range(ring_count):
		var angle:float=i*TAU/ring_count;var radius:float=r*(1+.1*sin(angle*3+site.phase)+.06*sin(angle*7-site.phase));ring.append(Vector2(cos(angle),sin(angle))*radius)
	for i in range(ring_count):
		var a:Vector2=p+ring[i];var b:Vector2=p+ring[(i+1)%ring_count]
		# The shell overlaps the ground vertically to seal small LOD height
		# differences. Bury only the actual apron crossing: lowering the whole
		# circumference opened a thin sky-visible crack around the shaft.
		var a_lip:float=-.5 if a.x>p.x+r*.85 and absf(a.y-p.y)<4.25 else 1.0
		var b_lip:float=-.5 if b.x>p.x+r*.85 and absf(b.y-p.y)<4.25 else 1.0
		var at:=Vector3(a.x,builder._get_height(a.x,a.y)+a_lip,a.y);var bt:=Vector3(b.x,builder._get_height(b.x,b.y)+b_lip,b.y)
		# The missing lower wall section is a real doorway, not a dark decal.
		if (a.x+b.x)*.5>p.x+r*.9 and absf((a.y+b.y)*.5-p.y)<12:
			interior_quad(Vector3(a.x,ceiling,a.y),Vector3(b.x,ceiling,b.y),bt,at,color)
		else:interior_quad(Vector3(a.x,bottom,a.y),Vector3(b.x,bottom,b.y),bt,at,color)
	var floor_indices:PackedInt32Array=Geometry2D.triangulate_polygon(PackedVector2Array(ring))
	for i in range(0,floor_indices.size(),3):
		var a:Vector2=p+ring[floor_indices[i]];var b:Vector2=p+ring[floor_indices[i+1]];var c:Vector2=p+ring[floor_indices[i+2]]
		g.triangle(Vector3(a.x,bottom,a.y),Vector3(b.x,bottom,b.y),Vector3(c.x,bottom,c.y),color)
	# Sloped spiral access: 8 m clear walking width, <= 12% analytic grade.
	var radius:float=70;var entry:float=ring[0].x;var turns:int=maxi(1,ceili((site.top-bottom)/(TAU*radius*.12)))
	var segments:int=turns*96;var top_h:float=builder._get_height(p.x+entry,p.y)+.15
	for i in range(segments):
		var t:float=float(i)/segments;var u:float=float(i+1)/segments
		var a:Vector2=Vector2(cos(t*turns*TAU),sin(t*turns*TAU));var b:Vector2=Vector2(cos(u*turns*TAU),sin(u*turns*TAU))
		g.quad(Vector3(p.x+a.x*(radius-4),lerpf(top_h,bottom,t),p.y+a.y*(radius-4)),Vector3(p.x+a.x*(radius+4),lerpf(top_h,bottom,t),p.y+a.y*(radius+4)),Vector3(p.x+b.x*(radius+4),lerpf(top_h,bottom,u),p.y+b.y*(radius+4)),Vector3(p.x+b.x*(radius-4),lerpf(top_h,bottom,u),p.y+b.y*(radius-4)),color)
	# A conforming outer apron joins the actual terrain, not a flat platform
	# whose edge can leave an unwalkable step on either side of the portal.
	for i in range(24):
		var xa:float=lerpf(74,entry+12,float(i)/24);var xb:float=lerpf(74,entry+12,float(i+1)/24)
		var v:Array[Vector3]=[]
		for q:Vector2 in [Vector2(xa,-4),Vector2(xb,-4),Vector2(xb,4),Vector2(xa,4)]:
			var blend:float=smoothstep(entry-5,entry+10,q.x)
			var height:float=lerpf(top_h,builder._get_height(p.x+q.x,p.y+q.y)+.04,blend)
			v.append(Vector3(p.x+q.x,height,p.y+q.y))
		g.quad(v[0],v[1],v[2],v[3],color)
	# Closed horizontal gallery with headroom, genuinely below uncut ground.
	var x0:float=p.x+entry-5;var x1:float=p.x+256;var z0:float=p.y-16;var z1:float=p.y+16
	g.quad(Vector3(x0,bottom,z0),Vector3(x1,bottom,z0),Vector3(x1,bottom,z1),Vector3(x0,bottom,z1),color)
	g.quad(Vector3(x0,ceiling,z1),Vector3(x1,ceiling,z1),Vector3(x1,ceiling,z0),Vector3(x0,ceiling,z0),color)
	for z:float in [z0,z1]:interior_quad(Vector3(x0,bottom,z),Vector3(x1,bottom,z),Vector3(x1,ceiling,z),Vector3(x0,ceiling,z),color)
	interior_quad(Vector3(x1,bottom,z0),Vector3(x1,bottom,z1),Vector3(x1,ceiling,z1),Vector3(x1,ceiling,z0),color)
func clipped_liquid(a:Vector3,b:Vector3,c:Vector3,level:float,color:Color)->void:
	var poly:Array[Vector3]=[a,b,c];var clipped:Array[Vector3]=[]
	for i in range(3):
		var p:Vector3=poly[i];var q:Vector3=poly[(i+1)%3];var pi:bool=p.y<level-.05;var qi:bool=q.y<level-.05
		if pi:clipped.append(Vector3(p.x,level,p.z))
		if pi!=qi:
			var inside:Vector3=p if pi else q;var outside:Vector3=q if pi else p
			for iteration in range(12):
				var mid:Vector3=(inside+outside)*.5
				if builder._get_height(mid.x,mid.z)<level-.05:inside=mid
				else:outside=mid
			clipped.append(Vector3(inside.x,level,inside.z))
	for i in range(1,clipped.size()-1):g.triangle(clipped[0],clipped[i],clipped[i+1],color)
func pool(p:Vector2,radius:float,color:Color)->bool:
	var center:float=builder._get_height(p.x,p.y);var rim:float=INF
	for i in range(32):
		var q:Vector2=p+Vector2(cos(i*TAU/32),sin(i*TAU/32))*radius;rim=minf(rim,builder._get_height(q.x,q.y))
	var level:float=minf(center+maxf(2,(rim-center)*.35),rim-.5)
	if level<center+.5 or level<builder.water_level+2:return false
	var step:float=radius/12
	for z in range(-12,12):
		for x in range(-12,12):
			if Vector2(x+.5,z+.5).length()>11.4:continue
			var v:Array[Vector3]=[]
			for offset:Vector2 in [Vector2(x,z),Vector2(x+1,z),Vector2(x+1,z+1),Vector2(x,z+1)]:
				var q:Vector2=p+offset*step;v.append(Vector3(q.x,builder._get_height(q.x,q.y),q.y))
			clipped_liquid(v[0],v[1],v[2],level,color);clipped_liquid(v[0],v[2],v[3],level,color)
	return true
func liquid_sites(bounds:Rect2,family_id:int)->Array:
	var sites:Array=[];var sampler=builder._extras[family_id]
	if sampler==null or not sampler.settings.special_liquids_enabled:return sites
	var span:float=(7200 if family_id==2 else 4096)*sampler.settings.feature_scale
	var first:=Vector2i(floori(bounds.position.x/span)-1,floori(bounds.position.y/span)-1);var last:=Vector2i(ceili(bounds.end.x/span),ceili(bounds.end.y/span))
	for z in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			var d:Dictionary=sampler.descriptor(Vector2i(x,z),span);var p:Vector2=d.position if family_id==2 else sampler.hive_node(Vector2i(x,z))
			if not bounds.has_point(p):continue
			if family_id==2 and d.chance>=sampler.settings.active_frequency:continue
			if family_id==2 and sampler.region(p)>2.65:continue
			if family_id==7 and (sampler.region(p)<2.65 or sampler.region(p)>3.4):continue
			builder._biome_weights(p.x,p.y)
			if builder._extra_weights[family_id]<.95 or builder._island_mask(p.x,p.y)<.1:continue
			sites.append({"position":p,"radius":d.radius*(.85 if sampler.region(p)>1.6 else .38) if family_id==2 else 300.0,"id":d.id})
	return sites
func build(host,coordinate:Vector2i)->Dictionary:
	builder=host;origin=Vector3(coordinate.x*builder.chunk_size,0,coordinate.y*builder.chunk_size);var bounds:=Rect2(Vector2(origin.x,origin.z),Vector2.ONE*builder.chunk_size)
	var portals:Array=portal_sites(bounds);var openings:=PackedVector4Array();var owned:Array=[]
	for site:Dictionary in portals:
		var q:Vector2=site.position-Vector2(origin.x,origin.z)
		if bounds.intersects(Rect2(site.position-Vector2.ONE*site.half*1.2,Vector2.ONE*site.half*2.4)):openings.append(Vector4(q.x,q.y,site.half,site.phase))
		if bounds.has_point(site.owner):owned.append(site)
	reset()
	for site:Dictionary in owned:cavern(site)
	var output:Array=[arrays()];var liquids:Array=[]
	for family_id:int in [2,7]:
		reset()
		for site:Dictionary in liquid_sites(bounds,family_id):
			if pool(site.position,site.radius,Color(1,.24,.025) if family_id==2 else Color(.18,.42,.27)):liquids.append({"family":family_id,"position":site.position,"id":site.id})
		output.append(arrays())
	reset();var falls:Array=waterfalls(bounds);output.append(arrays())
	if not builder._extras_enabled and falls.is_empty():return {}
	return {"surfaces":output,"openings":openings,"cavities":owned,"liquids":liquids,"waterfalls":falls}
func waterfalls(bounds:Rect2)->Array:
	var records:Array=tropical_waterfalls(bounds);var sampler=builder._extras[1]
	if sampler==null or not sampler.settings.waterfalls_enabled:return records
	var spacing:float=4000/maxf(builder.settings.grass_river_frequency,.01)
	for ix in range(floori(bounds.position.x/4096)-1,ceili(bounds.end.x/4096)+1):
		for lane in range(floori(bounds.position.y/spacing)-1,ceili(bounds.end.y/spacing)+1):
			var x:float=ix*4096+sin(ix*1.7+sampler.seed_value)*180;var outlet:float=builder._grass_river_center(x,lane,spacing);var side:float=1 if sampler.random(ix,lane,921)>.5 else -1
			var p:=Vector2(x,outlet+side*500)
			if not bounds.has_point(p):continue
			builder._biome_weights(p.x,p.y)
			if builder._extra_weights[1]<.95 or builder._island_mask(p.x,p.y)<.1:continue
			if builder.get_water_surface_height(p.x,p.y)<20 or builder._get_height(p.x,p.y)>builder.get_water_surface_height(p.x,p.y)-.5:continue
			for i in range(24):
				var za:float=outlet+side*(470+i*2.5);var zb:float=za+side*2.5
				var ha:float=sampler.tributary(Vector2(x,za)).x+.12;var hb:float=sampler.tributary(Vector2(x,zb)).x+.12
				g.quad(Vector3(x-10,ha,za),Vector3(x+10,ha,za),Vector3(x+10,hb,zb),Vector3(x-10,hb,zb),Color(.65,.78,.81))
			records.append({"position":p,"outlet":Vector2(x,outlet),"drop_metres":34.0,"connected_to_carrier":true})
	return records
func tropical_waterfalls(bounds:Rect2)->Array:
	var records:Array=[];var sampler=builder._tropical
	if sampler==null or sampler.settings.waterfall_frequency<=0 or not builder.settings.water_enabled:return records
	var spacing:float=sampler._spacing();var span:float=spacing*.6
	for segment in range(floori(bounds.position.x/span)-1,ceili(bounds.end.x/span)+1):
		for lane in range(floori(bounds.position.y/spacing)-2,ceili(bounds.end.y/spacing)+2):
			var r:float=sampler.random(segment,lane,131)
			var drop:float=sampler.cascade_height(segment,lane,r)
			if drop<=0:continue
			var center:Vector2=sampler.cascade_point(segment,lane,.5)
			if not bounds.has_point(center):continue # one half-open owning leaf
			builder._biome_weights(center.x,center.y)
			if builder._tropical_weight<.95:continue
			var points:Array[Vector3]=[];var stations:Array[Vector2]=[];var valid:bool=true
			var extent:float=128/(span*.7);var previous:float=-INF
			for i in range(33):
				var t:float=lerpf(.5-extent,.5+extent,float(i)/32)
				var p:Vector2=sampler.cascade_point(segment,lane,t)
				var bed:float=builder._get_height(p.x,p.y);var level:float=builder._last_swamp_water
				if level<bed+.12 or level<builder.water_level+4 or level<previous-.001:valid=false;break
				points.append(Vector3(p.x,level+.12,p.y));stations.append(p);previous=level
			if not valid or points.size()!=33:continue
			var actual_drop:float=points.back().y-points.front().y
			if actual_drop<maxf(6,drop*maxf(builder.settings.height_multiplier,.01)*.35):continue
			var cross_sections:Array=[]
			for i in range(points.size()):
				var tangent:Vector2=(stations[mini(i+1,32)]-stations[maxi(i-1,0)]).normalized()
				var side:=Vector2(-tangent.y,tangent.x)*(3+r*2)
				var section:Array[Vector3]=[]
				for p:Vector2 in [stations[i]-side,stations[i]+side]:
					var bed:float=builder._get_height(p.x,p.y);var level:float=builder._last_swamp_water
					if level<bed+.05:valid=false;break
					section.append(Vector3(p.x,level+.12,p.y))
				if not valid:break
				cross_sections.append(section)
			if not valid:continue
			for i in range(32):
				g.quad(cross_sections[i][0],cross_sections[i][1],cross_sections[i+1][1],cross_sections[i+1][0],Color(.65,.78,.81))
			records.append({"id":"tropical:"+str(segment)+":"+str(lane),"position":center,"segment":segment,"lane":lane,"drop_metres":actual_drop,"connected_to_carrier":true,"kind":"rocky_tributary_cascade","canonical_water_profile":points,"pool_t":.4,"renderer":"existing terrain_features kind 3; no water collision"})
	return records
