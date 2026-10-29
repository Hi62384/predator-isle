extends SceneTree
const Variants=preload("res://scripts/terrain_shader_variants.gd")
var checks:int=0
func verify(ok:bool)->void:
	assert(ok);checks+=1
func _initialize()->void:
	var source:String=preload("res://shaders/terrain_biomes.gdshader").code
	var settings:=TerrainSettings.new()
	for mask in range(65536):
		for i in range(7):settings.set(Variants.LEGACY[i]+"_coverage",100 if (mask & (1<<i))!=0 else 0)
		settings.rocky_coast_enabled=(mask & 128)!=0;settings.beaches_enabled=false
		for i in range(8):settings.set(TerrainSettings.EXTENSION_KEYS[i]+"_coverage",100 if (mask & (1<<(i+8)))!=0 else 0)
		verify(Variants.configured_mask(settings)==mask)
	var masks:Array[int]=[0,65535,128,32768,32769,0x550f,0xaaf0]
	for i in range(16):masks.append(1<<i);masks.append(65535 ^ (1<<i))
	for mask:int in masks:
		var code:String=Variants.source_for(source,mask)
		verify((code==source)==(mask==65535))
		for i in range(8):
			for threshold:String in [".001",".999"]:
				verify(code.contains("if("+Variants.CONTROLS[i]+">"+threshold+")")==((mask & (1<<i))!=0))
		if mask!=65535:
			var first:int=-1;var last:int=-1
			for i in range(8):
				if (mask & (1<<(i+8)))!=0:
					if first<0:first=i
					last=i
			if first<0:verify(not code.contains("float w=extension_texel(i).x") and not code.contains("shade_extension(i,extension_control(i)"))
			else:verify(code.count("for(int i=%d;i<%d;i++){" % [first,last+1])==2)
	# Unknown future dispatch contracts and invalid masks are never transformed.
	for malformed:String in [source.replace("if(coast_control.x>.999)","if(coast_control.x>0.999)"),source.replace("for(int i=0;i<8;i++){","for(int i=0;i<9;i++){"),source+"for(int i=0;i<8;i++){}"]:
		verify(Variants.source_for(malformed,0)==malformed)
	verify(Variants.source_for(source,-1)==source);verify(Variants.source_for(source,65536)==source)
	var shader:Shader=preload("res://shaders/terrain_biomes.gdshader")
	verify(Variants.select(shader,settings,false)==shader)
	verify(Variants.select(shader,null)==shader)
	for owner:String in Variants.LEGACY+TerrainSettings.EXTENSION_KEYS:settings.set(owner+"_coverage",0)
	settings.rocky_coast_enabled=false;settings.beaches_enabled=true
	verify(Variants.configured_mask(settings)==128)
	verify(Variants.select(shader,settings)!=shader)
	settings.beaches_enabled=false
	settings.alien_infected=settings.alien_infected.duplicate()
	settings.alien_infected.overlay_strength=.5
	verify(Variants.configured_mask(settings)==32768)
	verify(Variants.select(shader,settings)!=shader)
	settings.alien_infected.overlay_strength=0
	for i in range(18):
		for j in range(8):settings.set(TerrainSettings.EXTENSION_KEYS[j]+"_coverage",100 if ((i+1) & (1<<j))!=0 else 0)
		var a:Shader=Variants.select(shader,settings);verify(a==Variants.select(shader,settings));verify(Variants._cache.size()<=8)
		verify((a!=shader)==Variants.supported(Variants.configured_mask(settings)))
	# Exercise the original nine extension/Grass domains and every one of the
	#256 newly admitted legacy/coastal subsets under the same eight-entry cap.
	for i in range(9):
		for j in range(8):settings.set(TerrainSettings.EXTENSION_KEYS[j]+"_coverage",100 if i==j else 0)
		verify(Variants.select(shader,settings)!=shader);verify(Variants._cache.size()<=8)
	verify(Variants._cache.size()==8)
	for mask in range(256):
		for j in range(8):settings.set(TerrainSettings.EXTENSION_KEYS[j]+"_coverage",0)
		for j in range(7):settings.set(Variants.LEGACY[j]+"_coverage",100 if (mask & (1<<j))!=0 else 0)
		settings.beaches_enabled=(mask & 128)!=0
		verify(Variants.supported(mask));verify(Variants.select(shader,settings)!=shader);verify(Variants._cache.size()<=8)
	# The same conservative dispatch now admits mixed configured owners.
	for mask:int in [257,32769,49346,35010,768]:verify(Variants.supported(mask))
	verify(not Variants.supported(65535))
	verify(not Variants.supported(-1) and not Variants.supported(65536))
	var historical_path:String="res://tools/biome_extensions/artifacts/revisions/experiment_terrain_shader_variant_adoption_e32e70a10df7/sources/scripts/terrain_shader_variants.gd.txt"
	var historical:=GDScript.new();historical.source_code=FileAccess.get_file_as_string(historical_path);verify(historical.reload()==OK)
	for mask:int in [0,256,512,1024,2048,4096,8192,16384,32768]+range(256):
		var expected:String=historical.source_for(source,mask)
		for index in range(Variants.LEGACY.size()):
			if (mask & (1<<index))==0:expected=expected.replace(".001<"+Variants.CONTROLS[index],"false")
		verify(Variants.source_for(source,mask)==expected)
	verify(shader.code==source)
	var report:Dictionary={"passed":true,"failures":[],"assertions":checks,"configured_domains":65536,"source_variants":masks.size(),"cache_capacity":8,"source_sha256":{}}
	for path:String in ["res://scripts/terrain_shader_variants.gd","res://scripts/chunk_terrain.gd","res://shaders/terrain_biomes.gdshader","res://tools/biome_extensions/check_terrain_shader_variants.gd"]:report.source_sha256[path]=FileAccess.get_sha256(path)
	report.source_sha256[historical_path]=FileAccess.get_sha256(historical_path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_terrain_shader_variants.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TERRAIN_SHADER_VARIANTS_PASS ",checks);quit()
