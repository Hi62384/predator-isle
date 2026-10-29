shader_type spatial;
render_mode unshaded, wireframe, cull_disabled;
uniform vec4 line_color : source_color = vec4(0.54,0.76,0.69,1.0);
void fragment() { ALBEDO = line_color.rgb; }
