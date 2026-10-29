# Desert sediment and salt-source research

Fresh SHA256 reads of all **18** existing ambientCG source maps match the preserved
`downloaded_manifest.json`; `asset_integrity_20261014.json` records the hashes.
This verifies source identity, not compressed/rendered PBR quality.

## Authentic cracked sediment

[Mud Cracked Dry Riverbed 002](https://polyhaven.com/a/mud_cracked_dry_riverbed_002)
is a photographed dry-clay surface, licensed [CC0](https://polyhaven.com/license).
Photography: Dimitrios Savva; processing: Dario Barresi. Physical repeat: **2 m**.
Three original 2K JPG maps (Diffuse, nor_gl, Rough) were downloaded from official
files-API URLs. Each size/MD5 matched official metadata; SHA256, source URLs,
metadata and a license-page snapshot/hash are retained in
`assets/textures/desert/polyhaven/mud_cracked_dry_riverbed_002/provenance.json`.
No purchase or account was needed.

All three source maps were inspected: irregular fractured clay plates, brown
diffuse color, crack relief and mostly rough plate surfaces. This offers a coherent
basin structure compared with pebbly Ground031. It is **not salt**.

Prepared integration (not executed): `build_clay_palette.gd` packs 2K BC3 color/
linear roughness alpha and 1K BC5 OpenGL XY normals with mipmaps. Four new outputs
replace only clay in alternative six-layer arrays, refusing existing outputs and
preserving all original resources. ChunkTerrain selects the alternative arrays
only when both exist, using 2 m clay repeat. Until then the original palette and
2.3 m fallback remain active. The three-family pixel budget is retained. Packing,
shader validation and rendered appearance remain pending.

`run_clay_preparation.ps1` stages and prepares only this source in an isolated
owned child, using existing asset-packing limits (768 MiB entry, 384 MiB floor/cap).
It compares output formats, mipmaps, compressed byte counts and all original material
hashes before publishing four new paths; existing resources are never overwritten.
Prepared for a separate coordinated slot, not yet executed.

**Subsequent native preparation passed:** `clay_palette_delivery.json` records four
published/hash-readback-verified outputs. Native format/mip/byte-count checks passed
and all fourteen original material hashes remained unchanged. Peak child RAM was
143,089,664 bytes; slot released. The earlier preparation notes are historical;
the alternative arrays now exist. Shader/array runtime and appearance are unverified.

Other official CC0 candidates in `material_candidates_20261014.json`:
[Dry Mud Field 001](https://polyhaven.com/a/dry_mud_field_001) has compacted clumps,
stones and track marks; [Mud Cracked Dry 03](https://polyhaven.com/a/mud_cracked_dry_03)
is another cracked-ground candidate. Neither redundant set was downloaded.

## Authentic salt crust remains missing

- Official ambientCG salt search returned zero entries; Poly Haven's texture
  catalog had no salt identifier/tag candidate.
- [LotPixel Crystalline Salt Ore 5217](https://www.lotpixel.com/texture/crystalline-salt-ore-texture-5217)
  is labeled procedural, premium and three credits, requiring login. No purchase
  or download was performed.
- [BudgetPixel Cracked Salt Flat Crust](https://budgetpixel.com/images/cracked-salt-flat-crust-texture-e819c6f7)
  explicitly says BudgetPixel AI/Z-Image-Turbo and CC BY 4.0. It is generated stock
  imagery, not authentic scanned PBR; it was not downloaded or relabeled.
- Other results were stock photos, unrelated granite or paid/login assets.

This bounded search does not prove no suitable material exists elsewhere.
Ground033 remains the original pale sediment approximation. Genuine salt-crust
structure/asset acceptance remains open.
