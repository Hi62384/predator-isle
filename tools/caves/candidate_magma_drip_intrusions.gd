extends RefCounted
## Cooled dikes, bedding-parallel sills and solidified wall flows. Every slab
## has a fully measured buried attachment, exposed face and ordinary collider.
## No emissive source is inferred from the shape or from cave depth.
const Shapes=preload("res://scripts/caves/formations.gd")
const Fit=preload("res://scripts/caves/measured_formation.gd")
const Regions=preload("res://scripts/caves/biome_regions.gd")
const Shared=preload("res://scripts/biome_extension_structures.gd")
var templates:Dictionary={}
func prototype(kind:int)->PackedVector3Array:
	if templates.has(kind):return templates[kind]
	if kind==3:
		var points:=PackedVector3Array()
		for point:Vector3 in preload("res://scripts/caves/magma_geometry.gd").new().prototype(0,0):
			var taper:float=1-point.y*.93;points.append(Vector3(point.x*taper,point.y,point.z*taper))
		templates[kind]=points;return points
	var b=Shared.new();b._skip_degenerate=true
	var width:float=.12 if kind==0 else 1.0;var depth:float=.12 if kind==1 else 1.0
	# Two vertical lobes give the cooled cascade a folded, blunt flow face.
	for strip in range(4):
		var a:float=-depth+float(strip)*depth*.5;var c:float=a+depth*.5
		var face_a:float=.65+.2*cos(a*5) if kind==2 else 1.0
		var face_c:float=.65+.2*cos(c*5) if kind==2 else 1.0
		var p:=Vector3(-width,0,a);var q:=Vector3(width,0,a);var r:=Vector3(width,0,c);var s:=Vector3(-width,0,c)
		var u:=Vector3(-width,face_a,a);var v:=Vector3(width,face_a,a);var w:=Vector3(width,face_c,c);var t:=Vector3(-width,face_c,c)
		b.quad(p,q,v,u,Color.WHITE);b.quad(s,t,w,r,Color.WHITE);b.quad(p,u,t,s,Color.WHITE);b.quad(q,r,w,v,Color.WHITE);b.quad(u,v,w,t,Color.WHITE);b.quad(p,s,r,q,Color.WHITE)
	templates[kind]=b.vertices;return b.vertices
func build(field,key:Vector3i,seed_id:int,rooms:Dictionary,density:float,limit:int,settings:Dictionary={})->Dictionary:
	var placements:Array=[];var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray();var uv:=PackedVector2Array();var collision:=PackedVector3Array();var ids:Array=rooms.keys();ids.sort();var shapes=Shapes.new();var origin:=Vector3(key)*64
	for id:String in ids:
		var room:Dictionary=rooms[id];var radius:float=room.chamber_radius
		if not AABB(room.point-Vector3(radius+5,0,radius+5),Vector3((radius+5)*2,room.chamber_height,(radius+5)*2)).intersects(AABB(origin,Vector3.ONE*64)):continue
		for trial in range(9):
			if placements.size()>=mini(8,limit):break
			var identity:String=id+"/intrusion/"+str(trial)
			if Regions.random(identity,seed_id,"admit")>density*float(settings.get("intrusion_frequency",.55)):continue
			var kind:int=trial%3;var angle:float=Regions.random(id,seed_id,"intrusion_phase")*TAU+trial*TAU/9;var radial:=Vector3(cos(angle),0,sin(angle));var start:Vector3=room.point+Vector3.UP*(6+Regions.random(identity,seed_id,"elevation")*minf(12,room.chamber_height*.4));var previous:Vector3=start;var wall:=Vector3.INF
			if field.sample(start)>=0:continue
			for step in range(1,ceili((radius+32)/2)+1):
				var point:Vector3=start+radial*step*2
				if field.sample(point)>=0:wall=shapes.boundary(field,previous,point);break
				previous=point
			if not wall.is_finite() or field.cell(wall)!=key:continue
			var axis:Vector3=field.normal(wall)
			if absf(axis.y)>.45:continue
			var weight:float=field.biome_weights_at(wall+axis,["magma"]).x
			if weight<.7:continue
			var width:float=2.5+Regions.random(identity,seed_id,"width")*3.5;var thickness:float=1+Regions.random(identity,seed_id,"thickness")*1.5
			if kind==2:width=1.5+Regions.random(identity,seed_id,"width")*1.5;thickness=2+Regions.random(identity,seed_id,"thickness")
			var fitted:Dictionary=Fit.fit(field,prototype(kind),wall,axis,width,thickness,0)
			if not fitted.valid:continue
			var first:int=vertices.size();var tint:=Color(.065,.07,.075) if kind<2 else Color(.085,.067,.052)
			for index in range(fitted.vertices.size()):vertices.append(fitted.vertices[index]-origin);normals.append(fitted.normals[index]);colors.append(tint);uv.append(Vector2(3+kind,.4));collision.append(vertices[-1])
			placements.append({"id":identity,"kind":["cooled_volcanic_dike","cooled_volcanic_sill","solidified_lava_cascade"][kind],"owner":key,"root":wall,"axis":axis,"height":thickness,"width":width,"bounds":fitted.bounds,"attachments":fitted.attachments,"collider":true,"first_vertex":first,"vertex_count":fitted.vertices.size(),"family":3+kind,"raw_weight":weight})
	for id:String in ids:
		if placements.size()>=mini(8,limit):break
		var room:Dictionary=rooms[id];var radius:float=room.chamber_radius
		if not AABB(room.point-Vector3(radius+5,0,radius+5),Vector3((radius+5)*2,room.chamber_height+5,(radius+5)*2)).intersects(AABB(origin,Vector3.ONE*64)):continue
		for trial in range(2):
			if placements.size()>=mini(8,limit):break
			var identity:String=id+"/lava_drip/"+str(trial)
			if Regions.random(identity,seed_id,"admit")>=density*float(settings.get("lava_drip_frequency",.1)):continue
			var angle:float=Regions.random(identity,seed_id,"phase")*TAU;var start:Vector3=room.point+Vector3(cos(angle),0,sin(angle))*radius*(.25+.3*Regions.random(identity,seed_id,"inset"))+Vector3.UP*2;var attachment:Vector3=shapes.ceiling_at(field,start)
			if not attachment.is_finite() or field.cell(attachment)!=key:continue
			var weight:float=field.biome_weights_at(attachment+Vector3.DOWN,["magma"]).x
			if weight<.7:continue
			var width:float=.18+Regions.random(identity,seed_id,"width")*.27;var length:float=.8+Regions.random(identity,seed_id,"length")*1.6;var fitted:Dictionary=Fit.fit(field,prototype(3),attachment,Vector3.DOWN,width,length,angle)
			if not fitted.valid:continue
			var first:int=vertices.size()
			for index in range(fitted.vertices.size()):vertices.append(fitted.vertices[index]-origin);normals.append(fitted.normals[index]);colors.append(Color(.07,.067,.06));uv.append(Vector2(6,.6));collision.append(vertices[-1])
			placements.append({"id":identity,"kind":"basaltic_lava_stalactite","owner":key,"root":attachment,"axis":Vector3.DOWN,"height":length,"width":width,"bounds":fitted.bounds,"attachments":fitted.attachments,"collider":true,"first_vertex":first,"vertex_count":fitted.vertices.size(),"family":6,"raw_weight":weight})
	return {"vertices":vertices,"normals":normals,"colors":colors,"uv":uv,"collision":collision,"placements":placements,"prototype_count":templates.size()}
