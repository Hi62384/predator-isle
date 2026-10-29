extends RefCounted
## One committed set of64m surface replacement columns drives BOTH the
## parent visual mask and exact native ground subtraction. No dark decals or
## collider-only holes. This helper does not commit an incomplete runtime cut.
const CELL:float=64
const MAX_MASK_SIDE:int=1024
const VertexProjection=preload("res://scripts/caves/vertex_projection.gd")
static var _shaders:Dictionary={}
static var _shader_ring:Array[String]=[]
static func mask(columns:Dictionary,center:Vector2,side:int=1024)->Dictionary:
	if not center.is_finite() or side<16 or side>MAX_MASK_SIDE:return {}
	for number:float in [center.x,center.y]:
		if absf(number)>2147480000.0*CELL:return {}
	var origin:=Vector2i(floori(center.x/CELL),floori(center.y/CELL))-Vector2i(side/2,side/2);var bytes:=PackedByteArray();bytes.resize(side*side);var admitted:Dictionary={}
	for key:Vector2i in columns:
		var local:Vector2i=key-origin
		if local.x<0 or local.y<0 or local.x>=side or local.y>=side:continue
		bytes[local.y*side+local.x]=255;admitted[key]=true
	return {"origin_cell":origin,"side":side,"r8_bytes":bytes,"columns":admitted}
static func shader(original:Shader,common_projection:bool=false)->Shader:
	if original==null:return null
	var source:String=original.code;var marker:String="void fragment() {"
	if source.count(marker)!=1 or not source.contains("varying vec3 forest_local_position;"):return null
	var digest:String=source.sha256_text()+("/shared_projection" if common_projection else "")
	if _shaders.has(digest):return _shaders[digest]
	var uniforms:String="\nuniform bool cave_cut_enabled=false;\nuniform sampler2D cave_cut_mask:filter_nearest,repeat_disable;\nuniform vec2 cave_cut_tile_offset=vec2(0);\n"
	var clipping:String='''
 if(cave_cut_enabled){
  ivec2 cut_cell=ivec2(floor(forest_local_position.xz/64.0+cave_cut_tile_offset));
  if(all(greaterThanEqual(cut_cell,ivec2(0)))&&all(lessThan(cut_cell,textureSize(cave_cut_mask,0)))&&texelFetch(cave_cut_mask,cut_cell,0).r>.5)discard;
 }
'''
	var code:String=source.replace(marker,uniforms+marker+clipping)
	if common_projection:code=VertexProjection.source(code)
	if code.is_empty():return null
	var result:=Shader.new();result.code=code
	if _shader_ring.size()>=8:_shaders.erase(_shader_ring.pop_front())
	_shader_ring.append(digest);_shaders[digest]=result;return result
static func append_polygon(output:PackedVector3Array,polygon:Array[Vector3])->void:
	for j in range(1,polygon.size()-1):
		if (polygon[j]-polygon[0]).cross(polygon[j+1]-polygon[0]).length_squared()>0:output.append_array(PackedVector3Array([polygon[0],polygon[j],polygon[j+1]]))
static func subtract(polygon:Array[Vector3],rect:Rect2)->Array:
	var remaining:Array[Vector3]=polygon;var outside:Array=[]
	for plane in range(4):
		if remaining.size()<3:break
		var axis:int=0 if plane<2 else 2;var boundary:float=[rect.position.x,rect.end.x,rect.position.y,rect.end.y][plane];var sign_value:float=1 if plane%2==0 else -1;var inner:Array[Vector3]=[];var outer:Array[Vector3]=[]
		for j in range(remaining.size()):
			var a:Vector3=remaining[j];var b:Vector3=remaining[(j+1)%remaining.size()];var da:float=(a[axis]-boundary)*sign_value;var db:float=(b[axis]-boundary)*sign_value
			if da>=0:inner.append(a)
			if da<=0:outer.append(a)
			if (da<0 and db>0) or (da>0 and db<0):
				var crossing:Vector3=a.lerp(b,da/(da-db));crossing[axis]=boundary;inner.append(crossing);outer.append(crossing)
		if outer.size()>=3:outside.append(outer)
		remaining=inner
	return outside
static func ground(faces:PackedVector3Array,world_origin:Vector3,columns:Dictionary)->Dictionary:
	var reject:Dictionary={"valid":false,"faces":faces}
	if not world_origin.is_finite() or faces.size()%3!=0:return reject
	if columns.is_empty():return {"valid":true,"faces":faces,"removed_source_triangles":0,"split_source_triangles":0}
	var output:=PackedVector3Array();var removed:int=0;var split:int=0
	for i in range(0,faces.size(),3):
		var triangle:Array[Vector3]=[faces[i],faces[i+1],faces[i+2]]
		if not triangle[0].is_finite() or not triangle[1].is_finite() or not triangle[2].is_finite():return reject
		var center:Vector3=(triangle[0]+triangle[1]+triangle[2])/3+world_origin;var minimum:Vector3=triangle[0].min(triangle[1]).min(triangle[2])+world_origin;var maximum:Vector3=triangle[0].max(triangle[1]).max(triangle[2])+world_origin
		for value:float in [minimum.x,minimum.z,maximum.x,maximum.z]:
			if absf(value)>2147480000.0*CELL:return reject
		var key:=Vector2i(floori(center.x/CELL),floori(center.z/CELL))
		# All standard near grids divide64m. Preserve their complete original
		# triangles byte-for-byte; only custom unaligned boundary triangles clip.
		if minimum.x>=key.x*CELL and maximum.x<=(key.x+1)*CELL and minimum.z>=key.y*CELL and maximum.z<=(key.y+1)*CELL:
			if columns.has(key):removed+=1
			else:output.append_array(PackedVector3Array(triangle))
			continue
		var first:=Vector2i(floori(minimum.x/CELL),floori(minimum.z/CELL));var last:=Vector2i(floori(maximum.x/CELL),floori(maximum.z/CELL))
		if int(last.x-first.x+1)*int(last.y-first.y+1)>4096:return reject
		var polygons:Array=[triangle];var touched:bool=false
		for z in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				if not columns.has(Vector2i(x,z)):continue
				touched=true;var rect:=Rect2(Vector2(x*CELL-world_origin.x,z*CELL-world_origin.z),Vector2.ONE*CELL);var next:Array=[]
				for polygon:Array[Vector3] in polygons:next.append_array(subtract(polygon,rect))
				polygons=next
		if touched:split+=1
		for polygon:Array[Vector3] in polygons:append_polygon(output,polygon)
	return {"valid":true,"faces":output,"removed_source_triangles":removed,"split_source_triangles":split}
