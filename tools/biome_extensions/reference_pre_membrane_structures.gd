extends RefCounted
## Worker-side combined geometry. Each root is owned by exactly one half-open
## quadtree leaf; the complete-cut transaction swaps terrain AND structures.
## Root identity, geometry and anchors never depend on leaf size or load order.
var vertices:=PackedVector3Array()
var normals:=PackedVector3Array()
var colors:=PackedColorArray()
var uvs:=PackedVector2Array()
var origin:=Vector3.ZERO
## Reference switch for exact comparisons; production keeps the foundations.
var conduit_aprons:bool=true
## Reference switch; normal attached terrain conduits use climbable shoulders.
var conduit_shoulders:bool=true
## Reference switch; normal worker builds use the bounded numerical cache.
var conduit_cache_enabled:bool=true
const CONDUIT_MEMO_KEY="conduit_geometry_memo_v1"
var _conduit_memo:Dictionary={}
var _conduit_byte_budget:int=0
var _support_steps:=PackedFloat64Array()
var _support_heights:Dictionary={}
var _footing_vertices:Dictionary={}
var _conduit_uvs:Dictionary={}
var _protected_sites:Array=[]
var _skip_degenerate:bool=false
static func support_grids(base:float=256,close:int=128,middle:int=16,maximum_lod:int=6)->PackedFloat64Array:
	var unique:Dictionary={}
	for level in range(maximum_lod+1):
		var baseline:int=close if level==0 else (maxi(middle,32) if level==1 else middle)
		unique[base*float(1<<level)/baseline]=true
		if level>0:
			for resolution:int in [4,8,16,32,64,128]:
				if resolution>=baseline:unique[base*float(1<<level)/resolution]=true
	var result:=PackedFloat64Array(unique.keys());result.sort();return result
func _grid_height(builder,x:int,z:int,index:int,step:float)->float:
	var cacheable:bool=absi(x)<=2147483647 and absi(z)<=2147483647
	var key:Vector3i=Vector3i(x,z,index) if cacheable else Vector3i.ZERO
	if cacheable and _support_heights.has(key):return _support_heights[key]
	var h:float=builder._sample_normal_height(float(x)*step,float(z)*step)
	if cacheable:
		if _support_heights.size()>=16384:_support_heights.clear()
		_support_heights[key]=h
	return h
func footing_height(builder,p:Vector2)->float:
	var lowest:float=builder._get_height(p.x,p.y)
	for index in range(_support_steps.size()):
		var step:float=_support_steps[index];var gx:float=p.x/step;var gz:float=p.y/step
		var x:int=floori(gx);var z:int=floori(gz);var fx:float=gx-x;var fz:float=gz-z
		var a:float=_grid_height(builder,x,z,index,step);var b:float=_grid_height(builder,x+1,z,index,step)
		var c:float=_grid_height(builder,x,z+1,index,step);var d:float=_grid_height(builder,x+1,z+1,index,step)
		var chord:float=a+(b-a)*fx+(c-a)*fz if fx+fz<=1 else d+(c-d)*(1-fx)+(b-d)*(1-fz)
		lowest=minf(lowest,chord)
	# A buried visual margin, not a new walking surface or a lowered terrain field.
	return lowest-32
func triangle(a:Vector3,b:Vector3,c:Vector3,color:Color)->void:
	var cross_value:Vector3=(c-a).cross(b-a)
	if _skip_degenerate and cross_value.length_squared()<.00000001:return
	var normal:Vector3=cross_value.normalized() # Godot clockwise front faces
	for p:Vector3 in [a,b,c]:
		var local:Vector3=p-origin;var tint:Color=color
		# Opaque structure shaders use RGB only. Existing alpha storage marks
		# outer footings (0), apron interiors (.25), and guarded margins (.5).
		if not _footing_vertices.is_empty() and _footing_vertices.has(local):tint.a=_footing_vertices[local]
		vertices.append(local);normals.append(normal);colors.append(tint);uvs.append(_conduit_uvs.get(local,Vector2(p.x+p.z,p.y)*.15))
func quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3,color:Color)->void:
	triangle(a,b,c,color);triangle(a,c,d,color)
func prism(builder,anchor:Vector3,width:float,height:float,habit:int,angle:float,tilt:Vector2,broken:bool,color:Color)->void:
	var count:int=6 if habit<2 or habit==3 else 4
	var rings:Array=[]
	for level in range(3):
		var ring:=PackedVector3Array();var t:float=[0,.76,1][level]
		var radius:float=width*(1 if level<2 or broken or habit==4 else .04)
		for i in range(count):
			var a:float=angle+float(i)*TAU/count
			var p:=Vector3(cos(a)*radius,height*t,sin(a)*radius*(.14 if habit==2 else 1))
			p.x+=tilt.x*height*t;p.z+=tilt.y*height*t
			var v:Vector3=anchor+p
			if level==0:v.y=minf(v.y,builder._get_height(v.x,v.z)-8)
			ring.append(v)
		rings.append(ring)
	for level in range(2):
		for i in range(count):
			var j:int=(i+1)%count;quad(rings[level][i],rings[level][j],rings[level+1][j],rings[level+1][i],color)
	var top:Vector3=anchor+Vector3(tilt.x*height,height,tilt.y*height)
	for i in range(count):triangle(rings[2][i],rings[2][(i+1)%count],top,color)
func mound(builder,anchor:Vector3,width:float,height:float,archetype:int,phase:float,color:Color)->void:
	var first_vertex:int=vertices.size()
	var rings:Array=[];var sides:int=42
	for row in range(25):
		var t:float=float(row)/24;var ring:=PackedVector3Array()
		for i in range(sides):
			var a:float=float(i)*TAU/sides
			var flute:float=1+.18*sin(a*5+phase+t*.9)+.1*sin(a*3-phase-t*1.4)+.045*sin(a*13+t*18+phase)
			var radius:float=width*pow(maxf(.015,1-t),.65)*flute
			if archetype==3:radius=width*sqrt(maxf(.005,1-t*t))
			if archetype==0 or archetype==4:radius*=.84+.16*sin(t*14+a*3+phase)+.06*sin(a*19+t*35)
			if archetype==4:radius*=1-.15*smoothstep(.4,1,t)*(.5+.5*sin(a*7+phase))
			var p:=Vector3(cos(a)*radius,height*t,sin(a)*radius*(.22 if archetype==2 else 1))
			p.x+=width*.16*sin(t*2+phase)*t;p.z+=width*.12*t*t
			var v:Vector3=anchor+p
			if row==0:v.y=minf(v.y,builder._get_height(v.x,v.z)-8)
			ring.append(v)
		rings.append(ring)
	for row in range(24):
		for i in range(sides):
			var j:int=(i+1)%sides;quad(rings[row][i],rings[row][j],rings[row+1][j],rings[row+1][i],color)
	var top:Vector3=Vector3.ZERO
	for v:Vector3 in rings[24]:top+=v/float(sides)
	for i in range(sides):triangle(rings[24][i],rings[24][(i+1)%sides],top,color)
	# Earth is rounded and weathered, unlike the deliberately hard crystal facets.
	var sums:Dictionary={}
	for i in range(first_vertex,vertices.size()):sums[vertices[i]]=sums.get(vertices[i],Vector3.ZERO)+normals[i]
	for i in range(first_vertex,vertices.size()):
		var smooth:Vector3=sums[vertices[i]].normalized()
		if smooth.dot(normals[i])>.15:normals[i]=smooth
func _conduit_config_values(resource:Resource)->Dictionary:
	var values:Dictionary={}
	for property:Dictionary in resource.get_property_list():
		var name:String=property.name
		if (int(property.usage)&PROPERTY_USAGE_STORAGE)==0 or name in ["script","resource_path"]:continue
		var value=resource.get(name)
		values[name]=_conduit_config_values(value) if value is Resource else value
	return values
func _evict_conduit_memo()->void:
	var key:String=_conduit_memo.entries.keys()[0]
	_conduit_memo.bytes-=int(_conduit_memo.entries[key].bytes);_conduit_memo.entries.erase(key)
func _prepare_conduit_memo(builder)->void:
	_conduit_memo={};_conduit_byte_budget=0
	if conduit_cache_enabled and builder._extras[7]!=null:_conduit_byte_budget=clampi(builder.settings.alien_infected.conduit_cache_mib,0,16)*1024*1024
	if _conduit_byte_budget==0:
		if builder.has_meta(CONDUIT_MEMO_KEY):builder.remove_meta(CONDUIT_MEMO_KEY)
		return
	# Worker snapshots are independent. Include every stored numerical setting,
	# nested resource, world seed and water datum: a reused builder must never
	# serve geometry from a previous configuration. No SceneTree/GPU access.
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes([builder.world_seed,builder.water_level,_conduit_config_values(builder.settings)]));var signature:PackedByteArray=hash.finish()
	_conduit_memo=builder.get_meta(CONDUIT_MEMO_KEY,{})
	if _conduit_memo.is_empty() or _conduit_memo.signature!=signature:
		_conduit_memo={"signature":signature,"entries":{},"bytes":0,"hits":0,"misses":0,"validations":0};builder.set_meta(CONDUIT_MEMO_KEY,_conduit_memo)
	_conduit_memo.validations=int(_conduit_memo.get("validations",0))+1
	while not _conduit_memo.entries.is_empty() and (_conduit_memo.bytes>_conduit_byte_budget or _conduit_memo.entries.size()>32):_evict_conduit_memo()
func _conduit_relevant_sites(a:Vector2,b:Vector2,width:float)->Array:
	var sites:Array=[];var direction:Vector2=b-a;var denominator:float=maxf(direction.length_squared(),.000001)
	var magnitude:float=maxf(maxf(absf(a.x),absf(a.y)),maxf(absf(b.x),absf(b.y)));var rounding_pad:float=1+magnitude*.000002
	for site:Dictionary in _protected_sites:
		var nearest:Vector2=a+direction*clampf((site.position-a).dot(direction)/denominator,0,1)
		# Original aperture protection can only shrink an apron within reserve
		# +64+16+128 +5*radius +.8*width centreline sway. Pad float32 rounding.
		if nearest.distance_to(site.position)<=maxf(320,site.half*1.2)+208+5.8*width+rounding_pad:sites.append(site)
	return sites
func conduit(builder,a:Vector2,b:Vector2,width:float,phase:float,color:Color)->void:
	# Isolated primitive callers retain the original uncached implementation;
	# only a complete build prepares a configuration-validated worker memo.
	if _conduit_memo.is_empty():_conduit_uncached(builder,a,b,width,phase,color);return
	var sites:Array=_conduit_relevant_sites(a,b,width)
	var key:String=var_to_bytes([a,b,width,phase,color,conduit_aprons,conduit_shoulders,_support_steps,sites]).hex_encode();var entry:Dictionary={}
	if _conduit_memo.entries.has(key):entry=_conduit_memo.entries[key];_conduit_memo.hits+=1
	else:
		_conduit_memo.misses+=1
		var g=get_script().new();g.origin=Vector3.ZERO;g._support_steps=_support_steps;g._support_heights=_support_heights;g._protected_sites=sites;g.conduit_aprons=conduit_aprons;g.conduit_shoulders=conduit_shoulders
		g._conduit_uncached(builder,a,b,width,phase,color)
		entry={"vertices":g.vertices,"normals":g.normals,"colors":g.colors,"uvs":g.uvs,"bytes":g.vertices.size()*48}
		if entry.bytes<=_conduit_byte_budget:
			while not _conduit_memo.entries.is_empty() and (_conduit_memo.bytes+entry.bytes>_conduit_byte_budget or _conduit_memo.entries.size()>=32):_evict_conduit_memo()
			_conduit_memo.entries[key]=entry;_conduit_memo.bytes+=entry.bytes
	# Store original world float32 vertices, not already-local rounded meshes.
	# Subtraction is exactly the original emitter's new-leaf transform. Cached
	# arrays are read-only; render/collision arrays remain complete and unchanged.
	for vertex:Vector3 in entry.vertices:vertices.append(vertex-origin)
	normals.append_array(entry.normals);colors.append_array(entry.colors);uvs.append_array(entry.uvs)
	_footing_vertices.clear();_conduit_uvs.clear();_skip_degenerate=false
func _conduit_uncached(builder,a:Vector2,b:Vector2,width:float,phase:float,color:Color)->void:
	_footing_vertices.clear();_conduit_uvs.clear();_skip_degenerate=conduit_aprons
	var first_vertex:int=vertices.size()
	var direction:Vector2=(b-a).normalized();var side:=Vector2(-direction.y,direction.x);var rings:Array=[]
	var segments:int=clampi(ceili(a.distance_to(b)/96),16,64)
	for row in range(segments+1):
		var t:float=float(row)/segments;var p:Vector2=a.lerp(b,t)+side*sin(t*PI)*width*.8
		var h:float=builder._get_height(p.x,p.y);var ring:=PackedVector3Array();var radius:float=width*(.7+.2*sin(t*9+phase)+.1*sin(t*23-phase))
		var row_controls:=Vector2.ZERO
		if conduit_aprons:
			builder._extras[7].sample(p.x,p.y)
			row_controls=Vector2(builder._extras[7].state[3]*5,builder._extras[7].state[4])
		var left:Vector2=p+side*radius;var right:Vector2=p-side*radius
		var left_h:float=builder._get_height(left.x,left.y);var right_h:float=builder._get_height(right.x,right.y)
		for i in range(9):
			var angle:float=float(i)*PI/8
			var ground:float=lerpf(h,left_h if cos(angle)>0 else right_h,absf(cos(angle)))
			# A half ellipse has a vertical tangent at its buried margin. Its
			# first exposed face formed a 67-degree knee-high wall on flat ground.
			# Squared sine keeps the exact crest and horizontal support but bounds the added
			# cross-slope by .7 (before the underlying terrain's own gradient).
			var rise:float=sin(angle)
			if conduit_aprons and conduit_shoulders:rise*=rise
			var v:=Vector3(p.x+side.x*cos(angle)*radius,ground-2+rise*radius*.35,p.y+side.y*cos(angle)*radius)
			# Deep buried margins close the underside against intervening valleys;
			# these are solid terrain conduits, never implied open cave mouths.
			if i==0 or i==8:v.y=ground-(2 if conduit_aprons and conduit_shoulders else 3)
			ring.append(v)
			if conduit_aprons:_conduit_uvs[v-origin]=row_controls
		if conduit_aprons:
			var reach:float=128+radius*4;var factor:float=1
			for site:Dictionary in _protected_sites:
				# The finite cavity includes a spiral and a 256m return gallery.
				# Keep every NEW apron outside that entire reserved approach.
				var clearance:float=p.distance_to(site.position)-maxf(320,site.half*1.2)-64-radius-16
				factor=minf(factor,clampf(clearance/reach,0,1))
			var profile:=PackedVector3Array()
			for sign_value:float in [1.0,-1.0]:
				var outer:Vector2=p+side*sign_value*(radius+reach*factor)
				var outer_ground:float=builder._get_height(outer.x,outer.y)
				var foot:float=footing_height(builder,outer) if factor>0 else outer_ground-3
				var extra_depth:float=maxf(0,outer_ground-3-foot)
				var apron:=PackedVector3Array()
				for station in range(3):
					var u:float=float(3-station)/3
					var q:Vector2=p+side*sign_value*(radius+reach*factor*u)
					var y:float=builder._get_height(q.x,q.y)-3-extra_depth*smoothstep(.35,1,u)
					var v:=Vector3(q.x,y,q.y);apron.append(v)
					_footing_vertices[v-origin]=(0.0 if station==0 else .25) if factor>0 else .5
					builder._extras[7].sample(q.x,q.y)
					_conduit_uvs[v-origin]=Vector2(builder._extras[7].state[3]*5,builder._extras[7].state[4])
				if sign_value>0:
					profile.append_array(apron);profile.append_array(ring)
				else:
					apron.reverse();profile.append_array(apron)
			ring=profile
		rings.append(ring)
	for row in range(segments):
		for i in range(rings[row].size()-1):quad(rings[row][i],rings[row][i+1],rings[row+1][i+1],rings[row+1][i],color)
	var cap_a:=Vector3(a.x,builder._get_height(a.x,a.y)-width*4,a.y)
	var cap_b:=Vector3(b.x,builder._get_height(b.x,b.y)-width*4,b.y)
	if conduit_aprons:
		cap_a.y=minf(cap_a.y,minf(rings[0][0].y,rings[0][-1].y)-8)
		cap_b.y=minf(cap_b.y,minf(rings[segments][0].y,rings[segments][-1].y)-8)
		_conduit_uvs[cap_a-origin]=_conduit_uvs[rings[0][3]-origin]
		_conduit_uvs[cap_b-origin]=_conduit_uvs[rings[segments][3]-origin]
	for i in range(rings[0].size()-1):
		triangle(rings[0][i+1],rings[0][i],cap_a,color)
		triangle(rings[segments][i],rings[segments][i+1],cap_b,color)
	if conduit_aprons:
		# Smooth the actual attached shell, not a derivative of the underlying
		# height field: that derivative can point through a steep apron face.
		# Keep hard folds/caps in their outward hemisphere, as for earthworks.
		var sums:Dictionary={}
		for i in range(first_vertex,vertices.size()):sums[vertices[i]]=sums.get(vertices[i],Vector3.ZERO)+normals[i]
		for i in range(first_vertex,vertices.size()):
			var smooth:Vector3=sums[vertices[i]].normalized()
			if smooth.dot(normals[i])>.15:normals[i]=smooth
	_footing_vertices.clear();_conduit_uvs.clear();_skip_degenerate=false
func can_place_carapace(builder,p:Vector2,width:float,height:float)->bool:
	for site:Dictionary in _protected_sites:
		if p.distance_to(site.position)<maxf(320,site.half*1.2)+width*1.8+64:return false
	var heights:=PackedFloat64Array();var offsets:Array[Vector2]=[]
	for i in range(9):
		var angle:float=float(i)*TAU/8
		var q:Vector2=p+(Vector2(cos(angle),sin(angle))*width*1.6 if i<8 else Vector2.ZERO)
		var h:float=builder._get_height(q.x,q.y)
		var amount:float=builder._last_extras[7].x
		if amount<.8 or h<=maxf(builder.water_level,builder.get_water_surface_height(q.x,q.y))+4:return false
		heights.append(h);offsets.append(q-p)
	# A steady hillside is support, not a cliff. Separate its fitted grade
	# from abrupt residual relief instead of rejecting every tilted site.
	var radius:float=width*1.6
	var grade:=Vector2((heights[0]-heights[4])/(radius*2),(heights[2]-heights[6])/(radius*2))
	if grade.length()>.7:return false
	for i in range(8):
		if absf(heights[i]-(heights[8]+grade.dot(offsets[i])))>=height*.75:return false
	return true
func build(builder,coordinate:Vector2i,support_steps:PackedFloat64Array=PackedFloat64Array(),portal_provider:Callable=Callable())->Array:
	_conduit_memo={};_conduit_byte_budget=0;var memo_checked:bool=false
	var budget:int=clampi(builder.settings.alien_infected.conduit_cache_mib,0,16)*1024*1024 if conduit_cache_enabled and builder._extras[7]!=null else 0
	# Most near leaves contain no hive root. Do not hash all sixteen settings
	# resources merely to discover that no conduit will be emitted. Still honour
	# disable/shrink immediately, including an empty leaf after reconfiguration.
	if builder.has_meta(CONDUIT_MEMO_KEY):
		var previous:Dictionary=builder.get_meta(CONDUIT_MEMO_KEY)
		if budget==0 or int(previous.get("bytes",0))>budget:builder.remove_meta(CONDUIT_MEMO_KEY)
	var output:Array=[];output.resize(3);origin=Vector3(coordinate.x*builder.chunk_size,0,coordinate.y*builder.chunk_size)
	var bounds:=Rect2(Vector2(origin.x,origin.z),Vector2.ONE*builder.chunk_size)
	_support_steps=support_steps.duplicate() if not support_steps.is_empty() else support_grids()
	_support_heights.clear();_protected_sites.clear()
	if builder._extras[7]!=null and portal_provider.is_valid():
		_protected_sites=portal_provider.call(bounds.grow(8192*builder._extras[7].settings.feature_scale+512))
	for family_id in [5,6,7]:
		vertices=PackedVector3Array();normals=PackedVector3Array();colors=PackedColorArray();uvs=PackedVector2Array()
		if builder._extras[family_id]==null:continue
		var sampler=builder._extras[family_id];var span:float=(4096 if family_id==7 else (1700 if family_id==5 else 2100))*sampler.settings.feature_scale
		var start:=Vector2i(floori(bounds.position.x/span)-1,floori(bounds.position.y/span)-1);var end:=Vector2i(ceili(bounds.end.x/span),ceili(bounds.end.y/span))
		for z in range(start.y,end.y+1):
			for x in range(start.x,end.x+1):
				var cell:=Vector2i(x,z);var d:Dictionary=sampler.descriptor(cell,span);var p:Vector2=sampler.hive_node(cell) if family_id==7 else d.position
				if not bounds.has_point(p):continue
				builder._biome_weights(p.x,p.y)
				var weight:float=builder._extra_weights[family_id]
				if family_id==7:weight=maxf(weight,sampler.network(p).influence*sampler.settings.overlay_strength)
				if weight<.55 or builder._island_mask(p.x,p.y)<.03 or d.chance>sampler.settings.structure_density:continue
				var height:float=builder._get_height(p.x,p.y);var water:float=builder.get_water_surface_height(p.x,p.y)
				if height<water+2:continue
				var anchor:=Vector3(p.x,height-8,p.y);var type:int=clampi(roundi(sampler.region(p)),0,5)
				if family_id==5:
					var palette:Array=[Color(.59,.61,.58),Color(.41,.27,.49),Color(.76,.77,.68),Color(.25,.23,.22),Color(.23,.46,.37),Color(.63,.56,.43)]
					for i in range(5):
						var a:float=d.angle+i*2.4;var scale:float=1 if i==0 else .22+sampler.random(x,z,i+70)*.4
						var center:Vector3=anchor+Vector3(cos(a),0,sin(a))*d.radius*.15*minf(i,1)
						center.y=minf(anchor.y,builder._get_height(center.x,center.z)-8)
						var size:float=sampler.settings.crystal_height*(.4+d.age*1.4)*scale
						prism(builder,center,size*(.14 if type!=4 else .4),size,type,a,Vector2(cos(a),sin(a))*(.05+.18*sampler.random(x,z,i+90)),sampler.random(x,z,i+80)<sampler.settings.broken_fraction,palette[type])
				elif family_id==6:
					if type==1:continue # broad ant earthworks are canonical heightfield geometry
					var color:Color=Color(.44,.27,.14).lerp(Color(.55,.48,.36),float(type)/5)
					var scale:float=sampler.settings.nest_height*(.45+d.age)*(1-.35*float(type==4))
					mound(builder,anchor,scale*.4,scale,type,d.angle,color)
					if type==0 or type==4 or type==5:
						for i in range(5):
							var a:float=d.angle+i*1.31;var base:Vector3=anchor+Vector3(cos(a),0,sin(a))*scale*.23
							mound(builder,base,scale*.19,scale*(.4+sampler.random(x,z,110+i)*.5),0,a,color)
				else:
					if not memo_checked:_prepare_conduit_memo(builder);memo_checked=true
					var color:=Color(.34,.28,.26);var a:Vector2=sampler.hive_node(cell)
					var junction_emitted:bool=false
					for direction:Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
						var b:Vector2=sampler.hive_node(cell+direction);var mid:Vector2=(a+b)*.5+Vector2(-(b-a).y,(b-a).x)*(.08*sin(float(x+z)*1.71))
						conduit(builder,a,mid,12+d.age*16,d.angle,color);conduit(builder,mid,b,12+d.age*16,d.angle,color)
						var tip:Vector2=mid+Vector2(-(b-a).y,(b-a).x)*.23;conduit(builder,mid,tip,8,d.angle,color)
					if weight>=.92 and sampler.settings.hive_junction_frequency>0 and sampler.random(x,z,246)<sampler.settings.hive_junction_frequency:
						var width:float=sampler.settings.hive_junction_width*sampler.settings.feature_scale
						var clear:bool=true
						for site:Dictionary in _protected_sites:
							if a.distance_to(site.position)<maxf(320,site.half*1.2)+width*4+64:clear=false;break
						if clear:
							var edges:PackedVector2Array=sampler.network_edges(cell)
							var directions:Array[Vector2]=[(edges[1]-a).normalized(),(edges[5]-a).normalized()]
							var junction_height:float=sampler.settings.hive_junction_height*(.65+d.age*.7)*sampler.settings.relief*maxf(builder.settings.height_multiplier,.01)
							preload("res://tools/biome_extensions/reference_pre_membrane_junction_geometry.gd").new().emit(self,builder,a,directions,width,junction_height,d.angle)
							junction_emitted=true
					if not junction_emitted and weight>=.92 and type in [2,5] and sampler.settings.hive_carapace_frequency>0 and sampler.random(x,z,247)<sampler.settings.hive_carapace_frequency:
						var plate_width:float=sampler.settings.hive_carapace_width*sampler.settings.feature_scale*(.75+d.age*.5)
						var plate_height:float=sampler.settings.hive_carapace_height*(.7+d.age*.6)*sampler.settings.relief*maxf(builder.settings.height_multiplier,.01)
						if can_place_carapace(builder,a,plate_width,plate_height):
							var edges:PackedVector2Array=sampler.network_edges(cell)
							preload("res://scripts/alien_carapace_geometry.gd").new().emit(self,builder,a,(edges[1]-a).normalized(),plate_width,plate_height,d.angle,type)
		if not vertices.is_empty():
			var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV]=uvs;output[family_id-5]=arrays
	# A later direct primitive call must not accidentally reuse a build's memo
	# after the caller changes settings. Only the builder retains cached arrays.
	_conduit_memo={};_conduit_byte_budget=0
	return output
