extends SceneTree
const Coordinates=preload("res://scripts/alien_tissue_coordinates.gd")
const Prototype=preload("res://tools/biome_extensions/alien_tissue_flow_candidate.gd")
const BEFORE="res://tools/biome_extensions/artifacts/revisions/experiment_badlands_fan_gradient_adoption_f127dc8d2de1/sources/scripts/terrain_mesh_builder.gd.txt"
var checks:int=0
var failures:Array=[]
func verify(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
static func builder(seed_id:int,enabled:bool,profile:int=0):
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.world_seed=seed_id;b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	for owner:String in ["grass","jungle","forest","savanna","swamp","mountain","tropical","badlands"]+TerrainSettings.EXTENSION_KEYS:b.settings.set(owner+"_coverage",0)
	if profile==0:b.settings.alien_infected_coverage=100
	elif profile==1:b.settings.grass_coverage=100;b.settings.alien_infected.overlay_strength=.7
	else:b.settings.spore_forest_coverage=100
	b.settings.alien_infected.nerve_flow_texturing=enabled;b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false;b.settings.island_size=100400;b.settings.island_spacing=585;b._configure_noise();return b
func payload(b,cell:Vector2i)->Array:
	var a:Array=b.build(cell,16)
	return [a,b.build_swamp_water(a,16),b.built_extension_data.duplicate(),b.built_badlands_palette.duplicate(),b.built_extension_mask,b.built_badlands_palette_slot]
func _initialize()->void:
	var guards:Dictionary={}
	for path:String in [BEFORE,"res://scripts/alien_tissue_coordinates.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/chunk_terrain.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://shaders/alien_tissue_flow.gdshaderinc","res://shaders/biological_sampling.gdshaderinc","res://tools/biome_extensions/check_alien_tissue_transport.gd","res://tools/biome_extensions/alien_tissue_flow_candidate.gd"]:guards[path]=FileAccess.get_sha256(path)
	var before:=GDScript.new();before.source_code=FileAccess.get_file_as_string(BEFORE);assert(before.reload()==OK)
	var records:Array=[];var total_active:int=0
	for seed_id:int in [73921,17,92881]:
		for profile in range(3):
			var current=builder(seed_id,true,profile);var zero=builder(seed_id,false,profile);var old=before.new();old.world_seed=seed_id;old.settings=zero.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);old._configure_noise()
			var field=current._extras[7];var anchor:Vector2=Vector2.ZERO
			if field!=null:
				var path:PackedVector2Array=field.network_edges(Vector2i(-2,3));anchor=path[0].lerp(path[1],.5)
				# Retain the original proposed coordinate as an ocean/empty control;
				# the atlas is deliberately absent where no Alien payload survives.
				var proposed:=Vector2i(floori(anchor.x/256),floori(anchor.y/256));payload(current,proposed)
				verify((current.built_extension_mask&128)!=0 or current.built_alien_tissue_flow.is_empty(),"Original proposal without Alien payload allocates no atlas")
				if current._island_mask(anchor.x,anchor.y)<=.1:
					var found:bool=false
					for index in range(4096):
						var candidate_paths:PackedVector2Array=field.network_edges(Vector2i(index%64-32,index/64-32));var p:Vector2=candidate_paths[0].lerp(candidate_paths[1],.5)
						if current._island_mask(p.x,p.y)>.2 and Coordinates.sample(field,p).weight>.5:anchor=p;found=true;break
					verify(found,"Discover a real on-land aligned path before freezing positive transport site")
			var cell:=Vector2i(floori(anchor.x/256),floori(anchor.y/256))
			var expected:Array=payload(zero,cell);verify(expected==payload(old,cell),"Independent disabled mode exact full pre-flow payload")
			verify(expected==payload(current,cell),"Enabled material coordinates change no geometry/water/packed ownership controls")
			verify(zero.built_alien_tissue_flow.is_empty() and zero.built_alien_tissue_flow_rows==0,"Disabled mode allocates no material atlas")
			if profile==2:
				verify(current.built_alien_tissue_flow.is_empty(),"Unrelated Spore never allocates Alien transport");continue
			verify(current.built_alien_tissue_flow.size()<=129*129*16,"Bounded RGBA32F map")
			var active:int=0
			if not current.built_alien_tissue_flow.is_empty():
				var rows:int=current.built_alien_tissue_flow_rows;var data:PackedFloat32Array=current.built_alien_tissue_flow.to_float32_array()
				verify(rows==17 and data.size()==rows*rows*4,"Actual transport dimensions match terrain-or-8m bound")
				for z in range(rows):
					for x in range(rows):
						var p:Vector2=Vector2(cell)*256+Vector2(x,z)*16;var a:Dictionary=Coordinates.sample(field,p);var frozen:Dictionary=Prototype.sample(field,p)
						verify(a==frozen,"Production coordinates exact preserved private formula")
						var offset:int=(z*rows+x)*4
						if data[offset+2]>0:
							active+=1;verify(data[offset]==float(PackedFloat32Array([a.arc_metres])[0]) and data[offset+1]==float(PackedFloat32Array([a.across_metres])[0]) and data[offset+2]==float(PackedFloat32Array([a.weight])[0]),"Float32 transport stores canonical finite UV/strength")
							verify(data[offset+3]>=1 and data[offset+3]==floorf(data[offset+3]),"Exact local group ID,not an interpolated angle")
						else:verify(data.slice(offset,offset+4)==PackedFloat32Array([0,0,0,0]),"Empty transport records stay zero")
			verify(active>0,"Real seeded fan of hive coordinates reaches atlas");total_active+=active
			# Independent neighbouring maps share exact canonical edge values;
			# local path IDs deliberately need not be globally identical.
			var left:Dictionary=Coordinates.atlas(field,Vector2(cell)*256,256,32);var right:Dictionary=Coordinates.atlas(field,Vector2(cell+Vector2i.RIGHT)*256,256,32)
			if not left.data.is_empty() and not right.data.is_empty():
				var l:PackedFloat32Array=left.data.to_float32_array();var r:PackedFloat32Array=right.data.to_float32_array()
				for z in range(33):verify(l.slice((z*33+32)*4,(z*33+32)*4+3)==r.slice(z*33*4,z*33*4+3),"Neighbour edge has identical canonical UV/strength")
			records.append({"seed":seed_id,"profile":profile,"cell":str(cell),"active_records":active,"bytes":current.built_alien_tissue_flow.size()})
	for path:String in guards:verify(FileAccess.get_sha256(path)==guards[path],"Stable transport source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_alien_tissue_transport.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"assertions":checks,"source_sha256":guards,"cases":records,"active_records":total_active,"scope":"Production transport,explicit opt-in:three seeds/pure Alien/zero-coverage overlay/unrelated Spore. Complete current-off versus frozen pre-flow builder outputs and on-versus-off geometry,water,packed ownership remain exact;RGBA32F coordinates equal preserved independent prototype,adjacent edge UV/weights match. Local path IDs only group coordinates within each tile. No native seam/scenic/performance acceptance or default enablement yet."},"  "));print("ALIEN_TISSUE_TRANSPORT ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
