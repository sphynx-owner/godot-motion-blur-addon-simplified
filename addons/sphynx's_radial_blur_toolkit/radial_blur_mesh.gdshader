shader_type spatial;

render_mode unshaded, depth_draw_always, fog_disabled, blend_premul_alpha;

const float EPSILON = 0.00001;

uniform sampler2D screen_texture : filter_nearest;

uniform sampler2D depth_texture : filter_nearest, source_color;

uniform vec3 local_rotation_axis = vec3(0, 1, 0);

uniform float rotation_speed = 0;

uniform int sample_count = 8;

uniform vec4 debug_color : source_color = vec4(0);

uniform float sampling_error_threshold = 0.2;

//https://www.shadertoy.com/view/fdtfWM
vec3 rotate(float angle, vec3 axis, vec3 point) // NOTE: axis must be unit!
{
    float c = cos(angle);
    float s = sin(angle);
    return c * point + s * cross(axis, point) + (1.0 - c) * (dot(point, axis) * axis); // Rodrigues' Rotation Formula
}

// from https://www.shadertoy.com/view/ftKfzc
float interleaved_gradient_noise(vec2 uv, int FrameId){
	uv += float(FrameId)  * (vec2(47, 17) * 0.695);

    vec3 magic = vec3( 0.06711056, 0.00583715, 52.9829189 );

    return fract(magic.z * fract(dot(uv, magic.xy)));
}

void fragment() {
	vec2 screen_uv = SCREEN_UV;

	float depth = texture(depth_texture, screen_uv).x;

	if(depth < EPSILON) {
		depth = texture(screen_texture, screen_uv).z;
	}

	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth);
	vec4 world_position = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	world_position.xyz /= world_position.w;

	vec3 node_relative_position = world_position.xyz - NODE_POSITION_WORLD;

	vec3 world_rotation_axis = normalize(mat3(MODEL_MATRIX) * local_rotation_axis);

	vec3 camera_node_position = NODE_POSITION_WORLD - CAMERA_POSITION_WORLD;

	float noise_variation = interleaved_gradient_noise(SCREEN_UV * vec2(textureSize(screen_texture, 0)), int(TIME * 100.)) / float(sample_count);

	float sum = 0.;

	vec4 col = vec4(0);

	vec3 camera_relative_position_normalized = normalize(node_relative_position.xyz + camera_node_position);
	
	float squared_sampling_error_threshold = max(sampling_error_threshold * sampling_error_threshold, EPSILON);
	
	for(int i = 0; i < sample_count; i++)
	{
		float angle = (float(i) / float(sample_count) + noise_variation) * rotation_speed;

		vec3 node_rotated_sample = rotate(-angle, world_rotation_axis.xyz, node_relative_position.xyz);

		vec4 current_ndc = (PROJECTION_MATRIX * VIEW_MATRIX * (vec4(node_rotated_sample, 1) + vec4(NODE_POSITION_WORLD, 0)));

		current_ndc.xyz /= current_ndc.w;

		vec2 current_uv_sample = ((current_ndc + 1.) / 2.).xy ;

		if (current_uv_sample.x < 0. || current_uv_sample.x > 1. || current_uv_sample.y < 0. || current_uv_sample.y > 1.)
		{
			sum += 1.0;
			continue;
		}

		float current_depth = texture(depth_texture, current_uv_sample).x;

		if(current_depth < EPSILON) {
			sum += 1.0;
			continue;
		}

		vec4 current_world_position = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(vec3(current_ndc.xy, current_depth), 1.0);

		current_world_position.xyz /= current_world_position.w;

		vec3 current_camera_unrotated_position = rotate(angle, world_rotation_axis.xyz, current_world_position.xyz - NODE_POSITION_WORLD) + camera_node_position;

		vec3 current_unrotated_perpendicular_component = current_camera_unrotated_position - camera_relative_position_normalized * dot(current_camera_unrotated_position, camera_relative_position_normalized);

		if(dot(current_unrotated_perpendicular_component, current_unrotated_perpendicular_component) >= squared_sampling_error_threshold) {
			sum += 1.;
			continue;
		}

		sum += 1.;
		col += texture(screen_texture, current_uv_sample);
	}

	col /= sum;

	ALBEDO = col.xyz + debug_color.xyz;
	ALPHA = col.a + debug_color.a;
}