extends "res://tools/biome_extensions/check_all.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const Field=preload("res://scripts/caves/field.gd")
const Basins=preload("res://scripts/caves/seepage_basins.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/workload.gd","res://scripts/caves/field.gd","res://scripts/caves/seepage_basins.gd","res://scripts/caves/seepage_surface.gd","res://scripts/caves/cave_settings.gd","res://tools/caves/check_water_cache.gd"]:guards[path]=FileAccess.get_sha256(path)
	var b=make_builder(3,73921);var config=Config.new();var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Real owned worker configured")
	var surface:Callable=func(_x:float,_z:float)->float:return 150
	var region:Dictionary={"id":Vector2i.ZERO,"valid":true,"geology":0,"nodes":[{"id":"cache-room","point":Vector3(32,20,32),"level":0,"chamber_radius":28.0,"chamber_height":20.0}],"edges":[]};region["pools"]=Basins.make(region,73921,1);work.field=Field.new();check(work.field.compile([region],surface) and not region.pools.is_empty(),"Actual positive carved retained pool fixture");work._regions=[region];work.bundle_key=Vector2i.ZERO
	var pool:Dictionary=region.pools[0];var key:Vector3i=work.field.cell(Vector3(pool.center.x,pool.water_y,pool.center.z));var original:Dictionary=work.water_cell(key);check(not original.arrays.is_empty() and work._water_cache.size()==1,"Genuine positive water arrays cached on worker")
	check(var_to_bytes(original)==var_to_bytes(Basins.water_cell([region],work.field,key)),"Cached complete payload equals independent uncached extraction exactly")
	for i in range(20):check(work.water_cell(Vector3i(100+i,0,100)).arrays.is_empty(),"Empty ordinary cell has no water")
	check(work._water_cache.size()==1,"Empty-cell traffic cannot evict positive water or fill cache")
	work._water_cache.clear()
	for i in range(8):work._water_cache[Vector3i(100+i,0,100)]=original
	check(var_to_bytes(work.water_cell(key))==var_to_bytes(original) and work._water_cache.size()==8,"Predeclared eight-entry pressure model evicts one old item,retains complete actual new payload")
	check(work.use_bundle({"cell":Vector2i(1,0),"regions":[],"connections":[]}) and work._water_cache.is_empty(),"New canonical regional bundle invalidates every old water entry")
	check(work.water_cell(key).arrays.is_empty(),"Different empty bundle cannot return stale previous-world water")
	work._water_cache[key]=original;check(work.configure(b.settings,config,17,0) and work._water_cache.is_empty(),"Worker reconfiguration clears cached source geometry before any new bundle")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable water reuse source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_water_cache.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capacity":8,"scope":"Actual positive worker water payload versus independent complete uncached extraction,20empty cells,eight-entry seeded pressure model,bundle/reconfigure invalidation. No measured performance gain or global resident-memory claim."},"  "));print("CAVE_WATER_CACHE ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
