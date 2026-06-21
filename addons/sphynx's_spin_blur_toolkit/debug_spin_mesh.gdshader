shader_type spatial;
render_mode unshaded, wireframe;

uniform vec4 color: source_color;

uniform float enabled;

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a * enabled;
}
