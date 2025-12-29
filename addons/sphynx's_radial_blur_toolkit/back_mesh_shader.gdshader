shader_type spatial;

render_mode unshaded, shadows_disabled, depth_draw_never, cull_front;


void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	DEPTH = 0.;
	vec4 ndc = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	ndc.xyz /= ndc.w;
	ALBEDO = vec3(0, 0, ndc.z);
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
