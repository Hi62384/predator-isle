extends "res://tools/check_live_near_refinement.gd"
var held:GDScript
func intervention()->Dictionary:return {"private_candidate":true,"production_adoption":false,"change":"Grid-density ceiling removed; all actual emitted edge-overlap checks retained"}
func run()->void:
	held=load("res://scripts/terrain_ready_cut.gd")
	var source:String=held.source_code
	assert(source.count("\tif cs/fs>4:return {}\n")==1)
	held.source_code=source.replace("\tif cs/fs>4:return {}\n","")
	assert(held.reload()==OK)
	await super.run()
