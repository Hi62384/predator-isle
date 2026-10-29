extends RefCounted
## Cave core: sparse implicit union; no SceneTree/GPU access. One common volume
## removes internal walls at joins. Floor planes are not noisy circular pipes.
const BIN_METRES:float=16
const FAR:float=4
const MAX_FEATURES:int=65536
const BiomeRegions=preload("res://scripts/caves/biome_regions.gd")
## Immutable expressions of the compiled primitive. Float64 scalars preserve
## the original arithmetic,not reciprocals or quantized approximations.
var directions:=PackedVector2Array()
var span_squared:=PackedFloat64Array()
var span_length:=PackedFloat64Array()
var arch_height:=PackedFloat64Array()
var arch_center:=PackedFloat64Array()
var arch_scale:=PackedFloat64Array()
var begins:=PackedVector3Array()
var ends:=PackedVector3Array()
var dimensions:=PackedVector2Array()
var kinds:=PackedByteArray() # 0 closed route,1 intentional entrance,2 chamber
var styles:=PackedByteArray() # 0 retains the complete original ellipse
## Adjacent solved grades prevent rounded segment caps extending a descending
## floor into the next ascent and creating an artificial steep valley lip.
## Independent false mode retains the complete previous scalar for diagnosis.
var continuous_route_floors:bool=true
var endpoint_grades:=PackedFloat64Array()
## Exact XZ keys from the already-Float32 input Vector3,no spatial rounding.
## Normals and material ownership repeatedly ask the SAME canonical column.
## Numeric-only and bounded;changing the callable or compiling clears it.
const MAX_HEIGHT_SAMPLES:int=8192
var cache_height_samples:bool=true
var _height_memo:Dictionary={}
var bins:Dictionary={}
var chunks:Dictionary={}
var height:Callable:
	set(value):height=value;_height_memo.clear()
var maximum_depth:float=400
var minimum_roof:float=10
## A not-yet-committed mouth must remain a supported closed volume. Explicit
## portal extraction uses zero;ordinary streamed cells retain a6m rock seal.
var opening_rock_cover:float=0
var references:int=0
var _biome_assignment:Dictionary={}
var _biome_fields:Dictionary={}
var _biome_locks:Dictionary={}
var _protected_shores:Array=[]
## Optional bounded mesh root refinement; scalar volume itself is unchanged.
var precise_shores:Array=[]
func clear()->void:
	precise_shores.clear()
	directions.clear();span_squared.clear();span_length.clear();arch_height.clear();arch_center.clear();arch_scale.clear();begins.clear();ends.clear();dimensions.clear();kinds.clear();styles.clear();endpoint_grades.clear();_height_memo.clear();bins.clear();chunks.clear();references=0;_biome_assignment={};_biome_fields={};_biome_locks={};_protected_shores.clear()
func protected_shore(point:Vector3,radius:float,low:float,high:float)->bool:
	for shore:Dictionary in _protected_shores:
		if high<=shore.low or low>=shore.high:continue
		var q:=Vector2(absf(point.x-shore.center.x),absf(point.z-shore.center.z));var closest:Vector2=(q-Vector2.ONE*radius).max(Vector2.ZERO);var farthest:Vector2=q+Vector2.ONE*radius
		if closest.length()<=shore.outer and farthest.length()>=shore.inner:return true
	return false
func ground_height(point:Vector3)->float:
	if not cache_height_samples:return float(height.call(point.x,point.z))
	var key:=Vector2(point.x,point.z)
	if _height_memo.has(key):return _height_memo[key]
	var value:float=height.call(point.x,point.z)
	if _height_memo.size()>=MAX_HEIGHT_SAMPLES:_height_memo.clear()
	_height_memo[key]=value;return value
func cell(point:Vector3)->Vector3i:return Vector3i(floori(point.x/64),floori(point.y/64),floori(point.z/64))
func bin_cell(point:Vector3)->Vector3i:return Vector3i(floori(point.x/BIN_METRES),floori(point.y/BIN_METRES),floori(point.z/BIN_METRES))
func has_chunk(key:Vector3i)->bool:return chunks.has(key)
func append_feature(a:Vector3,b:Vector3,size:Vector2,kind:int,style:int=0)->bool:
	if not a.is_finite() or not b.is_finite() or not size.is_finite() or size.x<=0 or size.y<=0 or begins.size()>=MAX_FEATURES:return false
	var low:Vector3=a.min(b)-Vector3(size.x+FAR,FAR,size.x+FAR);var high:Vector3=a.max(b)+Vector3(size.x+FAR,size.y+FAR,size.x+FAR)
	for component:float in [low.x,low.y,low.z,high.x,high.y,high.z]:
		if absf(component)>2147483646.0*BIN_METRES:return false
	var first:Vector3i=bin_cell(low);var last:Vector3i=bin_cell(high)
	if int(last.x-first.x+1)*int(last.y-first.y+1)*int(last.z-first.z+1)>128:return false
	var ab:=Vector2(b.x-a.x,b.z-a.z);directions.append(ab);span_squared.append(maxf(ab.length_squared(),.000001));span_length.append(ab.length());arch_height.append(size.y*.6);arch_center.append(size.y*.4);arch_scale.append(minf(size.x,size.y*.6))
	var feature:int=begins.size();begins.append(a);ends.append(b);dimensions.append(size);kinds.append(kind);styles.append(clampi(style,0,7))
	if continuous_route_floors:endpoint_grades.append(INF);endpoint_grades.append(INF)
	for id:String in _biome_fields:_biome_fields[id].append(Vector2.ZERO)
	var first_chunk:Vector3i=cell(low);var last_chunk:Vector3i=cell(high)
	for z in range(first_chunk.z,last_chunk.z+1):
		for y in range(first_chunk.y,last_chunk.y+1):
			for x in range(first_chunk.x,last_chunk.x+1):chunks[Vector3i(x,y,z)]=true
	for z in range(first.z,last.z+1):
		for y in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				var key:=Vector3i(x,y,z)
				if not bins.has(key):bins[key]=[]
				bins[key].append(feature)
	return true
func compile(regions:Array,surface:Callable,extra_edges:Array=[],biome_assignment:Dictionary={})->bool:
	clear();height=surface
	if not surface.is_valid():return false
	var specialized:Array=[]
	for candidate:Dictionary in biome_assignment.get("candidates",[]):
		if candidate.biome_id==biome_assignment.get("fallback","default"):continue
		specialized.append(candidate);_biome_fields[str(candidate.biome_id)]=[]
	if not specialized.is_empty():_biome_assignment=biome_assignment.duplicate();_biome_assignment["candidates"]=specialized
	var edges:Array=extra_edges.duplicate()
	for region:Dictionary in regions:
		if not region.get("valid",false):continue
		if not _biome_fields.is_empty() and region.get("cave_family",-1) in [6,7]:_biome_locks[region.id]=true
		var style:int=int(region.get("cross_section_style",0))
		for edge:Dictionary in region.edges+region.get("pocket_passages",[]):
			var decorated:Dictionary=edge.duplicate();decorated["cross_section_style"]=style;edges.append(decorated)
		var rooms:Array=region.nodes+region.get("pockets",[])
		for pool:Dictionary in region.get("pools",[]):
			if pool.get("precise_shore",false):
				if precise_shores.size()>=128:clear();return false
				precise_shores.append({"center":pool.center,"radius":pool.radius})
			if pool.get("crystal_large_lake",false):
				if _protected_shores.size()>=128:clear();return false
				_protected_shores.append({"center":pool.center,"inner":pool.radius+.75,"outer":pool.radius+3.25,"low":pool.center.y-.75,"high":pool.center.y+8.0})
			var parent:String=str(pool.id).trim_suffix(":seepage");var bed:Dictionary=pool.bed.duplicate();bed["biome_parent"]=parent;rooms.append(bed)
			for lobe:Dictionary in pool.get("bed_lobes",[]):var part:Dictionary=lobe.duplicate();part["biome_parent"]=parent;rooms.append(part)
			for lobe:Dictionary in pool.get("bank_lobes",[]):var part:Dictionary=lobe.duplicate();part["biome_parent"]=parent;rooms.append(part)
			for channel:Dictionary in pool.get("stream_edges",[]):
				var decorated:Dictionary=channel.duplicate();decorated["cross_section_style"]=style;decorated["biome_parent"]=parent;edges.append(decorated)
			for access:Dictionary in pool.get("bank_access",[]):
				var decorated:Dictionary=access.duplicate();decorated["cross_section_style"]=style;decorated["biome_parent"]=parent;edges.append(decorated)
		for node:Dictionary in rooms:
			if int(node.get("level",-1))<0:continue
			if not append_feature(node.point,node.point,Vector2(node.chamber_radius,node.chamber_height),2,int(node.get("cross_section_style",style))):clear();return false
			if not _biome_fields.is_empty():var id:String=str(node.get("biome_parent",node.get("id","")));bind_feature_biomes(begins.size()-1,id,id,0,0,0)
	for edge:Dictionary in edges:
		var points:PackedVector3Array=edge.points
		var length_m:float=0;var station:float=0
		if not _biome_fields.is_empty():
			for i in range(1,points.size()):length_m+=points[i-1].distance_to(points[i])
		for i in range(points.size()-1):
			if not append_feature(points[i],points[i+1],Vector2(edge.half_width,edge.headroom),1 if edge.entrance else 0,int(edge.get("cross_section_style",0))):clear();return false
			if continuous_route_floors:
				var feature:int=begins.size()-1
				if i>0:endpoint_grades[feature*2]=(points[i].y-points[i-1].y)/maxf(Vector2(points[i].x-points[i-1].x,points[i].z-points[i-1].z).length(),.000001)
				if i+2<points.size():endpoint_grades[feature*2+1]=(points[i+2].y-points[i+1].y)/maxf(Vector2(points[i+2].x-points[i+1].x,points[i+2].z-points[i+1].z).length(),.000001)
			if not _biome_fields.is_empty():
				var end:float=station+points[i].distance_to(points[i+1]);var parent:String=str(edge.get("biome_parent",""));bind_feature_biomes(begins.size()-1,str(edge.get("from","")) if parent.is_empty() else parent,str(edge.get("to","")) if parent.is_empty() else parent,station,end,length_m if parent.is_empty() else 0);station=end
	for key:Vector3i in bins:references+=bins[key].size();bins[key]=PackedInt32Array(bins[key])
	for id:String in _biome_fields:_biome_fields[id]=PackedVector2Array(_biome_fields[id])
	return true
func bind_feature_biomes(feature:int,from_id:String,to_id:String,first:float,last:float,length_m:float)->void:
	var a:Dictionary=BiomeRegions.along_edge(_biome_assignment,from_id,to_id,first,length_m).weights;var b:Dictionary=BiomeRegions.along_edge(_biome_assignment,from_id,to_id,last,length_m).weights
	for id:String in _biome_fields:_biome_fields[id][feature]=Vector2(float(a.get(id,0)),float(b.get(id,0)))
func biome_ids_for_cell(key:Vector3i)->Array:
	if _biome_fields.is_empty():return []
	if _biome_locks.has(Vector2i(floori(float(key.x)/24),floori(float(key.z)/24))):return []
	var found:Dictionary={};var first:Vector3i=key*4
	for z in range(4):
		for y in range(4):
			for x in range(4):
				for feature:int in bins.get(first+Vector3i(x,y,z),PackedInt32Array()):
					for id:String in _biome_fields:
						var weights:Vector2=_biome_fields[id][feature]
						if maxf(weights.x,weights.y)>.00001:found[id]=true
	var result:Array=found.keys();result.sort();return result
func biome_weights_at(point:Vector3,ids:Array)->Vector4:
	var admission:float=biome_admission(point)
	if admission<=0:return Vector4.ZERO
	var best:float=FAR;var result:=Vector4.ZERO
	for feature:int in bins.get(bin_cell(point),PackedInt32Array()):
		var value:float=evaluate(point,PackedInt32Array([feature]))
		if value>=FAR or value>best:continue
		# Every joined flat floor shares exactly the same -Y distance. Taking
		# the first feature made its biome depend on discovery/insertion order.
		# Union equal minima component-wise;strictly closer geometry replaces
		# them. Exact ties avoid non-transitive epsilon/order dependencies.
		if value<best:best=value;result=Vector4.ZERO
		var ab:Vector2=directions[feature];var t:float=clampf(Vector2(point.x-begins[feature].x,point.z-begins[feature].z).dot(ab)/span_squared[feature],0,1)
		for i in range(mini(4,ids.size())):
			if not _biome_fields.has(ids[i]):continue
			var weights:Vector2=_biome_fields[ids[i]][feature];result[i]=maxf(result[i],lerpf(weights.x,weights.y,t))
	var total:float=result.x+result.y+result.z+result.w
	if total>1:result/=total
	return result*admission
func biome_admission(point:Vector3)->float:
	if _biome_locks.is_empty():return 1.0
	var region:=Vector2i(floori(point.x/1536),floori(point.z/1536));var nearest:float=INF
	# Match existing native material ownership:biological regions are locked.
	# Fade outside that ownership before reaching its edge,so a connector can
	# never ask a Hive shader to compile an incompatible mineral/ice adapter.
	for z in range(-1,2):
		for x in range(-1,2):
			var id:Vector2i=region+Vector2i(x,z)
			if not _biome_locks.has(id):continue
			var dx:float=maxf(maxf(id.x*1536.0-point.x,point.x-(id.x+1)*1536.0),0);var dz:float=maxf(maxf(id.y*1536.0-point.z,point.z-(id.y+1)*1536.0),0);nearest=minf(nearest,sqrt(dx*dx+dz*dz))
	return smoothstep(0,32,nearest)
func evaluate(point:Vector3,features:PackedInt32Array)->float:
	var closed:float=FAR;var opening:float=FAR
	var wall:float=sin(point.x*.71+sin(point.y*.23))*sin(point.z*.53+point.y*.41)*.12
	for feature:int in features:
		var a:Vector3=begins[feature];var b:Vector3=ends[feature];var size:Vector2=dimensions[feature];var floor_y:float=a.y;var radius_distance:float=0
		if kinds[feature]==2:radius_distance=Vector2(point.x-a.x,point.z-a.z).length()
		else:
			var ab:Vector2=directions[feature];var q:=Vector2(point.x-a.x,point.z-a.z);var along:float=q.dot(ab)/span_squared[feature];var t:float=clampf(along,0,1)
			# Continue the sloping floor plane through the rounded segment caps.
			# Clamping the floor to the lower endpoint made each cap cut a small
			# horizontal shelf/drop out of its uphill neighbor in the air union.
			radius_distance=(q-ab*t).length();floor_y=lerpf(a.y,b.y,along)
			if continuous_route_floors:
				if along<0 and is_finite(endpoint_grades[feature*2]):floor_y=a.y+along*span_length[feature]*endpoint_grades[feature*2]
				elif along>1 and is_finite(endpoint_grades[feature*2+1]):floor_y=b.y+(along-1)*span_length[feature]*endpoint_grades[feature*2+1]
		var y:float=point.y-floor_y;var arch:float=(Vector2(radius_distance/size.x,(y-arch_center[feature])/arch_height[feature]).length()-1)*arch_scale[feature]
		# Wider superellipse shoulders preserve the original protected floor
		# while supplying actual fracture/slab cross-sections. Relief enlarges
		# air only within the existing2m support-conflict reserve;floors and
		# canonical roof/depth clips remain unchanged.
		var style:int=styles[feature]
		if style==1 or style==2 or style==3 or style==5:
			var exponent:float=4 if style==1 else (3.4 if style==2 else (2.8 if style==3 else 2.5));var radial:float=absf(radius_distance/size.x);var vertical:float=absf((y-arch_center[feature])/arch_height[feature]);arch=(pow(pow(radial,exponent)+pow(vertical,exponent),1/exponent)-1)*arch_scale[feature]
		if style==2 or style==3 or style==4:
			var joint:float=.5+.5*sin(point.y*(.61 if style==2 else .19)+point.x*.013+point.z*.017);arch-=joint*(.24 if style==3 else .12)*smoothstep(0,1,y)
		if style==7:
			# Physical folded walls enlarge air by at most.65m inside the existing
			# 2m crossing reserve. Protected floors/widths never shrink or move.
			var phase:float=atan2(point.z-a.z,point.x-a.x)*9 if kinds[feature]==2 else radius_distance*.37+point.x*.08+point.z*.11
			var fold:float=.5+.5*sin(phase+y*.43+sin(point.y*.13)*.8);arch-=fold*fold*.65*smoothstep(1,4,y)
		var value:float=maxf(-y,arch+wall)
		if kinds[feature]==1:opening=minf(opening,value)
		else:closed=minf(closed,value)
	if minf(closed,opening)>=FAR:return FAR
	var ground:float=ground_height(point)
	if not is_finite(ground):return FAR
	var depth:float=ground-point.y
	if opening_rock_cover>0:opening=maxf(opening,opening_rock_cover-depth)
	return minf(FAR,maxf(minf(maxf(closed,minimum_roof-depth),opening),depth-maximum_depth))
func sample(point:Vector3)->float:
	if not point.is_finite():return FAR
	if absf(point.x)>2147483646.0*BIN_METRES or absf(point.y)>2147483646.0*BIN_METRES or absf(point.z)>2147483646.0*BIN_METRES:return FAR
	var key:Vector3i=bin_cell(point)
	if not bins.has(key):return FAR
	return evaluate(point,bins[key])
func normal(point:Vector3)->Vector3:
	var e:float=.125
	# Negative gradient points from solid rock into the navigable air volume.
	return -Vector3(sample(point+Vector3(e,0,0))-sample(point-Vector3(e,0,0)),sample(point+Vector3(0,e,0))-sample(point-Vector3(0,e,0)),sample(point+Vector3(0,0,e))-sample(point-Vector3(0,0,e))).normalized()
func numeric_bytes()->int:return begins.size()*(82+_biome_fields.size()*8)+references*4+endpoint_grades.size()*8+(_protected_shores.size()+precise_shores.size())*32
