// Four exact 24-bit float attributes carry twelve UNORM8 Snow fields.
// Caller includes desert_control_decode for the shared unpack24 primitive.
void snow_decode(vec4 packed,out vec4 a,out vec4 b,out vec4 c){
 vec3 p=desert_unpack24(packed.x),q=desert_unpack24(packed.y),r=desert_unpack24(packed.z),s=desert_unpack24(packed.w);
 a=vec4(p,q.x);b=vec4(q.yz,r.xy);c=vec4(r.z,s);
}
