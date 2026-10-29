extends SceneTree
const Features=preload("res://scripts/terrain_feature_meshes.gd")
const Collision=preload("res://scripts/terrain_collision.gd")
var checks:int=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func builder(seed_id:int,frequency:float=.12):
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.world_seed=seed_id
	b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	for key:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical","badlands"]+TerrainSettings.EXTENSION_KEYS:b.settings.set(key+"_coverage",0)
	b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false;b.settings.tropical_coverage=100;b.settings.tropical.waterfall_frequency=frequency;b._configure_noise();return b
func digest(b,arrays:Array,resolution:int)->String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256)
	for channel in arrays:h.update(var_to_bytes(channel))
	h.update(var_to_bytes(b.built_extension_data));h.update(var_to_bytes(b.build_swamp_water(arrays,resolution)));return h.finish().hex_encode()
func _initialize()->void:
	var sources:Dictionary={}
	for path:String in ["res://scripts/tropical_sampler.gd","res://scripts/tropical_settings.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_collision.gd","res://tools/tropical/check_cascades.gd","res://tools/tropical/reference_pre_cascades_sampler.gd"]:sources[path]=FileAccess.get_sha256(path)
	var records:Array=[];var candidates:int=0
	for seed_id:int in [73921,17,92881]:
		var b=builder(seed_id);var admitted:Array=[];var field=b._tropical
		for lane in range(-48,49):
			for segment in range(-100,101):
				var r:float=field.random(segment,lane,131)
				if field.cascade_height(segment,lane,r)<=0:continue
				candidates+=1;var p:Vector2=field.cascade_point(segment,lane,.5)
				var cell:=Vector2i(floori(p.x/256),floori(p.y/256));b.chunk_size=256
				var result:Dictionary=Features.new().build(b,cell)
				if result.is_empty():continue
				for fall:Dictionary in result.waterfalls:
					if not fall.get("kind","")=="rocky_tributary_cascade":continue
					if admitted.any(func(item:Dictionary)->bool:return item.id==fall.id):continue
					admitted.append(fall);check(fall.connected_to_carrier and fall.drop_metres>6,"Real connected tributary drop")
					var previous:float=-INF;var reversal:float=0
					for point:Vector3 in fall.canonical_water_profile:
						var ground:float=b._get_height(point.x,point.z);var water:float=b._last_swamp_water
						check(absf(point.y-water-.12)<.001,"Rendered cascade follows canonical water")
						check(water>ground+.1,"Water is above the actual bed, not a dry ledge")
						if previous!=-INF:reversal=maxf(reversal,previous-point.y)
						check(point.y>=previous-.001,"Canonical water rises monotonically towards the source")
						previous=point.y
					var repeat:Dictionary=Features.new().build(b,cell)
					check(result.surfaces==repeat.surfaces,"Stable numeric cascade geometry after cache reuse")
					var water_vertices:PackedVector3Array=result.surfaces[3][Mesh.ARRAY_VERTEX]
					check(water_vertices.size()>=192,"Actual foam triangles, not descriptor-only support")
					var root_count:int=0
					for dz in range(-1,2):
						for dx in range(-1,2):
							var neighbours:Dictionary=Features.new().build(b,cell+Vector2i(dx,dz))
							if neighbours.is_empty():continue
							for other:Dictionary in neighbours.waterfalls:
								if other.id==fall.id:root_count+=1
					check(root_count==1,"One half-open leaf owns the full cascade")
					b.chunk_size=1024;var parent:Dictionary=Features.new().build(b,Vector2i(floori(p.x/1024),floori(p.y/1024)));var same:bool=false
					if not parent.is_empty():
						for other:Dictionary in parent.waterfalls:
							if other.id==fall.id:same=other.canonical_water_profile==fall.canonical_water_profile
					check(same,"World-space cascade profile is independent of owning LOD")
					b.chunk_size=256
					var land:Array=b.build(cell,32);var collision:Dictionary=Collision.prepare(land,32,true,[],result)
					check(collision.cavity_faces.is_empty() and collision.structure_faces.is_empty(),"Waterfall sheet adds no solid-water collision")
					records.append({"seed":seed_id,"id":fall.id,"position":p,"drop_metres":fall.drop_metres,"maximum_reverse_step_m":reversal,"foam_vertices":water_vertices.size(),"owned_leaf":cell})
				if admitted.size()>=3:break
			if admitted.size()>=3:break
		check(admitted.size()>=3,"Three admitted real cascades at default frequency: "+str(seed_id))
		# Frequency zero preserves all previous terrain, water and material bytes.
		for dimensions:Vector2i in [Vector2i(256,64),Vector2i(4096,16)]:
			var current=builder(seed_id,0);var reference=builder(seed_id,0);current.chunk_size=dimensions.x;reference.chunk_size=dimensions.x
			reference._tropical=preload("res://tools/tropical/reference_pre_cascades_sampler.gd").new();reference._tropical.configure(reference.settings.tropical,seed_id,reference)
			var site:Vector2=admitted[0].position if not admitted.is_empty() else Vector2(14080,18688)
			var cell:=Vector2i(floori(site.x/dimensions.x),floori(site.y/dimensions.x))
			check(digest(current,current.build(cell,dimensions.y),dimensions.y)==digest(reference,reference.build(cell,dimensions.y),dimensions.y),"Disabled cascade preserves complete terrain/water/atlas arrays")
			check(Features.new().build(current,cell).is_empty(),"Disabled pure Tropical cascade adds no feature payload")
		check(field._cascade_cache.size()<=512,"Bounded candidate cache")
	for path:String in sources:check(FileAccess.get_sha256(path)==sources[path],"Stable source: "+path)
	var report:Dictionary={"checks":checks,"passed":failures.is_empty(),"failures":failures,"records":records,"eligible_candidates_tested":candidates,"source_sha256":sources,"scope":"Actual default-frequency rocky tributary cascades, canonical bed/water, one-owner and cross-LOD profiles, no water collision, and six full disabled-mode compatibility cases. Native rendering and full route/performance acceptance are separate."}
	FileAccess.open("res://tools/tropical/artifacts/check_cascades.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("TROPICAL_CASCADES ",checks," checks / ",records.size()," admitted; failures=",failures);quit(0 if failures.is_empty() else 1)
