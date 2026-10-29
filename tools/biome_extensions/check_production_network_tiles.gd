extends "res://tools/biome_extensions/check_network_tile_candidate.gd"
func install(b):
	var field=load("res://scripts/alien_infected_sampler.gd").new();field.configure(b.settings.alien_infected,b.world_seed,b,7);b._extras[7]=field;return field
func run()->void:
	output_basename="check_production_network_tiles";private_candidate_only=false;extra_guards=["res://tools/biome_extensions/check_production_network_tiles.gd"]
	super.run()
func lifecycle_checks(b,reference)->void:
	var field=b._extras[7];check(not field._query_tiles.is_empty(),"Actual production dense-query cache allocated")
	b.settings.alien_infected.network_query_cache_enabled=false
	for i in range(64):
		var p:=Vector2(i*7919%160000-80000,i*11939%160000-80000)
		check(field.network(p)==reference._extras[7].network(p) and field.nerve_fibre_relief(p)==reference._extras[7].nerve_fibre_relief(p),"Disabled production cache equals frozen original network and fibres")
	check(field._query_tiles.is_empty() and field._tile_probes.is_empty(),"Disabling releases all retained spatial metadata")
	b.settings.alien_infected.network_query_cache_enabled=true
