extends RefCounted
## Optional continuous room-floor relief. Shared point value across ALL room
## primitives avoids a step at overlapping mineral/default room boundaries.
static func wave(point:Vector3)->float:
	var x:float=fposmod(point.x,3840);var z:float=fposmod(point.z,3840);var phase:float=TAU*(x*.6+z*.8)/24+.4*sin(TAU*z/96)*sin(TAU*x/120);var u:float=.5+.5*sin(phase);return u*u*u*u
static func offset(field,point:Vector3,strength:float,biome_id:String="crystal")->float:
	if strength<=0 or not field._biome_fields.has(biome_id):return 0.0
	var admission:float=field.biome_admission(point)
	if admission<=0:return 0.0
	var features:PackedInt32Array=field.bins.get(field.bin_cell(point),PackedInt32Array());var amount:float=0;var mask:float=1
	for feature:int in features:
		var a:Vector3=field.begins[feature];var b:Vector3=field.ends[feature];var q:=Vector2(point.x-a.x,point.z-a.z);var t:float=0;var distance:float=q.length();var floor_y:float=a.y;var width:float=field.dimensions[feature].x
		if field.kinds[feature]!=2:
			t=clampf(q.dot(field.directions[feature])/field.span_squared[feature],0,1);distance=(q-field.directions[feature]*t).length();floor_y=lerpf(a.y,b.y,t)
		var vertical:float=1-smoothstep(2,4,absf(point.y-floor_y));var weights:Vector2=field._biome_fields[biome_id][feature];var raw:float=lerpf(weights.x,weights.y,t);var support:float=1-smoothstep(width*.6,width*.6+4,distance);amount=maxf(amount,raw*vertical*support)
		if field.kinds[feature]!=2:mask=minf(mask,1-vertical+vertical*smoothstep(width+1,width+4,distance))
	for shore:Dictionary in field._protected_shores:
		var radius:float=Vector2(point.x-shore.center.x,point.z-shore.center.z).length();var ring:float=smoothstep(shore.inner-3,shore.inner,radius)*(1-smoothstep(shore.outer,shore.outer+3,radius));var vertical:float=smoothstep(shore.low-4,shore.low,point.y)*(1-smoothstep(shore.high,shore.high+4,point.y));mask=minf(mask,1-ring*vertical)
	return wave(point)*clampf(strength,0,1)*clampf(amount,0,1)*clampf(mask,0,1)*admission
