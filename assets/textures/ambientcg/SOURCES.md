# Terrain materials

The active eight-layer palette, newly downloaded assets, compression and selected
maps are documented in [PALETTE_MANIFEST.md](PALETTE_MANIFEST.md). The table below
records the original four source assets; sand is now reserved for desert, not a
uniform shoreline outline.

All texture maps are from ambientCG, licensed CC0: https://docs.ambientcg.com/license/

| Biome | Asset | Resolution | World tile size |
| --- | --- | --- | --- |
| Grass | https://ambientcg.com/view?id=Grass001 | 2K JPG | 1.4 m |
| Desert / shore | https://ambientcg.com/view?id=Ground054 | 2K JPG | 3.5 m |
| Snow | https://ambientcg.com/view?id=Snow001 | 2K JPG | 3 m (artistic scale) |
| Stone / slopes | https://ambientcg.com/view?id=Rock030 | 2K JPG | 4 m (artistic scale) |

Downloaded through https://ambientcg.com/get?file=ASSET_2K-JPG.zip.
Retained original color, OpenGL normal and roughness JPG maps unmodified.
The terrain material uses world-space triplanar projection, mipmaps and anisotropic filtering.
Color maps are read as sRGB; normals and roughness are linear data.
Biome weights blend all three channels. The ocean remains animated water.
