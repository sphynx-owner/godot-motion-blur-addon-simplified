const float EPSILON = 0.00001;

uniform sampler2D screen_texture : filter_nearest, source_color;

uniform sampler2D depth_texture : filter_nearest, source_color;

uniform vec3 local_rotation_axis = vec3(0, 1, 0);

uniform float rotation_speed = 0;

uniform int sample_count = 8;

uniform float sampling_error_threshold = 0.1;

uniform float fade_in = 1;

uniform float blur_intensity;

uniform float rolling_shutter_amount = 1.0;


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
	
	if(depth == 0.0) {
		depth = FRAGCOORD.z;
	}
	
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth);
	vec4 view_position = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_position.xyz /= view_position.w;
	
	vec3 node_relative_position = view_position.xyz - NODE_POSITION_VIEW;
	
	vec3 view_rotation_axis = normalize(mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX) * local_rotation_axis);
	
	float j = interleaved_gradient_noise(SCREEN_UV * vec2(VIEWPORT_SIZE), int(TIME * 195.121124));
	
	float weight = 0.;
	
	float alpha_weight = 1e-8;
	
	vec4 sum = vec4(0);
	
	float squared_sampling_error_threshold = max(sampling_error_threshold * sampling_error_threshold, EPSILON);
	
	float rolling_shutter_uv_amount = SCREEN_UV.y * rolling_shutter_amount;
	
	for(int i = 0; i < sample_count; i++)
	{
		float ti = (float(i) + j) / float(sample_count);
		
		float t = mix(-0.5, 0.5, ti);
		
		float angle = (t * blur_intensity + rolling_shutter_uv_amount) * rotation_speed;
		
		vec3 node_rotated_sample = rotate(angle, view_rotation_axis, node_relative_position);
		
		vec4 current_ndc = PROJECTION_MATRIX * vec4(node_rotated_sample + NODE_POSITION_VIEW, 1);
		
		current_ndc.xyz /= current_ndc.w;
		
		vec2 current_uv_sample = ((current_ndc + 1.) / 2.).xy ;
		
		if (current_uv_sample.x < 0. || current_uv_sample.x > 1. || current_uv_sample.y < 0. || current_uv_sample.y > 1.)
		{
			continue;
		}
		
		float current_depth = texture(depth_texture, current_uv_sample).x;
		
		if(current_depth == 0.0) {
			alpha_weight += 1.0;
			continue;
		}
		
		vec4 current_view_position = INV_PROJECTION_MATRIX * vec4(vec3(current_ndc.xy, current_depth), 1.0);
		
		current_view_position.xyz /= current_view_position.w;
		
		vec3 unrotated_position = rotate(-angle, view_rotation_axis.xyz, current_view_position.xyz - NODE_POSITION_VIEW) + NODE_POSITION_VIEW;
		
		vec2 current_unrotated_perpendicular_component = unrotated_position.xy - view_position.xy;
		
		if(dot(current_unrotated_perpendicular_component, current_unrotated_perpendicular_component) >= squared_sampling_error_threshold) {
			continue;
		}
		
		weight += 1.;
		alpha_weight += 1.;
		sum += texture(screen_texture, current_uv_sample);
	}
	
	sum.xyz /= weight;
	sum.a /= alpha_weight;
	
	ALBEDO = sum.xyz;
	ALPHA = sum.a * fade_in;
}