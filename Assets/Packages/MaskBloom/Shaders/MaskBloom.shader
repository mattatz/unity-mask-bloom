Shader "mattatz/MaskBloom" {

	Properties {
		_MainTex("Texture", 2D) = "white" {}
		_BlurTex("Blur", 2D) = "white" {}
		_Intensity("Bloom intensity", Float) = 1.0
	}

	SubShader {
		Cull Off ZWrite Off ZTest Always

		CGINCLUDE

		#pragma target 5.0
		#include "UnityCG.cginc"

		struct v2f {
			float4 pos : SV_POSITION;
			float2 uv[2] : TEXCOORD0;
		};

		struct v2f_mt {
			float4 pos : SV_POSITION;
			float2 uv[5] : TEXCOORD0;
		};

		sampler2D _MainTex;
		sampler2D _BlurTex;

		half _Intensity;

		half4 _MainTex_TexelSize;
		half4 _BlurTex_TexelSize;

		const static float WEIGHTS[8] = { 0.013,  0.067,  0.194,  0.226, 0.226, 0.194, 0.067, 0.013 };
		const static float OFFSETS[8] = { -6.264, -4.329, -2.403, -0.649, 0.649, 2.403, 4.329, 6.264 };

		struct vsin {
			float4 vertex : POSITION;
			float2 uv : TEXCOORD0;
		};

		struct vs2psDown {
			float4 vertex : POSITION;
			float2 uv[4] : TEXCOORD0;
		};

		struct vs2psBlur {
			float4 vertex : POSITION;
			float2 uv[8] : TEXCOORD0;
		};

		vs2psDown vertDownsample(vsin IN) {
			vs2psDown OUT;
			OUT.vertex = mul(UNITY_MATRIX_MVP, IN.vertex);
			OUT.uv[0] = IN.uv;
			OUT.uv[1] = IN.uv + float2(-0.5, -0.5) * _MainTex_TexelSize.xy;
			OUT.uv[2] = IN.uv + float2(0.5, -0.5) * _MainTex_TexelSize.xy;
			OUT.uv[3] = IN.uv + float2(-0.5, 0.5) * _MainTex_TexelSize.xy;
			return OUT;
		}

		float4 fragDownsample(vs2psDown IN) : COLOR {
			float4 c = 0;
			for (uint i = 0; i < 4; i++) {
				c += tex2D(_MainTex, IN.uv[i]) * 0.25;
			}
			return c;
		}

		float4 fragMask(v2f IN) : COLOR {
			float4 c = tex2D(_MainTex, IN.uv[0]);
			return c * c.a;
		}

		vs2psBlur vertBlurH(vsin IN) {
			vs2psBlur OUT;
			OUT.vertex = mul(UNITY_MATRIX_MVP, IN.vertex);
			for (uint i = 0; i < 8; i++) {
				OUT.uv[i] = IN.uv + float2(OFFSETS[i], 0) * _MainTex_TexelSize.xy;
			}
			return OUT;
		}

		vs2psBlur vertBlurV(vsin IN) {
			vs2psBlur OUT;
			OUT.vertex = mul(UNITY_MATRIX_MVP, IN.vertex);
			for (uint i = 0; i < 8; i++) {
				OUT.uv[i] = IN.uv + float2(0, OFFSETS[i]) * _MainTex_TexelSize.xy;
			}
			return OUT;
		}

		float4 fragBlur(vs2psBlur IN) : COLOR {
			float4 c = 0;
			for (uint i = 0; i < 8; i++) {
				float4 col = tex2D(_MainTex, IN.uv[i]);
				c += col * WEIGHTS[i];
			}
			return c;
		}

		v2f vert(appdata_img v) {
			v2f o;
			o.pos = mul(UNITY_MATRIX_MVP, v.vertex);

			o.uv[0] = v.texcoord.xy;
			o.uv[1] = v.texcoord.xy;

			#if UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0) {
				o.uv[1].y = 1 - o.uv[1].y;
			}
			#endif	

			return o;
		}

		half4 mask(half4 src, half4 color) {
			return lerp(src, color, 1.0 - src.a);
		}

		half4 fragScreen(v2f i) : SV_Target{
			half4 screencolor = tex2D(_MainTex, i.uv[0]);
			half4 addedbloom = tex2D(_BlurTex, i.uv[1].xy);
			half4 result = 1 - (1 - addedbloom * _Intensity) * (1 - screencolor);
			return mask(screencolor, result);
		}

		half4 fragAdd(v2f i) : SV_Target{
			half4 screencolor = tex2D(_MainTex, i.uv[0].xy);
			half4 addedbloom = tex2D(_BlurTex, i.uv[1].xy);
			half4 result = _Intensity * addedbloom + screencolor;
			return mask(screencolor, result);
		}

		ENDCG

		// 0 : Downsample
		Pass {
			CGPROGRAM
			#pragma vertex vertDownsample
			#pragma fragment fragDownsample
			ENDCG
		}

		// 1 : Mask
		Pass {
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragMask
			ENDCG
		}

		// 2 : Horizontal Separable Gaussian
		Pass {
			CGPROGRAM
			#pragma vertex vertBlurH
			#pragma fragment fragBlur
			ENDCG
		}

		// 3 : Vertical Separable Gaussian
		Pass {
			CGPROGRAM
			#pragma vertex vertBlurV
			#pragma fragment fragBlur
			ENDCG
		}

		// 4 : Bloom (Screen)
		Pass {
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragScreen
			ENDCG
		}

		// 5 : Bloom (Add)
		Pass {
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragAdd
			ENDCG
		}

	}

}
