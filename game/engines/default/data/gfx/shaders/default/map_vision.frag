uniform sampler2D tex;

void main()
{
	float a = texture2D(tex, te4_uv).r;
	a = pow(a, 2.0);
	gl_FragColor = vec4(0.0, 0.0, 0.0, a) * te4_fragcolor;
}
