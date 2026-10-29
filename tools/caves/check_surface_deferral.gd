extends "res://tools/biome_extensions/check_all.gd"
const Policy=preload("res://scripts/caves/surface_streaming_policy.gd")
const Streamer=preload("res://scripts/caves/streamer.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
class Host:
	extends RefCounted
	var height:float=200.0
	var calls:int=0
	func get_height_at(_point:Vector3)->float:calls+=1;return height
func run()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://scripts/caves/surface_streaming_policy.gd","res://scripts/caves/streamer.gd","res://scripts/caves/cave_settings.gd","res://scripts/chunk_terrain.gd"]:guards[path]=FileAccess.get_sha256(path)
	var comparisons:int=0
	for enabled:bool in [true,false]:
		for entrance:bool in [true,false]:
			for y:float in [-400,-1,0,100,200]:
				for cover:float in [-INF,NAN,0,95.999,96,96.001,200,400,INF]:
					var p:=Vector3(20000.125,y,-20000.875);var ground:float=y+cover;var expected:bool=enabled and not entrance and is_finite(ground) and ground-y>96;check(Policy.can_defer(p,ground,enabled,entrance)==expected,"Actual production deep policy retains exact96m boundary,finite signed coordinates,enabled/off and required-mouth bypass");comparisons+=1
	check(not Policy.can_defer(Vector3.INF,200,true,false),"Invalid camera point fails open to normal planning")
	var stream=Streamer.new();stream.configuration=Config.new();var host:=Host.new();stream.host=host
	check(not stream.defer_surface_plan(Vector3.ZERO) and host.calls==0,"No compiled cave bundle never defers or samples old world")
	stream._bundle={"entrances":[]};check(stream.defer_surface_plan(Vector3.ZERO),"Actual streamer selects deep closed cover with no required mouth")
	stream.configuration.retain_deep_surface_cut=false;var before:int=host.calls;check(not stream.defer_surface_plan(Vector3.ZERO) and host.calls==before,"Independent original scheduling off mode avoids even extra canonical queries")
	stream.configuration.retain_deep_surface_cut=true;host.height=96;check(not stream.defer_surface_plan(Vector3.ZERO),"Actual streamer resumes planning at inclusive96m cover")
	host.height=200;stream._bundle.entrances=[{"point":Vector3.ZERO,"minimum_exposed_floor":0.0,"columns":{Vector2i.ZERO:true}}];check(not stream.defer_surface_plan(Vector3.ZERO),"Real required portal bypasses deferral despite arbitrary deep canonical cover")
	stream.free()
	var terrain_source:String=FileAccess.get_file_as_string("res://scripts/chunk_terrain.gd");check(terrain_source.contains("not destination.is_finite() and not _teleport_pending and _cave_streamer!=null and not _active_chunks.is_empty() and _cave_streamer.defer_surface_plan(target.global_position)"),"Normal terrain integrates tested policy only after explicit destination/teleport/active-cut guards;no geometry visibility mutation")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable adopted scheduler/profile source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_surface_deferral.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"policy_cases":comparisons,"scope":"Actual production96m finite-cover policy/enabled-off/required-mouth contract and actual Streamer canonical/bundle gating;normal ChunkTerrain explicit destination/teleport/active-cut guard. No new geometry,LOD hiding,player or worker changes. This check is scoped to scheduling;later connected-profile dry-bank changes have independent admission/native checks. Full production combined return/performance requires its own run;not FPS/art/registration completion."},"  "));print("SURFACE_DEFERRAL ",checks," cases=",comparisons," failures=",failures);quit(0 if failures.is_empty() else 1)
