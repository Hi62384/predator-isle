extends RefCounted
## Worker-owned geological growth. Forms grow from measured solid/air
## boundaries,not arbitrary decorative scatter. Protected graph passages are
## excluded in three dimensions. Each jittered16m cell has one stable owner.
const GRID:float=16
const MAX_FORMS:int=48
var vertices:=PackedVector3Array()
var normals:=PackedVector3Array()
var colors:=PackedColorArray()
var origin:=Vector3.ZERO
func random(cell:Vector3i,seed_id:int,salt:int)->float:
	var h:int=(cell.x*374761393+cell.y*668265263+cell.z*1442695041+seed_id*69069+salt*1274126177)&0x7fffffff;h=((h^(h>>13))*1274126177)&0x7fffffff;return float(h^(h>>16))/2147483647.0
func boundary(field,a:Vector3,b:Vector3)->Vector3:
	var positive:bool=field.sample(a)>=0
	for i in range(16):
		var mid:Vector3=(a+b)*.5
		if (field.sample(mid)>=0)==positive:a=mid
		else:b=mid
	return (a+b)*.5
func ceiling_at(field,floor_point:Vector3)->Vector3:
	var previous:Vector3=floor_point+Vector3(0,.1,0)
	if field.sample(previous)>=0:return Vector3.INF
	for step in range(1,65):
		var point:Vector3=floor_point+Vector3(0,step*2,0)
		if field.sample(point)>=0:return boundary(field,previous,point)
		previous=point
	return Vector3.INF
func protected(field,point:Vector3,radius:float,low:float,high:float)->bool:
	# Large retained Crystal basins reserve their measured dry bank in the
	# same compiled field. This excludes complete forms,never disables a
	# collider after upload or changes the walking rock/water geometry.
	if field.has_method("protected_shore") and field.protected_shore(point,radius,low,high):return true
	# Query only bins touched by the proposed form. Global feature scans turn
	# a tiny decoration pass into quadratic work in a long connected network.
	var first:Vector3i=field.bin_cell(Vector3(point.x-radius,low-1,point.z-radius));var last:Vector3i=field.bin_cell(Vector3(point.x+radius,high+1,point.z+radius));var visited:Dictionary={}
	for z in range(first.z,last.z+1):
		for y in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				for feature:int in field.bins.get(Vector3i(x,y,z),PackedInt32Array()):
					if visited.has(feature) or field.kinds[feature]==2:continue
					visited[feature]=true;var a:Vector3=field.begins[feature];var b:Vector3=field.ends[feature];var ab:=Vector2(b.x-a.x,b.z-a.z);var q:=Vector2(point.x-a.x,point.z-a.z);var t:float=clampf(q.dot(ab)/maxf(ab.length_squared(),.000001),0,1);var floor_y:float=lerpf(a.y,b.y,t)
					if (q-ab*t).length()<field.dimensions[feature].x+radius+1 and high>floor_y-.5 and low<floor_y+field.dimensions[feature].y+.5:return true
	return false
func triangle(a:Vector3,b:Vector3,c:Vector3,outward:Vector3,color:Color)->void:
	var cross_value:Vector3=(c-a).cross(b-a)
	if cross_value.length_squared()<.0000000001:return
	if cross_value.dot(outward)<0:var swap:Vector3=b;b=c;c=swap;cross_value=-cross_value
	var n:Vector3=cross_value.normalized()
	for p:Vector3 in [a,b,c]:vertices.append(p-origin);normals.append(n);colors.append(color)
func contacts(field,root:Vector3,radius:float,up:float,phase:float,height:float)->PackedVector3Array:
	# Measure the ENTIRE uneven foot,not only its center. Steep chamber rims
	# and pool banks that cannot support a complete attached ring are rejected.
	var result:=PackedVector3Array()
	for i in range(14):
		var angle:float=i*TAU/14;var flute:float=1+.075*sin(angle*5+phase)+.04*sin(angle*9-phase);var p:Vector3=root+Vector3(cos(angle),0,sin(angle))*radius*flute;var a:Vector3=p-Vector3(0,up*1.25,0);var b:Vector3=p+Vector3(0,up*1.25,0)
		if field.sample(a)<0 or field.sample(b)>=0:return PackedVector3Array()
		var contact:Vector3=boundary(field,a,b)
		if absf(contact.y-root.y)>minf(.9,height*.2):return PackedVector3Array()
		result.append(contact-Vector3(0,up*.35,0))
	return result
func growth(root:Vector3,radius:float,height:float,up:float,phase:float,foot:PackedVector3Array,flowing:bool=false,breakdown:bool=false)->void:
	var count:int=14;var rings:int=5 if breakdown else 12;var tint:Color=Color(.38,.35,.30,.5) if breakdown else Color(.73,.67,.54,1);var previous:=PackedVector3Array()
	for j in range(rings+1):
		var t:float=float(j)/rings;var profile:float=pow(maxf(0,1-t),.68)*(1+.12*sin(t*TAU*2+phase)*sin(PI*t));var ring:=PackedVector3Array()
		if flowing:profile=pow(maxf(0,1-t),.30)*(1+.085*sin(t*TAU*4+phase)*sin(PI*t))
		if breakdown:profile=pow(maxf(0,1-t),.28)*(1+.19*sin(t*PI*3+phase)*sin(PI*t))
		for i in range(count):
			var angle:float=i*TAU/count;var flute:float=1+.075*sin(angle*5+phase)+.04*sin(angle*9-phase);var r:float=radius*profile*flute;var bend:=Vector2(sin(phase),cos(phase))*height*.025*t*t
			var point:Vector3=root+Vector3(cos(angle)*r+bend.x,up*(height*t-.35),sin(angle)*r+bend.y);point.y+=(foot[i].y-(root.y-up*.35))*pow(1-t,2);ring.append(point)
		if j>0:
			for i in range(count):
				var n:int=(i+1)%count;var outward:=Vector3(cos((i+.5)*TAU/count),0,sin((i+.5)*TAU/count));triangle(previous[i],ring[i],ring[n],outward,tint);triangle(previous[i],ring[n],previous[n],outward,tint)
		else:
			for i in range(count):triangle(root-Vector3(0,up*.35,0),ring[i],ring[(i+1)%count],Vector3(0,-up,0),tint)
		previous=ring
func column(floor_point:Vector3,ceiling:Vector3,radius:float,phase:float,foot:PackedVector3Array,crown:PackedVector3Array)->void:
	var previous:=PackedVector3Array();var height:float=ceiling.y-floor_point.y;var tint:=Color(.73,.67,.54,1)
	for j in range(21):
		var t:float=float(j)/20;var profile:float=.34+.66*pow(absf(2*t-1),1.6);var ring:=PackedVector3Array()
		for i in range(14):
			var angle:float=i*TAU/14;var flute:float=1+.075*sin(angle*5+phase)+.04*sin(angle*9-phase);var r:float=radius*profile*flute;var bend:=Vector2(sin(phase),cos(phase))*height*.012*sin(PI*t);var point:Vector3=floor_point+Vector3(cos(angle)*r+bend.x,height*t,sin(angle)*r+bend.y);point.y+=(foot[i].y-floor_point.y)*pow(1-t,3)+(crown[i].y-ceiling.y)*pow(t,3);ring.append(point)
		if j>0:
			for i in range(14):
				var n:int=(i+1)%14;var outward:=Vector3(cos((i+.5)*TAU/14),0,sin((i+.5)*TAU/14));triangle(previous[i],ring[i],ring[n],outward,tint);triangle(previous[i],ring[n],previous[n],outward,tint)
		previous=ring
func build(field,key:Vector3i,seed_id:int,geology:int,density:float=1)->Dictionary:
	vertices.clear();normals.clear();colors.clear();origin=Vector3(key)*64;var placements:Array=[]
	var statistics:Dictionary={"candidates":0,"floors":0,"ceilings":0,"owned":0,"protected":0}
	if density<=0 or field==null:return {"arrays":[],"placements":placements}
	# Calcite growth belongs mainly to soluble geological domains. Other
	# rock families retain their natural vaults instead of universal spikes.
	if geology not in [0,2,3,5]:return {"arrays":[],"placements":placements}
	if geology==5:density*=.3
	for z in range(4):
		for x in range(4):
			var cell:=Vector3i(key.x*4+x,key.y,key.z*4+z)
			if random(cell,seed_id,1)>clampf(density*.72,0,1):continue
			statistics.candidates+=1
			var p:=Vector3((cell.x+.25+random(cell,seed_id,2)*.5)*GRID,origin.y,(cell.z+.25+random(cell,seed_id,3)*.5)*GRID);var previous:Vector3=p;var previous_value:float=field.sample(previous)
			# Start one station below the cell to include roots exactly on its
			# lower boundary; strict half-open Y ownership prevents duplicates.
			previous.y-=2;previous_value=field.sample(previous)
			for station in range(34):
				p.y=origin.y+station*2;var value:float=field.sample(p)
				if previous_value>=0 and value<0:
					var floor_point:Vector3=boundary(field,previous,p);var ceiling:Vector3=ceiling_at(field,floor_point)
					statistics.floors+=1
					if ceiling.is_finite():statistics.ceilings+=1
					if ceiling.is_finite() and floor_point.y>=origin.y-.0001 and floor_point.y<origin.y+64-.0001 and ceiling.y-floor_point.y>3 and float(field.height.call(floor_point.x,floor_point.z))-floor_point.y>8:
						statistics.owned+=1
						var radius:float=.45+random(cell,seed_id,5)*1.9;var height:float=minf(1.2+random(cell,seed_id,6)*7.5,(ceiling.y-floor_point.y)*.55);var up:float=1 if random(cell,seed_id,7)<.6 else -1;var root:Vector3=floor_point if up>0 else ceiling;var tip_y:float=root.y+up*height
						var phase:float=random(cell,seed_id,8)*TAU;var joined:bool=random(cell,seed_id,9)<.10 and ceiling.y-floor_point.y<32 and ceiling.y-floor_point.y>6
						# Volcanic domains supply their own opaque rock formations.
						# Deterministic complete-form thinning keeps the default side
						# byte-exact and avoids universal calcite in cooled lava tubes.
						if field.has_method("biome_weights_at") and random(cell,seed_id,55001)<field.biome_weights_at(root,["magma"]).x:previous=p;previous_value=value;continue
						var flowing:bool=geology in [0,2] and random(cell,seed_id,10)<.16;var breakdown:bool=geology==3
						if flowing or breakdown:
							joined=false;root=floor_point;up=1;radius=(2.0 if breakdown else 1.4)+random(cell,seed_id,11)*(2.2 if breakdown else 1.9);height=(1.0 if breakdown else .5)+random(cell,seed_id,12)*(2.5 if breakdown else 1.6);tip_y=root.y+height
						if joined:root=floor_point;up=1;height=ceiling.y-floor_point.y;tip_y=ceiling.y
						var extent:float=radius*1.15+height*.025
						if not protected(field,root,extent,minf(root.y,tip_y)-.9,maxf(root.y,tip_y)+.9) and placements.size()<MAX_FORMS:
							var foot:PackedVector3Array=contacts(field,root,radius,up,phase,height)
							if foot.is_empty():previous=p;previous_value=value;continue
							var attachments:Array=[foot]
							if joined:
								var crown:PackedVector3Array=contacts(field,ceiling,radius,-1,phase,height)
								if crown.is_empty():previous=p;previous_value=value;continue
								column(floor_point,ceiling,radius,phase,foot,crown);attachments.append(crown)
							else:growth(root,radius,height,up,phase,foot,flowing,breakdown)
							placements.append({"root":root,"radius":extent,"height":height,"up":up,"kind":"column" if joined else ("flowstone" if flowing else ("breakdown" if breakdown else ("stalagmite" if up>0 else "stalactite"))),"owner":key,"attachments":attachments})
						else:statistics.protected+=1
				previous=p;previous_value=value
	var arrays:Array=[]
	if not vertices.is_empty():arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors
	return {"arrays":arrays,"placements":placements,"statistics":statistics}
static func join(base:Array,extra:Array)->Array:
	if extra.is_empty():return base
	if base.is_empty():return extra
	var result:Array=base.duplicate()
	for slot:int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR]:
		var data=base[slot].duplicate();data.append_array(extra[slot]);result[slot]=data
	return result
