uniform sampler2D tex;
varying float bold;
varying float outline;

/*
const float glyph_center   = 0.50;
       vec3 outline_color  = vec3(1.0,0.0,0.0);
const float outline_center = 0.55;
       vec3 glow_color     = vec3(0.0,0.0,0.0);
const float glow_center    = 0.99;

void main(void)
{
	vec3 glyph_color = te4_fragcolor.rgb;
	vec4  color = texture2D(tex, te4_uv);
	float dist  = color.a;
	if (bold > 0.0) dist = sqrt(dist);
	float width = fwidth(dist);
	float alpha = smoothstep(glyph_center-width, glyph_center+width, dist);

	// Smooth
	// gl_FragColor = vec4(glyph_color, alpha);

	// Outline
	// dist = pow(dist,2);
	// float mu = smoothstep(outline_center-width, outline_center+width, dist);
	// vec3 rgb = mix(outline_color, glyph_color, mu);
	// gl_FragColor = vec4(rgb, max(alpha,mu));

	// Glow
	if (outline > 0.0) { 
		// dist = sqrt(dist);
		dist = pow(dist, 0.50);
		float mu = smoothstep(glyph_center, glow_center, sqrt(dist));
		vec3 o = mix(glow_color, glyph_color, alpha);
		vec3 c = glyph_color;
		// gl_FragColor = vec4(o, max(alpha,mu));
		// alpha = sqrt(alpha);
		gl_FragColor = vec4(c * alpha + o * (1.0 - alpha), max(alpha,mu));
		// gl_FragColor = c * alpha + o * (1.0 - alpha);
		// gl_FragColor = vec4(1,1,1, alpha);
	} else {
		gl_FragColor = vec4(glyph_color, alpha);
	}

	// Glow + outline
	// dist = sqrt(dist);
	// vec3 rgb = mix(glow_color, glyph_color, alpha);
	// float mu = smoothstep(glyph_center, glow_center, sqrt(dist));
	// color = vec4(rgb, max(alpha,mu));
	// float beta = smoothstep(outline_center-width, outline_center+width, dist);
	// rgb = mix(outline_color, color.rgb, beta);
	// gl_FragColor = vec4(rgb, max(color.a,beta));

}
*/


const float glyph_center = 0.50;

void main(void)
{
	vec4  color = texture2D(tex, te4_uv);
	float dist  = color.a;
	if (outline) {
		if (bold > 0.0) dist = pow(dist, 0.85);
	} else {
		if (bold > 0.0) dist = sqrt(dist);
	}

	// Normal
	// float width = 0.3;
	float width = fwidth(dist);
	float oa = smoothstep(glyph_center-width, glyph_center+width, sqrt(dist));
	float alpha = smoothstep(glyph_center-width, glyph_center+width, dist);

	vec3 o = mix(vec3(0,0,0), te4_fragcolor.rgb, oa);
	vec3 c = te4_fragcolor.rgb;
	gl_FragColor = vec4(c, alpha);
	// gl_FragColor = vec4(c, max(alpha,oa));
	// gl_FragColor = vec4(c * alpha + o * (1.0 - alpha), max(alpha,oa));

	// gl_FragColor = vec4(te4_fragcolor.rgb, oa);

	// Compute in the requested color alpha
	gl_FragColor.a *= te4_fragcolor.a;
}


/*

const float glyph_center = 0.50;

void main(void)
{
	vec4  color = texture2D(tex, te4_uv);
	float dist  = color.a;

	if (outline != 0.0) {
		// Outline -- it's actually a simple pregenerated outline, but without signed distance map
		gl_FragColor = vec4(te4_fragcolor.rgb, dist);
	} else {	
		if (bold > 0.0) dist = sqrt(dist);

		// Normal
		// float width = 0.3;
		float width = fwidth(dist);
		float alpha = smoothstep(glyph_center-width, glyph_center+width, dist);
		gl_FragColor = vec4(te4_fragcolor.rgb, alpha);
	}	

	// Compute in the requested color alpha
	gl_FragColor.a *= te4_fragcolor.a;
}
*/