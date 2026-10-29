// Three UNORM8 controls stored as one exactly representable float24 integer.
// Decode in the vertex stage before interpolation.
vec3 unpack_control24(float packed){
 // Encoded values are already exact integers. Adding .5 above 2^23 can
 // round odd float24 integers up, corrupting bytes (including 0xffffff).
 float value=floor(packed);
 return vec3(mod(value,256.0),mod(floor(value/256.0),256.0),floor(value/65536.0))/255.0;
}
