extends SceneTree
const Candidate=preload("res://tools/biome_extensions/conduit_shoulder_candidate.gd")
class Tissue:
	extends RefCounted
	var state:=PackedFloat64Array([0,0,.5,.2,1])
	func sample(_x:float,_z:float)->float:return 0
class PlanarSupport:
	extends RefCounted
	var gradient:=Vector2.ZERO
	var _extras:Array=[null,null,null,null,null,null,null,Tissue.new()]
	func _get_height(x:float,z:float)->float:return 100+gradient.dot(Vector2(x,z))
	func _sample_normal_height(x:float,z:float)->float:return _get_height(x,z)
var checks:int=0
func verify(ok:bool,label:String)->void:checks+=1;assert(ok,label)
func contacts(generator,builder)->Dictionary:
	var total:float=0;var maximum:float=0;var count:int=0;var surface_normal:=Vector3(-builder.gradient.x,1,-builder.gradient.y).normalized()
	for index in range(0,generator.vertices.size(),3):
		var a:Vector3=generator.vertices[index];var b:Vector3=generator.vertices[index+1];var c:Vector3=generator.vertices[index+2]
		if minf(a.x,minf(b.x,c.x))<32 or maxf(a.x,maxf(b.x,c.x))>992:continue # buried end caps,not lateral shoulders
		var distances:=PackedFloat64Array([a.y-builder._get_height(a.x,a.z),b.y-builder._get_height(b.x,b.z),c.y-builder._get_height(c.x,c.z)])
		if distances[0]>=0 and distances[1]>=0 and distances[2]>=0:continue
		if distances[0]<=0 and distances[1]<=0 and distances[2]<=0:continue
		var n:Vector3=(c-a).cross(b-a).normalized()
		if n.dot(surface_normal)<=0:continue
		var angle:float=rad_to_deg(acos(clampf(n.dot(surface_normal),-1,1)));total+=angle;maximum=maxf(maximum,angle);count+=1
	return {"triangles":count,"mean_angle_degrees":total/count if count>0 else null,"maximum_angle_degrees":maximum}
func _initialize()->void:
	var original:Script=load(Candidate.SOURCE);var candidate:GDScript=Candidate.script_for();var off:GDScript=Candidate.script_for(false);var records:Array=[]
	verify(off.source_code==FileAccess.get_file_as_string(Candidate.SOURCE),"Private disabled candidate keeps COMPLETE original source")
	for gradient:Vector2 in [Vector2.ZERO,Vector2(.1,0),Vector2(0,.2),Vector2(-.1,-.2)]:
		for width:float in [8.0,12.0,20.0,28.0]:
			for phase:float in [0.0,1.7,4.5]:
				var builder:=PlanarSupport.new();builder.gradient=gradient;var old=original.new();var current=candidate.new();var zero=off.new()
				for generator in [old,current,zero]:generator.conduit(builder,Vector2.ZERO,Vector2(1024,0),width,phase,Color(.34,.28,.26))
				verify(zero.vertices==old.vertices and zero.normals==old.normals and zero.colors==old.colors and zero.uvs==old.uvs,"False preserves complete original primitive arrays")
				verify(current.vertices.size()==old.vertices.size() and current.colors==old.colors and current.uvs==old.uvs,"Private shoulder changes no topology,semantic controls or colours")
				var changed:int=0
				for index in range(current.vertices.size()):
					var a:Vector3=old.vertices[index];var b:Vector3=current.vertices[index];verify(a.x==b.x and a.z==b.z,"Same original horizontal support and finite path")
					verify(b.y<=a.y+.0001,"Shoulder never raises original crest/roof or adds an obstruction")
					verify(current.normals[index].is_finite() and absf(current.normals[index].length()-1)<.0001,"Finite unit outward smoothed normal")
					if a!=b:changed+=1
				var before:Dictionary=contacts(old,builder);var after:Dictionary=contacts(current,builder)
				if width==8:verify(changed==0,"Small branch is exactly unchanged below conservative radius threshold")
				elif width>=20:verify(changed>0,"Negative control:the actual NEAR emitter must use the candidate,not only its far method")
				records.append({"gradient":str(gradient),"width":width,"phase":phase,"vertices":current.vertices.size(),"changed_vertices":changed,"original_contact":before,"candidate_contact":after})
	var guards:Dictionary={}
	for path:String in [Candidate.SOURCE,"res://scripts/biome_extension_structures.gd","res://scripts/alien_conduit_contact_lod.gd","res://tools/biome_extensions/conduit_shoulder_candidate.gd","res://tools/biome_extensions/check_conduit_shoulder_candidate.gd"]:guards[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_conduit_shoulder_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"source_sha256":guards,"checks":checks,"cases":records,"scope":"PRIVATE quartic-shoulder primitive geometry study.48 original/candidate/exact-off complete mesh triplets across actual production8/12/20/28m widths,three phases and flat/steadily tilted analytic supports. Same topology/semantic controls/horizontal support,never raises a vertex;small branches unchanged. Actual triangle-plane contact-angle distributions are REPORTED,not assumed improvements or artistic/physical-native acceptance. Buried end caps excluded only from lateral-contact angle statistics,not array/bounds checks. No production edits."},"  "));print("CONDUIT_SHOULDER_PRIVATE ",checks," checks / ",records.size()," triplets");quit()
