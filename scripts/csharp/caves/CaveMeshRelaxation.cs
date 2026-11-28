using Godot;
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace PredatorIsle.Caves;

internal sealed class CaveMeshRelaxation
{
    private struct Corner
    {
        public Vector3 Point, Adjusted, Normal, Offset;
        public float Area;
        public bool Fixed;
    }

    private readonly record struct Face(int A, int B, int C, Vector3 Cross);
    private readonly Dictionary<Vector3, int> _byPosition = new();
    private readonly List<Corner> _corners = new();
    private readonly List<Face> _faces = new();
    private readonly Dictionary<(int, int, int), int> _flatFaces = new();
    private readonly HashSet<int> _discardedFaces = new();

    public void Clear()
    {
        _byPosition.Clear();
        _corners.Clear();
        _faces.Clear();
        _flatFaces.Clear();
        _discardedFaces.Clear();
    }

    private int Index(Vector3 point)
    {
        ref int index = ref CollectionsMarshal.GetValueRefOrAddDefault(_byPosition, point, out bool exists);
        if (!exists)
        {
            index = _corners.Count;
            _corners.Add(new Corner { Point = point, Adjusted = point });
        }
        return index;
    }

    public void Add(Vector3 a, Vector3 b, Vector3 c, Vector3 cross)
    {
        int first = Index(a), second = Index(b), third = Index(c);
        // Zeros on a lattice face can emit the same triangle from both sides.
        // Opposite winding here encloses no rock, so discard both copies.
        if ((a.X == b.X && b.X == c.X && a.X % 2 == 0) ||
            (a.Y == b.Y && b.Y == c.Y && a.Y % 2 == 0) ||
            (a.Z == b.Z && b.Z == c.Z && a.Z % 2 == 0))
        {
            int low = Math.Min(first, Math.Min(second, third));
            int high = Math.Max(first, Math.Max(second, third));
            var key = (low, first + second + third - low - high, high);
            if (!_flatFaces.TryAdd(key, _faces.Count))
            {
                int prior = _flatFaces[key];
                if (_faces[prior].Cross.Dot(cross) < 0) _discardedFaces.Add(prior);
                return;
            }
        }
        _faces.Add(new Face(first, second, third, cross));
    }

    public void Write(ICaveField field, Vector3 origin, bool portal, bool preciseShore,
        List<Vector3> vertices, List<Vector3> normals)
    {
        var corners = CollectionsMarshal.AsSpan(_corners);
        var faces = CollectionsMarshal.AsSpan(_faces);
        for (int i = 0; i < faces.Length; i++)
        {
            if (_discardedFaces.Contains(i)) continue;
            var face = faces[i];
            ref var a = ref corners[face.A];
            ref var b = ref corners[face.B];
            ref var c = ref corners[face.C];
            float area = face.Cross.Length();
            var center = (a.Point + b.Point + c.Point) / 3;
            Accumulate(ref a, center, face.Cross, area);
            Accumulate(ref b, center, face.Cross, area);
            Accumulate(ref c, center, face.Cross, area);
        }
        foreach (ref var corner in corners)
        {
            if (corner.Area == 0) continue;
            var local = corner.Point - origin;
            corner.Fixed = local.X is 0 or 64 || local.Y is 0 or 64 || local.Z is 0 or 64;
            var normal = corner.Normal.Normalized();
            bool terrain = portal && normal.Y > .25f &&
                Math.Abs(field.SurfaceHeight(new Vector2(corner.Point.X, corner.Point.Z)) - corner.Point.Y) < 1.25;
            if (corner.Fixed || terrain || preciseShore) continue;
            float offset = (corner.Offset / corner.Area).Dot(normal);
            corner.Adjusted += normal * Mathf.Clamp(offset * .92f, -.40f, .40f);
        }
        // Moving a corner shared by several faces must preserve every face's winding.
        // Reset corners of any face that would fold and recheck its neighbours.
        bool changed;
        do
        {
            changed = false;
            for (int i = 0; i < faces.Length; i++)
            {
                if (_discardedFaces.Contains(i)) continue;
                var face = faces[i];
                ref var a = ref corners[face.A];
                ref var b = ref corners[face.B];
                ref var c = ref corners[face.C];
                var cross = (c.Adjusted - a.Adjusted).Cross(b.Adjusted - a.Adjusted);
                if (cross.Dot(face.Cross) >= .12f * face.Cross.LengthSquared() ||
                    a.Adjusted == a.Point && b.Adjusted == b.Point && c.Adjusted == c.Point) continue;
                a.Adjusted = a.Point;
                b.Adjusted = b.Point;
                c.Adjusted = c.Point;
                changed = true;
            }
        } while (changed);

        foreach (ref var corner in corners) corner.Normal = Vector3.Zero;
        for (int i = 0; i < faces.Length; i++)
        {
            if (_discardedFaces.Contains(i)) continue;
            var face = faces[i];
            ref var a = ref corners[face.A];
            ref var b = ref corners[face.B];
            ref var c = ref corners[face.C];
            var cross = (c.Adjusted - a.Adjusted).Cross(b.Adjusted - a.Adjusted);
            a.Normal += cross;
            b.Normal += cross;
            c.Normal += cross;
        }
        foreach (ref var corner in corners)
            corner.Normal = corner.Fixed ? field.Normal(corner.Point) : corner.Normal.Normalized();
        for (int i = 0; i < faces.Length; i++)
        {
            if (_discardedFaces.Contains(i)) continue;
            var face = faces[i];
            var a = corners[face.A];
            var b = corners[face.B];
            var c = corners[face.C];
            var normal = (c.Adjusted - a.Adjusted).Cross(b.Adjusted - a.Adjusted).Normalized();
            WriteCorner(a, normal);
            WriteCorner(b, normal);
            WriteCorner(c, normal);
        }

        void WriteCorner(Corner corner, Vector3 faceNormal)
        {
            vertices.Add(corner.Adjusted - origin);
            var normal = corner.Normal;
            float alignment = normal.Dot(faceNormal);
            // Keep the shared normals for smooth walls but keep them in the
            // front hemisphere on tight folds and at floor-wall junctions.
            normals.Add(alignment < .15f ? (normal + faceNormal * (.35f - alignment)).Normalized() : normal);
        }
    }

    private static void Accumulate(ref Corner corner, Vector3 center, Vector3 cross, float area)
    {
        corner.Normal += cross;
        corner.Offset += (center - corner.Point) * area;
        corner.Area += area;
    }
}
