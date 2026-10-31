using Godot;
using System;
using System.Collections.Generic;
using PredatorIsle.Biomes;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

/// <summary>Worker-side mesh arrays, canonical derivative field and existing material-bank encodings.</summary>
public partial class TerrainMeshGeometry : RefCounted
{
    public D index_templates { get; private set; } = new();
    public byte[] built_badlands_palette { get; private set; } = System.Array.Empty<byte>();
    public int built_badlands_palette_slot { get; private set; } = -1;
    public byte[] built_extension_data { get; private set; } = System.Array.Empty<byte>();
    public int built_extension_rows { get; private set; }
    public int built_extension_mask { get; private set; }
    public byte[] built_alien_tissue_flow { get; private set; } = System.Array.Empty<byte>();
    public int built_alien_tissue_flow_rows { get; private set; }
    public D last_build_profile { get; private set; } = new();
    private readonly AlienTissueCoordinates _tissue = new();
    private static int Round(double x) => (int)Math.Round(x, MidpointRounding.AwayFromZero);
    private static byte Byte(double x) => (byte)Round(Math.Clamp(x, 0, 1) * 255);
    private static double L(double a, double b, double t) => a + (b - a) * t;
    private static bool Approx(double a, double b) => a == b || Math.Abs(a - b) < Math.Max(1e-5 * Math.Abs(a), 1e-5);
    private static List<int> Boundary(int resolution)
    {
        int row = resolution + 1; var result = new List<int>(resolution * 4);
        for (int i = 0; i < row; i++) result.Add(i);
        for (int i = 1; i < row; i++) result.Add(i * row + resolution);
        for (int i = resolution - 1; i >= 0; i--) result.Add(resolution * row + i);
        for (int i = resolution - 1; i > 0; i--) result.Add(i * row);
        return result;
    }
    public int[] indices_for(int resolution)
    {
        if (index_templates.TryGetValue(resolution, out var cached)) return cached.AsInt32Array();
        int row = resolution + 1, cursor = 0; var indices = new int[checked(resolution * resolution * 6 + resolution * 24)];
        for (int z = 0; z < resolution; z++) for (int x = 0; x < resolution; x++)
        {
            int a = z * row + x; indices[cursor++] = a; indices[cursor++] = a + 1; indices[cursor++] = a + row;
            indices[cursor++] = a + 1; indices[cursor++] = a + row + 1; indices[cursor++] = a + row;
        }
        var boundary = Boundary(resolution);
        for (int i = 0; i < boundary.Count; i++)
        {
            int a = boundary[i], b = boundary[(i + 1) % boundary.Count], bottom = row * row + i * 2;
            indices[cursor++] = a; indices[cursor++] = bottom; indices[cursor++] = b;
            indices[cursor++] = b; indices[cursor++] = bottom; indices[cursor++] = bottom + 1;
        }
        if (index_templates.Count >= 16) index_templates.Clear(); index_templates[resolution] = indices; return indices;
    }
    public A build_water(RefCounted host, A arrays, int resolution)
    {
        var result = new A(); var settings = host.Get("settings").AsGodotObject(); if (!settings.Get("water_enabled").AsBool()) return result;
        double water = host.Get("water_level").AsDouble(); bool mountain = false;
        var mountainControls = arrays[(int)Mesh.ArrayType.Custom0].AsFloat32Array();
        if (host.Get("_mountain").AsGodotObject() is not null) foreach (float v in mountainControls) if (v < 0) { mountain = true; break; }
        var coastal = arrays[(int)Mesh.ArrayType.Custom1].VariantType == Variant.Type.Nil ? System.Array.Empty<float>() : arrays[(int)Mesh.ArrayType.Custom1].AsFloat32Array();
        if (arrays[(int)Mesh.ArrayType.Custom3].VariantType == Variant.Type.Nil && !mountain && coastal.Length == 0 && host.Get("_badlands").AsGodotObject() is null && !host.Get("_extras_enabled").AsBool()) return result;
        int row = resolution + 1, count = checked(row * row); var terrain = arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array(); var uv = arrays[(int)Mesh.ArrayType.TexUV].AsVector2Array();
        var controls = arrays[(int)Mesh.ArrayType.Custom3].VariantType == Variant.Type.Nil ? System.Array.Empty<float>() : arrays[(int)Mesh.ArrayType.Custom3].AsFloat32Array();
        var tropicalControls = arrays[(int)Mesh.ArrayType.Custom2].VariantType == Variant.Type.Nil ? System.Array.Empty<float>() : arrays[(int)Mesh.ArrayType.Custom2].AsFloat32Array();
        var terrainColors = arrays[(int)Mesh.ArrayType.Color].AsColorArray(); int mountainStride = mountainControls.Length / terrain.Length;
        var vertices = new Vector3[count]; var normals = new Vector3[count]; var colors = new Color[count]; var uvs = new Vector2[count]; var classes = new Vector2[count]; var wet = new byte[count]; var marine = new byte[count];
        for (int i = 0; i < count; i++)
        {
            double weight = controls.Length > 0 ? Math.Floor(controls[i * 4] / 65536.0) / 255 : 0;
            if (controls.Length > 0 && controls[i * 4] < 0) weight = terrainColors[i].A;
            double tw = tropicalControls.Length > 0 && tropicalControls[i * 4] < 0 ? (((long)(-(double)tropicalControls[i * 4] - 1) >> 16) & 255) / 255.0 : 0;
            if (mountainStride == 4 && mountainControls[i * 4 + 3] < 0) tw += ((long)uv[i].Y & 255) / 255.0;
            if (built_extension_mask != 0 && built_extension_data.Length > 0)
            {
                double ex = 0; int width = built_extension_data.Length / (row * 4);
                for (int family = 0; family < 8; family++) if ((built_extension_mask & (1 << family)) != 0) ex += built_extension_data[((i / row) * width + family * row + i % row) * 4] / 255.0;
                tw += ex;
            }
            double sediment = controls.Length > 0 ? ((long)controls[i * 4 + 1] & 255) / 255.0 : 0;
            double organic = controls.Length > 0 ? (((long)controls[i * 4 + 3] >> 8) & 255) / 255.0 : 0;
            double basin = controls.Length > 0 ? (((long)controls[i * 4 + 1] >> 16) & 255) / 255.0 : 0;
            double mw = mountain && mountainControls[i * mountainStride] < 0 ? Math.Floor(mountainControls[i * mountainStride + 1] / 65536.0) / 255 : 0;
            double cw = coastal.Length > 0 && coastal[i * 4 + 2] < 0 ? (((long)(-(double)coastal[i * 4 + 2] - 1) >> 8) & 255) / 255.0 : 0;
            double coastInfluence = cw; mw *= 1 - coastInfluence; tw *= 1 - coastInfluence;
            if (coastInfluence > .01 && uv[i].X <= water + .2) { cw = mw = weight = tw = 0; if (settings.Get("beaches_enabled").AsBool()) marine[i] = 1; }
            if (mw > 0) { sediment = L(sediment, (((long)mountainControls[i * mountainStride + 1] >> 8) & 255) / 255.0, mw); organic *= 1 - mw; }
            if (tw > 0) { sediment = L(sediment, .45, tw); organic *= 1 - tw; }
            if (cw > 0) { weight *= 1 - cw; sediment = L(sediment, (((long)coastal[i * 4 + 3] >> 16) & 255) / 255.0, cw); organic *= 1 - cw; }
            vertices[i] = new Vector3(terrain[i].X, uv[i].X, terrain[i].Z); normals[i] = Vector3.Up; colors[i] = new Color((float)sediment, (float)organic, (float)weight, (float)basin); uvs[i] = new Vector2(terrain[i].Y, uv[i].X);
            var classification = controls.Length > 0 ? new Vector2((float)((((long)controls[i * 4 + 1] >> 8) & 255) / 255.0), (float)((((long)controls[i * 4 + 3] >> 16) & 255) / 255.0)) : Vector2.Zero;
            if (mw + cw + tw > 0) classification.Y = (float)-Math.Max(Math.Max(mw, cw), tw); if (cw > 0) classification.X = (float)-cw; classes[i] = classification;
            if (weight + mw + cw + tw > .01 && uv[i].X + weight > terrain[i].Y) wet[i] = 1;
        }
        var indices = new List<int>(); var source = arrays[(int)Mesh.ArrayType.Index].AsInt32Array();
        for (int i = 0; i < resolution * resolution * 6; i += 3)
        {
            int a = source[i], b = source[i + 1], c = source[i + 2];
            if (wet[a] + wet[b] + wet[c] > 0 && marine[a] + marine[b] + marine[c] == 0) { indices.Add(a); indices.Add(b); indices.Add(c); }
        }
        if (indices.Count == 0) return result;
        result.Resize((int)Mesh.ArrayType.Max); result[(int)Mesh.ArrayType.Vertex] = vertices; result[(int)Mesh.ArrayType.Normal] = normals; result[(int)Mesh.ArrayType.Color] = colors;
        result[(int)Mesh.ArrayType.TexUV] = uvs; result[(int)Mesh.ArrayType.TexUV2] = classes; result[(int)Mesh.ArrayType.Index] = indices.ToArray(); return result;
    }
    public A build(RefCounted host, Vector2I coordinate, int resolution)
    {
        if (resolution <= 0) throw new ArgumentOutOfRangeException(nameof(resolution));
        var field = (TerrainHeightField)host.Get("_native_height").AsGodotObject(); var regions = (TerrainRegions)host.Get("_native_regions").AsGodotObject();
        var settings = (Resource)host.Get("settings").AsGodotObject(); double chunkSize = host.Get("chunk_size").AsDouble(), water = host.Get("water_level").AsDouble();
        bool prune = host.Get("prune_unused_halo").AsBool(), profile = host.Get("profile_build").AsBool();
        bool jungle = host.Get("_jungle").AsGodotObject() is not null, forest = host.Get("_forest").AsGodotObject() is not null, savanna = host.Get("_savanna").AsGodotObject() is not null;
        bool swamp = host.Get("_swamp").AsGodotObject() is not null, mountain = host.Get("_mountain").AsGodotObject() is not null, coast = host.Get("_coast").AsGodotObject() is not null, tropical = host.Get("_tropical").AsGodotObject() is not null;
        var badlands = host.Get("_badlands").AsGodotObject() as BadlandsSampler; bool extras = host.Get("_extras_enabled").AsBool();
        field.select_normal_cache_capacity(chunkSize);
        built_badlands_palette = System.Array.Empty<byte>(); built_badlands_palette_slot = -1; built_extension_data = System.Array.Empty<byte>(); built_extension_rows = built_extension_mask = 0;
        built_alien_tissue_flow = System.Array.Empty<byte>(); built_alien_tissue_flow_rows = 0;
        ulong start = profile ? Time.GetTicksUsec() : 0;
        int row = resolution + 1, sampleSize = row + 2, samples = checked(sampleSize * sampleSize), count = checked(row * row), total = checked(count + resolution * 8);
        double step = chunkSize / resolution, ox = coordinate.X * chunkSize, oz = coordinate.Y * chunkSize;
        bool inline = host.Get("interleave_badlands_normals").AsBool() && badlands is not null && step > 32;
        var pairs = new Dictionary<Vector2I, double[]>(); var heights = new float[samples]; var weights = new Color[samples]; var surfaces = new Vector2[samples]; var geology = new Vector3[samples];
        var jungleValues = jungle ? new float[samples] : System.Array.Empty<float>();
        var forestValues = forest ? new float[samples][] : System.Array.Empty<float[]>(); var savannaValues = savanna ? new float[samples][] : System.Array.Empty<float[]>();
        var swampValues = swamp ? new float[samples][] : System.Array.Empty<float[]>(); var mountainValues = mountain ? new float[samples][] : System.Array.Empty<float[]>();
        var coastValues = coast ? new Vector4[samples] : System.Array.Empty<Vector4>(); var tropicalValues = tropical ? new Vector3[samples] : System.Array.Empty<Vector3>();
        var extraValues = extras ? new Vector4[samples][] : System.Array.Empty<Vector4[]>(); var waterValues = new float[samples];
        var badlandsValues = badlands is not null ? new Vector3[samples] : System.Array.Empty<Vector3>(); var palettes = badlands is not null ? new Vector4[samples] : System.Array.Empty<Vector4>();
        var remnants = badlands is not null ? new float[samples] : System.Array.Empty<float>(); var skirts = badlands is not null ? new float[samples] : System.Array.Empty<float>();
        bool hasJungle = false, hasForest = false, hasSavanna = false, hasSwamp = false, hasMountain = false, hasCoast = false, hasTropical = false, hasBadlands = false;
        for (int sz = 0; sz < sampleSize; sz++) for (int sx = 0; sx < sampleSize; sx++)
        {
            if (prune && step > 32 && (sx == 0 || sz == 0 || sx == sampleSize - 1 || sz == sampleSize - 1)) continue;
            int i = sz * sampleSize + sx; double x = ox + (sx - 1) * step, z = oz + (sz - 1) * step;
            heights[i] = (float)field.grid_height(x, z); var w = field.last_weights; if (w == Vector4.Zero) w = regions.weights(x, z);
            weights[i] = new Color(w.X, w.Y, w.Z, w.W); surfaces[i] = field.last_surface; geology[i] = field.last_geology;
            if (jungle) { jungleValues[i] = (float)field.last_jungle; hasJungle |= field.last_jungle >= 65536; }
            if (forest) { forestValues[i] = field.last_forest; hasForest |= field.last_forest[0] >= 65536; }
            if (savanna) { savannaValues[i] = field.last_savanna; hasSavanna |= field.last_savanna[0] >= 65536; }
            if (swamp) { swampValues[i] = field.last_swamp; hasSwamp |= field.last_swamp[0] >= 65536; }
            if (mountain) { mountainValues[i] = field.last_mountain; hasMountain |= field.last_mountain[0] >= 65536; }
            if (coast) { coastValues[i] = field.last_coast; hasCoast |= field.last_coast.X > 1.0 / 255; }
            if (tropical) { tropicalValues[i] = field.last_tropical; hasTropical |= field.last_tropical.X > 1.0 / 255; }
            if (badlands is not null) { badlandsValues[i] = field.last_badlands; palettes[i] = field.last_badlands_palette; remnants[i] = (float)field.last_badlands_remnant; skirts[i] = (float)field.last_badlands_skirt; hasBadlands |= field.last_badlands.X > 0; }
            if (extras) extraValues[i] = field.last_extras;
            waterValues[i] = (float)field.last_water;
            if (inline && sx > 0 && sz > 0 && sx < sampleSize - 1 && sz < sampleSize - 1)
                pairs[new Vector2I(sx - 1, sz - 1)] = new[] { field.normal_height(x - 32, z), field.normal_height(x + 32, z), field.normal_height(x, z - 32), field.normal_height(x, z + 32) };
        }
        ulong heightTime = profile ? Time.GetTicksUsec() : 0;
        double normalStep = Math.Max(32, step); int normalX = (int)Math.Floor(ox / normalStep) - 1, normalZ = (int)Math.Floor(oz / normalStep) - 1;
        int width = (int)Math.Ceiling((ox + chunkSize) / normalStep) - normalX + 2, depth = (int)Math.Ceiling((oz + chunkSize) / normalStep) - normalZ + 2;
        var normalHeights = new float[checked(width * depth)]; var normalField = new Vector3[normalHeights.Length]; var curvatureField = new float[normalHeights.Length];
        for (int nz = 0; nz < depth; nz++) for (int nx = 0; nx < width; nx++)
        {
            if (prune && normalStep > 32 && (nx == 0 || nz == 0 || nx == width - 1 || nz == depth - 1)) continue;
            double x = (normalX + nx) * normalStep, z = (normalZ + nz) * normalStep, sx = (x - ox) / step + 1, sz = (z - oz) / step + 1;
            normalHeights[nz * width + nx] = Approx(sx, Math.Round(sx, MidpointRounding.AwayFromZero)) && Approx(sz, Math.Round(sz, MidpointRounding.AwayFromZero)) && sx >= 0 && sz >= 0 && sx < sampleSize && sz < sampleSize
                ? heights[Round(sz) * sampleSize + Round(sx)] : (float)field.normal_height(x, z);
        }
        for (int nz = 1; nz < depth - 1; nz++) for (int nx = 1; nx < width - 1; nx++)
        {
            int i = nz * width + nx; double x = (normalX + nx) * normalStep, z = (normalZ + nz) * normalStep, center = normalHeights[i];
            double left = normalHeights[i - 1], right = normalHeights[i + 1], back = normalHeights[i - width], front = normalHeights[i + width];
            if (normalStep > 32)
            {
                var local = new Vector2I(Round((x - ox) / step), Round((z - oz) / step));
                if (inline && pairs.TryGetValue(local, out var pair)) { left = pair[0]; right = pair[1]; back = pair[2]; front = pair[3]; }
                else { right = field.normal_height(x + 32, z); front = field.normal_height(x, z + 32); left = field.normal_height(x - 32, z); back = field.normal_height(x, z - 32); }
            }
            normalField[i] = new Vector3((float)(left - right), 64, (float)(back - front)).Normalized();
            curvatureField[i] = (float)((left + right + back + front - 4 * center) / 32);
        }
        ulong normalTime = profile ? Time.GetTicksUsec() : 0;
        var vertices = new Vector3[total]; var normals = new Vector3[total]; var colors = new Color[total]; var uvs = new Vector2[total]; var surfaceUvs = new Vector2[total];
        int stride = hasJungle || hasBadlands ? 4 : 3; var geologicalControls = new float[checked(total * stride)];
        var forestControls = hasForest || hasCoast || hasTropical ? new float[checked(total * 4)] : System.Array.Empty<float>();
        var savannaControls = hasSavanna || hasTropical ? new float[checked(total * 4)] : System.Array.Empty<float>();
        var swampControls = hasSwamp || hasTropical ? new float[checked(total * 4)] : System.Array.Empty<float>();
        for (int iz = 0; iz < row; iz++) for (int ix = 0; ix < row; ix++)
        {
            int vi = iz * row + ix, si = (iz + 1) * sampleSize + ix + 1; double x = ox + ix * step, z = oz + iz * step;
            vertices[vi] = new Vector3((float)(ix * step), heights[si], (float)(iz * step));
            double gx = x / normalStep - normalX, gz = z / normalStep - normalZ; int nx = Math.Min((int)Math.Floor(gx), width - 3), nz = Math.Min((int)Math.Floor(gz), depth - 3), ni = nz * width + nx;
            normals[vi] = normalField[ni].Lerp(normalField[ni + 1], (float)(gx - nx)).Lerp(normalField[ni + width].Lerp(normalField[ni + width + 1], (float)(gx - nx)), (float)(gz - nz)).Normalized();
            if (badlands is not null && remnants[si] > .000001)
            {
                var local = new Vector3((float)(field.normal_height(x - 2, z) - field.normal_height(x + 2, z)), 4, (float)(field.normal_height(x, z - 2) - field.normal_height(x, z + 2))).Normalized();
                double t = Math.Clamp(remnants[si] / .15, 0, 1); t = t * t * (3 - 2 * t); normals[vi] = normals[vi].Lerp(local, (float)t).Normalized();
            }
            colors[vi] = weights[si]; double curvature = L(L(curvatureField[ni], curvatureField[ni + 1], gx - nx), L(curvatureField[ni + width], curvatureField[ni + width + 1], gx - nx), gz - nz);
            uvs[vi] = new Vector2(swamp || mountain || coast || tropical || badlands is not null || extras ? waterValues[si] : (float)water, (float)curvature); surfaceUvs[vi] = surfaces[si]; var g = geology[si];
            geologicalControls[vi * stride] = g.X; geologicalControls[vi * stride + 1] = g.Y; geologicalControls[vi * stride + 2] = g.Z;
            if (hasJungle) geologicalControls[vi * 4 + 3] = jungleValues[si];
            if (hasForest) System.Array.Copy(forestValues[si], 0, forestControls, vi * 4, 4);
            if (hasSavanna) System.Array.Copy(savannaValues[si], 0, savannaControls, vi * 4, 4);
            if (hasSwamp) System.Array.Copy(swampValues[si], 0, swampControls, vi * 4, 4);
            if (hasMountain)
            {
                var m = mountainValues[si]; geologicalControls[vi * stride] = (float)(-field.pack(g.X, g.Y, g.Z) - 1); geologicalControls[vi * stride + 1] = m[0]; geologicalControls[vi * stride + 2] = m[1]; int q = (int)m[2];
                surfaceUvs[vi] = new Vector2((float)field.pack(surfaceUvs[vi].X, surfaceUvs[vi].Y, (q & 255) / 255.0), (float)field.pack(((q >> 8) & 255) / 255.0, ((q >> 16) & 255) / 255.0, m[3]));
            }
            if (hasCoast)
            {
                var c = coastValues[si]; double forestWater = forestControls[vi * 4 + 3];
                forestControls[vi * 4 + 2] = (float)(-field.pack(forestControls[vi * 4 + 2], c.X, c.Y) - 1);
                forestControls[vi * 4 + 3] = (float)field.pack(forestControls[vi * 4 + 3], c.Z, c.W);
                if (c.W < 0) { int sand = (int)(-c.W - 1); forestControls[vi * 4 + 3] = (float)(-field.pack(forestWater, (sand & 255) / 255.0, ((sand >> 8) & 255) / 255.0) - 1); }
            }
            if (hasTropical)
            {
                var t = tropicalValues[si]; int fi = (int)forestControls[vi * 4], sa = (int)savannaControls[vi * 4], wi = (int)swampControls[vi * 4];
                forestControls[vi * 4] = (float)(-((fi & 65535) + Round(t.Z * 255.0) * 65536.0) - 1);
                savannaControls[vi * 4] = (float)(-((sa & 65535) + Round(t.X * 255.0) * 65536.0) - 1);
                swampControls[vi * 4] = (float)(-((wi & 65535) + Round(t.Y * 255.0) * 65536.0) - 1);
            }
            if (hasBadlands)
            {
                var b = badlandsValues[si]; int curvatureByte = Round(Math.Clamp(curvature, -.5, .5) * 254) + 127;
                var uv = uvs[vi]; uv.Y = (float)(Round(b.X * 255.0) + Round(b.Z * 255.0) * 256 + curvatureByte * 65536); uvs[vi] = uv;
                geologicalControls[vi * 4 + 3] = -(hasJungle ? jungleValues[si] : 0) - 1;
            }
        }
        if (hasBadlands)
        {
            built_badlands_palette = new byte[checked(count * 4)];
            for (int z = 0; z < row; z++) for (int x = 0; x < row; x++)
            {
                int index = (z + 1) * sampleSize + x + 1; var palette = palettes[index];
                if (badlandsValues[index].X <= 0) palette = badlands!.material_palette(new Vector2((float)(ox + x * step), (float)(oz + z * step)));
                for (int c = 0; c < 4; c++) built_badlands_palette[(z * row + x) * 4 + c] = Byte(palette[c]);
            }
        }
        if (extras)
        {
            bool any = false; built_extension_data = new byte[checked(count * 8 * 4)]; built_extension_rows = row;
            for (int z = 0; z < row; z++) for (int x = 0; x < row; x++)
            {
                var payload = extraValues[(z + 1) * sampleSize + x + 1]; if (payload is null || payload.Length != 8) continue;
                for (int i = 0; i < 8; i++)
                {
                    var e = payload[i]; int offset = (z * row * 8 + i * row + x) * 4;
                    built_extension_data[offset] = Byte(e.X); if (built_extension_data[offset] > 0) built_extension_mask |= 1 << i;
                    built_extension_data[offset + 1] = Byte((double)e.Z * e.X); built_extension_data[offset + 2] = Byte((double)e.Y * e.X); built_extension_data[offset + 3] = Byte((double)e.W * e.X); any |= e.X > .5 / 255;
                }
            }
            if (!any) { built_extension_data = System.Array.Empty<byte>(); built_extension_rows = built_extension_mask = 0; }
        }
        if (hasBadlands)
        {
            if (built_extension_data.Length == 0) { built_extension_data = built_badlands_palette; built_extension_rows = row; built_badlands_palette_slot = 0; }
            else
            {
                var combined = new byte[checked(count * 9 * 4)];
                for (int z = 0; z < row; z++) { System.Array.Copy(built_extension_data, z * row * 8 * 4, combined, z * row * 9 * 4, row * 8 * 4); System.Array.Copy(built_badlands_palette, z * row * 4, combined, (z * row * 9 + row * 8) * 4, row * 4); }
                built_extension_data = combined; built_badlands_palette_slot = 8;
            }
        }
        if ((built_extension_mask & 128) != 0 && settings.Get("alien_infected").AsGodotObject().Get("nerve_flow_texturing").AsBool())
        {
            var flow = _tissue.atlas(host.Get("_extras").AsGodotArray()[7].AsGodotObject(), new Vector2((float)ox, (float)oz), chunkSize, resolution);
            built_alien_tissue_flow = flow["data"].AsByteArray(); built_alien_tissue_flow_rows = flow["rows"].AsInt32();
        }
        var boundary = Boundary(resolution);
        for (int i = 0; i < boundary.Count; i++)
        {
            int a = boundary[i], b = boundary[(i + 1) % boundary.Count], bottom = count + i * 2; double skirtDepth = Math.Max(32, step * 4);
            if (badlands is not null) skirtDepth += Math.Max(skirts[(a / row + 1) * sampleSize + a % row + 1], skirts[(b / row + 1) * sampleSize + b % row + 1]);
            Copy(a, bottom); Copy(b, bottom + 1); vertices[bottom] -= Vector3.Up * (float)skirtDepth; vertices[bottom + 1] -= Vector3.Up * (float)skirtDepth;
        }
        var arrays = new A(); arrays.Resize((int)Mesh.ArrayType.Max);
        arrays[(int)Mesh.ArrayType.Vertex] = vertices; arrays[(int)Mesh.ArrayType.Normal] = normals; arrays[(int)Mesh.ArrayType.Color] = colors;
        arrays[(int)Mesh.ArrayType.TexUV] = uvs; arrays[(int)Mesh.ArrayType.TexUV2] = surfaceUvs; arrays[(int)Mesh.ArrayType.Custom0] = geologicalControls;
        if (forestControls.Length > 0) arrays[(int)Mesh.ArrayType.Custom1] = forestControls;
        if (savannaControls.Length > 0) arrays[(int)Mesh.ArrayType.Custom2] = savannaControls;
        if (swampControls.Length > 0) arrays[(int)Mesh.ArrayType.Custom3] = swampControls;
        arrays[(int)Mesh.ArrayType.Index] = indices_for(resolution);
        if (profile) last_build_profile = new D { ["height_and_noise_ms"] = (heightTime - start) / 1000.0, ["normal_field_ms"] = (normalTime - heightTime) / 1000.0, ["mesh_arrays_ms"] = (Time.GetTicksUsec() - normalTime) / 1000.0 };
        return arrays;
        void Copy(int source, int target)
        {
            vertices[target] = vertices[source]; normals[target] = normals[source]; colors[target] = colors[source]; uvs[target] = uvs[source]; surfaceUvs[target] = surfaceUvs[source];
            System.Array.Copy(geologicalControls, source * stride, geologicalControls, target * stride, stride);
            if (forestControls.Length > 0) System.Array.Copy(forestControls, source * 4, forestControls, target * 4, 4);
            if (savannaControls.Length > 0) System.Array.Copy(savannaControls, source * 4, savannaControls, target * 4, 4);
            if (swampControls.Length > 0) System.Array.Copy(swampControls, source * 4, swampControls, target * 4, 4);
        }
    }
}
