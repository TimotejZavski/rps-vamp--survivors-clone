shader_type canvas_item;

// Hit-flash + optional pixel outline for enemy sprites.
//   flash              : 0..1, mixes the visible pixels toward white.
//   outline_color      : if alpha > 0, draws this color in transparent pixels
//                        adjacent to opaque ones.
//   outline_thickness  : how many texture pixels out to test (1.0-2.0 is plenty).

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float outline_thickness : hint_range(0.0, 8.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec4 out_color = c;
	out_color.rgb = mix(out_color.rgb, vec3(1.0), flash);

	if (outline_color.a > 0.001 && outline_thickness > 0.001 && c.a < 0.1) {
		vec2 px = TEXTURE_PIXEL_SIZE * outline_thickness;
		float n =
			texture(TEXTURE, UV + vec2( px.x, 0.0)).a +
			texture(TEXTURE, UV + vec2(-px.x, 0.0)).a +
			texture(TEXTURE, UV + vec2( 0.0,  px.y)).a +
			texture(TEXTURE, UV + vec2( 0.0, -px.y)).a;
		if (n > 0.0) {
			out_color = outline_color;
		}
	}

	COLOR = out_color;
}
