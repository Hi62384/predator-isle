shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Cached numerical terrain generation. RGBA8 stores the IEEE-754 bits of one
// scalar per texel; alpha is data, not transparency. Never color-correct this map.
#include "res://shaders/grassland_gpu_noise.gdshaderinc"
uniform sampler2D sample_positions : filter_nearest, repeat_disable;
uniform sampler2D planned_rivers : filter_nearest, repeat_disable;
uniform sampler2D planned_lakes : filter_nearest, repeat_disable;
uniform int river_columns = 1;
uniform int lake_columns = 1;
uniform int sample_count = 0;
uniform int sample_columns = 512;
uniform int sample_rows = 1;
uniform int position_rows = 2;
uniform int world_seed = 0;
uniform int noise_seed[7];
uniform int noise_octaves[7];
uniform vec4 noise_config[7]; // frequency, gain, lacunarity, fractal bounding
uniform vec2 noise_offset[7];
uniform float g_cliff_width;
uniform float g_erosion_strength;
uniform float g_escarpment_strength;
uniform float g_field_spacing;
uniform float g_foothill_size;
uniform float g_fractal_strength;
uniform float g_geographic_scale;
uniform float g_geographic_variety;
uniform float g_hill_frequency;
uniform float g_hill_height;
uniform float g_lake_depth;
uniform float g_lake_frequency;
uniform float g_lake_size;
uniform float g_landform_size;
uniform float g_local_detail;
uniform float g_macro_height;
uniform float g_mountain_frequency;
uniform float g_mountain_height;
uniform float g_mountain_ruggedness;
uniform float g_plains_flatness;
uniform float g_plains_frequency;
uniform float g_plateau_erosion;
uniform float g_plateau_frequency;
uniform float g_plateau_height;
uniform float g_ridge_strength;
uniform float g_river_depth;
uniform float g_river_frequency;
uniform float g_river_width;
uniform float g_rolling_strength;
uniform float g_talus_relief;
uniform float g_talus_width;
uniform float g_valley_strength;

float L(float a,float b,float t) { return a+(b-a)*t; }
float C(float v) { return clamp(v,0.0,1.0); }
float C(float v,float a,float b) { return clamp(v,a,b); }
float S(float a,float b,float v) { float t=C((v-a)/(b-a)); return t*t*(3.0-2.0*t); }
int Round(float v) { return int(sign(v)*floor(abs(v)+0.5)); }
float Random(int x,int z,int biome,int salt) {
 uint h=uint(x)*73856093u ^ uint(z)*19349663u ^ uint(world_seed)*83492791u ^ uint(biome)*2654435761u ^ uint(salt);
 h=(h^(h>>16u))*73244475u;
 h=(h^(h>>16u))*73244475u;
 h=h^(h>>16u);
 return float(h)/4294967296.0;
}
float N(int index,float x,float z) {
 vec4 config=noise_config[index];
 x=(x+noise_offset[index].x)*config.x;
 z=(z+noise_offset[index].y)*config.x;
 const float F2=0.366025388240814208984375; // CPU float-rounded skew constant.
 float t=(x+z)*F2; x+=t; z+=t;
 float value=0.0, amplitude=config.w;
 int seed=noise_seed[index];
 for(int octave=0;octave<noise_octaves[index];octave++) {
  value+=grass_noise_simplex(seed,x,z)*amplitude;
  seed++; x*=config.z; z*=config.z; amplitude*=config.y;
 }
 return value;
}
vec4 river_plan(int index) { return texelFetch(planned_rivers,ivec2(index%river_columns,index/river_columns),0); }
vec4 lake_plan(int index) { return texelFetch(planned_lakes,ivec2(index%lake_columns,index/lake_columns),0); }

vec4 prepared_input(int index,int band) { return texelFetch(sample_positions,ivec2(index%sample_columns,index/sample_columns+position_rows*band),0); }

struct GrassSample { vec3 value; vec2 surface; vec3 geology; float detail_weight; };
GrassSample sample_raw(float x,float z,int river_index,int lake_index,int sample_index) {
        vec4 affine_a=prepared_input(sample_index,1),affine_b=prepared_input(sample_index,2),affine_c=prepared_input(sample_index,3),affine_d=prepared_input(sample_index,4),affine_e=prepared_input(sample_index,5);
        float regionValue = affine_a.x;
        vec2 province = affine_a.zw; float variety = g_geographic_variety;
        float calm = (1.0 - S(.34, .49, province.x)) * variety, folded = S(.48, .65, province.x) * variety;
        float basinCountry = (1.0 - S(.40, .56, province.x)) * S(.45, .64, province.y) * variety;
        float canyonCountry = S(.50, .65, province.x) * (1.0 - S(.44, .60, province.y)) * variety;
        float humid = S(.46, .59, province.y), waterCountry = L(1.0, humid, variety);
        float plains = g_plains_frequency > 0.0 ? 1.0 - S(g_plains_frequency - .08, g_plains_frequency + .14, regionValue) : 0.0;
        float hills = g_hill_frequency > 0.0 ? S(1.0 - g_hill_frequency - .2, 1.0 - g_hill_frequency + .1, regionValue) * (1.0 - plains) : 0.0;
        float mountains = g_mountain_frequency > 0.0 ? S(1.0 - g_mountain_frequency - .28, 1.0 - g_mountain_frequency + .12, regionValue) : 0.0;
        plains = max(plains, calm); hills *= 1.0 - calm;
        mountains = C(mountains * L(1.0, .3 + folded * 1.4, variety) * (1.0 - calm));
        mountains = max(mountains, folded * S(.28, .52, regionValue) * .9);
        float plateauDistance = affine_a.y; // Canonical geological placement, before local relief.
        float plateau = 0.0, wallPrecision = 0.0, talus = 0.0, incision = 0.0, cliffControl = 0.0, crest = 0.0;
        float macroValue = N(1, x, z), roll = N(2,affine_b.z,affine_b.w), structure = N(3,affine_c.x,affine_c.y);
        plateauDistance += structure * 90.0 + roll * 65.0;
        bool needsGeology = mountains > .001 || (g_plateau_frequency > 0.0 && plateauDistance > -g_talus_width * 3.6 - 100.0);
        float lithology = needsGeology ? N(2,affine_c.z,affine_c.w) : 0.0;
        float drainageAxis = needsGeology ? N(2,affine_d.x,affine_d.y) : 0.0;
        if (g_plateau_frequency > 0.0)
        {
            if (abs(plateauDistance) < max(g_talus_width, g_cliff_width * 3.0) + 100.0) plateauDistance += N(2,affine_e.x,affine_e.y) * 90.0;
            plateau = S(-g_talus_width, 0.0, plateauDistance); mountains *= 1.0 - plateau;
        }
        hills *= 1.0 - mountains * .85;
        float divide = 1.0 - sqrt(structure * structure + .0064), flatness = plains * C(g_plains_flatness);
        float relief = 10.0 + (macroValue * .5 + .5) * g_macro_height * (1.0 - flatness * .95);
        relief += roll * g_rolling_strength * (1.0 - flatness);
        relief += (roll * roll * 2.0 + roll) * g_hill_height * 5.0 * hills;
        relief += (divide * divide - .55) * g_hill_height * 3.0 * hills;
        relief += (roll * 1.6 + (divide - .65) * 2.0) * plains;
        relief += folded * hills * (divide * divide * divide - .45) * g_hill_height * 4.0;
        relief = L(relief, 6.0 + roll * 3.0, basinCountry * (1.0 - mountains) * .8);
        if (mountains > .001)
        {
            float warp = N(2,affine_d.z,affine_d.w) * g_foothill_size * .12;
            float ridgeNoise = N(3, (x + warp) * 1.15, (z + x * .26) * .42);
            float crestWidth = L(.009, .04, S(-.4, .4, structure));
            float ridge = C(1.0 - (sqrt(ridgeNoise * ridgeNoise + crestWidth * crestWidth) - crestWidth) / (sqrt(1.0 + crestWidth * crestWidth) - crestWidth));
            crest = (1.0 - S(.04, .22, abs(ridgeNoise))) * mountains;
            float peakVariation = .74 + lithology * .38 + drainageAxis * .22;
            float backbone = pow(ridge, L(1.3, 3.4, S(-.10, .14, ridgeNoise))) * peakVariation;
            float mass = L(.3 + roll * .12, backbone, g_ridge_strength);
            float flank = S(.02, .16, abs(ridgeNoise)) * (1.0 - S(.6, .95, abs(ridgeNoise)));
            float branch = N(2, x * .55 + warp, z * .45 + ridgeNoise * 400.0), branchRidge = 1.0 - sqrt(branch * branch + .0064);
            float tributary = N(2, x * 2.1 + branch * 130.0, z * 1.6 + ridgeNoise * 650.0);
            float drainage = pow(1.0 - branchRidge, 1.3) * flank * .3;
            drainage += pow(1.0 - abs(tributary), 6.0) * flank * L(.035, .11, S(.18, .4, abs(ridgeNoise)));
            drainage *= S(-.35, .25, structure) * .85 + .15;
            mass += (branchRidge * branchRidge - .5) * flank * .18 * g_mountain_ruggedness;
            mass -= drainage * g_erosion_strength; mass *= 1.0 + ridgeNoise * .22;
            relief += mountains * g_mountain_height * max(mass, .015);
        }
        float capRelief = macroValue * 28.0 + roll * 7.0;
        if (plateau > 0.0) capRelief += roll * roll * 18.0 - (1.0 - S(.02, .16, abs(drainageAxis))) * 12.0;
        if (g_plateau_frequency > 0.0 && plateauDistance > max(600.0, g_talus_width * 2.0))
        { relief = g_plateau_height * (1.0 + lithology * .42) + capRelief; plateau = 1.0; }
        else if (g_plateau_frequency > 0.0 && plateauDistance > -g_talus_width * 3.6)
        {
            float competence = S(-.28, .25, lithology + structure * .22), apronWidth = g_talus_width * L(.7, 1.8, C(lithology + .5));
            float width = max(L(apronWidth * 1.8, g_cliff_width * L(2.5, 1.0, g_escarpment_strength), competence), 96.0);
            wallPrecision = 1.0 - S(width + 16.0, width + 80.0, abs(plateauDistance));
            float wall = S(-width * .5, width * .5, plateauDistance), ledgeHeight = C(.5 + structure * .6, .28, .72);
            float ledged = S(-width * .95, -width * .30, plateauDistance) * ledgeHeight + S(width * .08, width * .65, plateauDistance) * (1.0 - ledgeHeight);
            wall = L(wall, ledged, competence * S(-.1, .3, drainageAxis) * .8);
            float apron = S(-apronWidth, width * .2, plateauDistance), shelf = apron * .32 + wall * .68;
            float top = g_plateau_height * (1.0 + lithology * .42) + capRelief, foot = relief;
            relief = L(relief, top, shelf);
            float fanWidth = L(.032, .13, 1.0 - S(-apronWidth, 0.0, plateauDistance));
            float corridor = (1.0 - S(fanWidth, fanWidth + .055, abs(drainageAxis))) * S(-.18, .18, lithology);
            incision = corridor * (1.0 - S(30.0, 600.0, max(plateauDistance, 0.0)));
            incision *= S(-apronWidth * 2.0, -apronWidth * .65, plateauDistance) * g_plateau_erosion;
            float channelFloor = L(max(foot * .2, 5.0), top - 12.0, S(-apronWidth, 550.0, plateauDistance));
            relief = L(relief, min(relief, channelFloor), incision);
            talus = apron * (1.0 - wall) * competence * C((top - foot) / 180.0);
            talus *= C(.65 + structure * .7 + corridor * .6); talus = max(talus, corridor * apron * (1.0 - wall) * .8);
            relief += talus * g_talus_relief * (1.0 - incision * .7);
            cliffControl = 4.0 * wall * (1.0 - wall) * competence * (1.0 - incision); plateau = shelf;
        }
        float local = N(5, x, z);
        relief += local * g_local_detail * (1.0 - flatness * .98) * (1.0 - plateau * .8) * (1.0 - crest * .9);
        if (g_fractal_strength > 0.0)
        {
            float detailMask = (1.0 - flatness * .99) * (1.0 - plateau * .85) * (1.0 - crest * .92), ruggedness = (.55 + hills * .65) * (1.0 - mountains * .55);
            relief += N(4, x, z) * g_fractal_strength * detailMask * ruggedness;
        }
        float wet = 0.0, drainageInfluence = incision * .65, bed = -g_river_depth;
        if (g_river_frequency > 0.0 && waterCountry > .001)
        {
            float spacing = 4000.0 / max(g_river_frequency, .01); int lane = int(river_plan(river_index).w), nearestLane = lane;
            float across = 3.402823466e+38; vec3 column = vec3(0.0);
            for (int offset = -1; offset <= 1; offset++)
            {
                vec3 candidate = river_plan(river_index+offset+1).xyz; float delta = z - candidate.x;
                if (abs(delta) < abs(across)) { across = delta; nearestLane = lane + offset; column = candidate; }
            }
            float riverSlope = column.y, distance = abs(across) / sqrt(1.0 + riverSlope * riverSlope), bankNoise = N(6, x * 2.0, z * 2.0);
            float width = max(g_river_width, 1.0) * (1.0 + bankNoise * .55 + column.z * .35), valleyDistance = abs(across);
            width *= L(1.0, 1.7, basinCountry) * L(1.0, .65, canyonCountry);
            float valley = 1.0 - S(width * 2.0, width * 2.0 + g_foothill_size * L(.65, .12, canyonCountry), valleyDistance);
            float lowlandWater = max(1.0 - S(.05, .4, max(mountains, plateau * .7)), canyonCountry * (1.0 - plateau)) * waterCountry;
            drainageInfluence = max(drainageInfluence, valley * lowlandWater);
            float valleyFloor = L(relief - min(35.0, relief * .1), 4.0 + roll * 2.0, lowlandWater);
            relief = L(relief, valleyFloor, valley * g_valley_strength);
            float floodplain = (1.0 - S(width * 2.2, width * L(5.0, 9.0, C(roll + .5)), valleyDistance)) * lowlandWater;
            float terrace = S(width * 1.6, width * 3.0, valleyDistance);
            relief = L(relief, 3.0 + terrace * (2.0 + bankNoise) + roll, floodplain * g_valley_strength);
            if (floodplain > 0.0) relief -= (1.0 - S(width * .2, width * .8, abs(valleyDistance - width * (3.2 + column.z)))) * floodplain * .75;
            wet = (1.0 - S(width * .35, width * 1.7, distance)) * lowlandWater;
            bed *= .65 + .35 * (1.0 - C(distance / width));
            if (lowlandWater > 0.0)
            {
                float segmentSize = spacing * .6; int segment = int(floor(x / segmentSize));
                for (int k = -1; k <= 1; k++)
                {
                    int branch = segment + k; float random = Random(branch, nearestLane, 97, 617); if (random > .7) continue;
                    float start = (float(branch) + .1 + random * .3) * segmentSize, t = (x - start) / (segmentSize * L(.5, .9, random));
                    if (t < 0.0 || t > 1.0) continue;
                    float side = Random(branch, nearestLane, 97, 619) < .5 ? -1.0 : 1.0, offset = side * spacing * .24 * t * t;
                    offset += N(6,affine_e.z,float(branch)*931.0) * spacing * .045 * t * t;
                    float branchSlope = riverSlope + side * spacing * .48 * t / (segmentSize * L(.5, .9, random));
                    float tributary = abs(across - offset) / sqrt(1.0 + branchSlope * branchSlope), reach = 1.0 - S(.65, 1.0, t);
                    float streamWidth = width * L(.65, .18, t), stream = (1.0 - S(streamWidth * .4, streamWidth * 1.7, tributary)) * reach;
                    float streamValley = (1.0 - S(streamWidth, streamWidth + 80.0, abs(across - offset))) * reach;
                    relief = L(relief, 5.0, streamValley * g_valley_strength * lowlandWater);
                    wet = max(wet, stream * lowlandWater); drainageInfluence = max(drainageInfluence, streamValley * lowlandWater);
                }
            }
        }
        if (g_lake_frequency > 0.0 && mountains < .4 && plateau < .4 && basinCountry > .05)
        {
            int lake_count=int(lake_plan(lake_index).x);
            for(int site_index=0;site_index<lake_count;site_index++)
            {
                vec4 descriptor=lake_plan(lake_index+1+site_index);
                vec2 center = vec2(descriptor.x, descriptor.y); float radius = descriptor.z; vec2 p = vec2(x, z) - center;
                if (dot(p,p) > radius * radius * 9.0) continue;
                float sine = sin(descriptor.w), cosine = cos(descriptor.w);
                p = vec2(p.x * cosine - p.y * sine, p.x * sine + p.y * cosine); p /= max(radius, 1.0);
                p += vec2(N(6, x * 2.0, z * 2.0), N(6, x * 2.0 + 3187.0, z * 2.0 - 971.0)) * .3;
                float main = length(vec2(p.x / .85, p.y / .65));
                float lobe = length(p-vec2(.48,.25)) / .6;
                float arm = length(vec2((p.x + .55) / .65, (p.y - .25) / .28));
                float contour = min(main, min(lobe, arm)), lowland = (1.0 - S(.1, .4, max(mountains, plateau))) * L(1.0, basinCountry, variety);
                float basinExtent = 1.6 + C(p.x * .2 + roll * .25, -.25, .45), basin = (1.0 - S(.7, basinExtent, contour)) * lowland;
                drainageInfluence = max(drainageInfluence, basin);
                relief = L(relief, 2.0 + S(1.0, basinExtent, contour) * (4.0 + roll * 2.0), basin);
                float lake = (1.0 - S(.65, 1.12, contour)) * lowland, lakeBed = -g_lake_depth * (.3 + .7 * (1.0 - C(contour))) + local * .3;
                bed = L(bed, lakeBed, lake); wet = max(wet, lake);
            }
        }
        vec2 surface_value = vec2(max(mountains, plateau), max(drainageInfluence, wet));
        vec3 geology_value = vec3(talus, incision, cliffControl);
        float detail_weight = max(wallPrecision, max(S(0.0, .03, wet * (1.0 - wet)), crest));
        return GrassSample(vec3(relief,wet,bed),surface_value,geology_value,detail_weight);
}
// Opt-in vertex-stage height bake. A 1x9 pixel rectangle belongs to a
// single numerical sample. All four vertices evaluate identical raw data;
// the fragment stage only serializes the nine already-generated floats.
varying flat vec3 baked_land;
varying flat vec2 baked_surface;
varying flat vec3 baked_geology;
varying flat float baked_detail;

void vertex() {
    int sample_index = VERTEX_ID / 4;
    if (sample_index >= sample_count) {
        VERTEX = vec2(-10000.0, -10000.0);
        baked_land = vec3(0.0);
        baked_surface = vec2(0.0);
        baked_geology = vec3(0.0);
        baked_detail = 0.0;
        return;
    }
    vec4 point = prepared_input(sample_index, 0);
    GrassSample value = sample_raw(point.x, point.y, int(point.z), int(point.w), sample_index);
    baked_land = value.value;
    baked_surface = value.surface;
    baked_geology = value.geology;
    baked_detail = value.detail_weight;
}
vec4 encode_scalar(float value) {
    uint bits = floatBitsToUint(value);
    return vec4(float(bits & 255u), float((bits >> 8u) & 255u),
                float((bits >> 16u) & 255u), float((bits >> 24u) & 255u)) / 255.0;
}
void fragment() {
    int component = int(FRAGCOORD.y) % 9;
    float scalar = 0.0;
    if (component < 3) scalar = baked_land[component];
    else if (component < 5) scalar = baked_surface[component - 3];
    else if (component < 8) scalar = baked_geology[component - 5];
    else scalar = baked_detail;
    COLOR = encode_scalar(scalar);
}
