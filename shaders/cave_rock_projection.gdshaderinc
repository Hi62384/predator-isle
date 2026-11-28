vec2 cave_rock_slope(vec2 encoded) {
	vec2 xy = encoded * 2.0 - 1.0;
	return xy / max(sqrt(max(1.0 - dot(xy, xy), .001)), .3);
}

vec4 cave_rock_axis(sampler2DArray colors, sampler2DArray normals, vec2 uv, vec2 dx, vec2 dy,
		float wall, float floor_layer, float floor_mix, float bump_strength, out vec2 slope) {
	float layer = floor_mix >= .998 ? floor_layer : wall;
	vec4 sample_color = textureGrad(colors, vec3(uv, layer), dx, dy);
	slope = vec2(0.0);
	if (bump_strength > 0.0) {
		slope = cave_rock_slope(textureGrad(normals, vec3(uv, layer), dx, dy).rg);
	}
	if (floor_mix > .002 && floor_mix < .998 && floor_layer != wall) {
		sample_color = mix(sample_color, textureGrad(colors, vec3(uv, floor_layer), dx, dy), floor_mix);
		if (bump_strength > 0.0) {
			vec2 floor_slope = cave_rock_slope(textureGrad(normals, vec3(uv, floor_layer), dx, dy).rg);
			slope = mix(slope, floor_slope, floor_mix);
		}
	}
	return sample_color;
}

void project_cave_rock(sampler2DArray colors, sampler2DArray normals, vec3 p, vec3 dx, vec3 dy, vec3 n,
		float wall, float floor_layer, float gravel, float bump_strength, out vec4 surface, out vec3 mapped) {
	// An interpolated normal can point across a triangle whose texture
	// projection along that axis is nearly edge-on. Downweight that projection.
	vec3 face = normalize(cross(dx, dy));
	vec3 weights = n * n * abs(n) * smoothstep(vec3(.12), vec3(.65), abs(face));
	weights += abs(face) * .015;
	weights /= max(dot(weights, vec3(1.0)), .0001);
	vec3 signs = mix(vec3(-1.0), vec3(1.0), step(vec3(0.0), n));
	float floor_mix = smoothstep(.48, .91, n.y) * smoothstep(.2, .68, abs(face.y)) * gravel;
	surface = vec4(0.0);
	vec3 slope = vec3(0.0);
	vec2 t;
	if (weights.x > .002) {
		vec2 orientation = vec2(1.0, -signs.x);
		surface += weights.x * cave_rock_axis(colors, normals, p.zy * orientation, dx.zy * orientation,
			dy.zy * orientation, wall, wall, 0.0, bump_strength, t);
		slope += weights.x * vec3(0.0, -t.y * signs.x, t.x);
	}
	if (weights.y > .002) {
		vec2 orientation = vec2(1.0, -signs.y);
		surface += weights.y * cave_rock_axis(colors, normals, p.xz * orientation, dx.xz * orientation,
			dy.xz * orientation, wall, floor_layer, floor_mix, bump_strength, t);
		slope += weights.y * vec3(t.x, 0.0, -t.y * signs.y);
	}
	if (weights.z > .002) {
		vec2 orientation = vec2(1.0, signs.z);
		surface += weights.z * cave_rock_axis(colors, normals, p.xy * orientation, dx.xy * orientation,
			dy.xy * orientation, wall, wall, 0.0, bump_strength, t);
		slope += weights.z * vec3(t.x, t.y * signs.z, 0.0);
	}
	slope -= n * dot(slope, n);
	slope *= min(1.0, .6 / max(length(slope), .0001));
	mapped = normalize(n + slope * bump_strength);
}

vec3 cave_fill_light(vec3 base, vec3 normal) {
	// Keep shape and texture visible in total shade, including deep passages.
	return base * (.72 + .16 * clamp(normal.y, -1.0, 1.0));
}
