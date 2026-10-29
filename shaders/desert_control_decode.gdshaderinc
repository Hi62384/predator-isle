// Four exactly representable float32 integers carry twelve original UNORM8 bytes.
// Decode only in vertex(), BEFORE interpolation; mixed-biome zero-weight vertices
// must also be decoded so their original neutral controls are retained.
vec3 desert_unpack24(float packed_value) {
 float v = floor(packed_value + 0.0);
 return vec3(mod(v,256.0),mod(floor(v/256.0),256.0),floor(v/65536.0))/255.0;
}
void decode_desert_controls(vec4 packed_value, out vec4 region, out vec4 surface, out vec4 wind) {
 vec3 a=desert_unpack24(packed_value.x), b=desert_unpack24(packed_value.y);
 vec3 c=desert_unpack24(packed_value.z), d=desert_unpack24(packed_value.w);
 region=vec4(a,b.x); surface=vec4(b.yz,c.xy); wind=vec4(c.z,d);
}
