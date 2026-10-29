$ErrorActionPreference='Stop'
$beachBatches=@(
 'wide_beach,narrow_beach,dune_field,high_foredunes',
 'backdunes,parabolic_dunes,sandy_cove,barrier_beach',
 'sand_spit,lagoon,tidal_flat,sandy_estuary',
 'low_sandy_island,storm_scarps,mixed_rock_sand,sandbars',
 'grass_beach_transition,forest_beach_transition,jungle_beach_transition',
 'savanna_beach_transition,swamp_beach_transition,mountain_beach_transition'
)
# Sequential render batches: avoid CPU/GPU contention and keep profiles separate.
for($beachBatch=0;$beachBatch -lt $beachBatches.Count;$beachBatch++){
 & "$PSScriptRoot/run_test.ps1" -Script render_review -GPU -Extra ('-- feature='+$beachBatches[$beachBatch]+' batch='+($beachBatch+1))
}
