extends "res://tools/biome_extensions/check_all.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const PrivateNetwork=preload("res://tools/caves/cave_network_candidate.gd")
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in ["res://tools/caves/check_colony_network.gd","res://tools/caves/cave_network_candidate.gd","res://scripts/insect_colony_sampler.gd","res://scripts/biome_extension_structures.gd","res://shaders/default_cave_rock.gdshader","res://shaders/cave_entry_rock.gdshaderinc"]:guards[path]=FileAccess.get_sha256(path)
	var b=make_builder(6,73921);var config=Config.new();config.regional_activity=1;var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Actual immutable colony workload configuration");var cell:=Vector2i(7,-2);var original=PrivateNetwork.new();original.configure(b._get_height,b.get_water_surface_height,73921);original.activity=1;var previous:Dictionary=original.region(cell);check(previous.valid and previous.nodes.size()==17,"Original fixed Insect geographic control retained before extension")
	var started:int=Time.get_ticks_usec();var data:Dictionary=work.network.region(cell);check(data.valid and data.get("cave_family",-1)==6 and data.geology==6,"Original fixed region produces real colony excavation graph,not only optional descriptors")
	check(work.network.half_width==4 and work.network.headroom==8 and work.network.flat_radius==26 and work.network._active_context.is_empty(),"Per-region excavation dimensions do not leak into neighboring Default or connection generation")
	var reached:Dictionary={};var samples:int=0;var branches:int=0;var maximum_depth:float=0
	if data.valid:
		reached[data.entrances[0]]=true
		for repeat_id in range(data.nodes.size()):
			for edge:Dictionary in data.edges:
				if reached.has(edge.from):reached[edge.to]=true
				if reached.has(edge.to):reached[edge.from]=true
		check(reached.size()==data.nodes.size(),"Every actual major/satellite excavation chamber has the same proven exit-rooted route")
		check(data.nodes.size()>=17 and data.get("major_excavation_chambers",0)>0 and data.get("satellite_passages",0)>0,"Positive enlarged excavation rooms and genuinely narrower satellite branches")
		check(data.underground_colony_center.is_finite() and data.underground_colony_center.y<b._get_height(data.underground_colony_center.x,data.underground_colony_center.z)-50,"Colony center is a real graph chamber below local land,not arbitrary worldY placeholder")
		for edge:Dictionary in data.edges:
			if edge.get("excavation_role","")=="secondary_passage":branches+=1;check(edge.half_width==4 and edge.headroom==8,"Actual secondary excavation dimensions preserve minimum route clearance")
			elif not edge.entrance:check(edge.half_width==5 and edge.headroom==10,"Actual wider main earth passages,not identical Default tunnel dimensions")
			var points:PackedVector3Array=edge.points
			for i in range(points.size()-1):
				var a:Vector3=points[i];var bv:Vector3=points[i+1];var delta:=Vector2(bv.x-a.x,bv.z-a.z);check(absf(bv.y-a.y)<=delta.length()*.2+.0002,"Packed excavated routes retain original20percent grade")
				for fraction:float in [0.0,.5,1.0]:
					var p:Vector3=a.lerp(bv,fraction);var side:=Vector2(-delta.y,delta.x).normalized()
					for lateral:float in [-edge.half_width,0,edge.half_width]:
						var q:=Vector2(p.x,p.z)+side*lateral;var depth:float=b._get_height(q.x,q.y)-p.y;maximum_depth=maxf(maximum_depth,depth);samples+=1;check(depth<=396.001,"Actual colony floor stays inside canonical400mdepth with original4m reserve")
						if not edge.entrance:check(depth-edge.headroom>=9.999,"Actual excavation has full promised height and real rock roof")
		check(maximum_depth>=300,"Original admitted colony still reaches genuinely deep connected levels")
		check(work._insect_guard.clear_access(data.edges[0]),"Whole exposed access path stays clear of complete mound complexes and old finite cavities")
		var bundle:Dictionary={"cell":cell,"regions":[data],"connections":[]};check(work.use_bundle(bundle),"Actual excavated graph and chambers compile into the shared field,not a second mesh engine")
		var point:Vector3=data.nodes[1].point+Vector3(0,2,0);check(work.field.sample(point)<0,"Colony interior contains real open shared3Dvolume");var key:Vector3i=work.field.cell(point);var arrays:Array=work.build(key);check(not arrays.is_empty(),"Real collidable/renderable colony worker mesh,not metadata-only adoption")
		var cold=Workload.new();check(cold.configure(b.settings,config,73921,0),"Independent cold colony worker");cold.network.region(cell+Vector2i.RIGHT);check(var_to_bytes(data)==var_to_bytes(cold.network.region(cell)),"Complete excavated graph independent of neighbor query order")
	var other=make_builder(3,73921);var zero=Config.new();zero.regional_activity=1;zero.chamber_variety=false;zero.geological_morphology=false;zero.seepage_density=0;zero.formation_density=0;var unrelated=Workload.new();check(unrelated.configure(other.settings,zero,73921,0),"Unrelated explicit zero-geology workload");var control=PrivateNetwork.new();control.configure(other._get_height,other.get_water_surface_height,73921);control.activity=1;check(var_to_bytes(unrelated.network.region(Vector2i(9,-3)))==var_to_bytes(control.region(Vector2i(9,-3))),"Complete original pure-Spore graph stays exactly unchanged under inactive colony context")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable colony integration source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_colony_network.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"fixed_original_region":str(cell),"seed":73921,"nodes":data.nodes.size(),"edges":data.edges.size(),"major_excavation_chambers":data.get("major_excavation_chambers",0),"satellite_passages":branches,"independent_samples":samples,"maximum_canonical_depth_m":maximum_depth,"single_order_seconds":(Time.get_ticks_usec()-started)/1000000.0,"scope":"Original fixed actual Insect seed73921region(7,-2) versus its admitted legacy core control. Same shared constrained network/implicit mesher,real wider earth passages,enlarged major rooms,narrower exit-rooted satellite branches,canonical roof/depth/grade samples,mound/finite-cavity-safe access,cold order independence,real worker mesh and whole unrelated pure-Spore zero-mode graph equality. Not yet native capsule/surface streaming/GPU art/full Insect completion."},"  "));print("CAVE_COLONY_NETWORK ",checks," nodes=",data.nodes.size()," edges=",data.edges.size()," major=",data.get("major_excavation_chambers",0)," satellites=",branches," failures=",failures);quit(0 if failures.is_empty() else 1)
