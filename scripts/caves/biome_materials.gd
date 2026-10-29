extends RefCounted
## One adapter per registered biome;no monolithic enum/conditional renderer.
const Blend=preload("res://scripts/caves/biome_blend.gd")
static var _shaders:Dictionary={}
static var _ring:Array[String]=[]
static func definition(registry:Resource,id:String)->Resource:
	if registry==null:return null
	for item:Resource in registry.definitions:
		if str(item.biome_id)==id:return item
	return null
static func shader(original:Shader,ids:Array,registry:Resource,entry:bool=false)->Shader:
	if ids.is_empty():return original
	var key:String=original.code.sha256_text()+"/"+str(ids)+"/"+str(entry)+"/independent_targets_v1/"+Blend.new().get_script().source_code.sha256_text()
	# Provider changes under the same stable biome ID must not reuse stale
	# generated code after a settings restart in the same editor process.
	for id in ids:
		var provider:Resource=definition(registry,str(id))
		if provider==null or provider.surface_provider==null:return null
		if ids.size()>1:
			var adapter=provider.surface_provider.new()
			if not adapter.has_method("supports_weighted_blend") or adapter.supports_weighted_blend()!=true:return null
		key+="/"+provider.surface_provider.source_code.sha256_text()
	if _shaders.has(key):return _shaders[key]
	var code:String=Blend.source(original.code,ids.size(),true)
	if code.is_empty():return null
	if ids.size()>1:code=code.insert(code.rfind("}"),Blend.begin(ids.size()))
	for slot in range(ids.size()):
		var item:Resource=definition(registry,str(ids[slot]))
		if item==null or item.surface_provider==null:return null
		if ids.size()>1:code=code.insert(code.rfind("}"),Blend.restore())
		code=item.surface_provider.new().source(code,slot,entry)
		if code.is_empty():return null
		if ids.size()>1:code=code.insert(code.rfind("}"),Blend.accumulate(slot))
	if ids.size()>1:code=code.insert(code.rfind("}"),Blend.finish())
	var result:=Shader.new();result.code=code
	if _ring.size()>=16:_shaders.erase(_ring.pop_front())
	_ring.append(key);_shaders[key]=result;return result
static func bind(material:ShaderMaterial,ids:Array,registry:Resource,context:Dictionary={})->void:
	for id in ids:
		var item:Resource=definition(registry,str(id))
		if item!=null and item.surface_provider!=null:
			var provider=item.surface_provider.new();provider.bind(material,item.material_configuration)
			if provider.has_method("bind_context"):provider.bind_context(material,context)
