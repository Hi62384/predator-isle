extends RefCounted
## Numeric attachment for opaque geological prototypes in the existing field.
## Full feet are buried; exposed long edges and protected routes are checked.
const Shapes=preload("res://scripts/caves/formations.gd")
static func fit(field,points:PackedVector3Array,root:Vector3,axis:Vector3,width:float,height:float,phase:float)->Dictionary:
	if not root.is_finite() or not axis.is_finite() or absf(axis.length()-1)>.001 or width<.1 or height<.35 or points.is_empty() or points.size()%3!=0:return {"valid":false,"reason":"size_or_basis"}
	var shapes=Shapes.new();var tangent:Vector3=(Vector3.UP if absf(axis.y)<.9 else Vector3.RIGHT).cross(axis).normalized().rotated(axis,phase);var across:Vector3=tangent.cross(axis).normalized();var basis:=Basis(tangent,axis,across)
	if basis.determinant()<0:basis=Basis(tangent,axis,-across)
	var vertices:=PackedVector3Array();var contacts:Dictionary={};var low:=Vector3.INF;var high:Vector3=-Vector3.INF
	for q:Vector3 in points:
		var p:Vector3=root+basis*Vector3(q.x*width,q.y*height,q.z*width)
		if q.y<.001:
			var id:=Vector2(q.x,q.z)
			if not contacts.has(id):
				var back:Vector3=p-axis*(2+width);var front:Vector3=p+axis*(2+width)
				if field.sample(back)<0 or field.sample(front)>=0:return {"valid":false,"reason":"whole_foot_bracket"}
				var foot:Vector3=shapes.boundary(field,back,front)-axis*1.25
				if field.sample(foot)<.15:return {"valid":false,"reason":"whole_foot_burial"}
				contacts[id]=foot
			p=contacts[id]
		elif field.sample(p)>-minf(.5,height*.2):return {"valid":false,"reason":"exposed_airspace"}
		vertices.append(p);low=low.min(p);high=high.max(p)
	var bounds:=AABB(low,high-low)
	if shapes.protected(field,bounds.get_center(),Vector2(bounds.size.x,bounds.size.z).length()*.5,low.y,high.y):return {"valid":false,"reason":"protected_route"}
	var normals:=PackedVector3Array()
	for i in range(0,vertices.size(),3):
		var cross_value:Vector3=(vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i])
		if cross_value.length_squared()<.0000000001:return {"valid":false,"reason":"collapsed_facet"}
		for j in range(3):normals.append(cross_value.normalized())
		for pair:Vector2i in [Vector2i(0,1),Vector2i(1,2),Vector2i(2,0)]:
			if points[i+pair.x].y<.001 or points[i+pair.y].y<.001:continue
			var a:Vector3=vertices[i+pair.x];var b:Vector3=vertices[i+pair.y];var count:int=ceili(a.distance_to(b)/2)
			for station in range(1,count):
				if field.sample(a.lerp(b,float(station)/count))>-.15:return {"valid":false,"reason":"edge_airspace"}
	return {"valid":true,"vertices":vertices,"normals":normals,"attachments":PackedVector3Array(contacts.values()),"bounds":bounds}
