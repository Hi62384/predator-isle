uniform sampler2D cave_ground_height : filter_nearest, repeat_disable;
uniform vec4 cave_ground_bounds = vec4(0.0);

bool dry_cave_ground(vec3 position) {
    vec2 local = position.xz - cave_ground_bounds.xy;
    if(any(lessThan(local,vec2(0))) || any(greaterThanEqual(local,cave_ground_bounds.zw)))return false;
    return texelFetch(cave_ground_height,ivec2(floor(local/8.0)),0).r > position.y;
}
