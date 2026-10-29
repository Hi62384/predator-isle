extends "res://tools/biome_extensions/check_all.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const Collision=preload("res://scripts/terrain_collision.gd")
func expanded(arrays:Array,indices:PackedInt32Array,slot:int)->PackedByteArray:
	if slot==Mesh.ARRAY_COLOR:
		var result:=PackedColorArray()
		for index:int in indices:result.append(arrays[slot][index])
		return result.to_byte_array()
	var result:=PackedVector3Array()
	for index:int in indices:result.append(arrays[slot][index])
	return result.to_byte_array()
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	guards["res://tools/caves/check_indexed_entry_extraction.gd"]=FileAccess.get_sha256("res://tools/caves/check_indexed_entry_extraction.gd");var records:Array=[]
	for fixture:Array in [[6,Vector2i(7,-2)],[3,Vector2i(9,-3)]]:
		var b=make_builder(fixture[0],73921);var config=Config.new();config.regional_activity=1;var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Original actual numeric worker configured");var bundle:Dictionary=work.discover(fixture[1]);var entrance:Dictionary={}
		for entry:Dictionary in bundle.entrances:
			if entry.region==fixture[1]:entrance=entry;break
		check(not entrance.is_empty(),"Original fixed entry retained without site reroll");var selected:=Vector2i(floori(entrance.point.x/64),floori(entrance.point.z/64));check(entrance.columns.has(selected),"Original aperture column inside full immutable mask");var parents:Array=[];var owners:Dictionary={}
		for column:Vector2i in entrance.columns:owners[Vector2i(floori(float(column.x)/4),floori(float(column.y)/4))]=true
		for owner:Vector2i in owners:
			var arrays:Array=b.build(owner,128);parents.append({"id":str(Vector3i(owner.x,owner.y,0)),"origin":Vector3(owner.x*256,0,owner.y*256),"span":256.0,"resolution":128,"arrays":arrays,"extension_normalization":true,"ground_faces":Collision.surface_faces(arrays,128)})
		work.configuration.indexed_entry_payload=false;var old:Dictionary=work.portal(bundle,entrance.columns,parents,{selected:true});work.configuration.indexed_entry_payload=true;var shared:Dictionary=work.portal(bundle,entrance.columns,parents,{selected:true});check(old.valid and shared.valid and old.cells.size()==shared.cells.size(),"Complete old/indexed actual aperture extraction succeeds");check(var_to_bytes(old.ground)==var_to_bytes(shared.ground),"Every original parent ground-subtraction byte unchanged");var corners:int=0;var unique:int=0;var old_bytes:int=0;var new_bytes:int=0
		for cell in range(old.cells.size()):
			var a:Dictionary=old.cells[cell];var c:Dictionary=shared.cells[cell];check(a.key==c.key and a.groups.keys()==c.groups.keys(),"Same ordered native cells/material owners");check(a.collision_faces.to_byte_array()==c.collision_faces.to_byte_array() and var_to_bytes(a.water)==var_to_bytes(c.water),"Every real native collision face and water record unchanged");
			for id:String in a.groups:
				var original:Dictionary=a.groups[id];var indexed:Dictionary=c.groups[id];var indices:PackedInt32Array=indexed.arrays[Mesh.ARRAY_INDEX];corners+=original.arrays[Mesh.ARRAY_VERTEX].size();unique+=indexed.arrays[Mesh.ARRAY_VERTEX].size()
				for slot:int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR]:check(expanded(indexed.arrays,indices,slot)==original.arrays[slot].to_byte_array(),"Full expanded actual vertex/normal/color bytes exact")
				if id!="__interior__":
					var values:PackedFloat32Array=indexed.atlas.bytes.to_float32_array();var expanded_values:=PackedFloat32Array()
					for index:int in indices:
						for component in range(68):expanded_values.append(values[index*68+component])
					check(expanded_values.to_byte_array()==original.payload.to_byte_array(),"Every actual material/depth semantic exact across original aperture");old_bytes+=original.atlas.bytes.size();new_bytes+=indexed.atlas.bytes.size()
		check(unique<corners*.5 and new_bytes<old_bytes*.5,"Positive actual aperture payload reduction,not only synthetic sharing");records.append({"family":fixture[0],"region":str(fixture[1]),"original_aperture_column":str(selected),"complete_mask_columns":entrance.columns.size(),"aperture_cells":old.cells.size(),"triangle_corners":corners,"unique_render_vertices":unique,"original_atlas_bytes":old_bytes,"indexed_atlas_bytes":new_bytes});print("INDEXED_ACTUAL_ENTRY ",records[-1]);await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable extraction source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_indexed_entry_extraction.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"records":records,"scope":"Two original fixed actual Insect/Spore aperture columns under complete original entry masks and full3x3connected fields. Actual worker legacy versus promoted indexed render transport,all cell/group expanded vertex/normal/color/68float semantic bytes,unchanged collision/water and complete original-parent ground cut. Aperture columns,not full entire-entry live streaming or process-memory evidence."},"  "));print("CAVE_INDEXED_ENTRY_EXTRACTION ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
