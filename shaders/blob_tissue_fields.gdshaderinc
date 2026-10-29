float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y), mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}

vec3 sample_tissue_color(vec3 pigment,vec3 p){
	float grain=noise(p*32.0);
	float mottles=noise(p*5.0);
	float bruise=smoothstep(.54,.78,noise(p*1.8))*smoothstep(.35,.72,noise(p*7.0))*.3;
	vec3 color=pigment*(.78+mottles*.38+grain*.13);
	return mix(color,color*vec3(.73,.48,.66),bruise);
}
