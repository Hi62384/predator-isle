extends "res://tools/biome_extensions/profile_network_tile_candidate.gd"
func install(b):
	var field=load("res://scripts/alien_infected_sampler.gd").new();field.configure(b.settings.alien_infected,b.world_seed,b,7);b._extras[7]=field;return field
func run()->void:
	profile_basename="profile_production_network_tiles";private_candidate_only=false;profile_guards=["res://tools/biome_extensions/profile_production_network_tiles.gd"]
	super.run()
