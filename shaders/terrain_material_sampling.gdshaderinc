#ifndef PREDATOR_TERRAIN_MATERIAL_SAMPLING
#define PREDATOR_TERRAIN_MATERIAL_SAMPLING
// Validation may disable pruning to compare the original two-sample path.
// Only exact endpoints are omitted: no new fade, threshold or material LOD.
// All reads below retain the caller's explicit gradients, so divergent mask
// boundaries cannot change texture footprints or mip selection.
uniform bool terrain_material_sample_pruning=true;
bool terrain_sample_first(float blend){return !terrain_material_sample_pruning || blend<1.0;}
bool terrain_sample_second(float blend){return !terrain_material_sample_pruning || blend>0.0;}
#endif
