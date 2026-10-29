extends SceneTree
var failures:Array[String]=[]
var checks:int=0
func verify(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func leaf(host:Node,key:Vector3i)->MeshInstance3D:
	var node:=MeshInstance3D.new();node.set_meta("tile",key);node.set_meta("resolution",host._tile_resolution(key));node.mesh=ArrayMesh.new();node.visible=false;host.add_child(node);return node
func _initialize()->void:call_deferred("run")
func run()->void:
	# No _ready/material initialization is needed to exercise publication policy.
	var host=load("res://scripts/chunk_terrain.gd").new();host.terrain_collision_enabled=false;host._target_chunk=Vector2i.ZERO
	var a:=Vector3i.ZERO;var b:=Vector3i(1,0,0)
	host._wanted={a:true,b:true};host.partition_revision=1
	host._staged[a]=leaf(host,a);host._commit_partition()
	verify(host._active_chunks.has(a) and host._active_chunks[a].visible,"Nearest ready leaf displays before distant work completes")
	verify(host.committed_revision==0 and not host._startup_coverage_complete,"Partial startup never claims complete coverage")
	host._staged[b]=leaf(host,b);host._commit_partition()
	verify(host.committed_revision==1 and host._startup_coverage_complete and host._active_chunks.size()==2,"Final startup cut commits normally")
	var c:=Vector3i(2,0,0);host._wanted[c]=true;host.partition_revision=2;host._staged[c]=leaf(host,c)
	var d:=Vector3i(3,0,0);host._wanted[d]=true;host._commit_partition()
	verify(host._active_chunks.has(c) and host.committed_revision==1,"Completed local region publishes without claiming the unfinished whole cut")
	host._staged[d]=leaf(host,d);host._startup_coverage_complete=false;host._teleport_pending=true;host._publish_startup_chunks()
	verify(not host._active_chunks.has(d),"Pending teleport never publishes partial destination")
	host._teleport_pending=false
	var parent:=Vector3i(0,0,1);host._wanted[parent]=true;host._staged[parent]=leaf(host,parent);host._publish_startup_chunks()
	verify(not host._active_chunks.has(parent),"Replan cannot display a parent overlapping existing children")
	var coarse:=Vector3i(-1,0,3);host._wanted[coarse]=true;host._staged[coarse]=leaf(host,coarse);host._publish_startup_chunks()
	verify(not host._active_chunks.has(coarse),"Replan cannot publish an illegal adjacent LOD jump")
	verify(host._tile_resolution(a)==128 and host._tile_resolution(b)==128,"Camera and adjacent leaves retain 2 m grid")
	verify(host._tile_resolution(Vector3i(0,0,1))==64,"Next terrain level retains 8 m grid")
	verify(host._tile_resolution(Vector3i(0,0,2))==32,"Second terrain level retains 32 m grid")
	host.free();print("STARTUP_PUBLICATION ",checks," checks failures=",failures);quit(0 if failures.is_empty() else 1)
