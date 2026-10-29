extends SceneTree
const Flow=preload("res://tools/biome_extensions/alien_tissue_flow_candidate.gd")
var checks:int=0
var failures:Array=[]
func verify(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func _initialize()->void:
	var guards:Dictionary={}
	for path:String in ["res://tools/biome_extensions/alien_tissue_flow_candidate.gd","res://tools/biome_extensions/check_alien_tissue_flow_candidate.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd"]:guards[path]=FileAccess.get_sha256(path)
	var records:Array=[]
	for seed_id:int in [73921,17,92881]:
		for scale:float in [.2,1,2]:
			var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.world_seed=seed_id;b.settings.alien_infected_coverage=100;b.settings.alien_infected.feature_scale=scale;b._configure_noise();var field=b._extras[7]
			var active:int=0;var points:Array[Vector2]=[];var expected:Array=[]
			for cell:Vector2i in [Vector2i.ZERO,Vector2i(-12,8),Vector2i(37,-41)]:
				var paths:PackedVector2Array=field.network_edges(cell)
				for edge in range(2):
					var start:Vector2=paths[edge*4];var mid:Vector2=paths[edge*4+1];var end:Vector2=paths[edge*4+2]
					for node:Vector2 in [start,mid,end]:verify(Flow.sample(field,node).weight==0,"No artificial UV alignment at a true graph junction/bend")
					for segment:Array in [[start,mid],[mid,end]]:
						var direction:Vector2=(segment[1]-segment[0]).normalized();var normal:=Vector2(-direction.y,direction.x)
						for t:float in [.2,.35,.5,.65,.8]:
							for cross_offset:float in [-140,-50,0,50,140]:points.append(segment[0].lerp(segment[1],t)+normal*cross_offset*scale)
			for p:Vector2 in points:
				var before:Dictionary=field.network(p).duplicate();var raw=field.evaluate(p,1);var full:Dictionary=Flow.sample(field,p,false);var indexed:Dictionary=Flow.sample(field,p,true)
				verify(full==indexed,"Pruned path coordinates equal complete actual graph")
				verify(field.network(p)==before and field.evaluate(p,1)==raw,"Material query never changes canonical network/height controls")
				verify(indexed.weight>=0 and indexed.weight<=1 and is_finite(indexed.arc_metres) and is_finite(indexed.across_metres),"Finite bounded material frame")
				if indexed.weight>.5:
					active+=1;var ahead:Dictionary=Flow.sample(field,p+indexed.tangent*2*scale)
					if ahead.path==indexed.path and ahead.weight>.5:verify(absf((ahead.arc_metres-indexed.arc_metres)-2*scale)<.08,"UV arc advances along actual finite conduit")
				expected.append(indexed)
			for index in range(points.size()-1,-1,-1):verify(Flow.sample(field,points[index])==expected[index],"Material projection is query-order independent")
			verify(active>20,"Actual nontrivial aligned paths exist")
			verify(field._query_tiles.size()<=512 and field._network_edges.size()<=512,"Existing bounded graph caches retained")
			records.append({"seed":seed_id,"scale":scale,"queries":points.size(),"strong_alignment_samples":active})
	for path:String in guards:verify(FileAccess.get_sha256(path)==guards[path],"Stable material-frame source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_alien_tissue_flow_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":guards,"assertions":checks,"cases":records,"production_registration":false,"scope":"Private actual-hive finite-path material-coordinate prototype,full-versus-conservative-index comparison,three seeds/min-default-max feature scales,query-order independence,unchanged network/height controls,and junction/bend fades. No mesh transport,shader,native art/cost or production acceptance yet."},"  "));print("ALIEN_TISSUE_FLOW_PRIVATE ",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
