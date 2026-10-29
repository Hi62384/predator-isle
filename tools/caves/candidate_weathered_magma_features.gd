extends RefCounted
## Cooled volcanic geology on the existing graph, field, worker and renderer.
const Shapes=preload("res://scripts/caves/formations.gd")
const Geometry=preload("res://tools/caves/candidate_weathered_magma_geometry.gd")
const Fit=preload("res://scripts/caves/measured_formation.gd")
const Regions=preload("res://scripts/caves/biome_regions.gd")
const Profiles=preload("res://scripts/caves/chamber_profiles.gd")
const Basins=preload("res://scripts/caves/seepage_basins.gd")
const Tubes=preload("res://scripts/caves/magma_tubes.gd")
const LakeChambers=preload("res://scripts/caves/magma_lake_chambers.gd")
const Intrusions=preload("res://scripts/caves/magma_intrusions.gd")
const Cascades=preload("res://scripts/caves/magma_cascades.gd")
const MAX_FORMS:int=64
const MAX_VERTICES:int=24000
func decorate_region_with_context(region:Dictionary,height:Callable,seed_id:int,configuration:Dictionary,maximum_depth:float,minimum_roof:float,heat_context)->Dictionary:
	var cooled:Dictionary=decorate_region(region,height,seed_id,configuration,maximum_depth,minimum_roof)
	if heat_context==null or not cooled.get("valid",false) or cooled.get("cave_family",-1) in [6,7] or not configuration.get("source_heat",true):return cooled
	var pools:Array=cooled.get("pools",[]).duplicate();var changed:bool=false
	# A magmatic depression need not be preselected by the Default soluble
	# groundwater lottery. Reuse its bounded side-basin builder with an
	# explicit geological source,never reactivate water in every dry room.
	var rooms:Array=cooled.get("nodes",[])+cooled.get("pockets",[]);rooms.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return str(a.id)<str(b.id))
	var proposed_ids:Dictionary={}
	for room:Dictionary in rooms:
		if pools.size()>=Basins.MAX_BASINS:break
		if int(room.get("level",-1))<0:continue
		var pool_id:String=str(room.id)+":seepage";var exists:bool=false
		for pool:Dictionary in pools:
			if str(pool.id)==pool_id:exists=true;break
		if exists:continue
		var amount:float=float(Regions.along_edge(cooled.get("cave_biome_regions",{}),str(room.id),str(room.id),0,0).weights.get("magma",0))
		if amount<.7 or Regions.random(pool_id,seed_id,"magma/active_pool")>float(configuration.get("active_pool_chance",.14)):continue
		if float(heat_context.sample(room.point).heat)<.5:continue
		var basin_region:Dictionary=cooled.duplicate();basin_region["nodes"]=[room];basin_region["pockets"]=[]
		for candidate:Dictionary in Basins.make(basin_region,seed_id,1.0,false):
			var overlaps:bool=false
			for previous:Dictionary in pools:
				if Vector2(candidate.center.x-previous.center.x,candidate.center.z-previous.center.z).length()<candidate.radius+previous.radius+2 and absf(candidate.water_y-previous.water_y)<candidate.depth+previous.depth+2:overlaps=true;break
				if not Basins.route_clear(candidate.center,candidate.radius,candidate.bed_y,candidate.water_y,{"edges":previous.get("stream_edges",[])}):overlaps=true;break
			if not overlaps:pools.append(candidate);proposed_ids[str(candidate.id)]=true
	var accepted:Array=[]
	for index in range(pools.size()):
		var pool:Dictionary=pools[index];var parent:String=str(pool.id).trim_suffix(":seepage");var amount:float=float(Regions.along_edge(cooled.get("cave_biome_regions",{}),parent,parent,0,0).weights.get("magma",0))
		if amount<.7 or Regions.random(str(pool.id),seed_id,"magma/active_pool")>float(configuration.get("active_pool_chance",.14)):
			if not proposed_ids.has(str(pool.id)):accepted.append(pool)
			continue
		var witness:Dictionary=heat_context.sample(Vector3(pool.center.x,pool.water_y,pool.center.z))
		if float(witness.heat)<.5:
			if not proposed_ids.has(str(pool.id)):accepted.append(pool)
			continue
		var admitted:bool=true
		# Whole pool and any feeder must share an ACTUAL source witness.
		for side in range(16):
			var angle:float=side*TAU/16;var point:Vector3=Vector3(pool.center.x,pool.water_y,pool.center.z)+Vector3(cos(angle),0,sin(angle))*pool.radius;var sample:Dictionary=heat_context.sample(point)
			if float(sample.heat)<.5 or sample.get("id","")!=witness.id:admitted=false;break
		for point:Vector3 in pool.get("stream_points",PackedVector3Array()):
			var sample:Dictionary=heat_context.sample(Vector3(point.x,pool.water_y,point.z))
			if float(sample.heat)<.5 or sample.get("id","")!=witness.id:admitted=false;break
		if not admitted:
			if not proposed_ids.has(str(pool.id)):accepted.append(pool)
			continue
		var molten:Dictionary=pool.duplicate();molten["fluid_kind"]="magma";molten["thermal_source"]=witness.id;molten["surface_witness"]=witness.surface_witness;molten["source_heat"]=witness.heat;molten["heat_source_kind"]=witness.get("kind","explicit_diagnostic_intrusion")
		if proposed_ids.has(str(pool.id)):molten["construction"]="source_backed_magmatic_side_basin"
		accepted.append(molten);changed=true
	var result:Dictionary=cooled
	if changed:result=cooled.duplicate();result["pools"]=accepted
	return Cascades.prepare(LakeChambers.prepare(result,height,seed_id,configuration,maximum_depth,minimum_roof,heat_context),height,seed_id,configuration,maximum_depth,minimum_roof,heat_context)
func decorate_region(region:Dictionary,height:Callable,seed_id:int,configuration:Dictionary,maximum_depth:float,minimum_roof:float)->Dictionary:
	if not configuration.get("chamber_growth",true) or not region.get("valid",false) or region.get("cave_family",-1) in [6,7]:return region
	var result:Dictionary=region;var changed:bool=false
	for table:String in ["nodes","pockets"]:
		var rooms:Array=region.get(table,[]).duplicate()
		for index in range(rooms.size()):
			var node:Dictionary=rooms[index]
			if int(node.get("level",-1))<0:continue
			var assignment:Dictionary=Regions.along_edge(region.get("cave_biome_regions",{}),str(node.id),str(node.id),0,0)
			if float(assignment.weights.get("magma",0))<.7:continue
			var radius:float=maxf(node.chamber_radius,22+Regions.random(str(node.id),seed_id,"magma/radius")*4);var headroom:float=maxf(node.chamber_height,32+Regions.random(str(node.id),seed_id,"magma/vault")*16)
			var layout:int=0
			if configuration.get("chamber_variety",false):
				# One province identity, not unrelated random props in every room.
				var province:String=str(assignment.candidate_ids.get("magma",node.id));layout=mini(4,int(Regions.random(province,seed_id,"magma/geological_province")*5))
				var extents:Array=[Vector2(26,48),Vector2(32,30),Vector2(28,36),Vector2(30,28),Vector2(24,40)]
				radius=maxf(node.chamber_radius,extents[layout].x);headroom=maxf(node.chamber_height,extents[layout].y)
			if radius>(32 if configuration.get("chamber_variety",false) else 26) or headroom>48 or not Profiles.compatible(node.point,radius,headroom,region,region.get("pockets",[])):continue
			var admitted:bool=true
			for z in range(-2,3):
				for x in range(-2,3):
					if Vector2(x,z).length()>2.1:continue
					var surface:float=height.call(node.point.x+x*radius*.5,node.point.z+z*radius*.5)
					if not is_finite(surface) or surface-node.point.y>maximum_depth-4 or surface-node.point.y<headroom+minimum_roof+4:admitted=false
			if not admitted:continue
			var grown:Dictionary=node.duplicate();grown.chamber_radius=radius;grown.chamber_height=headroom;grown["magma_profile"]=["cooled_basalt_vault","collapsed_lava_tube","rough_scoria_chamber","volcanic_ash_cavern","obsidian_lens_cavern"][layout];grown["cross_section_style"]=[0,3,3,1,2][layout];rooms[index]=grown
			if not changed:result=region.duplicate();changed=true
		if changed:result[table]=rooms
	var final:Dictionary=Tubes.decorate(result,height,seed_id,configuration,maximum_depth,minimum_roof)
	# Real cooled deposits share the existing continuous room-floor kernel.
	# Its masks preserve full-width solved passages and retained lake rims.
	if configuration.get("cooled_deposits",false) and (changed or final!=region):
		final=final.duplicate();final["cave_floor_relief"]=final.get("cave_floor_relief",{}).duplicate();final.cave_floor_relief["magma"]=float(configuration.get("deposit_height",.45))
	return final
func build(field,key:Vector3i,seed_id:int,regions:Array,configuration:Dictionary,_water:Dictionary)->Dictionary:
	var density:float=clampf(float(configuration.get("density",.65)),0,1)
	if density<=0:return {"valid":true,"batches":[],"placements":[]}
	var old_air:bool=field.include_surface_air;var old_cover:float=field.opening_rock_cover;field.include_surface_air=false;field.opening_rock_cover=6
	var shapes=Shapes.new();var geometry=Geometry.new();var placements:Array=[];var rejected:Dictionary={};var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray();var uvs:=PackedVector2Array();var collision:=PackedVector3Array();var far:=PackedInt32Array();var origin:=Vector3(key)*64;var rooms:Dictionary={}
	for region:Dictionary in regions:
		if region.get("cave_family",-1) in [6,7]:continue
		var all_rooms:Array=region.get("nodes",[])+region.get("pockets",[])
		for pool:Dictionary in region.get("pools",[]):all_rooms.append_array(pool.get("bank_lobes",[]))
		for room:Dictionary in all_rooms:
			if int(room.get("level",-1))>=0:rooms[str(room.id)]=room
	var ids:Array=rooms.keys();ids.sort()
	for id:String in ids:
		var room:Dictionary=rooms[id];var parent:String=str(room.get("biome_parent",id));var assignment:Dictionary=Regions.along_edge(field._biome_assignment,parent,parent,0,0)
		if float(assignment.weights.get("magma",0))<.3:continue
		var radius:float=room.chamber_radius;var room_box:=AABB(room.point-Vector3(radius+4,4,radius+4),Vector3((radius+4)*2,room.chamber_height+8,(radius+4)*2))
		if not room_box.intersects(AABB(origin,Vector3.ONE*64)):continue
		for patch in range(48):
			if placements.size()>=MAX_FORMS:break
			var identity:String=id+"/basalt/"+str(patch)
			if Regions.random(identity,seed_id,"admit")>density:continue
			var angle:float=patch*TAU/48+Regions.random(id,seed_id,"magma/phase")*TAU;var radial:=Vector3(cos(angle),0,sin(angle));var family:int=0 if patch%12<int(12*float(configuration.get("column_frequency",.75))) else (2 if Regions.random(id,seed_id,"silica_lens")<float(configuration.get("obsidian_lens_chance",.12)) else 1);var width:float=.45+Regions.random(identity,seed_id,"width")*1.5;var air:Vector3=room.point+radial*radius*(.55+Regions.random(identity,seed_id,"inset")*.25)+Vector3.UP*3
			if family==0 and patch%12!=0:
				# Follow the measured union wall at mid-height;do not arrange a
				# forest of identical isolated shafts through the chamber floor.
				var start:Vector3=room.point+Vector3.UP*minf(12,room.chamber_height*.35);var wall:=Vector3.INF;var previous:Vector3=start
				if field.sample(start)>=0:continue
				for station in range(1,ceili((radius+32)/2)+1):
					var point:Vector3=start+radial*station*2
					if field.sample(point)>=0:wall=shapes.boundary(field,previous,point);break
					previous=point
				if not wall.is_finite():continue
				air=Vector3(wall.x,room.point.y+3,wall.z)-radial*(width*1.7+.7)
			var rock:Vector3=air-Vector3.UP*10
			if field.sample(air)>=0 or field.sample(rock)<0:continue
			var root:Vector3=shapes.boundary(field,rock,air)
			if field.cell(root)!=key:continue
			var amount:float=field.biome_weights_at(root+Vector3.UP,["magma"]).x
			if amount<.3:continue
			width*=smoothstep(.15,.8,amount);var height:float=(2+pow(Regions.random(identity,seed_id,"height"),1.5)*minf(20,room.chamber_height*.6))*smoothstep(.15,.8,amount);var phase:float=Regions.random(identity,seed_id,"phase")*TAU
			if family==0:
				var ceiling:Vector3=shapes.ceiling_at(field,root)
				if not ceiling.is_finite():continue
				height=minf(height,(ceiling.y-root.y)*.82)
			if family!=0:height*=.3;width*=1.3
			var fitted:Dictionary=Fit.fit(field,geometry.prototype(family,patch%4),root,Vector3.UP,width,height,phase)
			if not fitted.valid:rejected[fitted.reason]=int(rejected.get(fitted.reason,0))+1;continue
			if vertices.size()+fitted.vertices.size()>MAX_VERTICES:break
			var first:int=vertices.size();var age:float=Regions.random(id,seed_id,"cooled_age");var tint:=Color(.13,.14,.15).lerp(Color(.28,.19,.14),age*.4);var physical:bool=height>=1.5 and width>=.35
			for i in range(fitted.vertices.size()):
				vertices.append(fitted.vertices[i]-origin);normals.append(fitted.normals[i]);colors.append(tint);uvs.append(Vector2(family,age))
				if physical:collision.append(vertices[-1])
				if family==0 or height>=4:far.append(first+i)
			placements.append({"id":identity,"kind":["jointed_basalt_column","volcanic_block","obsidian_wedge"][family],"owner":key,"root":root,"height":height,"width":width,"bounds":fitted.bounds,"attachments":fitted.attachments,"collider":physical,"first_vertex":first,"vertex_count":fitted.vertices.size(),"family":family,"raw_weight":amount})
	var intrusion_prototypes:int=0
	if configuration.get("cooled_intrusions",false) and placements.size()<MAX_FORMS:
		var extra:Dictionary=Intrusions.new().build(field,key,seed_id,rooms,density,MAX_FORMS-placements.size(),configuration)
		if vertices.size()+extra.vertices.size()<=MAX_VERTICES:
			var offset:int=vertices.size()
			for placement:Dictionary in extra.placements:placement.first_vertex+=offset;placements.append(placement)
			vertices.append_array(extra.vertices);normals.append_array(extra.normals);colors.append_array(extra.colors);uvs.append_array(extra.uv);collision.append_array(extra.collision)
			for index in range(extra.vertices.size()):far.append(offset+index)
			intrusion_prototypes=extra.prototype_count
	field.include_surface_air=old_air;field.opening_rock_cover=old_cover
	var batches:Array=[]
	if not vertices.is_empty():
		var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV]=uvs;var indices:=PackedInt32Array()
		for i in range(vertices.size()):indices.append(i)
		arrays[Mesh.ARRAY_INDEX]=indices;var lods:Dictionary={}
		if configuration.get("mesh_lods",true) and not far.is_empty() and far.size()<vertices.size():lods[1.5]=far
		batches.append({"kind":"cooled_volcanic","arrays":arrays,"lods":lods,"collision_faces":collision,"shadows":true})
	var molten:Dictionary=Cascades.append_to(Basins.water_cell(regions,field,key,"magma"),regions,key)
	if not molten.arrays.is_empty():batches.append({"kind":"molten_volcanic","arrays":molten.arrays,"lods":{},"collision_faces":PackedVector3Array(),"shadows":false,"source_basins":molten.ids})
	return {"valid":true,"batches":batches,"placements":placements,"rejections":rejected,"prototype_count":geometry.templates.size()+intrusion_prototypes}
