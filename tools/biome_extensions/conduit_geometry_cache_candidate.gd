extends "res://tools/biome_extensions/reference_pre_conduit_memo_structures.gd"
## Experimental worker-owned memoization only; not connected to production.
const Base=preload("res://tools/biome_extensions/reference_pre_conduit_memo_structures.gd")
const META_KEY="conduit_geometry_experiment_v1"
var byte_budget:int=8*1024*1024
var entry_budget:int=32
var _memo:Dictionary={}
func config_values(resource:Resource)->Dictionary:
	var values:Dictionary={}
	for property:Dictionary in resource.get_property_list():
		var name:String=property.name
		if (int(property.usage)&PROPERTY_USAGE_STORAGE)==0 or name in ["script","resource_path"]:continue
		var value=resource.get(name)
		values[name]=config_values(value) if value is Resource else value
	return values
func evict()->void:
	var key:String=_memo.entries.keys()[0]
	_memo.bytes-=int(_memo.entries[key].bytes);_memo.entries.erase(key)
func prepare_memo(builder)->void:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes([builder.world_seed,builder.water_level,config_values(builder.settings)]));var signature:PackedByteArray=hash.finish()
	_memo=builder.get_meta(META_KEY,{})
	if _memo.is_empty() or _memo.signature!=signature:
		_memo={"signature":signature,"entries":{},"bytes":0,"hits":0,"misses":0};builder.set_meta(META_KEY,_memo)
	while not _memo.entries.is_empty() and (_memo.bytes>byte_budget or _memo.entries.size()>entry_budget):evict()
func build(builder,coordinate:Vector2i,support_steps:PackedFloat64Array=PackedFloat64Array(),portal_provider:Callable=Callable())->Array:
	prepare_memo(builder)
	return super.build(builder,coordinate,support_steps,portal_provider)
func relevant_sites(a:Vector2,b:Vector2,width:float)->Array:
	var sites:Array=[];var direction:Vector2=b-a;var denominator:float=maxf(direction.length_squared(),.000001)
	var magnitude:float=maxf(maxf(absf(a.x),absf(a.y)),maxf(absf(b.x),absf(b.y)));var rounding_pad:float=1+magnitude*.000002
	for site:Dictionary in _protected_sites:
		var nearest:Vector2=a+direction*clampf((site.position-a).dot(direction)/denominator,0,1)
		# Exact original apron test can only shrink reach within this bound:
		# site reserve +64+16+128 +5*radius + .8*width centreline sway.
		if nearest.distance_to(site.position)<=maxf(320,site.half*1.2)+208+5.8*width+rounding_pad:sites.append(site)
	# Preserve the original site's visit order. Unrelated distant reservations
	# always contribute factor=1 and cannot affect the emitted primitive.
	return sites
func conduit(builder,a:Vector2,b:Vector2,width:float,phase:float,color:Color)->void:
	if _memo.is_empty():prepare_memo(builder)
	var sites:Array=relevant_sites(a,b,width)
	var key:String=var_to_bytes([a,b,width,phase,color,conduit_aprons,conduit_shoulders,_support_steps,sites]).hex_encode()
	var entry:Dictionary={}
	if _memo.entries.has(key):entry=_memo.entries[key];_memo.hits+=1
	else:
		_memo.misses+=1
		var g=Base.new();g.origin=Vector3.ZERO;g._support_steps=_support_steps;g._support_heights=_support_heights;g._protected_sites=sites;g.conduit_aprons=conduit_aprons;g.conduit_shoulders=conduit_shoulders
		g.conduit(builder,a,b,width,phase,color)
		entry={"vertices":g.vertices,"normals":g.normals,"colors":g.colors,"uvs":g.uvs,"bytes":g.vertices.size()*48}
		if entry.bytes<=byte_budget and entry_budget>0:
			while not _memo.entries.is_empty() and (_memo.bytes+entry.bytes>byte_budget or _memo.entries.size()>=entry_budget):evict()
			_memo.entries[key]=entry;_memo.bytes+=entry.bytes
	# Cache stores original world-space float32 positions. Subtracting the new
	# leaf origin reproduces the original triangle emitter, not a rounded LOD
	# transform of already-local positions. Packed arrays remain read-only.
	for vertex:Vector3 in entry.vertices:vertices.append(vertex-origin)
	normals.append_array(entry.normals);colors.append_array(entry.colors);uvs.append_array(entry.uvs)
	_footing_vertices.clear();_conduit_uvs.clear();_skip_degenerate=false
