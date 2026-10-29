extends "res://tools/biome_extensions/render_alien_memory_baseline.gd"
## Private compile-cost experiment: same active lanes, dynamically bounded loop.
func output_basename()->String:return "render_dynamic_extension_loop_candidate"
func prepare_shader()->void:
	hashes["res://tools/biome_extensions/render_dynamic_extension_loop_candidate.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/render_dynamic_extension_loop_candidate.gd")
	var shader:Shader=load("res://shaders/terrain_biomes.gdshader")
	var original:String="for(int i=0;i<8;i++){"
	assert(shader.code.count(original)==2)
	# The gathering loop initializes all weights to zero and only active bits
	# contribute. Beyond the highest set bit both loops are no-ops. Retaining
	# the uniform in the loop bound avoids assuming the driver unrolls cheaply.
	shader.code=shader.code.replace(original,"for(int i=0;((extension_active_mask & 255)>>i)!=0;i++){")
	private_shader_override=true
