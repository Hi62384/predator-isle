extends RefCounted
## Worker-owned numeric workload. No Node, GPU, physics or scene-tree access.
## Each worker owns its canonical sampler and compiled field. Bundles passed
## between workers contain immutable numeric descriptors only.
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
const Network=preload("res://scripts/caves/network.gd")
const Field=preload("res://scripts/caves/portal_field.gd")
const Mesher=preload("res://scripts/csharp/caves/PortalCaveMesher.cs")
const Context=preload("res://scripts/caves/surface_context.gd")
const SurfaceCut=preload("res://scripts/caves/surface_cut.gd")
var Collision=preload("res://scripts/csharp/terrain/TerrainCollision.cs").new()
const Formations=preload("res://scripts/caves/formations.gd")
const Basins=preload("res://scripts/caves/seepage_basins.gd")
const InsectGuard=preload("res://scripts/caves/insect_entry_guard.gd")
const Colony=preload("res://scripts/caves/colony_network.gd")
const Frontiers=preload("res://scripts/caves/stream_frontiers.gd")
const BiomeRegions=preload("res://scripts/caves/biome_regions.gd")
const SurfaceBiomes=preload("res://scripts/caves/surface_biomes.gd")
const BiomeFeatures=preload("res://scripts/caves/biome_features.gd")
const MagmaHeat=preload("res://scripts/caves/magma_heat.gd")
var _magma_heat
var builder
var network
var field
var configuration
var bundle_key:=Vector2i(2147483647,2147483647)
var _regions:Array=[]
var _seed:int=73921
var _water_cache:Dictionary={}
var _insect_guard
var _colony
var _biomes
var _last_frontiers:Dictionary={}
var _last_biome_ids:Array=[]
var _last_valid:bool=true
func configure(terrain_settings:Resource,caves:Resource,seed_value:int,water:float)->bool:
	if caves==null or not caves.validation_errors().is_empty():return false
	_water_cache.clear()
	configuration=caves.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);_seed=seed_value;_regions=[];builder=Builder.new();builder.settings=terrain_settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);builder.world_seed=seed_value;builder.water_level=water;builder._configure_noise();network=Network.new();network.configure(builder._get_height,builder.get_water_surface_height,seed_value,configuration.maximum_depth_metres);network.activity=configuration.regional_activity;network.half_width=configuration.main_route_width_metres*.5;network.headroom=configuration.main_route_height_metres;network.minimum_roof=configuration.minimum_rock_cover_metres;network.maximum_grade=configuration.maximum_route_grade;network.chamber_variety=configuration.chamber_variety;network.geological_morphology=configuration.geological_morphology;network.seepage_density=configuration.seepage_density;_insect_guard=InsectGuard.new();_insect_guard.configure(builder);network.access_admission=_insect_guard.clear_access;_colony=Colony.new();_colony.configure(builder,configuration,network);network.region_context=_colony.context;network.region_decorator=_colony.decorate;_biomes=BiomeRegions.new();_biomes.configure(builder,configuration.biome_regions,seed_value);_magma_heat=null;
	for definition:Resource in configuration.biome_regions.definitions:
		if configuration.biome_regions.enabled and definition.enabled and str(definition.biome_id)=="magma" and definition.spawn_chance_percent>0 and definition.feature_configuration.get("source_heat",true):_magma_heat=MagmaHeat.new();_magma_heat.geological_intrusions=definition.feature_configuration.get("geological_intrusions",true);_magma_heat.configure(builder);break
	_biomes.geometry_provider=BiomeFeatures.decorate.bind(configuration,seed_value,builder._get_height,_magma_heat);network.region_finalizer=_biomes.decorate;field=Field.new();field.maximum_depth=configuration.maximum_depth_metres;field.minimum_roof=configuration.minimum_rock_cover_metres;bundle_key=Vector2i(2147483647,2147483647);return true
func discover(cell:Vector2i)->Dictionary:
	if network==null:return {}
	var regions:Array=[];var edges:Array=[];var entrances:Array=[];var halo:int=configuration.biome_regions.discovery_halo()
	for z in range(cell.y-halo,cell.y+halo+1):
		for x in range(cell.x-halo,cell.x+halo+1):
			var data:Dictionary=network.region(Vector2i(x,z));regions.append(data)
			if data.valid:
				var access:Dictionary=data.edges[0];entrances.append({"region":data.id,"point":data.nodes[0].point,"access":access})
	for z in range(cell.y-halo,cell.y+halo+1):
		for x in range(cell.x-halo,cell.x+halo+1):
			for offset:Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
				var other:Vector2i=Vector2i(x,z)+offset
				if other.x>cell.x+halo or other.y>cell.y+halo:continue
				var edge:Dictionary=network.connection(Vector2i(x,z),other)
				if not edge.is_empty():edges.append(edge)
	var bundle:Dictionary={"cell":cell,"regions":regions,"connections":edges,"entrances":entrances}
	if configuration.biome_regions.enabled:bundle["cave_biome_regions"]=BiomeRegions.combine(regions,edges,str(configuration.biome_regions.fallback_biome_id))
	if not use_bundle(bundle):return {"error":"Cave bundle exceeds numeric field bounds"}
	bundle["cells"]=field.chunks.keys()
	for entrance:Dictionary in entrances:entrance["columns"]=exposed_columns(entrance)
	return bundle
func use_bundle(bundle:Dictionary)->bool:
	if field==null or not bundle.has("cell") or not bundle.has("regions") or not bundle.has("connections"):return false
	if bundle_key==bundle.cell:return true
	var assignment:Dictionary=BiomeRegions.combine(bundle.regions,bundle.connections,str(configuration.biome_regions.fallback_biome_id)) if configuration.biome_regions.enabled else {}
	if not assignment.get("valid",true):return false
	if not field.compile(bundle.regions,builder._get_height,bundle.connections,assignment):return false
	_regions=bundle.regions;bundle_key=bundle.cell;_water_cache.clear();return true
func exposed_columns(entrance:Dictionary)->Dictionary:
	var columns:Dictionary={};var edge:Dictionary=entrance.access;var points:PackedVector3Array=edge.points;var minimum_exposed_floor:float=INF
	for i in range(points.size()-1):
		var a:Vector3=points[i];var b:Vector3=points[i+1];var exposed:bool=false
		for fraction:float in [0.0,.5,1.0]:
			var p:Vector3=a.lerp(b,fraction)
			for dx:float in [-edge.half_width,0.0,edge.half_width]:
				for dz:float in [-edge.half_width,0.0,edge.half_width]:
					if float(builder._get_height(p.x+dx,p.z+dz))<p.y+edge.headroom+4:exposed=true
		if not exposed:continue
		minimum_exposed_floor=minf(minimum_exposed_floor,minf(a.y,b.y))
		var first:=Vector2i(floori((minf(a.x,b.x)-edge.half_width)/64)-1,floori((minf(a.z,b.z)-edge.half_width)/64)-1);var last:=Vector2i(floori((maxf(a.x,b.x)+edge.half_width)/64)+1,floori((maxf(a.z,b.z)+edge.half_width)/64)+1)
		for z in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):columns[Vector2i(x,z)]=true
	entrance["minimum_exposed_floor"]=minimum_exposed_floor;return columns
func build(key:Vector3i,capture_frontiers:bool=false)->Array:
	if field!=null:field.surface_columns.clear();field.surface_limits.clear();field.top_height=Callable();field.include_surface_air=false;field.opening_rock_cover=6
	_last_frontiers={};_last_biome_ids=[];_last_valid=true
	if field==null:return []
	var mesher=Mesher.new();mesher.capture_boundary_values=capture_frontiers;var arrays:Array=mesher.build(field,key,2)
	if capture_frontiers:_last_frontiers=Frontiers.build(field,key,mesher.boundary_values)
	var bound:Dictionary=SurfaceBiomes.bind(decorated(arrays,key),field,key);_last_biome_ids=bound.ids;_last_valid=bound.valid
	if capture_frontiers:
		for face:int in _last_frontiers:_last_frontiers[face]=SurfaceBiomes.bind(_last_frontiers[face],field,key,_last_biome_ids).arrays
	return bound.arrays
func decorated(arrays:Array,key:Vector3i)->Array:
	if arrays.is_empty() or configuration.formation_density<=0:return arrays
	var region_id:=Vector2i(floori(float(key.x)/24),floori(float(key.z)/24));var style:int=0
	for region:Dictionary in _regions:
		if region.id==region_id:style=int(region.get("geology",0));break
	return Formations.join(arrays,Formations.new().build(field,key,_seed,style,configuration.formation_density).arrays)
func water_cell(key:Vector3i)->Dictionary:
	if _water_cache.has(key):return _water_cache[key]
	var result:Dictionary=Basins.water_cell(_regions,field,key) if field!=null else {"arrays":[],"ids":[],"rejected":[]}
	# Cache only positive immutable water payloads,not thousands of empty
	# ordinary cells. Eight per worker;bundle changes invalidate all entries.
	if not result.arrays.is_empty():
		if _water_cache.size()>=8:_water_cache.erase(_water_cache.keys()[0])
		_water_cache[key]=result
	return result
func build_cell(key:Vector3i)->Dictionary:
	var arrays:Array=build(key,configuration.seal_stream_frontiers);var result:Dictionary={"key":key,"arrays":arrays,"water":water_cell(key),"valid":_last_valid}
	if configuration.seal_stream_frontiers:result["frontiers"]=_last_frontiers
	if not _last_biome_ids.is_empty():result["biome_ids"]=_last_biome_ids
	if not _last_biome_ids.is_empty():
		var features:Dictionary=BiomeFeatures.build(field,key,_seed,_regions,configuration.biome_regions,result.water)
		if not features.valid:result["valid"]=false;result["reason"]=features.reason
		elif not features.batches.is_empty():result["features"]=features.batches
	return result
func portal(bundle:Dictionary,columns:Dictionary,parents:Array,owned_columns:Dictionary={},prepare_ground:bool=true)->Dictionary:
	if not use_bundle(bundle):return {"valid":false,"reason":"Invalid portal bundle"}
	var extraction:Dictionary=columns if owned_columns.is_empty() else owned_columns
	for column:Vector2i in extraction:
		if not columns.has(column):return {"valid":false,"reason":"Owned column outside complete surface mask"}
	var context=Context.new()
	if not context.configure(parents,builder._get_height):return {"valid":false,"reason":"Invalid immutable surface snapshot"}
	field.top_height=context.height_at
	field.include_surface_air=true
	field.opening_rock_cover=0
	if not field.measure_surface(columns):field.top_height=Callable();return {"valid":false,"reason":"Invalid measured surface bounds"}
	var result:Array=[]
	for column:Vector2i in extraction:
		var limits:Vector2=field.surface_limits[column]
		for y in range(floori(limits.x/64)-1,floori(limits.y/64)+1):
			var key:=Vector3i(column.x,y,column.y);var arrays:Array=decorated(Mesher.new().build(field,key,2),key);var groups:Dictionary=context.surfaces_indexed(arrays,Vector3(key)*64) if configuration.indexed_entry_payload else context.surfaces(arrays,Vector3(key)*64)
			if not groups.valid:field.surface_columns.clear();field.surface_limits.clear();field.top_height=Callable();return groups
			groups["key"]=key;groups["water"]=water_cell(key)
			var ids:Array=field.biome_ids_for_cell(key)
			if ids.size()>4:return {"valid":false,"reason":"More than four surface biome overlaps at portal"}
			if not ids.is_empty():
				groups["biome_ids"]=ids
				for id:String in groups.groups:groups.groups[id]["arrays"]=SurfaceBiomes.bind(groups.groups[id].arrays,field,key,ids).arrays
				var features:Dictionary=BiomeFeatures.build(field,key,_seed,_regions,configuration.biome_regions,groups.water)
				if not features.valid:
					field.surface_columns.clear();field.surface_limits.clear();field.top_height=Callable();return {"valid":false,"reason":features.reason}
				if not features.batches.is_empty():groups["features"]=features.batches
			if configuration.seal_stream_frontiers:
				groups["frontiers"]=Frontiers.build(field,key)
				for face:int in groups.frontiers:groups.frontiers[face]=SurfaceBiomes.bind(groups.frontiers[face],field,key,ids).arrays
			result.append(groups)
	var ground:Dictionary={}
	if prepare_ground:
		for parent:Dictionary in parents:
			var original:PackedVector3Array=parent.ground_faces
			if original.is_empty():original=Collision.surface_faces(parent.arrays,parent.resolution)
			ground[parent.id]=SurfaceCut.ground(original,parent.origin,columns)
			if not ground[parent.id].valid:field.surface_columns.clear();field.surface_limits.clear();field.top_height=Callable();return {"valid":false,"reason":"Original ground subtraction failed"}
	field.surface_columns.clear();field.surface_limits.clear();field.top_height=Callable();return {"valid":true,"cells":result,"ground":ground,"columns":columns,"owned_columns":extraction}
