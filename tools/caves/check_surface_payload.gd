extends "res://tools/biome_extensions/check_all.gd"
const Payload=preload("res://tools/caves/cave_surface_payload_candidate.gd")
const SurfaceShader=preload("res://tools/caves/cave_surface_shader_candidate.gd")
func pack(a:int,b:int,c:int)->float:return float(a+256*b+65536*c)
func fixture()->Array:
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.BACK,Vector3(1,0,1)]);arrays[Mesh.ARRAY_COLOR]=PackedColorArray();arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array();arrays[Mesh.ARRAY_TEX_UV2]=PackedVector2Array()
	for slot in range(Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM3+1):arrays[slot]=PackedFloat32Array()
	for i in range(4):
		arrays[Mesh.ARRAY_COLOR].append(Color(.123456+i*.1,.234567,.345678,.456789));arrays[Mesh.ARRAY_TEX_UV].append(Vector2(25+i,pack(14+i,42,127+i)));arrays[Mesh.ARRAY_TEX_UV2].append(Vector2(pack(3,7+i,11),pack(13,17,19+i)))
		arrays[Mesh.ARRAY_CUSTOM0].append_array(PackedFloat32Array([-pack(21+i,23,29)-1,pack(31,37,41+i),pack(43,47+i,53),-pack(59+i,61,67)-1]))
		arrays[Mesh.ARRAY_CUSTOM1].append_array(PackedFloat32Array([-pack(71+i,73,79)-1,pack(83,89,97+i),-pack(101,103+i,107)-1,(-pack(109,113,127+i)-1) if i%2==0 else pack(131,137,139+i)]))
		arrays[Mesh.ARRAY_CUSTOM2].append_array(PackedFloat32Array([-pack(149,151+i,157)-1,pack(163,167,173+i),pack(179,181+i,191),pack(193+i,197,199)]))
		arrays[Mesh.ARRAY_CUSTOM3].append_array(PackedFloat32Array([-pack(211,223,227+i)-1,pack(229+i,233,239),pack(241,251,253-i),pack(255-i,254,252)]))
	return arrays
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://tools/caves/check_surface_payload.gd","res://tools/caves/cave_surface_payload_candidate.gd","res://tools/caves/cave_surface_shader_candidate.gd","res://shaders/terrain_biomes.gdshader","res://shaders/terrain_control_decode.gdshaderinc"]:guards[path]=FileAccess.get_sha256(path)
	for n:int in [0,1,255,256,65535,8388607,8388609,16777215]:
		var d:Vector3=Payload.unpack24(n);check(roundi(d.x*255)+(roundi(d.y*255)<<8)+(roundi(d.z*255)<<16)==n,"Full float24 edge integers decode exactly,including odd integers above2^23")
	var arrays:Array=fixture();var decoded:Array=[]
	for i in range(4):
		var d:PackedFloat32Array=Payload.decode(arrays,i);decoded.append(d);check(d.size()==68,"Complete67component semantic record plus pad")
		check(absf(d[0]-float(21+i)/255)<.0000001 and absf(d[3]-float(59+i)/255)<.0000001,"Nested mountain geology and signed Jungle/Badlands wrapper decoded separately")
		check(absf(d[55]-float(127+i)/255)<.0000001 if i%2==0 else d[55]==0,"Beach wrapper does not numerically interpolate into coast packing")
		check(absf(d[62]-float(i)/254)<.0000001 and d[61]==25+i,"Badlands curvature and water remain distinct semantic scalars")
		for j in range(4):check(absf(d[63+j]-float(int(arrays[Mesh.ARRAY_COLOR][i][j]*255))/255)<.0000001,"Original native truncated RGBA8 upload represented exactly once")
	var maximum_error:float=0
	for z in range(33):
		for x in range(33):
			var point:=Vector2(x,z)/32;var selected:Dictionary=Payload.triangle(point,1,1);var d:PackedFloat32Array=Payload.interpolate(decoded,selected);check(d.size()==68,"Both original terrain triangle diagonals interpolate complete decoded attributes")
			for component in range(68):
				var expected:float=0
				for corner in range(3):expected+=float(decoded[selected.indices[corner]][component])*selected.weights[corner]
				maximum_error=maxf(maximum_error,absf(d[component]-expected));check(absf(d[component]-expected)<.00002,"Linear semantic interpolation,never byte-carry interpolation of packed integers")
	var data:Dictionary=Payload.atlas(decoded[0]);check(data.width==1024 and data.height==1 and data.bytes.size()==16384 and data.vertices==1,"Bounded explicit RGBAF atlas layout/padding")
	check(Payload.atlas(PackedFloat32Array()).is_empty() and Payload.triangle(Vector2.INF,1,1).is_empty() and Payload.triangle(Vector2(-.1,0),1,1).is_empty(),"Invalid empty/out-of-domain payload fails closed")
	var source:String=FileAccess.get_file_as_string("res://shaders/terrain_biomes.gdshader");var code:String=SurfaceShader.code(source);check(not code.is_empty() and code.count("VERTEX_ID*17")==1 and code.contains("UV.x=swamp_water_level"),"Alternate shader rewrites only recognized native decode path and preserves water UV")
	check(code.substr(code.find(SurfaceShader.END))==source.substr(source.find(SurfaceShader.END)),"Entire native fragment/material implementation untouched")
	check(SurfaceShader.code(source.replace(SurfaceShader.BEGIN,"\n changed;")).is_empty(),"Unknown shader layout fails closed,not a silent missing material")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable surface transport source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_surface_payload.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"maximum_scalar_interpolation_error":maximum_error,"production_registration":false,"scope":"PRIVATE CPU decoded-before-interpolation surface payload,67semantic floats/vertex in17RGBAF texels,16MiB per-atlas cap. All nested legacy wrappers,beach/coast mixed tags,float24limits,original RGBA8truncation,original terrain B-C diagonal and water/curvature. Native GPU/material/streaming correctness must be tested separately."},"  "));print("SURFACE_PAYLOAD ",checks," max_error=",maximum_error," failures=",failures);quit(0 if failures.is_empty() else 1)
