extends SceneTree
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func _initialize()->void:
	var builder=preload("res://scripts/terrain_mesh_builder.gd").new();builder.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	builder.settings.beaches_enabled=false;builder.settings.rocky_coast_enabled=false
	for biome:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]:builder.settings.set(biome+"_coverage",0)
	builder.settings.badlands_coverage=100;builder._configure_noise();var field=builder._badlands
	var placed:Array=[];var profiles:Dictionary={}
	for lane in range(-8,9):
		for index in range(-24,25):
			for side in [-1,1]:
				var tree:Dictionary=field._tree(index,lane,side)
				if tree.random>=field.settings.remnants:continue
				var p:=Vector2(tree.ends[0].x+80,tree.ends[0].z)
				if builder._island_mask(p.x,p.y)<.1 or field.region_weights(p)[5]<.95:continue
				for formation:Dictionary in field._remnant_formations(tree,index,lane,side):
					var anchor:Vector2=formation.position
					if builder._island_mask(anchor.x,anchor.y)<.1:continue
					var cap:Vector2=field.strata(anchor,formation.height)
					check(cap.y>.99,"Descriptor cap belongs to a real resistant bed")
					check(is_finite(formation.height) and formation.radius.x>=22 and formation.radius.y>=22,"Finite locally representable terrain-supported remnant")
					profiles[str(formation.radius)+str(formation.shoulder)+str(formation.angle)]=true
					var h:float=field.sample(anchor.x,anchor.y)
					if field.state[10]<.99 or absf(h-formation.height)>.1:continue
					check(field.strata(anchor,h).y>.99,"Actual analytic cap still exposes its resistant bed")
					check(absf(h-formation.height)<.1,"Physical cap has no coarse-lattice interpolation overshoot")
					placed.append({"position":anchor,"cap_height":formation.height,"sampled_height":h,"radius":formation.radius,"angle":formation.angle})
					if placed.size()>=16:break
				if placed.size()>=16:break
			if placed.size()>=16:break
		if placed.size()>=16:break
	check(placed.size()>=8,"Actual procedural hoodoo-country placements found")
	check(profiles.size()>=8,"Remnant footprints, orientation and shoulders vary")
	var wall_normals:int=0;var shared_normals:int=0
	for record:Dictionary in placed.slice(0,2):
		var anchor:Vector2=record.position;var cell:=Vector2i(floori(anchor.x/256),floori(anchor.y/256))
		builder.chunk_size=256;var fine:Array=builder.build(cell,64)
		var parent_cell:=Vector2i(floori(cell.x/2.0),floori(cell.y/2.0));builder.chunk_size=512;var parent:Array=builder.build(parent_cell,64)
		var offset:Vector2i=(cell-parent_cell*2)*32
		for z in range(33):
			for x in range(33):
				var p:=Vector2(cell.x*256+x*8,cell.y*256+z*8);builder._get_height(p.x,p.y)
				if builder._last_badlands_remnant<.2:continue
				var normal:Vector3=fine[Mesh.ARRAY_NORMAL][z*2*65+x*2]
				check(normal.is_equal_approx(parent[Mesh.ARRAY_NORMAL][(z+offset.y)*65+x+offset.x]),"Actual caprock normals agree at shared 4m/8m LOD vertices");shared_normals+=1
				if normal.y>.9:continue
				var actual:=Vector3(builder._get_height(p.x-2,p.y,false)-builder._get_height(p.x+2,p.y,false),4,builder._get_height(p.x,p.y-2,false)-builder._get_height(p.x,p.y+2,false)).normalized()
				check(normal.dot(actual)>.99999,"Physical caprock wall normal follows its local two-metre derivative");wall_normals+=1
	check(wall_normals>=8 and shared_normals>=16,"Real compact wall/LOD normal samples were exercised")
	var result:Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty(),"placements":placed,"distinct_profiles":profiles.size(),"wall_normal_samples":wall_normals,"shared_lod_normal_samples":shared_normals,"sampler_sha256":FileAccess.get_sha256("res://scripts/badlands_sampler.gd"),"builder_sha256":FileAccess.get_sha256("res://scripts/terrain_mesh_builder.gd"),"scope":"Continuous caprock, actual compact wall normals and shared 4m/8m LOD vertices; no detached caps, overhangs, decorative objects or universal traversal claim"}
	FileAccess.open("res://tools/badlands/artifacts/check_hoodoos.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("BADLANDS_HOODOOS ",result);quit(0 if failures.is_empty() else 1)
