extends SceneTree
## Measure real canonical cross-sections, not a count of named descriptors.
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
var checks:int=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func builder(seed_id:int,secondary:float):
	var b=Builder.new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.world_seed=seed_id
	for key:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]+TerrainSettings.EXTENSION_KEYS:b.settings.set(key+"_coverage",0)
	b.settings.badlands_coverage=100;b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false;b.settings.badlands.secondary_gullies=secondary;b._configure_noise();return b
func sections(incised,uncut)->Array:
	var results:Array=[]
	for lane in range(-12,13):
		for index in range(-36,37):
			for side in [-1,1]:
				var tree:Dictionary=incised._badlands._tree(index,lane,side)
				for edge:Array in tree.edges:
					if edge[2]!=2:continue
					var middle:Vector3=edge[0].lerp(edge[1],.5);var p:=Vector2(middle.x,middle.z)
					if incised._island_mask(p.x,p.y)<.1:continue
					var w:PackedFloat32Array=incised._badlands.region_weights(p)
					if w[4]+w[6]+w[7]+w[13]<.9:continue
					var axis:=Vector2(edge[1].x-edge[0].x,edge[1].z-edge[0].z).normalized().orthogonal()
					var heights:=PackedFloat64Array();var depth:float=0;var low:float=INF;var high:float=-INF;var slope:float=0
					for station in range(-40,41):
						var q:Vector2=p+axis*station*4.0
						var h:float=incised._get_height(q.x,q.y);var original:float=uncut._get_height(q.x,q.y)
						depth=maxf(depth,original-h);low=minf(low,h);high=maxf(high,h)
						if not heights.is_empty():slope=maxf(slope,absf(h-heights[-1])/4.0)
						heights.append(h)
					# Admit only actual incised hillsides, not a descriptor buried
					# under another valley or an already flat trunk junction.
					if depth<10 or high-low<30 or slope<.2:continue
					check(depth>=10,"Real secondary valley removes at least 10m of sediment")
					check(high-low>=30 and slope>=.2,"Cross-section has physical relief and inclined walls")
					for h:float in heights:check(is_finite(h),"Finite canonical cross-section")
					var crest:Dictionary={};var best_prominence:float=0
					for sample_index in range(16,heights.size()-16):
						var near_prominence:float=minf(heights[sample_index]-heights[sample_index-8],heights[sample_index]-heights[sample_index+8])
						var far_prominence:float=minf(heights[sample_index]-heights[sample_index-16],heights[sample_index]-heights[sample_index+16])
						if near_prominence<=3 or far_prominence<=best_prominence:continue
						best_prominence=far_prominence;crest={"position":p+axis*(sample_index-40)*4.0,"height":heights[sample_index],"prominence_at_32m":near_prominence,"prominence_at_64m":far_prominence}
					results.append({"position":p,"axis":axis,"sample_spacing_m":4,"width_m":320,"maximum_secondary_incision_m":depth,"relief_m":high-low,"maximum_grade":slope,"measured_crest":crest,"heights":heights})
					if results.size()==4:return results
	return results
func _initialize()->void:
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		var enabled=builder(seed_id,.75);var disabled=builder(seed_id,0)
		check(enabled.settings.badlands!=disabled.settings.badlands,"Independent controlled fixtures")
		var found:Array=sections(enabled,disabled)
		check(found.size()==4,"Four actual inland incised cross-sections found for seed "+str(seed_id))
		cases.append({"seed":seed_id,"sections":found})
	var report:Dictionary={"checks":checks,"failures":failures,"cases":cases,"sampler_sha256":FileAccess.get_sha256("res://scripts/badlands_sampler.gd"),"scope":"Twelve actual inland canonical cross-sections at four-metre spacing, across three seeds. Does not certify every ridge, knife-edge silhouettes or visual reference quality."}
	FileAccess.open("res://tools/badlands/artifacts/check_incised_profiles.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("BADLANDS_INCISED_PROFILES ",checks," checks; failures=",failures);quit(0 if failures.is_empty() else 1)
