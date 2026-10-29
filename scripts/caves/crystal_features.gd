extends RefCounted
## Worker-only measured mineral growth in the SAME cave volume. Logical roots,
## family/patch identity and far silhouettes never depend on camera/load order.
const Shapes=preload("res://scripts/caves/formations.gd")
const Geometry=preload("res://scripts/caves/crystal_geometry.gd")
const Regions=preload("res://scripts/caves/biome_regions.gd")
const Profiles=preload("res://scripts/caves/chamber_profiles.gd")
const ConnectedProfiles=preload("res://scripts/caves/crystal_profiles.gd")
const VeinExposure=preload("res://scripts/caves/crystal_vein_exposure.gd")
const Corridors=preload("res://scripts/caves/crystal_corridor_features.gd")
const LakeChambers=preload("res://scripts/caves/crystal_lake_chambers.gd")
const Luminous=preload("res://scripts/caves/crystal_luminous.gd")
const Shallow=preload("res://scripts/caves/crystal_shallow.gd")
const MAX_FORMS:int=160
const MAX_VERTICES:int=60000
## Added AFTER the original160 crystal/vein forms,never instead of a major.
## These shallow,noncolliding attached wall mantles share an existing batch.
const MAX_LINING_PATCHES:int=32
var shapes=Shapes.new()
var geometry=Geometry.new()
var batches:Dictionary={}
var placements:Array=[]
var key:Vector3i
var origin:Vector3
var settings:Dictionary={}
var rejections:Dictionary={}
var _seed_id:int=0
var _lining_candidates:Array=[]
var _debris_candidates:Array=[]
func lining_patch(field,patch:Dictionary)->bool:
	var root:Vector3=patch.root;var normal:Vector3=patch.normal;var tangent:Vector3=Vector3.UP.cross(normal).normalized();var across:Vector3=tangent.cross(normal).normalized();var radius:float=1.4+Regions.random(patch.id,_seed_id,"lining/radius")*.9;var front:Array[Vector3]=[];var rear:Array[Vector3]=[];var attachments:=PackedVector3Array();var low:=Vector3.INF;var high:Vector3=-Vector3.INF
	var facets:int=8;var stretch:float=.55+.3*Regions.random(patch.id,_seed_id,"lining/aspect")
	for index in range(facets):
		var angle:float=TAU*index/facets+patch.phase;var distance:float=radius*(.4+.6*Regions.random(patch.id,_seed_id,"lining/rim/"+str(index)));var p:Vector3=root+(tangent*cos(angle)+across*sin(angle)*stretch)*distance;var a:Vector3=p-normal*4;var b:Vector3=p+normal*4
		if field.sample(a)<.15 or field.sample(b)>-.15:return reject("lining_surface_bracket")
		var contact:Vector3=shapes.boundary(field,a,b)
		if not owns_wall(field,patch.room,contact):return reject("lining_foreign_wall")
		var foot:Vector3=contact-normal*1.25;var face:Vector3=contact+normal*(.04+.08*Regions.random(patch.id,_seed_id,"lining/facet/"+str(index)))
		if field.sample(foot)<.15 or field.sample(face)>-.015:return reject("lining_whole_foot")
		front.append(face);rear.append(foot);attachments.append(foot);low=low.min(face).min(foot);high=high.max(face).max(foot)
	var cap:Vector3=root+normal*.24;var back:Vector3=root-normal*1.25;attachments.append(back);low=low.min(cap).min(back);high=high.max(cap).max(back)
	if field.sample(back)<.15 or field.sample(cap)>-.04:return reject("lining_center_attachment")
	var bounds:=AABB(low,high-low)
	if shapes.protected(field,bounds.get_center(),Vector2(bounds.size.x,bounds.size.z).length()*.5,low.y,high.y):return reject("lining_protected_route")
	var emitter=Geometry.Shared.new();emitter.origin=origin;emitter._skip_degenerate=true;var midpoint:Vector3=(cap+back)*.5
	for index in range(facets):
		var next:int=(index+1)%facets;geometry.quad(emitter,cap,front[index],front[next],cap,midpoint);geometry.quad(emitter,back,rear[next],rear[index],back,midpoint);geometry.quad(emitter,front[index],rear[index],rear[next],front[next],midpoint)
	var target:Dictionary=bucket("mineral_opaque");var first:int=target.vertices.size();var tint:Color=Geometry.tint(patch.family,patch.age).lerp(Color(.32,.30,.26),.4);tint.a=patch.age
	if first+emitter.vertices.size()>MAX_VERTICES:return reject("lining_vertex_budget")
	for index in range(emitter.vertices.size()):
		target.vertices.append(emitter.vertices[index]);target.normals.append(emitter.normals[index]);target.colors.append(tint);target.uvs.append(Vector2(patch.family+.08,.3));target.growth_uvs.append(Vector2((emitter.vertices[index]+origin-root).dot(normal),patch.phase));target.middle.append(first+index);target.far.append(first+index)
	placements.append({"id":patch.id,"kind":"crystal_lining","owner":key,"root":root,"axis":normal,"height":.24,"width":radius,"family":patch.family,"broken":false,"age":patch.age,"importance":0,"thin_transmission":false,"collider":false,"attachments":attachments,"bounds":bounds,"raw_weight":weight(field,root+normal*.3),"batch":"mineral_opaque","first_vertex":first,"vertex_count":emitter.vertices.size(),"host_room":str(patch.room.id)});return true
func reject(reason:String)->bool:rejections[reason]=int(rejections.get(reason,0))+1;return false
func decorate_region(region:Dictionary,height:Callable,seed_id:int,configuration:Dictionary,maximum_depth:float,minimum_roof:float)->Dictionary:
	if not configuration.get("chamber_growth",true) or not region.get("valid",false) or region.get("cave_family",-1) in [6,7]:return region
	var result:Dictionary=region;var changed:bool=false
	for table:String in ["nodes","pockets"]:
		var rooms:Array=region.get(table,[]).duplicate()
		for index in range(rooms.size()):
			var node:Dictionary=rooms[index]
			if int(node.get("level",-1))<0:continue
			var assignment:Dictionary=Regions.along_edge(region.get("cave_biome_regions",{}),str(node.id),str(node.id),0,0)
			if float(assignment.weights.get("crystal",0))<.7:continue
			var identity:String=str(assignment.candidate_ids.get("crystal",str(node.id)));var layout:int=mini(5,int(Regions.random(identity,seed_id,"crystal/layout")*6))
			var radius:float=maxf(node.chamber_radius,22+Regions.random(str(node.id),seed_id,"crystal/radius")*6);var headroom:float=maxf(node.chamber_height,28+Regions.random(str(node.id),seed_id,"crystal/vault")*20)
			if not Profiles.compatible(node.point,radius,headroom,region,region.get("pockets",[])):continue
			var admitted:bool=true
			for z in range(-2,3):
				for x in range(-2,3):
					if Vector2(x,z).length()>2.1:continue
					var surface:float=height.call(node.point.x+x*radius*.5,node.point.z+z*radius*.5)
					if not is_finite(surface) or surface-node.point.y>maximum_depth-4 or surface-node.point.y<headroom+minimum_roof+4:admitted=false
			if not admitted:continue
			var grown:Dictionary=node.duplicate();grown["chamber_radius"]=radius;grown["chamber_height"]=headroom;grown["cross_section_style"]=0 if layout in [0,3,4] else (1 if layout in [1,2] else 3);grown["crystal_layout"]=layout;grown["crystal_region"]=identity;rooms[index]=grown
			if not changed:result=region.duplicate();changed=true
		if changed:result[table]=rooms
	# The optional dedicated lake profile owns enlargement when selected.
	# Its OFF mode keeps the complete previous existing-host lake policy.
	var connected_configuration:Dictionary=configuration
	if configuration.get("lake_chambers",false):connected_configuration=configuration.duplicate();connected_configuration.large_lake_frequency=0.0
	var with_profiles:Dictionary=LakeChambers.prepare(ConnectedProfiles.decorate(result,height,seed_id,connected_configuration,maximum_depth,minimum_roof),height,seed_id,configuration,maximum_depth,minimum_roof)
	var final:Dictionary=Shallow.prepare(with_profiles,height,configuration.get("shallow_chambers",false),maximum_depth,minimum_roof)
	if configuration.get("floor_ridges",false) and (changed or final!=region):
		final=final.duplicate();final["cave_floor_relief"]=final.get("cave_floor_relief",{}).duplicate();final.cave_floor_relief["crystal"]=float(configuration.get("floor_ridge_height",.65))
	return final
func weight(field,p:Vector3)->float:return field.biome_weights_at(p,["crystal"]).x
func boundary(field,start:Vector3,direction:Vector3,reach:float)->Vector3:
	if field.sample(start)>=-.01:return Vector3.INF
	var previous:Vector3=start
	for station in range(1,ceili(reach)+1):
		var next:Vector3=start+direction*station
		if field.sample(next)>=0:return shapes.boundary(field,previous,next)
		previous=next
	return Vector3.INF
func bucket(kind:String)->Dictionary:
	if not batches.has(kind):batches[kind]={"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"colors":PackedColorArray(),"uvs":PackedVector2Array(),"growth_uvs":PackedVector2Array(),"middle":PackedInt32Array(),"far":PackedInt32Array(),"collision_faces":PackedVector3Array()}
	return batches[kind]
func spanning_form(field,root:Vector3,axis:Vector3,width:float,maximum:float,family:int,age:float,identity:String,phase:float)->bool:
	if family>3 or weight(field,root+axis*.6)<.8:return false
	var opposite:Vector3=boundary(field,root+axis*2,axis,maximum-2)
	if not opposite.is_finite():return false
	var length:float=root.distance_to(opposite)
	if length<8 or length>maximum or weight(field,opposite-axis*.6)<.8:return false
	return form(field,root,axis,width,length,family,true,age,identity,0,false,phase,true)
func form(field,root:Vector3,axis:Vector3,width:float,height:float,family:int,broken:bool,age:float,identity:String,importance:int,selective:bool,phase:float,spanning:bool=false,loose:bool=false)->bool:
	if placements.size()>=MAX_FORMS or not root.is_finite() or field.cell(root)!=key or height<.35 or width<.10:return reject("bounds_or_size")
	var amount:float=weight(field,root+axis*.6)
	if amount<.3:return reject("transition_weight")
	# A transition reduces the complete habit uniformly. Shrinking only its
	# height turns cubic fluorite into plates and distorts calcite cleavage.
	var growth:float=1.0 if spanning else smoothstep(.15,.8,amount);height*=growth;width*=growth
	if height<.35 or width<.10:return reject("transition_size")
	var tangent:Vector3=Vector3.UP.cross(axis).normalized() if absf(axis.y)<.9 else Vector3.RIGHT.cross(axis).normalized();tangent=tangent.rotated(axis,phase);var across:Vector3=tangent.cross(axis).normalized();var basis:=Basis(tangent,axis,across)
	# Right-handed basis preserves the original prism's clockwise orientation.
	if basis.determinant()<0:across=-across;basis=Basis(tangent,axis,across)
	var prototype:Array=geometry.prototype(family,broken);var points:PackedVector3Array=prototype[Mesh.ARRAY_VERTEX];var vertices:=PackedVector3Array();var contacts:Dictionary={};var end_contacts:Dictionary={};var low:=Vector3.INF;var high:Vector3=-Vector3.INF
	for q:Vector3 in points:
		var p:Vector3=root+basis*Vector3(q.x*width,q.y*height,q.z*width)
		if loose and q.y>.001 and field.sample(p)>-.04:
			# Fractured short clasts rest partly embedded on the actual floor.
			# Preserve their buried base;fit exposed facets above local support.
			var up:Vector3=field.normal(root);var low_point:Vector3=p-up*(1.5+width);var high_point:Vector3=p+up*2
			if field.sample(low_point)<0 or field.sample(high_point)>=0:return reject("debris_floor_bracket")
			p=shapes.boundary(field,low_point,high_point)+up*(.04+q.y*height*.25)
		if q.y<.001:
			var local_key:=Vector2(q.x,q.z)
			if not contacts.has(local_key):
				var margin:float=2.0+width;var back:Vector3=p-axis*margin;var front:Vector3=p+axis*margin
				if field.sample(back)<0 or field.sample(front)>=0:return reject("whole_foot_bracket")
				var foot:Vector3=shapes.boundary(field,back,front)-axis*1.25
				if field.sample(foot)<.15:return reject("whole_foot_burial")
				contacts[local_key]=foot
			p=contacts[local_key]
		elif spanning and q.y>.999:
			var local_key:=Vector2(q.x,q.z)
			if not end_contacts.has(local_key):
				var margin:float=2.0+width;var air:Vector3=p-axis*margin;var rock:Vector3=p+axis*margin
				if field.sample(air)>=0 or field.sample(rock)<0:return reject("span_far_foot_bracket")
				var foot:Vector3=shapes.boundary(field,rock,air)+axis*1.25
				if field.sample(foot)<.15:return reject("span_far_foot_burial")
				end_contacts[local_key]=foot
			p=end_contacts[local_key]
		elif field.sample(p)>(-.015 if loose else -minf(1.05,height*.2)):return reject("airspace_or_roof")
		vertices.append(p);low=low.min(p);high=high.max(p)
	var center:Vector3=(low+high)*.5;var horizontal:float=Vector2(high.x-low.x,high.z-low.z).length()*.5
	if shapes.protected(field,center,horizontal,low.y,high.y):return reject("protected_route")
	for i in range(0,vertices.size(),3):
		if (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).length_squared()==0:return reject("collapsed_facet")
	# Large faces may have clear corners but cross rock along a long edge.
	for i in range(0,vertices.size(),3):
		for pair:Vector2i in [Vector2i(0,1),Vector2i(1,2),Vector2i(2,0)]:
			var a:Vector3=vertices[i+pair.x];var b:Vector3=vertices[i+pair.y]
			if spanning:
				# Both caps are intentionally buried. Every exposed long edge is
				# sampled,including edges with an attached endpoint.
				var intervals:int=ceili(a.distance_to(b)/.5)
				for station in range(1,intervals):
					var p:Vector3=a.lerp(b,float(station)/intervals);var along:float=(p-root).dot(axis)
					if along>2.0+width and along<height-2.0-width and field.sample(p)>-.15:return reject("span_body_airspace")
				continue
			if points[i+pair.x].y<.001 or points[i+pair.y].y<.001:continue
			for station in range(1,ceili(a.distance_to(b)/2)):
				if field.sample(a.lerp(b,float(station)/ceili(a.distance_to(b)/2)))>(-.015 if loose else -.5):return reject("face_edge_airspace")
	var thin:bool=width<.45 and height<4 and family in [0,2,4];var small_fluorite:bool=family==4 and width<1.5 and height<3
	# Thin geometry is eligibility,not automatic transparency. Keep most
	# lining minerals opaque;choose a stable minority for near-only optics.
	var clear:bool=selective and settings.get("selective_transmission",true) and (thin or small_fluorite) and Regions.random(identity,_seed_id,"crystal/selective_near_transmission")<.25;var kind:String="mineral_clear" if clear else ("mineral_grains" if height<1.2 else "mineral_opaque");var target:Dictionary=bucket(kind);var first:int=target.vertices.size();var tint:Color=Geometry.tint(family,age);tint.a=age
	if first+vertices.size()>MAX_VERTICES:return reject("vertex_budget")
	var physical_thickness:float=width*(.28 if family==2 else (sqrt(2) if family==4 else 2.0))
	for i in range(0,vertices.size(),3):
		var normal:Vector3=(vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
		for j in range(3):target.vertices.append(vertices[i+j]-origin);target.normals.append(normal);target.colors.append(tint);target.uvs.append(Vector2(family+clampf(points[i+j].y,0,1)*.25,physical_thickness));target.growth_uvs.append(Vector2(points[i+j].y*height,phase))
	var collider:bool=(height>=1.5 and width>=.35) or (family in [4,5] and height>=.75 and width>=.3)
	for i in range(first,target.vertices.size()):
		if importance==0 or height>=2:target.middle.append(i)
		if importance==0 or height>=5:target.far.append(i)
		if collider:target.collision_faces.append(target.vertices[i])
	# Never remove isolated vertices from a triangle. Keep complete forms in
	# each index level;minor grains disappear as units,not arbitrary triangles.
	var placement:Dictionary={"id":identity,"kind":"crystal","owner":key,"root":root,"axis":axis,"height":height,"width":width,"family":family,"broken":broken,"age":age,"importance":importance,"thin_transmission":clear,"collider":collider,"attachments":PackedVector3Array(contacts.values()),"bounds":AABB(low,high-low),"raw_weight":amount,"batch":kind,"first_vertex":first,"vertex_count":vertices.size()}
	if spanning:
		placement["spanning"]=true;placement["far_attachments"]=PackedVector3Array(end_contacts.values());placement.attachments.append_array(placement.far_attachments)
	placements.append(placement);return true
func clusters(field,room:Dictionary,identity:String,seed_id:int,density:float)->void:
	var family:int=mini(5,int(Regions.random(identity,seed_id,"crystal/mineral")*6));var layout:int=int(room.get("crystal_layout",mini(5,int(Regions.random(identity,seed_id,"crystal/layout")*6))));var geode:bool=room.get("crystal_profile","")=="geode";var lined:bool=geode and settings.get("geode_lining",true);var phase:float=Regions.random(str(room.id),seed_id,"crystal/phase")*TAU;var patches:int=192 if lined else (48 if geode else (24 if layout in [0,3] else (14 if layout==2 else 7)))
	for patch in range(patches):
		var patch_id:String=str(room.id)+"/patch/"+str(patch);var chance:float=Regions.random(patch_id,seed_id,"admit")
		if chance>density:continue
		var angle:float=phase+patch*TAU/patches;var radial:=Vector3(cos(angle),0,sin(angle));var root:Vector3;var start:Vector3
		var floor_form:bool=patch%8==0 if geode else patch%3!=0;var ceiling_form:bool=patch%8==1 if geode else patch%7==0
		if floor_form:
			start=room.point+radial*room.chamber_radius*(.52+Regions.random(patch_id,seed_id,"inset")*.23)+Vector3.UP*3
			root=boundary(field,start,Vector3.DOWN,8)
		elif ceiling_form:root=boundary(field,room.point+radial*room.chamber_radius*.45+Vector3.UP*3,Vector3.UP,room.chamber_height+4)
		else:root=boundary(field,room.point+Vector3.UP*room.chamber_height*((.15 if geode else .2)+(.65 if geode else .35)*Regions.random(patch_id,seed_id,"wall_height")),radial,room.chamber_radius+12)
		if not root.is_finite() or field.cell(root)!=key:continue
		var normal:Vector3=field.normal(root);var tangent:Vector3=Vector3.UP.cross(normal).normalized() if absf(normal.y)<.9 else Vector3.RIGHT.cross(normal).normalized();var axis:Vector3=(normal+tangent*(Regions.random(patch_id,seed_id,"tilt")-.5)*.8).normalized()
		if lined and not floor_form and not ceiling_form and absf(normal.y)<.7 and owns_wall(field,room,root):_lining_candidates.append({"id":patch_id+"/lining","room":room,"root":root,"normal":normal,"family":family,"age":Regions.random(identity,seed_id,"crystal/weather")*.7,"phase":phase,"priority":Regions.random(patch_id,seed_id,"lining/priority")})
		var giant:bool=Regions.random(patch_id,seed_id,"giant")<float(settings.get("giant_chance",.18))*(.35 if geode else 1.0);var maximum:float=float(settings.get("maximum_height",32));var height_fraction:float=Regions.random(patch_id,seed_id,"height")
		var size:float=lerpf(minf(8,maximum),maximum,pow(height_fraction,.65)) if giant else lerpf(2,8,height_fraction)
		if family==4:size=lerpf(3,minf(8,maximum),height_fraction) if giant else lerpf(.6,3,height_fraction)
		elif family==5:size=lerpf(3,minf(9,maximum),height_fraction) if giant else lerpf(.7,3.6,height_fraction)
		if geode and not giant and family not in [4,5]:size=lerpf(.7,4,height_fraction)
		size=minf(minf(size,maximum),room.chamber_height*.72)
		var width_fraction:float=Regions.random(patch_id,seed_id,"width");var width:float=size*(.055 if family==2 else .10)*lerpf(.7,1.3,width_fraction)
		# Fluorite's diamond-plan unit cube has edge sqrt(2)*width. Calcite
		# keeps a broad skewed cleavage block,not a stretched quartz prism.
		if family==4:width=size/sqrt(2)*lerpf(.9,1.1,width_fraction)
		elif family==5:width=size*.55*lerpf(.8,1.2,width_fraction)
		var age:float=Regions.random(identity,seed_id,"crystal/weather")*.7;var broken:bool=Regions.random(patch_id,seed_id,"broken")<.16
		if floor_form and family<4 and normal.y>.75 and _debris_candidates.size()<32 and settings.get("crystal_debris",false) and Regions.random(patch_id,seed_id,"debris/admit")<float(settings.get("debris_chance",.35)):
			var start_point:Vector3=root+normal*2+tangent*(Regions.random(patch_id,seed_id,"debris/offset")-.5)*3;var debris_root:Vector3=boundary(field,start_point,-normal,6)
			if debris_root.is_finite() and field.cell(debris_root)==key:_debris_candidates.append({"id":patch_id+"/debris","root":debris_root,"axis":(normal*.45+tangent*(.85 if patch%2==0 else -.85)).normalized(),"width":.16+.16*Regions.random(patch_id,seed_id,"debris/width"),"height":.35+.5*Regions.random(patch_id,seed_id,"debris/height"),"family":family,"age":maxf(age,.65),"phase":phase,"priority":Regions.random(patch_id,seed_id,"debris/priority")})
		var selected_clear:bool=family==4 and Regions.random(patch_id,seed_id,"clear_cleavage")<.25
		var joined:bool=false
		if giant and family<4 and settings.get("spanning_crystals",false) and Regions.random(patch_id,seed_id,"spanning")<float(settings.get("spanning_chance",.15)):
			joined=spanning_form(field,root,axis,width,maximum,family,age,patch_id+"/primary",phase)
		if not joined:form(field,root,axis,width,size,family,broken,age,patch_id+"/primary",0,selected_clear,phase)
		# Shared mineral bed/primary-secondary axes. Secondary species are limited
		# to compatible silica;the dominant family is region-coherent,not rainbow.
		var secondary_count:int=3 if geode else (8 if layout in [0,3] else (5 if layout==2 else 2))
		for secondary in range(secondary_count):
			var child_id:String=patch_id+"/secondary/"+str(secondary);var fan:float=(secondary-float(secondary_count-1)*.5);var spread:float=fan*.6;var child_start:Vector3=root+normal*2+tangent*spread;var child_root:Vector3=boundary(field,child_start,-normal,6)
			if not child_root.is_finite():continue
			var child_axis:Vector3=(normal+tangent*fan*.25).normalized();var child_size:float=minf(maximum,lerpf(.45,1.8 if family==4 else (2.2 if family==5 else 3.8),Regions.random(child_id,seed_id,"height")));var child_family:int=family
			if family in [0,1,3] and Regions.random(child_id,seed_id,"secondary_mineral")<.1:child_family=0
			var child_width:float=child_size*(.09 if family==2 else .16)
			if child_family==4:child_width=child_size/sqrt(2)
			elif child_family==5:child_width=child_size*.55
			form(field,child_root,child_axis,child_width,child_size,child_family,Regions.random(child_id,seed_id,"broken")<.22,age,child_id,1,true,phase+.2*secondary)
func owns_wall(field,room:Dictionary,point:Vector3)->bool:
	# A boundary of the UNION may belong to a neighboring chamber. Painting
	# every room's fracture there stacks unrelated bands on the same wall.
	for feature:int in field.bins.get(field.bin_cell(point),PackedInt32Array()):
		if field.kinds[feature]==2 and field.begins[feature]==room.point and absf(field.evaluate(point,PackedInt32Array([feature])))<=.2:return true
	return false
func vein_contact(field,room:Dictionary,angle:float,band:int,offset:float)->Vector3:
	var radial:=Vector3(cos(angle),0,sin(angle));var p:Vector3=room.point+radial*room.chamber_radius
	# Same periodic physical fracture as the host shader,not a line restarted
	# at each cell/room. Reconcile the curved measured wall and seam height.
	for iteration in range(3):
		var y:float=(band*PI-.3*sin(p.x*TAU/96)-.25*sin(p.z*TAU/120))*12/TAU+offset
		p=boundary(field,Vector3(room.point.x,y,room.point.z),radial,room.chamber_radius+12)
		if not p.is_finite():return Vector3.INF
	return p if owns_wall(field,room,p) else Vector3.INF
func veins(field,room:Dictionary,identity:String,seed_id:int,density:float)->void:
	if Regions.random(str(room.id),seed_id,"crystal/vein_admit")>density:return
	var band:int=roundi((room.point.y+room.chamber_height*.4)/6);var family:int=mini(5,int(Regions.random(identity,seed_id,"crystal/mineral")*6));var age:float=Regions.random(identity,seed_id,"crystal/weather")*.7;var tint:Color=Geometry.tint(family,age);tint.a=age
	for segment in range(32):
		if placements.size()>=MAX_FORMS:break
		var a:float=segment*TAU/32;var b:float=(segment+1)*TAU/32;var width_a:float=.12+.3*pow(.5+.5*sin(a*7+room.point.x*.03),2);var width_b:float=.12+.3*pow(.5+.5*sin(b*7+room.point.x*.03),2)
		# Finite branching mineral beds follow one global fracture but do not
		# form uniform plaster trim around every chamber. Omitted stretches
		# remain visible in the continuous subtle host-rock joint material.
		if .5+.5*sin((a+b)*1.5+room.point.z*.02)<.28:continue
		var directions:Array[Vector3]=[Vector3(cos(a),0,sin(a)),Vector3(cos(b),0,sin(b))];var contacts:Array[Vector3]=[vein_contact(field,room,a,band,-width_a),vein_contact(field,room,b,band,-width_b),vein_contact(field,room,b,band,width_b),vein_contact(field,room,a,band,width_a)];var valid:bool=true
		for contact:Vector3 in contacts:
			if not contact.is_finite():valid=false;break
		if not valid:continue
		var center:Vector3=(contacts[0]+contacts[1]+contacts[2]+contacts[3])*.25
		if settings.get("localized_veins",true) and VeinExposure.amount(center)<.2:continue
		if field.cell(center)!=key or weight(field,center-directions[0]*.5)<.4:continue
		var front:Array[Vector3]=[];var rear:Array[Vector3]=[];var low:=Vector3.INF;var high:Vector3=-Vector3.INF;var attachments:=PackedVector3Array()
		for i in range(4):
			var direction:Vector3=directions[0 if i in [0,3] else 1];front.append(contacts[i]-direction*.08);rear.append(contacts[i]+direction*1.25)
			if field.sample(front[-1])>-.035 or field.sample(rear[-1])<.15:valid=false
			attachments.append(rear[-1]);low=low.min(front[-1]).min(rear[-1]);high=high.max(front[-1]).max(rear[-1])
		var bounds:AABB=AABB(low,high-low)
		if not valid or shapes.protected(field,bounds.get_center(),Vector2(bounds.size.x,bounds.size.z).length()*.5,low.y,high.y):continue
		var emitter=Geometry.Shared.new();emitter.origin=origin;var midpoint:Vector3=(front[0]+front[2]+rear[0]+rear[2])*.25
		geometry.quad(emitter,front[0],front[1],front[2],front[3],midpoint);geometry.quad(emitter,rear[3],rear[2],rear[1],rear[0],midpoint)
		for i in range(4):var j:int=(i+1)%4;geometry.quad(emitter,front[i],rear[i],rear[j],front[j],midpoint)
		var target:Dictionary=bucket("mineral_bed");var first:int=target.vertices.size()
		for i in range(emitter.vertices.size()):target.vertices.append(emitter.vertices[i]);target.normals.append(emitter.normals[i]);target.colors.append(tint);target.uvs.append(Vector2(family+.1,.7));target.growth_uvs.append(Vector2.ZERO);target.middle.append(first+i);target.far.append(first+i)
		placements.append({"id":str(room.id)+"/vein/"+str(band)+"/"+str(segment),"kind":"mineral_vein","owner":key,"root":center,"axis":-directions[0],"height":2*maxf(width_a,width_b),"width":.08,"family":family,"broken":false,"age":age,"importance":0,"thin_transmission":false,"collider":false,"attachments":attachments,"surface_contacts":PackedVector3Array(contacts),"host_room":str(room.id),"bounds":bounds,"raw_weight":weight(field,center-directions[0]*.5),"batch":"mineral_bed","first_vertex":first,"vertex_count":emitter.vertices.size(),"fracture_band":band})
func build(field,cell:Vector3i,seed_id:int,regions:Array,configuration:Dictionary,_water:Dictionary)->Dictionary:
	key=cell;origin=Vector3(cell)*64;settings=configuration;_seed_id=seed_id;batches={};placements=[];rejections={};_lining_candidates=[];_debris_candidates=[];geometry=Geometry.new();var density:float=clampf(float(configuration.get("density",.65)),0,1)
	if density<=0:return {"valid":true,"batches":[],"placements":[]}
	var surface_air:bool=field.include_surface_air;var cover:float=field.opening_rock_cover;field.include_surface_air=false;field.opening_rock_cover=6;var rooms:Dictionary={}
	for region:Dictionary in regions:
		if region.get("cave_family",-1) in [6,7]:continue
		var regional_rooms:Array=region.nodes+region.get("pockets",[])
		for pool:Dictionary in region.get("pools",[]):regional_rooms.append_array(pool.get("bank_lobes",[]))
		for room:Dictionary in regional_rooms:
			if int(room.get("level",-1))>=0:rooms[str(room.id)]=room
	var room_ids:Array=rooms.keys();room_ids.sort()
	for id:String in room_ids:
		var room:Dictionary=rooms[id];var reach:float=room.chamber_radius+6;var low:Vector3=room.point-Vector3(reach,4,reach);var high:Vector3=room.point+Vector3(reach,room.chamber_height+4,reach)
		if high.x<origin.x or low.x>=origin.x+64 or high.z<origin.z or low.z>=origin.z+64 or high.y<origin.y or low.y>=origin.y+64:continue
		var parent_id:String=str(room.get("biome_parent",id));var assignment:Dictionary=Regions.along_edge(field._biome_assignment,parent_id,parent_id,0,0)
		if float(assignment.weights.get("crystal",0))<.3:continue
		var identity:String=str(assignment.candidate_ids.get("crystal",id));clusters(field,room,identity,seed_id,density);veins(field,room,identity,seed_id,density)
	# Only spend remaining original160-form budget AFTER every primary,
	# secondary and vein. Loose fragments cannot displace major silhouettes.
	_debris_candidates.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.priority<b.priority or (a.priority==b.priority and str(a.id)<str(b.id)));var debris_count:int=0
	for debris:Dictionary in _debris_candidates:
		if debris_count>=16 or placements.size()>=MAX_FORMS:break
		if form(field,debris.root,debris.axis,debris.width,debris.height,debris.family,true,debris.age,debris.id,1,false,debris.phase,false,true):placements[-1].kind="crystal_debris";debris_count+=1
	_lining_candidates.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.priority<b.priority or (a.priority==b.priority and str(a.id)<str(b.id)));var lining_count:int=0
	for patch:Dictionary in _lining_candidates:
		if lining_count>=MAX_LINING_PATCHES:break
		if lining_patch(field,patch):lining_count+=1
	# Optional corridor growth uses only remaining space after ALL existing
	# forms,including attached wall mantles. Never displace their root IDs.
	Corridors.append(self,field,regions,seed_id,configuration)
	field.include_surface_air=surface_air;field.opening_rock_cover=cover
	var result:Array=[];var count:int=0
	for kind:String in batches:
		var b:Dictionary=batches[kind];var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=b.vertices;arrays[Mesh.ARRAY_NORMAL]=b.normals;arrays[Mesh.ARRAY_COLOR]=b.colors;arrays[Mesh.ARRAY_TEX_UV]=b.uvs;arrays[Mesh.ARRAY_TEX_UV2]=b.growth_uvs;var indices:=PackedInt32Array();indices.resize(b.vertices.size())
		for i in range(indices.size()):indices[i]=i
		arrays[Mesh.ARRAY_INDEX]=indices;count+=indices.size();var lods:Dictionary={}
		# A secondary-only batch still has meaningful lower-detail index sets.
		# Retain its single largest complete root at far range,not a zero-index
		# mesh or individual triangles shaved off every mineral silhouette.
		if b.middle.is_empty() or b.far.is_empty():
			var representative:Dictionary={}
			for placement:Dictionary in placements:
				if placement.batch==kind and (representative.is_empty() or placement.height>representative.height):representative=placement
			var keep:=PackedInt32Array()
			for i in range(representative.first_vertex,representative.first_vertex+representative.vertex_count):keep.append(i)
			if b.middle.is_empty():b.middle=keep
			if b.far.is_empty():b.far=keep
		if configuration.get("mesh_lods",true):
			if not b.middle.is_empty() and b.middle.size()<indices.size():lods[.5]=b.middle
			if not b.far.is_empty() and b.far.size()<mini(indices.size(),b.middle.size()):lods[1.5]=b.far
		var batch:Dictionary={"kind":kind,"arrays":arrays,"lods":lods,"collision_faces":b.collision_faces,"shadows":kind!="mineral_grains"}
		if kind=="mineral_clear":batch["far_kind"]="mineral_opaque";batch["near_distance"]=32.0
		result.append(batch)
	return Luminous.apply({"valid":count<=MAX_VERTICES,"reason":"Crystal cell numeric vertex bound" if count>MAX_VERTICES else "","batches":result,"placements":placements,"prototype_count":geometry.templates.size(),"rejections":rejections},regions,seed_id,configuration)
