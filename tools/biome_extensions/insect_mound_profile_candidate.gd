extends RefCounted
## PRIVATE shape study. Long construction ribs have unequal widths/heights;
## small erosion interrupts them without an evenly repeated horizontal wave.
static func coefficients(sides:int,phase:float)->Array[Vector4]:
	var result:Array[Vector4]=[]
	for side in range(sides):
		var angle:float=side*TAU/sides;var buttress:float=0;var groove:float=0;var upper:float=0;var strongest:float=0;var termination:float=.7
		for rib in range(11):
			var seed:float=.5+.5*sin(rib*18.713+phase*2.341);var center:float=(rib+.24*sin(rib*7.31+phase))*TAU/11+phase*.17;var delta:float=wrapf(angle-center,-PI,PI);var width:float=.10+.10*seed;var crest:float=exp(-delta*delta/(width*width));buttress+=crest*(.16+.22*seed);upper+=crest*(.05+.14*(1-seed));var gap:float=wrapf(angle-center-width*1.65,-PI,PI);groove+=exp(-gap*gap/.0036)*(.05+.08*seed)
			if crest>strongest:strongest=crest;termination=.38+.55*seed
		result.append(Vector4(buttress,upper,groove,termination))
	return result
static func sculpt(positions:PackedVector3Array,origin:Vector3,anchor:Vector3,width:float,height:float,archetype:int,phase:float)->PackedVector3Array:
	if archetype==3:return positions
	var rows:Array[Vector4]=coefficients(42,phase);var moved:=PackedVector3Array();var memo:Dictionary={}
	for point:Vector3 in positions:
		if memo.has(point):moved.append(memo[point]);continue
		var p:Vector3=point+origin-anchor;var t:float=p.y/height;var output:Vector3=point
		# Footers and exact summit/vent rims stay byte-identical. Only the
		# existing24outer shell rows are supplied by the caller.
		if t>0 and t<.99999:
			var lean:=Vector2(width*.16*sin(t*2+phase)*t,width*.12*t*t);var ellipse:float=.22 if archetype==2 else 1;var radial:=Vector2(p.x-lean.x,(p.z-lean.y)/ellipse);var angle:float=radial.angle();var side:int=posmod(roundi(angle*42/TAU),42);var c:Vector4=rows[side];var factor:float=.91+c.x*(1-smoothstep(.12,c.w,t))+c.y*(1-smoothstep(maxf(.2,c.w-.2),.96,t))-c.z*(.3+.7*smoothstep(.1,.5,t));factor+=.012*sin(angle*19+t*7+phase)+.008*sin(angle*31-t*11-phase)
			if archetype==4:factor-=.12*smoothstep(.15,.8,t)*(.5+.5*sin(angle*3+phase))
			if archetype==2:factor=lerpf(1,factor,.55)
			var radius:float=width*pow(maxf(.015,1-t),.65)*clampf(factor,.72,1.42);var target:=Vector3(cos(angle)*radius+lean.x,p.y,sin(angle)*radius*ellipse+lean.y);var influence:float=.55*smoothstep(0,.12,t)*(1-smoothstep(.88,1,t));output=(point+origin).lerp(target+anchor,influence)-origin
		memo[point]=output;moved.append(output)
	return moved
