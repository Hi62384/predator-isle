using Godot;
using System;
using System.Collections.Generic;
using D = Godot.Collections.Dictionary;
using static PredatorIsle.Caves.CaveField;

namespace PredatorIsle.Caves;

internal static class CaveFieldEvaluation
{
    /// <summary>Conservative sign-only evaluation for skipped GPU cubes.
    /// The exact projection and roof/depth tests are retained. Wall noise and
    /// style offsets have known bounded amplitudes. For the power arches
    /// (p >= 2), max(|x|,|y|) <= Lp <= Euclidean; a generous relative margin
    /// rejects uncertain near-surface arithmetic instead of trusting a GPU sign.
    /// Returns null whenever these bounds cannot determine the canonical sign.</summary>
    internal static bool? CertifySign(CaveField f,Vector3 point,double ground,double? top=null)
    {
        if(!CaveField.SafePoint(point))return false;
        if(top.HasValue)
        {
            if(!double.IsFinite(top.Value))return false;
            if((float)(top.Value-point.Y)<0)return true;
            if(f is PortalCaveField { RoundEntrance: true } &&
                top.Value - point.Y < PortalCaveField.EntranceFillet)return null;
        }
        if(!f.Bins.TryGetValue(f.bin_cell(point),out var features))return false;
        if(!double.IsFinite(ground))return false;
        double depth=ground-point.Y;
        if(depth>=f.maximum_depth)return false;
        const double margin=.0001;
        // Anything extremely close to a depth constraint takes the original
        // scalar path (including float-cast signed-zero behavior).
        bool closedAllowed=depth>f.minimum_roof;
        bool openingAllowed=f.opening_rock_cover<=0||depth>f.opening_rock_cover;
        if(!closedAllowed&&!openingAllowed)return false;
        bool floorReliefPossible=false;
        if(f.floor_relief.Count>0)
            foreach(int feature in features)
                if((f.Kinds[feature] is 2 or 4)&&Math.Abs((double)point.Y-f.Begins[feature].Y)<=5)
                {floorReliefPossible=true;break;}
        bool uncertain=false;
        foreach(int feature in features)
        {
            int kind=f.Kinds[feature];if(kind is 3 or 4)return null;bool opening=kind==1;
            if(opening?!openingAllowed:!closedAllowed)continue;
            var a=f.Begins[feature];var b=f.Ends[feature];var size=f.Dimensions[feature];
            double floorY=a.Y,radius;
            if(kind==2)radius=new Vector2(point.X-a.X,point.Z-a.Z).Length();
            else
            {
                var ab=f.Directions[feature];var q=new Vector2(point.X-a.X,point.Z-a.Z);
                double along=q.Dot(ab)/f.SpanSquared[feature],t=Math.Clamp(along,0,1);
                radius=(q-ab*(float)t).Length();floorY=Lerp(a.Y,b.Y,along);
                if(f.continuous_route_floors)
                {
                    if(along<0&&double.IsFinite(f.EndpointGrades[feature*2]))
                        floorY=a.Y+along*f.SpanLength[feature]*f.EndpointGrades[feature*2];
                    else if(along>1&&double.IsFinite(f.EndpointGrades[feature*2+1]))
                        floorY=b.Y+(along-1)*f.SpanLength[feature]*f.EndpointGrades[feature*2+1];
                }
            }
            double y=point.Y-floorY;
            if(!double.IsFinite(y)||!double.IsFinite(radius)){uncertain=true;continue;}
            if(y<=0)continue; // the flat floor alone guarantees rock
            double radial=radius/size.X,vertical=(y-f.ArchCenter[feature])/f.ArchHeight[feature],
                scale=f.ArchScale[feature];
            if(!double.IsFinite(radial)||!double.IsFinite(vertical)||!double.IsFinite(scale)||scale<=0)
            {uncertain=true;continue;}
            int style=f.Styles[feature];
            double lower,upper;
            if(style is 1 or 2 or 3 or 5)
            {
                double r=Math.Abs(radial),v=Math.Abs(vertical);
                // Loosen the mathematical norm bounds enough to cover
                // ordinary double pow/sqrt rounding at all supported sizes.
                double lo=Math.Max(r,v),hi=Math.Sqrt(r*r+v*v);
                lower=(lo-1)*scale-margin*(1+lo*scale);
                upper=(hi-1)*scale+margin*(1+hi*scale);
            }
            else
            {
                // Identical float-vector norm to the canonical evaluator.
                double arch=(new Vector2((float)radial,(float)vertical).Length()-1.0)*scale;
                lower=upper=arch;
            }
            double shift=style==7?.65:style==3?.24:(style is 2 or 4) ? .12 : 0;
            if(double.IsFinite(lower)&&lower-shift-.12>margin)continue;
            bool floorUnknown=kind==2&&floorReliefPossible;
            bool depthSafe=f.maximum_depth-depth>margin&&
                (opening?f.opening_rock_cover<=0||depth-f.opening_rock_cover>margin:depth-f.minimum_roof>margin);
            if(!floorUnknown&&depthSafe&&y>margin&&double.IsFinite(upper)&&upper+.12<-margin)return true;
            uncertain=true;
        }
        return uncertain?null:false;
    }

    // Negative values are open air. The rock separating the two levels
    // widens at the abutments and arches upward over the lower crossing.
    private static double Vault(Vector3 p,Vector3 floor,double span,out double retainedRock)
    {
        double angle=Math.Sin(floor.X*.031+floor.Z*.013)*Math.PI;
        double dx=p.X-floor.X,dz=p.Z-floor.Z;
        double x=dx*Math.Cos(angle)+dz*Math.Sin(angle),z=dz*Math.Cos(angle)-dx*Math.Sin(angle), y=p.Y-floor.Y;
        double phase=floor.X*.043;
        double shoulder=Math.Sin(z*.089+phase)*3.1+Math.Sin(x*.14+y*.16)*1.7;
        double r=Math.Sqrt(Math.Pow((x+shoulder)/(.84*span),2)+Math.Pow((z-3*Math.Sin(x*.073))/span,2));
        // A sloping perimeter bench climbs to both bridgeheads from the lower floor.
        double approach=Smooth(.38,.78,Math.Abs(x)/span);
        double ledge=(18+.055*x)*approach+7*Smooth(.55,.95,r)*(1-approach);
        ledge+=1.8*Math.Sin(z*.13+phase)*Smooth(.25,.75,r);
        double structure=Math.Sin(phase);
        // A stepped bedding plane makes a second walkable shelf in deeper bowls.
        if(structure>.35)ledge+=7*Smooth(.19,.54,z/span)*Smooth(.3,.72,r);
        double bed=ledge+2*Math.Sin(x*.12+phase)*Math.Cos(z*.074)+1.1*Math.Sin(z*.22);
        double roof=32+13*(1-r*r)+5*Math.Sin(x*.065+phase)+4*Math.Cos(z*.081);
        double flute=Math.Sin(x*.093-z*.11+y*.07+phase);
        double wall=(r-1)*span+3*Math.Sin(y*.25+x*.055)+2.2*Math.Cos(z*.21+y*.12)+3.6*flute*flute;
        roof-=3*Math.Abs(Math.Sin(x*.12+z*.07+phase))+2*Math.Sin(z*.19);
        double air=Math.Max(wall,Math.Max(bed-y,y-roof));
        double az=Math.Abs(x)/span;
        double axis=4*Math.Sin(x*.067+phase)+2.5*Math.Sin(x*.12+phase*.6);
        double deck=17+1.2*Math.Cos(x*.081)+x*.035;
        double soffit=deck-3.6-15*Math.Pow(Math.Min(1,az*1.5),2);
        double bank=Math.Abs(z-axis)-(3.3+6*az*az+1.1*Math.Cos(x*.17));
        double stone=Math.Max(bank,Math.Max(y-deck,soffit-y));
        if(structure>-.35 && structure<.35){
            // A buttress beneath the deck separates the two lower arches.
            double buttress=Math.Abs(x-5-2*Math.Sin(z*.13))-(3+5*Math.Pow(Math.Clamp((y-7)/13,-1,1),2));
            stone=Math.Min(stone,Math.Max(Math.Max(buttress,bank-2),y-deck));
        }else if(structure>=.35){
            // An oblique shelf splits off from the bridge and descends into the side wall.
            double run=Math.Clamp((x+17)/38,0,1);
            double fork=axis+run*run*27;
            double top=deck-6*run;
            double slab=Math.Max(Math.Abs(z-fork)-(3.4+2.8*run),Math.Max(y-top,top-4.8-y));
            stone=Math.Min(stone,Math.Max(slab,-18-x));
        }
        // Isolated remnants of the bedrock divide some chambers into aisles.
        // Their flared bases and crown merge with the bed and ceiling.
        int piers=(int)(1.5+1.49*Math.Sin(phase));
        for(int i=0;i<piers;i++){
            double px=span*(i==0 ? -.41 : .37)+2*Math.Sin(y*.09+phase);
            double pz=span*(i==0 ? .29 : -.32)+1.8*Math.Cos(y*.12+phase);
            double flare=4.2+6*Math.Pow(Math.Clamp(Math.Abs((y-19)/23),0,1),2);
            double pier=Math.Sqrt((x-px)*(x-px)*.72+(z-pz)*(z-pz)*1.55)-flare;
            stone=Math.Min(stone,pier);
        }
        retainedRock=Math.Min(-stone,-air);
        return Math.Max(air,-stone);
    }

    // Bounded freeform chamber. The horizontal axes, height envelope,
    // terraces and occasional off-centre stone rib are independently varied.
    // Match cave_lattice_gpu.gdshader; exact scalar/normal/mesh authority is CPU.
    private static double WarpedRoom(Vector3 p,Vector3 a,Vector2 size,Vector2 direction,double minor,int style,double wall,double floorOffset)
    {
        double ux=direction.X/minor,uz=direction.Y/minor;
        double dx=(double)p.X-a.X,dz=(double)p.Z-a.Z;
        double u=(dx*ux+dz*uz)/size.X,v=(-dx*uz+dz*ux)/minor;
        double y=(double)p.Y-a.Y,phase=ux*2.3+uz*3.7+style*.73+size.X*.019+minor*.031+size.Y*.023;
        double layer=Math.Clamp(y/size.Y,0,1);
        // The axes drift and twist through the elevation of the room, while
        // angular dissolution and bedding independently change each section.
        double twist=.46*Math.Sin(phase*1.7)*(layer-.5);
        double cu=u*Math.Cos(twist)-v*Math.Sin(twist),cv=u*Math.Sin(twist)+v*Math.Cos(twist);
        cu-=.15*Math.Sin(layer*5+phase)*layer;cv-=.13*Math.Cos(layer*4-phase)*layer;
        double r=Math.Sqrt(cu*cu+cv*cv);
        double warp=.68+.16*Math.Sin(cu*5+cv*3+phase)+.10*Math.Sin(cv*7-cu*2+phase*1.7)+.06*Math.Cos(layer*11+cu*4-phase);
        double rise=Smooth(.25,.85,r)*Math.Min(size.Y*.20,7)*(.5+.5*Math.Sin(u*5-v*3+phase));
        double ceiling=size.Y*(.56+.44*(.5+.5*Math.Sin(u*3+v*4+phase)));
        double h=Math.Max(1,ceiling-rise);
        double radial=r/Math.Max(.34,warp),vertical=(y-rise-h*.45)/(h*.55);
        double power=2+2.6*(.5+.5*Math.Sin(phase));
        double arch=(Math.Pow(Math.Pow(Math.Abs(radial),power)+Math.Pow(Math.Abs(vertical),power),1/power)-1)*Math.Min(minor,h*.55);
        double value=Math.Max(rise+floorOffset-y,arch+wall);
        // Raised side galleries can leave a natural arch or terrace. This
        // feature's solid is local to its own room, never a global subtraction
        // from other graph routes, biome chambers, or the protected core.
        if(size.X>=15&&size.Y>=20)
        {
            double ru=u-(.53+.09*Math.Sin(phase+y*.13));
            double rv=v-(.28+.07*Math.Cos(phase-y*.11));
            double rib=(Math.Sqrt(ru*ru+rv*rv)-(.07+.055*Math.Abs(Math.Sin(phase+y*.17))))*minor;
            if(Math.Cos(phase)>.0)value=Math.Max(value,-rib);
            double shelfWidth=.16+.12*(.5+.5*Math.Sin(phase*1.9));
            double shelfY=size.Y*(.36+.12*Math.Sin(phase*1.3));
            double shelf=Math.Max((Math.Abs(u-.58)-shelfWidth)*size.X,Math.Abs(y-shelfY)-Math.Max(1,size.Y*.055));
            shelf=Math.Max(shelf,(Math.Abs(v+.12)-.42)*minor);
            if(Math.Sin(phase*1.4)>.12)value=Math.Max(value,-shelf);
        }
        return value;
    }

    internal static double Evaluate(CaveField f, Vector3 point, ReadOnlySpan<int> features)
    {
        double closed = Far, opening = Far, floorOffset = 0, retainedRock = -Far;
        if (f.floor_relief.Count > 0)
            foreach (int feature in features)
                if ((f.Kinds[feature] is 2 or 4) && Math.Abs((double)point.Y - f.Begins[feature].Y) <= 5)
                {
                    foreach (var pair in f.floor_relief) floorOffset = Math.Max(floorOffset, FloorRelief.Offset(f, point, pair.Value.AsDouble(), pair.Key.AsString()));
                    break;
                }
        double wall = Math.Sin(point.X * .71 + Math.Sin(point.Y * .23)) * Math.Sin(point.Z * .53 + point.Y * .41) * .12;
        foreach (int feature in features)
        {
            var a = f.Begins[feature]; var b = f.Ends[feature]; var size = f.Dimensions[feature]; double floorY = a.Y, radius;
            if(f.Kinds[feature]==4)
            {
                closed=Math.Min(closed,WarpedRoom(point,a,size,f.Directions[feature],f.SpanLength[feature],f.Styles[feature],wall,floorOffset));
                continue;
            }
            if(f.Kinds[feature]==3){closed=Math.Min(closed,Vault(point,a,size.X,out var rock));retainedRock=Math.Max(retainedRock,rock);continue;}
            if (f.Kinds[feature] == 2) radius = new Vector2(point.X - a.X, point.Z - a.Z).Length();
            else
            {
                var ab = f.Directions[feature]; var q = new Vector2(point.X - a.X, point.Z - a.Z); double along = q.Dot(ab) / f.SpanSquared[feature], t = Math.Clamp(along, 0, 1);
                radius = (q - ab * (float)t).Length(); floorY = Lerp(a.Y, b.Y, along);
                if (f.continuous_route_floors)
                {
                    if (along < 0 && double.IsFinite(f.EndpointGrades[feature * 2])) floorY = a.Y + along * f.SpanLength[feature] * f.EndpointGrades[feature * 2];
                    else if (along > 1 && double.IsFinite(f.EndpointGrades[feature * 2 + 1])) floorY = b.Y + (along - 1) * f.SpanLength[feature] * f.EndpointGrades[feature * 2 + 1];
                }
            }
            double y = point.Y - floorY;
            double arch = (new Vector2((float)(radius / size.X), (float)((y - f.ArchCenter[feature]) / f.ArchHeight[feature])).Length() - 1.0) * f.ArchScale[feature];
            int style = f.Styles[feature];
            if (style is 1 or 2 or 3 or 5)
            {
                double exponent = style == 1 ? 4 : style == 2 ? 3.4 : style == 3 ? 2.8 : 2.5;
                double radial = Math.Abs(radius / size.X), vertical = Math.Abs((y - f.ArchCenter[feature]) / f.ArchHeight[feature]);
                arch = (Math.Pow(Math.Pow(radial, exponent) + Math.Pow(vertical, exponent), 1 / exponent) - 1) * f.ArchScale[feature];
            }
            if (style is 2 or 3 or 4)
            {
                double joint = .5 + .5 * Math.Sin(point.Y * (style == 2 ? .61 : .19) + point.X * .013 + point.Z * .017);
                arch -= joint * (style == 3 ? .24 : .12) * Smooth(0, 1, y);
            }
            if (style == 7)
            {
                double phase = f.Kinds[feature] == 2 ? Math.Atan2((double)point.Z - a.Z, (double)point.X - a.X) * 9 : radius * .37 + point.X * .08 + point.Z * .11;
                double fold = .5 + .5 * Math.Sin(phase + y * .43 + Math.Sin(point.Y * .13) * .8); arch -= fold * fold * .65 * Smooth(1, 4, y);
            }
            double value = Math.Max(-y, arch + wall);
            if (floorOffset > 0 && f.Kinds[feature] == 2) value = Math.Max(value, -y + floorOffset);
            if (f.Kinds[feature] == 1) opening = Math.Min(opening, value); else closed = Math.Min(closed, value);
        }
        if (Math.Min(closed, opening) >= Far) return Far;
        double ground = f.ground_height(point); if (!double.IsFinite(ground)) return Far;
        double depth = ground - point.Y;
        if (f.opening_rock_cover > 0) opening = Math.Max(opening, f.opening_rock_cover - depth);
        return Math.Min(Far, Math.Max(retainedRock,Math.Max(Math.Min(Math.Max(closed, f.minimum_roof - depth), opening), depth - f.maximum_depth)));
    }
}

internal static class FloorRelief
{
    internal static double Wave(Vector3 point)
    {
        double x = point.X % 3840.0, z = point.Z % 3840.0; if (x < 0) x += 3840; if (z < 0) z += 3840;
        double phase = Math.Tau * (x * .6 + z * .8) / 24 + .4 * Math.Sin(Math.Tau * z / 96) * Math.Sin(Math.Tau * x / 120), u = .5 + .5 * Math.Sin(phase);
        return u * u * u * u;
    }
    internal static double Offset(CaveField f, Vector3 point, double strength, string biome)
    {
        if (strength <= 0 || !f.BiomeFields.TryGetValue(biome, out var field)) return 0;
        double admission = f.biome_admission(point); if (admission <= 0) return 0;
        double amount = 0, mask = 1;
        if (f.Bins.TryGetValue(f.bin_cell(point), out var features))
            foreach (int feature in features)
            {
                var a = f.Begins[feature]; var b = f.Ends[feature]; var q = new Vector2(point.X - a.X, point.Z - a.Z);
                double t = 0, distance = q.Length(), floorY = a.Y, width = f.Dimensions[feature].X;
                if (f.Kinds[feature] is not (2 or 4))
                {
                    t = Math.Clamp(q.Dot(f.Directions[feature]) / f.SpanSquared[feature], 0, 1); distance = (q - f.Directions[feature] * (float)t).Length(); floorY = Lerp(a.Y, b.Y, t);
                }
                double vertical = 1 - Smooth(2, 4, Math.Abs(point.Y - floorY)); var weights = field[feature];
                double raw = Lerp(weights.X, weights.Y, t), support = 1 - Smooth(width * .6, width * .6 + 4, distance); amount = Math.Max(amount, raw * vertical * support);
                if (f.Kinds[feature] is not (2 or 4)) mask = Math.Min(mask, 1 - vertical + vertical * Smooth(width + 1, width + 4, distance));
            }
        foreach (var item in f._protected_shores)
        {
            var shore = item.AsGodotDictionary(); var center = shore["center"].AsVector3(); double radius = new Vector2(point.X - center.X, point.Z - center.Z).Length();
            double ring = Smooth(Num(shore, "inner") - 3, Num(shore, "inner"), radius) * (1 - Smooth(Num(shore, "outer"), Num(shore, "outer") + 3, radius));
            double vertical = Smooth(Num(shore, "low") - 4, Num(shore, "low"), point.Y) * (1 - Smooth(Num(shore, "high"), Num(shore, "high") + 4, point.Y)); mask = Math.Min(mask, 1 - ring * vertical);
        }
        return Wave(point) * Math.Clamp(strength, 0, 1) * Math.Clamp(amount, 0, 1) * Math.Clamp(mask, 0, 1) * admission;
    }
}
