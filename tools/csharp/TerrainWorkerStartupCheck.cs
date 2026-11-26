using Godot;
using System;
using System.Linq;
using System.Threading.Tasks;
using PredatorIsle.Terrain;
using PredatorIsle.Biomes;

namespace PredatorIsle.Checks;

public partial class TerrainWorkerStartupCheck : Node
{
    public override async void _Ready()
    {
        try
        {
            TerrainWorkerScripts.Prepare();
            if (TerrainWorkerScripts.RetainedCount != 7) throw new Exception("Missing retained worker scripts");
            int constructions = 0;
            for (int wave = 0; wave < 4; wave++)
            {
                GC.Collect(); GC.WaitForPendingFinalizers(); GC.Collect();
                var work = Enumerable.Range(0, 8).Select(_ => Task.Run(() =>
                {
                    for (int repeat = 0; repeat < 8; repeat++)
                    {
                        using var features = new TerrainFeatureMeshes();
                        using var structures = new LodBiomeStructureGeometry();
                        using var collision = new TerrainCollision();
                        using var coordinates = new AlienTissueCoordinates();
                        foreach (GodotObject helper in new GodotObject[] { features, structures, collision, coordinates })
                        {
                            if (helper.GetScript().VariantType == Variant.Type.Nil)
                                throw new Exception("Worker helper lost its native script binding");
                            System.Threading.Interlocked.Increment(ref constructions);
                        }
                    }
                })).ToArray();
                await Task.WhenAll(work);
            }
            bool rejected = await Task.Run(() =>
            {
                try { TerrainWorkerScripts.Prepare(); return false; }
                catch (InvalidOperationException) { return true; }
            });
            if (!rejected) throw new Exception("Worker-thread registration was allowed");
            GD.Print($"TERRAIN_WORKER_STARTUP_PASS: {constructions} concurrent constructions, four GC waves, main-thread guard");
            GetTree().Quit();
        }
        catch (Exception error) { GD.PushError(error.ToString()); GetTree().Quit(1); }
    }
}
