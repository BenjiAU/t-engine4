uniform sampler2D tex;
uniform vec2 mapCoord;
uniform vec2 texSize;

vec4 minc = vec4(0.4, 0.4, 0.4, 0.05);
vec4 maxc = vec4(0.4, 0.8, 0.6, 0.8);

void main()
{
	vec2 dist = mapCoord/texSize - gl_FragCoord.xy/texSize;
	dist.x *= texSize.x/texSize.y;
	float l = length(dist);

	// float a = mix(0.1, 1.0, clamp(1.0 - l, 0.0, 1.0));
	// gl_FragColor = vec4(1.0, 0.0, 0.0, a) * te4_fragcolor;
	l = clamp(1.0 - l, 0.0, 1.0);
	gl_FragColor = mix(minc, maxc, l * l) * te4_fragcolor;
}
