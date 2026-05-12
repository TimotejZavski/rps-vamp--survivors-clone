shader_type canvas_item;

uniform float blur_radius : hint_range(0.0, 20.0) = 6.0;

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE * blur_radius;
	vec4 sum = vec4(0.0);
	sum += texture(TEXTURE, UV + vec2(-ps.x, -ps.y)) * 0.0625;
	sum += texture(TEXTURE, UV + vec2( 0.0,  -ps.y)) * 0.125;
	sum += texture(TEXTURE, UV + vec2( ps.x, -ps.y)) * 0.0625;
	sum += texture(TEXTURE, UV + vec2(-ps.x,  0.0))  * 0.125;
	sum += texture(TEXTURE, UV)                      * 0.25;
	sum += texture(TEXTURE, UV + vec2( ps.x,  0.0))  * 0.125;
	sum += texture(TEXTURE, UV + vec2(-ps.x,  ps.y)) * 0.0625;
	sum += texture(TEXTURE, UV + vec2( 0.0,   ps.y)) * 0.125;
	sum += texture(TEXTURE, UV + vec2( ps.x,  ps.y)) * 0.0625;
	COLOR = sum;
}
