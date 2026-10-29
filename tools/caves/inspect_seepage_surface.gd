extends "res://tools/biome_extensions/check_all.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
func run()->void:
	var b=make_builder(3,73921);var config=Config.new();config.regional_activity=1;var work=Workload.new();assert(work.configure(b.settings,config,73921,0));var bundle:Dictionary=work.discover(Vector2i(9,-3))
	for region:Dictionary in bundle.regions:
		for pool:Dictionary in region.get("pools",[]):
			var data:Dictionary=work.water_cell(work.field.cell(Vector3(pool.center.x,pool.water_y,pool.center.z)));print("SEEPAGE_DIAGNOSTIC ",pool.id," style=",region.get("cross_section_style",0)," channel=",pool.has("stream_points")," water=",data.ids," errors=",data.rejection_reasons)
	quit()
