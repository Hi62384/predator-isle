using System;

namespace PredatorIsle.Terrain;

/// <summary>Slow budget adaptation during ordinary play; geometry quality never oscillates with frame time.</summary>
public sealed class TerrainRingBudget
{
    private double averageFrame=1.0/60,elapsed,pressureTime,healthyTime;
    public int WorkerAllowance{get;private set;}
    public double UploadMilliseconds{get;private set;}
    public TerrainRingBudget(TerrainRingSettings settings){WorkerAllowance=Math.Max(1,settings.maximum_workers);UploadMilliseconds=settings.upload_budget_ms;}
    public void Observe(double frameSeconds,double previousUploadMilliseconds,TerrainRingSettings settings)
    {
        if(!double.IsFinite(frameSeconds)||frameSeconds<=0||frameSeconds>.5)return;elapsed+=frameSeconds;double weight=1-Math.Exp(-frameSeconds/2);averageFrame+=(frameSeconds-averageFrame)*weight;
        if(!settings.adaptive_budgets){WorkerAllowance=Math.Max(1,settings.maximum_workers);UploadMilliseconds=settings.upload_budget_ms;return;}
        bool pressure=averageFrame>1.0/45||previousUploadMilliseconds>settings.upload_budget_ms*1.5;pressureTime=pressure?pressureTime+frameSeconds:0;healthyTime=!pressure&&averageFrame<1.0/58?healthyTime+frameSeconds:0;
        if(pressureTime>=3){WorkerAllowance=Math.Max(1,WorkerAllowance-1);UploadMilliseconds=Math.Max(.25,UploadMilliseconds*.8);pressureTime=0;healthyTime=0;}
        else if(healthyTime>=10&&elapsed>=10){WorkerAllowance=Math.Min(settings.maximum_workers,WorkerAllowance+1);UploadMilliseconds=Math.Min(settings.upload_budget_ms,UploadMilliseconds+.25);healthyTime=0;}
        WorkerAllowance=Math.Clamp(WorkerAllowance,1,Math.Max(1,settings.maximum_workers));UploadMilliseconds=Math.Clamp(UploadMilliseconds,.25,Math.Max(.25,settings.upload_budget_ms));
    }
}
