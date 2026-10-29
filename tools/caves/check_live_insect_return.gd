extends "res://tools/caves/check_live_portal.gd"
const Workload=preload("res://scripts/caves/workload.gd")
func report_name()->String:return "check_cave_live_insect_return"
func fixture_family()->int:return 6
func fixture_cell()->Vector2i:return Vector2i(7,-2)
func fixture_name()->String:return "insect_colony"
func expected_core_nodes()->int:return 19
func capture_prefix()->String:return "cave_insect_live"
func render_motion()->bool:return false
func fixture_region(b)->Dictionary:
	var config=Config.new();config.regional_activity=1;var work=Workload.new();assert(work.configure(b.settings,config,73921,0));return work.network.region(fixture_cell())
func motion_scope()->String:return "Original fixed actual Insect seed73921/cell(7,-2),actual shared-colony graph and full main-scene surface structures/terrain/materials/collision/workers. Surface→real excavated entrance→first colony chamber→same surface,ordinary capsule,unchanged180s preload/420s motion/1.8m/.4m/5mps/45degree/.75mdrop gates. Main excavation10mwide/10mhigh,with6region-context guard enabled;old finite burrows remain intact. Fixed60Hz accelerated physics with explicit loading pauses and render-off motion;natural plus separately labelled temporary debug-light images. Not full Insect art,all-world/custom-settings or uninterrupted-performance acceptance."
