uniform sampler2D tex;
uniform vec2 resolution;
uniform vec2 player;

void main(void)
{
	vec4 c = texture2D(tex, te4_uv).rgba;
	// c.a = ;
	// gl_FragColor = c;

	// Normalized pixel coordinates (from 0 to 1)
	vec2 uv = gl_FragCoord.xy / resolution;
	vec2 center = uv - vec2(player.x, 1.0 - player.y);
	center.x = center.x * (resolution.x / resolution.y);

	float r = 0.1;
	vec3 a = vec3(smoothstep(r, r + 0.05, length(center)));
	c.a *= a / 0.7 + 0.3;

	// Output to screen
	gl_FragColor = c;
}
