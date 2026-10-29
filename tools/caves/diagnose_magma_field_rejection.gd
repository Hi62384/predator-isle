extends "res://tools/caves/check_frozen_world_cohort.gd"
class TraceField extends "res://scripts/caves/portal_field.gd":
	var rejected:Array=[]
	func append_feature(a:Vector3,b:Vector3,size:Vector2,kind:int,style:int=0)->bool:
		var result:bool=super.append_feature(a,b,size,kind,style)
		if not result:
			var low:Vector3=a.min(b)-Vector3(size.x+FAR,FAR,size.x+FAR);var high:Vector3=a.max(b)+Vector3(size.x+FAR,size.y+FAR,size.x+FAR);var first:Vector3i=bin_cell(low);var last:Vector3i=bin_cell(high);rejected.append({"a":a,"b":b,"size":size,"kind":kind,"style":style,"bins":(last.x-first.x+1)*(last.y-first.y+1)*(last.z-first.z+1)})
		return result
func run()->void:
	var path:String="res://tools/biome_extensions/artifacts/check_cave_magma_scenic_index.json";var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));var rows:Array=[]
	for original:Dictionary in source.rows:
		if original.configured and original.compiled_positive:continue
		var builder=owner(original.host,int(original.seed));var work=Workload.new();assert(work.configure(builder.settings,Config.new(),int(original.seed),0));var region:Dictionary=work.network.region(Vector2i(original.site[0],original.site[1]));var field=TraceField.new();work.field=field
		var result:bool=work.use_bundle({"cell":region.id,"regions":[region],"connections":[]});var row:Dictionary={"ordinal":original.ordinal,"host":original.host,"seed":original.seed,"site":original.site,"compiled":result,"rejected":field.rejected};rows.append(row);print("MAGMA_FIELD_REJECTION ",row)
	FileAccess.open("res://tools/biome_extensions/artifacts/diagnose_magma_field_rejection.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"scope":"Trace subclass records the original real production append rejection without changing its bound or geometry. Fixed four cases from complete720case survey."},"  "));quit()
