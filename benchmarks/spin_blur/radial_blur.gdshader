shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform sampler2D screen_texture : source_color, hint_screen_texture;

uniform int sample_count = 4;


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
	float j = interleaved_gradient_noise(SCREEN_UV * vec2(VIEWPORT_SIZE), int(0));
	
	vec4 sum = vec4(0);
	float weight = 0.0;
	
	vec2 uv_offset = SCREEN_UV - 0.5;
	
	float intensity = (sin(TIME) + 1.0) / 2.0;
	
	float twist_amount = sin( 2.0 * TIME);
	
	for(int i = 0; i < sample_count; i++)
	{
		float ti = (float(i) + j) / float(sample_count);
		
		float t = mix(-0.5, 0.5, ti);
		
		vec2 current_uv_sample = rotate(length(uv_offset) * twist_amount, vec3(0, 0, 1), vec3(SCREEN_UV - 0.5, 0.0)).xy + 0.5 + rotate(length(uv_offset) * twist_amount, vec3(0, 0, 1), vec3(uv_offset, 0.0)).xy * t * intensity;
		
		if(current_uv_sample.x < 0.0 || current_uv_sample.x > 1.0 || current_uv_sample.y < 0.0 || current_uv_sample.y > 1.0)
		{
			continue;
		}
		
		weight += 1.0;
		
		sum += texture(screen_texture, current_uv_sample);
	}
	
	ALBEDO = (sum / float(sample_count)).xyz;
}
