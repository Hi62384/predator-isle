extends RefCounted
## Focused202 branch boundary certificate; reuse201 directed scalar intervals
## and actual binary32 preimage enclosure. This is not a new interval library.
const I=preload("res://alien_foundry/scripts/geometry/BlobEnvelope201Certificate.gd")
const SUBDIVISIONS:=256
static func bernstein(values: Array,t: Array) -> Array:
	var c: Array=[]
	for value: float in values: c.append(I.point(value))
	var one_minus:=I.sub(I.point(1.0),t)
	for degree in range(c.size()-1,0,-1):
		for i in range(degree): c[i]=I.add(I.mul(one_minus,c[i]),I.mul(t,c[i+1]))
	return c[0]
static func boundary(f: RefCounted,low: Array,high: Array,halo: float) -> Dictionary:
	var minima: Array=[INF,INF,INF,INF,INF,INF]
	var pieces: Array=[[low[2],0.0],[0.0,1.0],[1.0,high[2]]]
	for piece in range(3):
		for j in range(SUBDIVISIONS):
			var za: float=pieces[piece][0]; var zb: float=pieces[piece][1]
			var z0:=I.add(I.point(za),I.mul(I.sub(I.point(zb),I.point(za)),I.point(float(j)/float(SUBDIVISIONS))))
			var z1:=I.add(I.point(za),I.mul(I.sub(I.point(zb),I.point(za)),I.point(float(j+1)/float(SUBDIVISIONS))))
			var z: Array=[z0[0],z1[1]]
			var t:=I.div(I.sub(z,I.point(f.midpoint)),I.point(f.half_span))
			var px: Array; var py: Array; var cx:=I.point(0.0); var cy:=I.point(0.0)
			if piece==0 or piece==2:
				var index:=0 if piece==0 else 1
				var r: float=f.caps[index][0]
				var numerator:=I.sub(I.point(1.0+float(f.caps[1][0])),z) if piece==0 else I.add(z,I.point(float(f.caps[0][0])))
				var denominator:=I.sub(I.point(r),z) if piece==0 else I.add(I.sub(z,I.point(1.0)),I.point(r))
				var factor: float=r*r/(f.half_span*f.half_span)
				px=I.div(I.mul(I.point(factor/pow(float(f.caps[index][2]),2.0)),numerator),denominator)
				py=I.div(I.mul(I.point(factor/pow(float(f.caps[index][1]),2.0)),numerator),denominator)
			else:
				z=[maxf(z[0],0.0),minf(z[1],1.0)]
				var values: Array=[]
				for i in range(4): values.append(I.round32(bernstein(f.profiles[i],z)))
				var a:=I.mul(I.add(values[0],values[1]),I.point(0.5)); var b:=I.mul(I.add(values[2],values[3]),I.point(0.5))
				cx=I.mul(I.sub(values[2],values[3]),I.point(0.5)); cy=I.mul(I.sub(values[0],values[1]),I.point(0.5))
				var q:=I.sub(I.point(1.0),I.mul(t,t))
				px=I.div(q,I.mul(b,b)); py=I.div(q,I.mul(a,a))
			if not I.finite(px) or not I.finite(py) or px[0]<=0.0 or py[0]<=0.0 or low[0]>=cx[0] or high[0]<=cx[1] or low[1]>=cy[0] or high[1]<=cy[1]: return {"ok":false,"reason":"fixed202 boundary interval inconclusive"}
			for face in range(4):
				var axis:=0 if face<2 else 1
				var coord: float=low[axis] if face%2==0 else high[axis]
				var x:=I.sub(I.point(coord),cx if axis==0 else cy)
				var term:=I.mul(I.mul(px if axis==0 else py,x),x)
				var value:=I.round32(I.mul(I.point(f.raw_scale*0.5),I.sub(I.add(I.square(t),term),I.point(1.0))))
				minima[face]=minf(minima[face],value[0])
	for face in [4,5]:
		var z: float=low[2] if face==4 else high[2]
		var t:=I.div(I.sub(I.point(z),I.point(f.midpoint)),I.point(f.half_span))
		minima[face]=I.round32(I.mul(I.point(f.raw_scale*0.5),I.sub(I.square(t),I.point(1.0))))[0]
	return {"ok":float(minima.min())>halo,"face_lower_bounds":minima,"required_halo":halo,"minimum_clearance":float(minima.min())-halo,"fixed_axial_intervals":SUBDIVISIONS*3,"includes_vector4_binary32_rounding":true,"outside_monotonicity":true}
