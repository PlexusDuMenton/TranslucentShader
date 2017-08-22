#if !defined(MY_SHADOWS_INCLUDED)
    #define MY_SHADOWS_INCLUDED

    #include "UnityCG.cginc"

    struct appdata {
	    float4 vertex : POSITION;
	    float2 uv : TEXCOORD0;
	    float3 normal : NORMAL;
    };
    struct v2f {
	    float4 vertex : SV_POSITION;
	    float2 uv : TEXCOORD0;
        #if defined(SHADOWS_CUBE)
	        float3 lightVec : TEXCOORD1;
        #endif
    };

    float4 _Tint;
    sampler2D _MainTex;
    float4 _MainTex_ST;
    float _AlphaCutoff;

    v2f vert (appdata v) {
    v2f i;
        #if defined(SHADOWS_CUBE)
            i.position = UnityObjectToClipPos(v.position);
            i.lightVec =
                mul(unity_ObjectToWorld, v.position).xyz - _LightPositionRange.xyz;
        #else
            i.vertex = UnityClipSpaceShadowCasterPos(v.vertex.xyz, v.normal);
            i.vertex = UnityApplyLinearShadowBias(i.vertex);
        #endif
        i.uv = TRANSFORM_TEX(v.uv, _MainTex);
        return i;
    }
    
    float GetAlpha(v2f i)
    {
        float alpha = _Tint.a;
        alpha *= tex2D(_MainTex, i.uv.xy).a;
        return alpha;
    }

    half4 frag (v2f i) : SV_Target{
        float alpha = GetAlpha(i);
        #if defined(_RENDERING_CUTOUT)
            clip(alpha - _AlphaCutoff);
        #endif
        #if defined(SHADOWS_CUBE)
            float depth = length(i.lightVec) + unity_LightShadowBias.x;
                depth *= _LightPositionRange.w;
                return UnityEncodeCubeShadowDepth(depth);
        #else
            return 0;
        #endif
    }
#endif