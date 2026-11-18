shader_type spatial;
render_mode diffuse_lambert_wrap,specular_disabled;
uniform vec4 shade : source_color = vec4(.43,.55,.28,1);
uniform vec4 light_ink : source_color = vec4(.57,.66,.36,1);
uniform vec4 grass_tip : source_color = vec4(.68,.72,.40,1);
uniform vec4 dust : source_color;
uniform vec4 dust_tip : source_color;
uniform sampler2D tracks : filter_linear_mipmap,repeat_disable;
uniform int biome = -1;
varying vec2 field_pos;
varying float height;

float hash(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1.,0.)),f.x),mix(hash(i+vec2(0.,1.)),hash(i+vec2(1.)),f.x),f.y);
}
void vertex() {field_pos=VERTEX.xz; height=VERTEX.y;}
void fragment() {
	vec2 p=field_pos;
	float broad=noise(p*.16+vec2(noise(p*.32),0.))*0.57+noise(p*.59)*.32+noise(p*1.7)*.11;
	vec3 grass=mix(shade.rgb,light_ink.rgb,smoothstep(.22,.77,broad));
	vec2 slant=vec2(p.x+p.y*.49,p.y-p.x*.12);
	float brush=smoothstep(.69,.88,noise(slant*vec2(3.1,8.5)));
	grass=mix(grass,grass_tip.rgb,.16*brush);
	if (biome==1) {
		float ripples=sin(p.x*11.+p.y*4.+noise(p*.39)*9.);
		grass=mix(grass,grass_tip.rgb,smoothstep(.68,1.,ripples)*(.07+.11*broad));
	} else if (biome==3) {
		float wet=smoothstep(.51,.69,noise(p*.46)+.055*noise(p*2.));
		grass=mix(grass,shade.rgb*.83,wet*.47);
	} else if (biome==4) {
		float wind=smoothstep(.52,.79,noise(p*vec2(.5,1.9)+vec2(broad*1.7)));
		grass=mix(grass,grass_tip.rgb,wind*.28);
	} else if (biome==5) {
		float ash=noise(p*.36+vec2(noise(p*.7)*1.3));
		grass=mix(grass,shade.rgb*.75,smoothstep(.50,.79,ash)*.56);
	}
	grass=mix(grass,grass_tip.rgb,smoothstep(.08,.85,height)*.12);
	vec2 wobble=vec2(noise(p*2.3),noise(p*2.3+vec2(2.,4.)))-vec2(.5);
	float coverage=texture(tracks,(p+wobble*.50)/48.+.5).r;
	float tooth=noise(p*5.)*.26+noise(p*1.3)*.24;
	float opacity=smoothstep(.02+tooth*.26,.58+tooth*.27,coverage);
	vec3 road=mix(dust.rgb,dust_tip.rgb,clamp(broad*.49+coverage*.44+noise(slant*vec2(2.,7.))*.11,0.,1.));
	ALBEDO=mix(grass,road,opacity);
	ROUGHNESS=1.;
}
