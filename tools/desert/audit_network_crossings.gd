extends SceneTree
const Desert=preload("res://scripts/desert_sampler.gd")
func _initialize():
 var records:Array=[];var count:int=0;var graph_count:int=0
 for seed_number in [73921,12345,90317]:
  var s=Desert.new();s.configure(DesertSettings.new(),seed_number)
  for z in range(-2,3):
   for x in range(-2,3):
    var edges:Array=s._drainage_graph._catchment(Vector2i(x,z),s)[0];graph_count+=1
    for i in range(edges.size()):
     var a:Array=edges[i]
     for j in range(i+1,edges.size()):
      var b:Array=edges[j]
      if a[0].is_equal_approx(b[0]) or a[0].is_equal_approx(b[1]) or a[1].is_equal_approx(b[0]) or a[1].is_equal_approx(b[1]):continue
      var hit:bool=false
      for u in range(12):
       var t0:float=u/12.0;var t1:float=(u+1)/12.0
       var a0:Vector2=a[0]+a[7]*t0+a[6]*4*t0*(1-t0)
       var a1:Vector2=a[0]+a[7]*t1+a[6]*4*t1*(1-t1)
       for v in range(12):
        var q0:float=v/12.0;var q1:float=(v+1)/12.0
        var b0:Vector2=b[0]+b[7]*q0+b[6]*4*q0*(1-q0)
        var b1:Vector2=b[0]+b[7]*q1+b[6]*4*q1*(1-q1)
        if Geometry2D.segment_intersects_segment(a0,a1,b0,b1)!=null:hit=true
      if hit:count+=1;records.append({"seed":seed_number,"cell":str(Vector2i(x,z)),"a":i,"b":j})
 var result={"catchments":graph_count,"nonjunction_centerline_crossings":count,"records":records,"curve_segments":12}
 print(JSON.stringify(result));FileAccess.open("res://tools/desert/network_crossings.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));quit()
