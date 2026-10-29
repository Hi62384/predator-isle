extends "res://tools/biome_extensions/check_conduit_shoulder_candidate.gd"
const GroundUnion=preload("res://tools/biome_extensions/conduit_ground_union_candidate.gd")
func _initialize()->void:
	var original:Script=load(GroundUnion.SOURCE);var candidate:GDScript=GroundUnion.script_for();var off:GDScript=GroundUnion.script_for(false);var records:Array=[]
	verify(off.source_code==FileAccess.get_file_as_string(GroundUnion.SOURCE),"Disabled candidate retains the COMPLETE original source")
	for gradient:Vector2 in [Vector2.ZERO,Vector2(.1,0),Vector2(0,.2),Vector2(-.1,-.2)]:
		for width:float in [8.0,12.0,20.0,28.0]:
			for phase:float in [0.0,1.7,4.5]:
				var builder:=PlanarSupport.new();builder.gradient=gradient;var old=original.new();var current=candidate.new();var zero=off.new()
				for generator in [old,current,zero]:generator.conduit(builder,Vector2.ZERO,Vector2(1024,0),width,phase,Color(.34,.28,.26))
				verify(zero.vertices==old.vertices and zero.normals==old.normals and zero.colors==old.colors and zero.uvs==old.uvs,"Independent false complete-array exact")
				verify(current.vertices.size()==old.vertices.size() and current.colors==old.colors and current.uvs==old.uvs,"No new vertices or changed semantic controls")
				var changed:int=0
				for index in range(current.vertices.size()):
					var a:Vector3=old.vertices[index];var b:Vector3=current.vertices[index];verify(a.x==b.x and a.z==b.z,"Original horizontal support exact")
					var t:float=b.x/1024;var radius:float=width*(.7+.2*sin(t*9+phase)+.1*sin(t*23-phase));var maximum:float=maxf(0,radius*.35-2)
					verify(b.y-builder._get_height(b.x,b.z)<=maximum+.001,"Actual support-relative roof never exceeds original crest")
					verify(current.normals[index].is_finite() and absf(current.normals[index].length()-1)<.0001,"Finite unit outward normals")
					if a!=b:changed+=1
				if width==8:verify(changed==0,"All small-branch arrays retain original geometry")
				elif width>=20:verify(changed>0,"Actual near geometry changes")
				records.append({"gradient":str(gradient),"width":width,"phase":phase,"vertices":current.vertices.size(),"changed_vertices":changed,"original_contact":contacts(old,builder),"candidate_contact":contacts(current,builder)})
	var protected_builder:=PlanarSupport.new();var old=original.new();var protected_candidate=candidate.new();protected_candidate._protected_sites=[{"position":Vector2(512,0),"half":96.0}];old._protected_sites=protected_candidate._protected_sites.duplicate(true)
	for generator in [old,protected_candidate]:generator.conduit(protected_builder,Vector2.ZERO,Vector2(1024,0),28,1.7,Color(.34,.28,.26))
	for index in range(old.vertices.size()):
		if absf(old.vertices[index].x-512)<280:verify(old.vertices[index]==protected_candidate.vertices[index],"Complete central protected approach receives no new shoulder displacement")
	var guards:Dictionary={}
	for path:String in [GroundUnion.SOURCE,GroundUnion.BASE,"res://scripts/alien_conduit_contact_lod.gd","res://tools/biome_extensions/conduit_shoulder_candidate.gd","res://tools/biome_extensions/conduit_ground_union_candidate.gd","res://tools/biome_extensions/check_conduit_shoulder_candidate.gd","res://tools/biome_extensions/check_conduit_ground_union_candidate.gd"]:guards[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_conduit_ground_union_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"source_sha256":guards,"checks":checks,"cases":records,"scope":"PRIVATE second shoulder study,actual ground at every profile vertex with tangent compact lips.48 complete planar support mesh triplets across production widths/phases/grades plus central protected approach. Exact independent-off arrays,unchanged XZ/topology/semantic controls/small branches,bounded original crest and no new displacement inside protection. Contact triangle angles reported without a universal quality claim. New vertices may rise relative to the old buried shoulder but never exceed the old support-relative crest. No production/native/collision/streaming acceptance."},"  "));print("CONDUIT_GROUND_UNION_PRIVATE ",checks);quit()
