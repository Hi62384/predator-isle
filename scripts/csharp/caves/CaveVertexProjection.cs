using Godot;
using System;
using System.Text.RegularExpressions;

namespace PredatorIsle.Caves;
public partial class CaveVertexProjection : RefCounted
{
    private const string ProjectionCall = "\n POSITION=cave_project_vertex(VERTEX,MODEL_MATRIX,VIEW_MATRIX,INV_VIEW_MATRIX,PROJECTION_MATRIX,MODELVIEW_MATRIX);\n";
    private const string Include = "\n#include \"res://shaders/cave_vertex_projection.gdshaderinc\"\n";
    public string source(string original) => Source(original);
    internal static string Source(string original)
    {
        if (original.Contains("cave_project_vertex(", StringComparison.Ordinal)) return original;
        var matches = Regex.Matches(original, @"void\s+vertex\s*\(\s*\)\s*\{");
        if (matches.Count != 1) return "";
        int start = matches[0].Index + matches[0].Length, depth = 1, cursor = start, end = -1;
        while (cursor < original.Length)
        {
            if (original.AsSpan(cursor).StartsWith("//"))
            { int newline = original.IndexOf('\n', cursor + 2); cursor = newline < 0 ? original.Length : newline + 1; continue; }
            if (original.AsSpan(cursor).StartsWith("/*"))
            { int close = original.IndexOf("*/", cursor + 2, StringComparison.Ordinal); if (close < 0) return ""; cursor = close + 2; continue; }
            if (original[cursor] == '{') depth++;
            else if (original[cursor] == '}' && --depth == 0) { end = cursor; break; }
            cursor++;
        }
        if (end < 0) return "";
        int header = original.IndexOf("render_mode ", StringComparison.Ordinal);
        int declarationStart = header >= 0 ? header : original.IndexOf("shader_type spatial", StringComparison.Ordinal);
        if (declarationStart < 0) return "";
        int declaration = original.IndexOf(';', Math.Max(0, declarationStart));
        if (declaration < 0 || declaration >= start) return "";
        return original[..(declaration + 1)] + Include + original[(declaration + 1)..end] + ProjectionCall + original[end..];
    }
}
