extends RefCounted
## Ice grows from measured rock contacts and retained water geography. This
## does not carve another cave volume, reroll a biome, or change walking rules.
const Shapes=preload("res://scripts/caves/formations.gd")
const Basins=preload("res://scripts/caves/seepage_basins.gd")
const Profiles=preload("res://scripts/caves/chamber_profiles.gd")
const Regions=preload("res://scripts/caves/biome_regions.gd")
const MAX_FORMS:int=32
const MAX_VERTICES:int=120000
const ICE_FREEBOARD:float=.06
const ICE_THICKNESS:float=.55
var shapes=Shapes.new()
var thin=Shapes.new()
var placements:Array=[]
var key:Vector3i
var origin:Vector3
var smooth_normals:bool=true
func smooth_range(builder,first:int)->void:
	if not smooth_normals:return
	var accumulated:Dictionary={}
	for i in range(first,builder.vertices.size()):var p:Vector3=builder.vertices[i];accumulated[p]=accumulated.get(p,Vector3.ZERO)+builder.normals[i]
	for i in range(first,builder.vertices.size()):
		var normal:Vector3=accumulated[builder.vertices[i]].normalized()
		if normal.dot(builder.normals[i])>.15:builder.normals[i]=normal
func decorate_region(region:Dictionary,height:Callable,_seed_id:int,configuration:Dictionary,maximum_depth:float,minimum_roof:float)->Dictionary:
	if not configuration.get("large_lakes",true) or region.get("cave_family",-1) in [6,7] or not region.get("valid",false):return region
	var pools:Array=region.get("pools",[]);var grown:Array=pools.duplicate();var changed:bool=false
	for index in range(pools.size()):
		var pool:Dictionary=pools[index];var parent:String=str(pool.id).trim_suffix(":seepage");var cold:float=float(Regions.along_edge(region.get("cave_biome_regions",{}),parent,parent,0,0).weights.get("frozen",0))
		if cold<.8:continue
		var radius:float=clampf(pool.radius*float(configuration.get("lake_radius_multiplier",1.8)),float(configuration.get("lake_radius_minimum",8)),float(configuration.get("lake_radius_maximum",12)));var depth:float=minf(4.8,pool.depth*1.3);var bed_y:float=pool.center.y-depth;var headroom:float=depth+8
		if radius<=pool.radius+.01 or not Basins.route_clear(pool.center,radius,bed_y,pool.water_y,region) or not Profiles.compatible(pool.center,radius,8,region,region.get("pockets",[])):continue
		var admitted:bool=true
		for other_index in range(grown.size()):
			if other_index==index:continue
			var other:Dictionary=grown[other_index]
			if Vector2(pool.center.x-other.center.x,pool.center.z-other.center.z).length()<radius+other.radius+2 and absf(pool.water_y-other.water_y)<depth+other.depth+2:admitted=false
		for z in range(-2,3):
			for x in range(-2,3):
				if Vector2(x,z).length()>2.1:continue
				var surface:float=height.call(pool.center.x+x*radius*.5,pool.center.z+z*radius*.5)
				if not is_finite(surface) or surface-bed_y>maximum_depth-4 or surface-pool.center.y<8+minimum_roof+4:admitted=false
		if not admitted:continue
		var expanded:Dictionary=pool.duplicate(true);var ratio:float=radius/pool.radius;expanded["frozen_lake"]=true;expanded["frozen_original_radius"]=pool.radius;expanded.radius=radius;expanded.depth=depth;expanded.bed_y=bed_y;expanded.water_radius=radius*.8;expanded.bed.point.y=bed_y;expanded.bed.chamber_radius=radius*.85;expanded.bed.chamber_height=headroom
		for lobe:Dictionary in expanded.get("bed_lobes",[]):
			var offset:Vector3=lobe.point-pool.center;lobe.point=Vector3(pool.center.x+offset.x*ratio,bed_y+.15,pool.center.z+offset.z*ratio);lobe.chamber_radius=radius*.65;lobe.chamber_height=headroom
		grown[index]=expanded;changed=true
	if not changed:return region
	var output:Dictionary=region.duplicate();output["pools"]=grown;return output
func weight(field,point:Vector3)->float:return field.biome_weights_at(point,["frozen"]).x
func hot_points(field,points:Array)->bool:
	if field.thermal_sources.is_empty():return false
	var low:=Vector3.INF;var high:Vector3=-Vector3.INF
	for row in points:
		for point:Vector3 in row:low=low.min(point);high=high.max(point)
	return field.hot_bounds(AABB(low,high-low))
func wetness(point:Vector3,regions:Array)->float:
	var wet:float=0
	for region:Dictionary in regions:
		for pool:Dictionary in region.get("pools",[]):wet=maxf(wet,1-smoothstep(pool.radius+8,pool.radius+72,point.distance_to(pool.center)))
	return wet
func arrays(builder)->Array:
	if builder.vertices.is_empty():return []
	var result:Array=[];result.resize(Mesh.ARRAY_MAX);result[Mesh.ARRAY_VERTEX]=builder.vertices;result[Mesh.ARRAY_NORMAL]=builder.normals;result[Mesh.ARRAY_COLOR]=builder.colors;return result
func forms(field,seed_id:int,regions:Array,density:float)->void:
	for z in range(4):
		for x in range(4):
			var cell:=Vector3i(key.x*4+x,key.y,key.z*4+z)
			if shapes.random(cell,seed_id,51001)>density:continue
			var p:=Vector3((cell.x+.2+shapes.random(cell,seed_id,51002)*.6)*16,origin.y-2,(cell.z+.2+shapes.random(cell,seed_id,51003)*.6)*16)
			var previous:Vector3=p;var previous_value:float=field.sample(previous)
			for station in range(34):
				p.y=origin.y+station*2;var value:float=field.sample(p)
				if previous_value>=0 and value<0 and placements.size()<MAX_FORMS:
					var floor_point:Vector3=shapes.boundary(field,previous,p);var ceiling:Vector3=shapes.ceiling_at(field,floor_point)
					if floor_point.y<origin.y-.0001 or floor_point.y>=origin.y+64-.0001 or not ceiling.is_finite() or float(field.height.call(p.x,p.z))-ceiling.y<10:previous=p;previous_value=value;continue
					var cold:float=weight(field,floor_point+Vector3.UP);var moisture:float=wetness(floor_point,regions)
					# Ceiling condensation requires actual nearby retained groundwater.
					# Dry Frozen rooms retain exposed rock/frost,not giant wet cascades.
					if cold<.55 or moisture<.08:previous=p;previous_value=value;continue
					var room_height:float=ceiling.y-floor_point.y;var phase:float=shapes.random(cell,seed_id,51004)*TAU
					var radius:float=.25+pow(shapes.random(cell,seed_id,51005),2)*2.4
					var height:float=minf(.9+pow(shapes.random(cell,seed_id,51006),1.7)*18,room_height*.72)*smoothstep(.45,.9,cold)
					var up:float=-1 if shapes.random(cell,seed_id,51007)<.74 else 1
					var root:Vector3=ceiling if up<0 else floor_point
					var joined:bool=room_height>9 and room_height<38 and moisture>.35 and shapes.random(cell,seed_id,51008)<.12
					if joined:root=floor_point;up=1;height=room_height;radius=maxf(radius,1.2)
					if height<.7:previous=p;previous_value=value;continue
					var tip:Vector3=root+Vector3(0,up*height,0);var extent:float=radius*1.15+height*.025
					if field.hot_bounds(AABB(Vector3(root.x-extent,minf(root.y,tip.y)-.9,root.z-extent),Vector3(extent*2,absf(tip.y-root.y)+1.8,extent*2))):previous=p;previous_value=value;continue
					if shapes.protected(field,root,extent,minf(root.y,tip.y)-.9,maxf(root.y,tip.y)+.9):previous=p;previous_value=value;continue
					var foot:PackedVector3Array=shapes.contacts(field,root,radius,up,phase,height)
					if foot.is_empty():previous=p;previous_value=value;continue
					var attachments:Array=[foot];var selected=thin if radius<.5 and height<3 and up<0 else shapes;var first_vertex:int=selected.vertices.size()
					if joined:
						var crown:PackedVector3Array=shapes.contacts(field,ceiling,radius,-1,phase,height)
						if crown.is_empty():previous=p;previous_value=value;continue
						shapes.column(floor_point,ceiling,radius,phase,foot,crown);attachments.append(crown)
					else:selected.growth(root,radius,height,up,phase,foot,up>0)
					smooth_range(selected,first_vertex)
					placements.append({"kind":"ice_column" if joined else ("icicle" if up<0 else "ice_stalagmite"),"owner":key,"root":root,"height":height,"radius":extent,"up":up,"attachments":attachments,"cold":cold,"groundwater":moisture,"thin":selected==thin})
				previous=p;previous_value=value
func wall_point(field,center:Vector3,direction:Vector3,maximum:float)->Vector3:
	if field.sample(center)>=-.03:return Vector3.INF
	var previous:Vector3=center
	for step in range(1,ceili(maximum/.75)+1):
		var next:Vector3=center+direction*step*.75
		if field.sample(next)>=0:return shapes.boundary(field,previous,next)
		previous=next
	return Vector3.INF
func curtains(field,seed_id:int,regions:Array,chance:float)->void:
	for region:Dictionary in regions:
		for pool:Dictionary in region.get("pools",[]):
			var room:Dictionary={};var parent:String=str(pool.id).trim_suffix(":seepage")
			for node:Dictionary in region.nodes+region.get("pockets",[]):
				if str(node.id)==parent:room=node;break
			if room.is_empty() or room.chamber_height<12:continue
			var direction:Vector3=Vector3(pool.center.x-room.point.x,0,pool.center.z-room.point.z).normalized()
			if direction.length_squared()<.5:continue
			var base:Vector3=wall_point(field,room.point+Vector3(0,1,0),direction,room.chamber_radius+48)
			if not base.is_finite() or field.cell(base)!=key or weight(field,base-direction)<.65 or shapes.random(field.bin_cell(base),seed_id,52001)>chance:continue
			var height:float=minf(room.chamber_height*.78,34);var width:float=3+pool.radius*.75;var yaw:float=atan2(direction.z,direction.x);var front:Array=[];var back:Array=[];var attached:=PackedVector3Array();var accepted:bool=true
			const ROWS:int=32
			const COLUMNS:int=24
			for row in range(ROWS+1):
				var t:float=float(row)/ROWS;var strip:=PackedVector3Array();var buried:=PackedVector3Array()
				for col in range(COLUMNS+1):
					var s:float=float(col)/COLUMNS;var spread:float=.55+.45*pow(sin(PI*t),.35);var angle:float=yaw+(s-.5)*width*spread/maxf(room.chamber_radius,8);var radial:=Vector3(cos(angle),0,sin(angle));var crown:float=.72+.28*pow(.5+.5*sin(s*TAU*1.5+yaw),.6);var center:Vector3=room.point+Vector3(0,lerpf(.15,height*crown,t),0);var contact:Vector3=wall_point(field,center,radial,room.chamber_radius+48)
					if not contact.is_finite():accepted=false;break
					var thickness:float=(.75+1.7*pow(.5+.5*sin(s*TAU*5+.3*sin(t*TAU)),2)+1.15*pow(1-t,3))*sin(PI*(.13+.74*s))*sin(PI*(.18+.64*t))
					var point:Vector3=contact-radial*thickness;var rear:Vector3=contact+radial*1.2
					if field.sample(rear)<.08 or shapes.protected(field,point,.45,point.y-.5,point.y+.5) or weight(field,point)<.55:accepted=false;break
					strip.append(point);buried.append(rear);attached.append(rear)
				if not accepted:break
				front.append(strip);back.append(buried)
			# A real curved/receding rock face is required,not a freestanding blue
			# rectangle on a flat arbitrary wall. Retained basin identifies water.
			if not accepted or hot_points(field,front+back):continue
			var lower:Vector3=front[1][COLUMNS/2]-room.point;var upper:Vector3=front[ROWS-2][COLUMNS/2]-room.point
			if absf(Vector2(lower.x,lower.z).length()-Vector2(upper.x,upper.z).length())<.6:continue
			var tint:=Color(.65,.22,.9,1);var first_vertex:int=shapes.vertices.size()
			for row in range(ROWS):
				for col in range(COLUMNS):
					quad(front[row][col],front[row+1][col],front[row+1][col+1],front[row][col+1],-direction,tint)
					quad(back[row][col+1],back[row+1][col+1],back[row+1][col],back[row][col],direction,tint)
				for col:int in [0,COLUMNS]:quad(front[row][col],back[row][col],back[row+1][col],front[row+1][col],-direction.cross(Vector3.UP) if col==0 else direction.cross(Vector3.UP),tint)
			for col in range(COLUMNS):
				quad(front[0][col],front[0][col+1],back[0][col+1],back[0][col],Vector3.DOWN,tint)
				quad(front[ROWS][col+1],front[ROWS][col],back[ROWS][col],back[ROWS][col+1],Vector3.UP,tint)
			# Smooth only this joined ice sheet's coincident corners. Geometry
			# and native collision stay identical;avoid faceted paper-panel ribs.
			smooth_range(shapes,first_vertex)
			placements.append({"kind":"frozen_waterfall","owner":key,"root":base,"height":height,"width":width,"source_basin":pool.id,"attachments":[attached],"measured_wall_vertices":attached.size(),"front":front})
func quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3,n:Vector3,tint:Color)->void:
	shapes.triangle(a,b,c,n,tint);shapes.triangle(a,c,d,n,tint)
func lake(field,water:Dictionary)->void:
	var original:Array=water.get("arrays",[])
	if original.is_empty():return
	var vertices:PackedVector3Array=original[Mesh.ARRAY_VERTEX];var edges:Dictionary={};var triangles:int=0
	for i in range(0,vertices.size(),3):
		var a:Vector3=vertices[i]+origin;var b:Vector3=vertices[i+1]+origin;var c:Vector3=vertices[i+2]+origin
		if hot_points(field,[PackedVector3Array([a,b,c,a-Vector3.UP*ICE_THICKNESS,b-Vector3.UP*ICE_THICKNESS,c-Vector3.UP*ICE_THICKNESS])]):continue
		# Partial-freeze boundary follows the same continuous graph scalar.
		# Low-cold water remains water;no fabricated blue floor puddles.
		if minf(weight(field,a),minf(weight(field,b),weight(field,c)))<.70:continue
		a.y+=ICE_FREEBOARD;b.y+=ICE_FREEBOARD;c.y+=ICE_FREEBOARD
		if field.sample(a)>=0 or field.sample(b)>=0 or field.sample(c)>=0:continue
		var tint:=Color(.85,.08,.95,1);shapes.triangle(a,b,c,Vector3.UP,tint);shapes.triangle(a-Vector3(0,.55,0),c-Vector3(0,.55,0),b-Vector3(0,.55,0),Vector3.DOWN,tint);triangles+=1
		for pair:Array in [[a,b],[b,c],[c,a]]:
			var first:Vector3=pair[0];var last:Vector3=pair[1];var order:bool=first.x<last.x or (first.x==last.x and (first.y<last.y or (first.y==last.y and first.z<last.z)));var edge:Array=[first,last] if order else [last,first];var id:String=str(var_to_bytes(edge).hex_encode())
			if edges.has(id):edges.erase(id)
			else:edges[id]={"points":edge,"outward":((first+last)*.5-(a+b+c)/3)*Vector3(1,0,1)}
	for edge:Dictionary in edges.values():
		var a:Vector3=edge.points[0];var b:Vector3=edge.points[1];var n:Vector3=edge.outward.normalized();quad(a,b,b-Vector3(0,.55,0),a-Vector3(0,.55,0),n,Color(.8,.2,.95,1))
	if triangles>0:placements.append({"kind":"frozen_water","owner":key,"source_basins":water.get("ids",[]),"top_triangles":triangles,"shore_edges":edges.size(),"thickness":ICE_THICKNESS,"water_offset":ICE_FREEBOARD,"stream_count":water.get("channels",0)})
func shore_aprons(field,regions:Array,water:Dictionary)->void:
	# A clipped water edge sits inside a2m extracted rock chord. Merely lifting
	# its ice plate can leave a small vertical lip,even with an analytic dry
	# floor nearby. A broad,solid ice deposit connects the actual parent-room
	# floor to the SAME retained lake level. No bridge prop or movement assist.
	for region:Dictionary in regions:
		for pool:Dictionary in region.get("pools",[]):
			if not water.get("ids",[]).has(pool.id):continue
			var parent_id:String=str(pool.id).trim_suffix(":seepage");var room:Dictionary={}
			for node:Dictionary in region.nodes+region.get("pockets",[]):
				if str(node.id)==parent_id:room=node;break
			if room.is_empty():continue
			var finish:=Vector3(pool.center.x,pool.water_y+ICE_FREEBOARD,pool.center.z)
			if field.cell(Vector3(pool.center.x,pool.water_y,pool.center.z))!=key or weight(field,finish)<.7:continue
			var direction:Vector3=Vector3(pool.center.x-room.point.x,0,pool.center.z-room.point.z).normalized();var span:float=minf(pool.radius+6,Vector2(pool.center.x-room.point.x,pool.center.z-room.point.z).length()-1)
			if span<5:continue
			var start:Vector3=finish-direction*span;start.y=room.point.y;var side:Vector3=direction.cross(Vector3.UP);var top:Array=[];var bottom:Array=[];var contact:=PackedVector3Array();var valid:bool=true;var maximum_grade:float=0
			for row in range(25):
				var t:float=float(row)/24;var middle:Vector3=start.lerp(finish,t);middle.y+=.13*sin(PI*t);var width:float=1.75+sin(PI*t)*.45;var strip:=PackedVector3Array();var buried:=PackedVector3Array()
				for col in range(9):
					var u:float=float(col)/8*2-1;var p:Vector3=middle+side*u*width;p.y-=.015*pow(absf(u),3)*sin(PI*t)
					if field.sample(p+Vector3(0,2.1,0))>=-.1:valid=false;break
					strip.append(p);buried.append(p-Vector3(0,.55,0))
				if not valid:break
				if row==0:
					for point:Vector3 in buried:
						if field.sample(point)<.08:valid=false
					contact=buried
				if not top.is_empty():maximum_grade=maxf(maximum_grade,absf(strip[4].y-top[-1][4].y)/(span/24))
				top.append(strip);bottom.append(buried)
			if not valid or maximum_grade>.2 or hot_points(field,top+bottom):continue
			var tint:=Color(.8,.24,.95,1)
			for row in range(24):
				for col in range(8):quad(top[row][col],top[row+1][col],top[row+1][col+1],top[row][col+1],Vector3.UP,tint);quad(bottom[row][col+1],bottom[row+1][col+1],bottom[row+1][col],bottom[row][col],Vector3.DOWN,tint)
				for col:int in [0,8]:quad(top[row][col],bottom[row][col],bottom[row+1][col],top[row+1][col],-side if col==0 else side,tint)
			for col in range(8):quad(top[0][col+1],top[0][col],bottom[0][col],bottom[0][col+1],-direction,tint);quad(top[24][col],top[24][col+1],bottom[24][col+1],bottom[24][col],direction,tint)
			placements.append({"kind":"ice_shore_apron","owner":key,"source_basin":pool.id,"start":start,"finish":finish,"maximum_grade":maximum_grade,"width_minimum":3.5,"thickness":.55,"attachments":[contact]})
func build(field,cell:Vector3i,seed_id:int,regions:Array,configuration:Dictionary,water:Dictionary)->Dictionary:
	key=cell;origin=Vector3(cell)*64;shapes=Shapes.new();thin=Shapes.new();shapes.origin=origin;thin.origin=origin;placements=[];smooth_normals=bool(configuration.get("smooth_normals",true))
	var surface_air:bool=field.include_surface_air;var cover:float=field.opening_rock_cover;field.include_surface_air=false;field.opening_rock_cover=6
	forms(field,seed_id,regions,clampf(float(configuration.get("density",.6)),0,1));curtains(field,seed_id,regions,clampf(float(configuration.get("curtain_chance",.2)),0,1))
	if configuration.get("lake_ice",true):lake(field,water);shore_aprons(field,regions,water)
	field.include_surface_air=surface_air;field.opening_rock_cover=cover
	if shapes.vertices.size()+thin.vertices.size()>MAX_VERTICES:return {"valid":false,"reason":"Frozen geometry vertex bound exceeded","batches":[]}
	# Calcite helper supplies only geometry. Store ice-specific surface traits.
	for i in range(shapes.colors.size()):
		if shapes.colors[i].r>.70 and shapes.colors[i].r<.76:shapes.colors[i]=Color(.65,.28,.95,1)
	for i in range(thin.colors.size()):thin.colors[i]=Color(.3,.05,.95,1)
	var batches:Array=[]
	if not shapes.vertices.is_empty():batches.append({"kind":"ice","arrays":arrays(shapes)})
	if not thin.vertices.is_empty():batches.append({"kind":"thin_ice","arrays":arrays(thin)})
	return {"valid":true,"batches":batches,"placements":placements}
