uniform sampler2D tex;
uniform vec2 resolution;
uniform vec2 unhide[200];
uniform float unhide_cnt;

void main(void)
{
	vec4 c = texture2D(tex, te4_uv).rgba;
	// c.a = ;
	// gl_FragColor = c;

	// Normalized pixel coordinates (from 0 to 1)
	vec2 uv = gl_FragCoord.xy / resolution;
	float r_ratio = resolution.x / resolution.y;
	float a = 1.0;
	float r = 0.05;
	for(int i = 0; i < unhide_cnt; i++) {
		vec2 center = uv - vec2(unhide[i].x, 1.0 - unhide[i].y);
		center.x = center.x * r_ratio;

		float aa = smoothstep(r, r * 1.3, length(center)) / 0.5 + 0.5;
		a = min(a, aa);
	}

	// Output to screen
	c.a *= a;
	gl_FragColor = c;
}
