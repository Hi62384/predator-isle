extends "res://tools/biome_extensions/check_all.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in ["res://tools/caves/check_hive_network.gd","res://scripts/alien_infected_sampler.gd"]:guards[path]=FileAccess.get_sha256(path)
	var b=make_builder(7,73921);var config=Config.new();config.regional_activity=1;var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Actual shared Hive worker configured");var cell:=Vector2i(-31,-31);var region:Dictionary=work.network.region(cell);print("HIVE_ORIGINAL_REGION valid=",region.valid," nodes=",region.nodes.size()," reason=",region.reason);check(region.valid and region.get("cave_family",-1)==7,"Original fixed Alien region admitted as true shared organic cave,without site replacement");var samples:int=0;var lobes:int=0;var branches:int=0
	if region.valid:
		check(region.geology==7 and region.cross_section_style==7 and region.get("underground_geometry",false),"Organic field style is actual canonical geometry,not only a descriptor");check(region.underground_hive_center.is_finite() and region.underground_hive_center.y!=-900,"Real solved core point replaces arbitrary global-Y placeholder in shared graph");var connected:Dictionary={region.nodes[0].id:true}
		for repeat_id in range(region.nodes.size()):
			for edge:Dictionary in region.edges:
				if connected.has(edge.from):connected[edge.to]=true
				if connected.has(edge.to):connected[edge.from]=true
		check(connected.size()==region.nodes.size(),"Every primary/secondary Hive chamber has a solved two-way surface exit");check(region.primary_hive_chambers>0 and region.secondary_nerve_branches>0 and not region.pockets.is_empty(),"Positive larger nerve junctions,smaller connected branches and multi-lobed organ core");lobes=region.pockets.size();branches=region.secondary_nerve_branches
		for edge:Dictionary in region.edges:
			for i in range(edge.points.size()-1):
				var a:Vector3=edge.points[i];var bv:Vector3=edge.points[i+1];var ab:=Vector2(bv.x-a.x,bv.z-a.z);check(absf(bv.y-a.y)<=ab.length()*.2+.0002,"Independent20percent canonical nerve-route grade");
				for t:float in [0,.5,1]:
					var p:Vector3=a.lerp(bv,t);var normal:=Vector2(-ab.y,ab.x).normalized()
					for side:float in [-edge.half_width,0,edge.half_width]:
						var q:=Vector2(p.x,p.z)+normal*side;var depth:float=b._get_height(q.x,q.y)-p.y;check(depth<=396.001,"Actual original Hive route remains in reserved local400m envelope");samples+=1
		var bundle:Dictionary=work.discover(cell);check(not bundle.has("error"),"Entire actual3x3Hive field fits existing bounded sparse compiler")
		if not bundle.has("error"):
			for room:Dictionary in region.pockets:
				check(work.field.sample(room.point+Vector3(0,.3,0))<0 and work.field.sample(room.point-Vector3(0,.3,0))>0,"Every organic lobe has real open air and original flat solid floor");var parent:Dictionary={}
				for node:Dictionary in region.nodes:
					if node.id==room.parent:parent=node;break
				for i in range(21):check(work.field.sample(parent.point.lerp(room.point,i/20.0)+Vector3(0,1,0))<0,"Full dry physical neck into each organ lobe")
			var key:Vector3i=work.field.cell(region.underground_hive_center+Vector3(0,3,0));var arrays:Array=work.build(key);check(not arrays.is_empty() and arrays[Mesh.ARRAY_VERTEX].size()>0,"Actual existing worker mesher emits Hive environment triangles/native-collision source");check(work.water_cell(key).arrays.is_empty(),"No automatic default limestone pools or props injected into Hive core")
		check(work.network.half_width==4 and work.network.headroom==8 and work.network.flat_radius==26 and work.network._active_context.is_empty(),"Organic dimensions never leak into unrelated generation")
	# Independently disabled Hive mode leaves other supported owners byte-exact.
	for family:int in [3,6]:
		var other=make_builder(family,73921);var old=Workload.new();var current=Workload.new();var off=Config.new();off.regional_activity=1;off.hive_networks=false;check(old.configure(other.settings,off,73921,0) and current.configure(other.settings,config,73921,0),"Independent unrelated pair configured");var key:=Vector2i(9,-3) if family==3 else Vector2i(7,-2);check(var_to_bytes(old.network.region(key))==var_to_bytes(current.network.region(key)),"Complete Spore/Insect region unchanged by Hive registration")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable Hive source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_hive_network.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"fixed_seed":73921,"fixed_region":str(cell),"nodes":region.nodes.size(),"edges":region.edges.size(),"core_lobes":lobes,"secondary_branches":branches,"independent_route_samples":samples,"scope":"Original fixed Alien seed73921/region(-31,-31),actual shared constrained graph/SDF/worker,real connected larger junctions/smaller branches/multi-lobed underground core,independent grade/local-depth and true air/floor/neck checks,full3x3sparse compile and emitted native-collision mesh source. Unrelated complete Spore/Insect region controls exact. New organic entry guard reserves existing surface conduits/junctions/finite galleries. Not native live breach return,GPU organic-material/art,all-world or phase completion."},"  "));print("CAVE_HIVE_NETWORK ",checks," nodes=",region.nodes.size()," lobes=",lobes," failures=",failures);quit(0 if failures.is_empty() else 1)
