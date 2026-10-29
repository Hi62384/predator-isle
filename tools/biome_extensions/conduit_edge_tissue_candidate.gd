extends "res://scripts/biome_extension_structures.gd"
## Private existing-alpha transition study. No new geometry/control channel.
var edge_tissue_enabled:bool=true
func _conduit_uncached(builder,a:Vector2,b:Vector2,width:float,phase:float,color:Color)->void:
	var first:int=vertices.size();super._conduit_uncached(builder,a,b,width,phase,color)
	if not edge_tissue_enabled or not conduit_aprons or not conduit_shoulders:return
	var direction:Vector2=(b-a).normalized();var side:=Vector2(-direction.y,direction.x);var segments:int=clampi(ceili(a.distance_to(b)/96),16,64);var labels:Dictionary={}
	for row in range(segments+1):
		# Exactly the original float32 x/z construction; no new height samples.
		var t:float=float(row)/segments;var p:Vector2=a.lerp(b,t)+side*sin(t*PI)*width*.8;var radius:float=width*(.7+.2*sin(t*9+phase)+.1*sin(t*23-phase))
		for column:int in [0,1,2,6,7,8]:
			var angle:float=float(column)*PI/8;var q:=Vector2(p.x+side.x*cos(angle)*radius,p.y+side.y*cos(angle)*radius)-Vector2(origin.x,origin.z)
			labels[q]=.25 if column in [0,8] else (.45 if column in [1,7] else .65)
	for i in range(first,vertices.size()):
		var q:=Vector2(vertices[i].x,vertices[i].z)
		if colors[i].a>.9 and labels.has(q):
			var tint:Color=colors[i];tint.a=labels[q];colors[i]=tint
