shader_type spatial;

uniform float amount = 1.0;

//https://www.shadertoy.com/view/fdtfWM
vec3 rotate(float angle, vec3 axis, vec3 point) // NOTE: axis must be unit!
{
	float c = cos(angle);
	float s = sin(angle);
	return c * point + s * cross(axis, point) + (1.0 - c) * (dot(point, axis) * axis); // Rodrigues' Rotation Formula
}

void vertex() {
	vec3 rotation_axis = vec3(0, 0, 1.0);

	rotation_axis = normalize(rotation_axis);

	vec3 cross_axis = (rotation_axis == vec3(1.0, 0.0, 0.0)) ? vec3(0.0, 1.0, 0.0): vec3(1.0, 0.0, 0.0);

	vec3 perpen_axis = normalize(cross(rotation_axis, cross_axis));

	vec3 projected_vertex = normalize(VERTEX - (dot(VERTEX, rotation_axis) * rotation_axis));

	float x = dot(projected_vertex, perpen_axis);

	float y = dot(rotation_axis, cross(projected_vertex, perpen_axis));

	float angle = atan(y, x);

	VERTEX = rotate(angle * (1.0 - amount), rotation_axis, VERTEX);
}
