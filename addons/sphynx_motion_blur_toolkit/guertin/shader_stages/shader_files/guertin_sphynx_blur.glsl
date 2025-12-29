#[compute]
#version 450

#define FLT_MAX 3.402823466e+38
#define FLT_MIN 1.175494351e-38
#define M_PI 3.1415926535897932384626433832795

layout(set = 0, binding = 0) uniform sampler2D color_sampler;
layout(set = 0, binding = 1) uniform sampler2D velocity_sampler;
layout(set = 0, binding = 2) uniform sampler2D neighbor_max;
layout(set = 0, binding = 3) uniform sampler2D tile_variance;
layout(rgba16f, set = 0, binding = 4) uniform writeonly image2D output_color;
layout(set = 0, binding = 3) uniform sampler2D custom_curve;


layout(push_constant, std430) uniform Params 
{	
	float minimum_user_threshold;
	float importance_bias;
	float maximum_jitter_value;
	float motion_blur_intensity;
	int tile_size;
	int sample_count;
	int frame;
	int nan4;
} params;

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

// Guertin's functions https://research.nvidia.com/sites/default/files/pubs/2013-11_A-Fast-and/Guertin2013MotionBlur-small.pdf
// ----------------------------------------------------------
float z_compare(float a, float b, float sze)
{
	return clamp(1. - sze * (a - b), 0, 1);
}
// ----------------------------------------------------------

// from https://www.shadertoy.com/view/ftKfzc
// ----------------------------------------------------------
float interleaved_gradient_noise(vec2 uv){
	uv += float(params.frame) * (vec2(47, 17) * 0.695);

    vec3 magic = vec3( 0.06711056, 0.00583715, 52.9829189 );

    return fract(magic.z * fract(dot(uv, magic.xy)));
}
// ----------------------------------------------------------

// from https://github.com/bradparks/KinoMotion__unity_motion_blur/tree/master
// ----------------------------------------------------------
vec2 safenorm(vec2 v)
{
	float l = max(length(v), 1e-6);
	return v / l * int(l >= 0.5);
}

vec2 jitter_tile(vec2 uvi)
{
	float rx, ry;
	float angle = interleaved_gradient_noise(uvi + vec2(2, 0)) * M_PI * 2;
	rx = cos(angle);
	ry = sin(angle);
	return vec2(rx, ry) / textureSize(neighbor_max, 0) / 4;
}
// ----------------------------------------------------------

void main() 
{
	// The size of the output texture
	ivec2 render_size = ivec2(textureSize(color_sampler, 0));

	// Resolution of neighbor max texture (max velocity tiles)
	ivec2 tile_render_size = ivec2(textureSize(neighbor_max, 0));

	// The pixel we are running the shader for.
	ivec2 uvi = ivec2(gl_GlobalInvocationID.xy);

	// If the pixel we are in is outside the target render's size, we 
	// exit early
	if ((uvi.x >= render_size.x) || (uvi.y >= render_size.y)) 
	{
		return;
	}

	// We convert the pixel position into a texturing sampling position
	// we add 0.5 to offset the sampling to be in the "middle" of the pixel
	// and avoid artifacts caused by bilinear interpolation.
	vec2 x = (vec2(uvi) + vec2(0.5)) / vec2(render_size);

	// We get the neighbor-max velocity for the tile we are in, with some jitter
	// between tiles to hide seams between them.
	// We then multiply the velocity by the render size to get its magnitude
	// in pixels. We also mulitply it by the blur intensity factor.
	// TODO @sphynx-owner: figure out whether adding half a tile size to x is 
	// correct. 
	vec4 vnzw = textureLod(neighbor_max, x + jitter_tile(uvi), 0.0) * vec4(render_size / 2., 1, 1) * params.motion_blur_intensity;

	// We get the xy components of the max tile velocity. Velocities can have a z
	// component too (we generate it in the pre-blur processing stage for stationary
	// elements), but it is used separately and does not express itself visually in the
	// blur (it represents the movement of elements towards the camera, which means
	// they don't visually move).
	vec2 vn = vnzw.xy;

	float vn_length = length(vn);

	vec4 base_color = textureLod(color_sampler, x, 0.0);

	// We get the true velocity at the current pixel, mulitplied by the motion blur intensity.
	vec4 vxzw = textureLod(velocity_sampler, x, 0.0) * vec4(render_size / 2., 1, 1) * params.motion_blur_intensity;

	if(vn_length < 0.5)
	{
		imageStore(output_color, uvi, base_color);
#ifdef DEBUG
		imageStore(debug_1_image, uvi, base_color);
		imageStore(debug_2_image, uvi, vec4(vn / render_size * 2, abs(vnzw.z) * 10000, 1));
		imageStore(debug_3_image, uvi, vec4(vxzw.xy / render_size * 2, abs(vxzw.z) * 10000, 1));
		imageStore(debug_4_image, uvi, vec4(0));
#endif
		return;
	}

	// We normalize neighbor-max velocity
	vec2 wn = safenorm(vn);

	// We get the xy components of the true velocity (see declaration of vn)
	vec2 vx = vxzw.xy;

	float vx_length = max(0.5, length(vx));

	vec2 wx = safenorm(vx);
	
	// We get some random value for the current pixel. This will be used to
	// jitter the blur sampling, and achieve smoother looking blur gradient
	// with a fraction of the sample count.
	float j = interleaved_gradient_noise(uvi) * 2. - 1.;

	// Get the depth at current pixel
	float zx = vxzw.w;

	// Create an initial color sum
	vec4 sum = vec4(0);

	for(int i = 0; i < params.sample_count; i++)
	{
		// A point in time along the blur interval, used to scale velocity vectors to sample for color.
		float t = mix(-1.0, 1.0, (i + j * params.maximum_jitter_value + 1.0) / (params.sample_count + 1.0));

		// Get sample point
		vec2 yx = x + t * vx / vec2(render_size);
		
		vec2 yn = x + t * vn / vec2(render_size);

		// Get the true velocity at the sample point.
		vec4 vyzwx = textureLod(velocity_sampler, yx, 0.0) * vec4(render_size / 2, 1, 1) * params.motion_blur_intensity;
		
		vec4 vyzwn = textureLod(velocity_sampler, yn, 0.0) * vec4(render_size / 2, 1, 1) * params.motion_blur_intensity; 

		vec2 vyn = vyzwn.xy;

		// Get the depth at the sample point.
		float zyx = vyzwx.w;

		float zyn = vyzwn.w;

		// TODO @sphynx-owner: figure out depth comparisons, as well as 
		// including the correct depth velocity components.
		float overlapx = z_compare(-zx, -zyx, 20000);

		float overlapn = z_compare(-zyn, -zx, 20000);

		vec2 wyn = safenorm(vyn);

		float Tn = abs(t * length(vn));

		float vyn_length = max(0.5, length(vyn));

		float projected = abs(dot(wyn, wn));

		float current_weightn = step(Tn, vyn_length * projected) * overlapn;

		float current_weightx = 1 * overlapx;

		sum += mix(mix(base_color, textureLod(color_sampler, yx, 0.0), current_weightx), textureLod(color_sampler, yn, 0.0), current_weightn);
	}

	sum /= params.sample_count;

	imageStore(output_color, uvi, sum);
#ifdef DEBUG
	imageStore(debug_1_image, uvi, base_color);
	imageStore(debug_2_image, uvi, vec4(vn / render_size * 2, 0, 1));
	imageStore(debug_3_image, uvi, vec4(vx / render_size * 2, 0, 1));
	imageStore(debug_4_image, uvi, vxzw);
#endif
}