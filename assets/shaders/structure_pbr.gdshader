// Make It Flat — Shader PBR per strutture distruttibili
// • Proiezione triplanare in coordinate MONDO: blocchi adiacenti dello stesso materiale mostrano una
//   superficie continua (niente "cubi" visibili, niente texture che ricomincia ogni metro).
// • Quando il blocco diventa maceria (local_mode = 1) la proiezione passa in coordinate OGGETTO,
//   così la texture resta incollata al pezzo mentre cade e rotola.
// • Normal map triplanare con blend "whiteout", roughness e AO dalle mappe Poly Haven.
// • Anti-tiling: variazione cromatica a bassa frequenza + sporco procedurale.
// • Crepe procedurali 3D (Voronoi) che si allargano con il danno (instance uniform "damage").
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform bool has_normal = true;
uniform vec4 tint : source_color = vec4(1.0);
uniform float world_size = 2.0;
uniform float roughness_mult : hint_range(0.0, 2.0) = 1.0;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float blend_sharpness : hint_range(1.0, 16.0) = 6.0;
uniform float grime_amount : hint_range(0.0, 1.0) = 0.35;
uniform vec3 grime_color : source_color = vec3(0.30, 0.27, 0.23);
uniform vec3 crack_color : source_color = vec3(0.06, 0.05, 0.045);

instance uniform float damage = 0.0;      // 0 = intatto, 1 = sul punto di cedere
instance uniform float local_mode = 0.0;  // 1 = mappatura in spazio oggetto (macerie)
instance uniform float hit_flash = 0.0;   // lampo bianco breve all'impatto

varying vec3 v_tri_pos;
varying vec3 v_tri_nrm;
varying vec3 v_world_pos;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453123);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1, 0, 0));
	float n010 = hash13(i + vec3(0, 1, 0));
	float n110 = hash13(i + vec3(1, 1, 0));
	float n001 = hash13(i + vec3(0, 0, 1));
	float n101 = hash13(i + vec3(1, 0, 1));
	float n011 = hash13(i + vec3(0, 1, 1));
	float n111 = hash13(i + vec3(1, 1, 1));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y), mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += value_noise(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

// Distanza dal bordo di cella Voronoi (F2 - F1): valori vicini a 0 = linea di frattura
float voronoi_edge(vec3 p) {
	vec3 ip = floor(p);
	vec3 fp = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = hash33(ip + g);
				vec3 r = g + o - fp;
				float d = dot(r, r);
				if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
			}
		}
	}
	return sqrt(f2) - sqrt(f1);
}

void vertex() {
	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_world_pos = wpos;
	if (local_mode > 0.5) {
		v_tri_pos = VERTEX;
		v_tri_nrm = NORMAL;
	} else {
		v_tri_pos = wpos;
		v_tri_nrm = wnrm;
	}
}

void fragment() {
	vec3 n = normalize(v_tri_nrm);
	vec3 w = pow(abs(n), vec3(blend_sharpness));
	w /= (w.x + w.y + w.z + 1e-5);

	vec3 p = v_tri_pos / max(world_size, 0.01);
	vec2 uv_x = p.zy;
	vec2 uv_y = p.xz;
	vec2 uv_z = p.xy;

	vec3 alb = texture(albedo_tex, uv_x).rgb * w.x + texture(albedo_tex, uv_y).rgb * w.y + texture(albedo_tex, uv_z).rgb * w.z;
	float rough = texture(rough_tex, uv_x).r * w.x + texture(rough_tex, uv_y).r * w.y + texture(rough_tex, uv_z).r * w.z;
	float ao = texture(ao_tex, uv_x).r * w.x + texture(ao_tex, uv_y).r * w.y + texture(ao_tex, uv_z).r * w.z;

	// Normal map triplanare (whiteout blend) nello spazio di mappatura
	vec3 mapped_n = n;
	if (has_normal) {
		vec3 tnx = texture(normal_tex, uv_x).rgb * 2.0 - 1.0;
		vec3 tny = texture(normal_tex, uv_y).rgb * 2.0 - 1.0;
		vec3 tnz = texture(normal_tex, uv_z).rgb * 2.0 - 1.0;
		tnx.xy *= normal_strength;
		tny.xy *= normal_strength;
		tnz.xy *= normal_strength;
		tnx = vec3(tnx.xy + n.zy, abs(tnx.z) * n.x);
		tny = vec3(tny.xy + n.xz, abs(tny.z) * n.y);
		tnz = vec3(tnz.xy + n.xy, abs(tnz.z) * n.z);
		mapped_n = normalize(tnx.zyx * w.x + tny.xzy * w.y + tnz.xyz * w.z);
	}
	vec3 world_n = mapped_n;
	if (local_mode > 0.5) {
		world_n = normalize((MODEL_MATRIX * vec4(mapped_n, 0.0)).xyz);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(world_n, 0.0)).xyz);

	// Anti-tiling: macro-variazione cromatica (in spazio mondo/oggetto, non ripetitiva)
	float macro = fbm(v_tri_pos * 0.23);
	alb *= mix(0.86, 1.10, macro);

	// Sporco: chiazze procedurali + accumulo verso il basso (vicino al terreno)
	float grime_noise = smoothstep(0.42, 0.78, fbm(v_tri_pos * 0.9 + vec3(7.1, 3.3, 1.7)));
	float ground = 1.0 - smoothstep(0.0, 1.4, v_world_pos.y);
	float grime = clamp(grime_noise * grime_amount + ground * grime_amount * 0.9, 0.0, 0.85);
	alb = mix(alb, alb * grime_color * 1.6, grime);
	rough = mix(rough, 1.0, grime * 0.5);

	alb *= tint.rgb;

	// Crepe procedurali 3D che crescono con il danno
	if (damage > 0.01) {
		vec3 cp = v_tri_pos * 2.2;
		float edge = voronoi_edge(cp + fbm(cp * 1.7) * 0.6);
		float spread = smoothstep(0.35, 0.75, fbm(cp * 0.8 + 11.0) + damage * 0.55);
		float width = mix(0.010, 0.045, damage);
		float crack = (1.0 - smoothstep(0.0, width, edge)) * spread * smoothstep(0.05, 0.25, damage);
		// Scheggiature fini sul secondo livello di dettaglio
		float edge2 = voronoi_edge(cp * 3.1 + 5.0);
		crack = max(crack, (1.0 - smoothstep(0.0, width * 0.6, edge2)) * spread * smoothstep(0.45, 0.9, damage) * 0.8);
		alb = mix(alb, crack_color, crack * 0.85);
		alb *= mix(1.0, 0.82, damage); // polvere/annerimento generale
		rough = mix(rough, 1.0, crack);
		ao *= 1.0 - crack * 0.6;
	}

	ALBEDO = alb + vec3(hit_flash) * 0.35;
	ROUGHNESS = clamp(rough * roughness_mult, 0.04, 1.0);
	METALLIC = metallic_value;
	AO = ao;
	AO_LIGHT_AFFECT = 0.25;
}
