extends SceneTree
const Fan=preload("res://scripts/badlands_fan_geometry.gd")
var checks:int=0
var failures:Array=[]
func verify(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
static func builder(seed_id:int,strength:float=1):
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.world_seed=seed_id;b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	for owner:String in ["grass","forest","jungle","savanna","swamp","mountain","tropical","badlands"]+TerrainSettings.EXTENSION_KEYS:b.settings.set(owner+"_coverage",0)
	b.settings.badlands_coverage=100;b.settings.badlands.fan_shape_strength=strength;b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false;b.settings.island_size=100400;b.settings.island_spacing=585;b._configure_noise();return b
func digest(b,arrays:Array,resolution:int)->String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(var_to_bytes(arrays));h.update(var_to_bytes(b.build_swamp_water(arrays,resolution)));h.update(var_to_bytes(b.built_extension_data));h.update(var_to_bytes(b.built_badlands_palette));return h.finish().hex_encode()
func _initialize()->void:call_deferred("run")
func run()->void:
	var records:Array=[]
	for length:float in [250,600,1600]:
		for angle:float in [-2.8,-1.4,0,.3,1.4,PI]:
			var axis:=Vector2(cos(angle),sin(angle));var normal:=Vector2(-axis.y,axis.x)
			for offset:Vector2 in [Vector2.ZERO,Vector2(4096,-8192),Vector2(-131072,65536)]:
				var root:=Vector3(offset.x,28,offset.y);var end:=root+Vector3(axis.x*length,20,axis.y*length);var tree:Dictionary={"root":root,"edges":[[root,end,0]]}
				var frame:PackedFloat64Array=Fan.frame(tree);var reach:float=minf(650,maxf(32,frame[4]*.85));var actual_axis:=Vector2(frame[2],frame[3]);var actual_normal:=Vector2(-actual_axis.y,actual_axis.x)
				verify(Fan.mask(offset,tree,650)==1,"Fan attached at actual wash outlet")
				verify(Fan.mask(offset+actual_axis*(reach+2),tree,650)==0,"Finite upstream support")
				verify(Fan.mask(offset-actual_axis*reach*.25,tree,650)==0,"Finite downstream toe")
				verify(Fan.mask(offset+actual_normal*322,tree,650)==0,"Finite lateral support")
				verify(Fan.mask(offset+actual_axis*reach*.85+actual_normal*100,tree,650)==0,"Narrow feeder throat")
				verify(Fan.mask(offset+actual_axis*reach*.15+actual_normal*100,tree,650)>.5,"Broadening apron toward wash")
				verify(tree.fan_frame==frame,"Stable bounded frame stored on owning tree")
	for seed_id:int in [73921,17,92881]:
		for relief:float in [.2,1,2]:
			var b=builder(seed_id);b.settings.badlands.relief=relief;b._badlands.configure(b.settings.badlands,seed_id,b)
			for side:int in [-1,1]:
				for index:int in [-7,0,2]:
					var tree:Dictionary=b._badlands._tree(index,-3,side);var basis:PackedFloat64Array=Fan.frame(tree);var root:=Vector2(basis[0],basis[1]);var axis:=Vector2(basis[2],basis[3]);var normal:=Vector2(-axis.y,axis.x)
					var span:float=350+391*relief;var reach:float=minf(span,maxf(32,basis[4]*.85));var bounds:Vector4=tree.support_bounds
					for t:float in [-.3,-.1,0,.1,.4,.7,.9,1,1.1,1.3]:
						for across:float in [-400,-320,-180,-80,0,80,180,320,400]:
							var p:Vector2=root+axis*reach*(1-t)+normal*across;var value:float=Fan.mask(p,tree,span)
							verify(value>=0 and value<=1 and is_finite(value),"Finite normalized fan mask")
							if value>0:verify(p.x>=bounds.x and p.x<=bounds.z and p.y>=bounds.y and p.y<=bounds.w,"Rotated fan stays inside existing conservative tree support")
	# Exact full pre-change sampler, not a second implementation of zero mode.
	var reference_path:String="res://tools/biome_extensions/artifacts/revisions/experiment_tropical_river_detail_adoption_a8501c4a606b/sources/scripts/badlands_sampler.gd.txt"
	var reference:=GDScript.new();reference.source_code=FileAccess.get_file_as_string(reference_path);assert(reference.reload()==OK)
	for seed_id:int in [73921,17,92881]:
		var a=builder(seed_id,0);var b=builder(seed_id,0);var original=reference.new();original.configure(b.settings.badlands,seed_id,b);b._badlands=original
		for i in range(120):
			var p:=Vector2(i*7919%160000-80000,i*11939%160000-80000)
			var h:float=a._get_height(p.x,p.y);var payload:Array=[a._last_badlands,a._last_geology,a._last_surface,a._last_swamp_water]
			verify(h==b._get_height(p.x,p.y),"Zero-mode exact original height");verify(payload==[b._last_badlands,b._last_geology,b._last_surface,b._last_swamp_water],"Zero-mode complete published controls")
		for cell:Vector2i in [Vector2i(19,14),Vector2i(-42,-11)]:verify(digest(a,a.build(cell,16),16)==digest(b,b.build(cell,16),16),"Zero-mode complete original mesh/water/palette")
		# Search unchanged drainage roots for actual fan provinces. The new
		# apron must not alter the primary core, compared with fans disabled.
		var field=builder(seed_id,1);var raw=field._badlands;var admitted:Array=[]
		for lane in range(-30,31):
			for index in range(-96,97):
				var r:float=raw.random(index,lane,42);var x:float=(index+.25+r*.5)*field.settings.badlands.drainage_spacing
				var p:=Vector2(x,raw._carrier(x,lane))
				if field._island_mask(p.x,p.y)<.1:continue
				var w:PackedFloat32Array=raw.region_weights(p)
				if w[14]<.6:continue
				var tree:Dictionary=raw._tree(index,lane,1);var root:Vector3=tree.root;p=Vector2(root.x,root.z)
				field.settings.badlands.fans=0;var no_fan:PackedFloat64Array=raw._raw(p)
				field.settings.badlands.fans=.65;var shaped:PackedFloat64Array=raw._raw(p)
				verify(no_fan[0]==shaped[0] and shaped[8]>.999,"Primary floor unchanged by fan deposition")
				if shaped[13]>.05:admitted.append({"index":index,"lane":lane,"root":[root.x,root.z],"fan":shaped[13],"height":shaped[0],"island":field._island_mask(p.x,p.y)})
				if admitted.size()==3:break
			if admitted.size()==3:break
		verify(admitted.size()==3,"Three actual fan-province roots per seed")
		records.append({"seed":seed_id,"floor_cases":admitted})
	var report:Dictionary={"passed":failures.is_empty(),"failures":failures,"assertions":checks,"cases":records,"source_sha256":{},"scope":"Finite trunk-aligned widening aprons,actual outlet attachment and conservative support over three seeds/relief bounds. Exact zero mode against the full frozen original sampler,complete meshes/water/palettes,and three primary-floor controls per seed. Not native scenic/traversal/performance acceptance or all-world coverage."}
	for path:String in ["res://scripts/badlands_fan_geometry.gd","res://scripts/badlands_sampler.gd","res://scripts/badlands_settings.gd","res://scripts/terrain_mesh_builder.gd","res://tools/badlands/check_fan_geometry.gd",reference_path]:report.source_sha256[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/badlands/artifacts/check_fan_geometry.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("BADLANDS_FANS_RESULT ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
