shader_type spatial;

uniform float height_range;
uniform sampler2D heightmap;

void vertex() {
	// Called for every vertex the material is visible on.uniform texture source;
	vec2 xz = VERTEX.xz;
	float h = texture(heightmap, UV).g * height_range;
	VERTEX = vec3(xz.x, h, xz.y);
	//VERTEX = MODELVIEW_MATRIX.xyz *  VERTEX;

}

void fragment() {
	ALBEDO = texture(heightmap, UV).rgb;
	// Called for every pixel the material is visible on.
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
