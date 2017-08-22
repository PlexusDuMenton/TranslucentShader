#if !defined(MY_LIGHTING_INCLUDED)
    #define MY_LIGHTING_INCLUDED
	
    #include "UnityPBSLighting.cginc"
    #include "AutoLight.cginc"
    #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
	    #define FOG_DEPTH 1
    #endif
			






    //==================================DATA STRUCT ================
    struct FragmentOutput
    {
        float4 color : SV_Target;
    };
    struct appdata
    {
        float4 vertex : POSITION;
        float4 uv : TEXCOORD0;
        float4 tangent : TANGENT;
        float3 normal : NORMAL;
    };

    struct v2f
    {
        float4 pos : SV_POSITION;
        float4 uv : TEXCOORD0;
        float3 normal : TEXCOORD1;

        #if defined(BINORMAL_PER_FRAGMENT)
            float4 tangent : TEXCOORD2;
        #else
            float3 tangent : TEXCOORD2;
            float3 binormal : TEXCOORD3;
        #endif

        #if FOG_DEPTH
            float4 worldPos : TEXCOORD4;
        #else
            float3 worldPos : TEXCOORD4;
        #endif

        SHADOW_COORDS(5)

        #if defined(VERTEXLIGHT_ON)
            float3 vertexLightColor : TEXCOORD6;
        #endif
        float3 viewDir : TEXCOORD7;
    };











    //===========================VARIABLE==========================


    sampler2D _MainTex, 
            _AlphaTex,
            _DetailTex,
            _TranslucencyMap,
            _EmissionMap;


    float4 _MainTex_ST,
            _DetailTex_ST;
    float4 _Tint,
            _Emission;

    //Translucency floats
    float _TranslucencyScale,
            _TranslucencyPower,
            _SSS;
    float4 _TranslucencyColor;


    //smootness Metalic
    sampler2D _MetallicMap,
            _SmoothnessMap;
    float _Smoothness,
            _Metallic;

    sampler2D _OcclusionMap;
    float _OcclusionStrength;

    float _AlphaCutoff;

    sampler2D _NormalMap, 
            _DetailNormalMap;
    float _BumpScale, 
            _DetailBumpScale;









    //=============== UTILITY FUNCTION ===========

    float GetOcclusion(v2f i)
    {
        return lerp(1, tex2D(_OcclusionMap, i.uv.xy).g, _OcclusionStrength);
    }

    float4 GetEmission(v2f i)
    {
    #if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
            return tex2D(_EmissionMap, i.uv.xy) * _Emission;
    #else
        return 0;
    #endif
    }

    float GetAlpha(v2f i)
    {
        float alpha = _Tint.a;
        alpha *= tex2D(_MainTex, i.uv.xy).a;
        return alpha;
    }

    float GetSmoothness(v2f i)
    {
        return tex2D(_SmoothnessMap, i.uv) * _Smoothness;

    }

    //=== BOX PROJECTION : Used for undirect light reflection ====
    float3 BoxProjection(
        float3 direction, float3 position,
        float4 cubemapPosition, float3 boxMin, float3 boxMax
    )
    {
    #if UNITY_SPECCUBE_BOX_PROJECTION
            UNITY_BRANCH
            if (cubemapPosition.w > 0) {
                float3 factors =
                    ((direction > 0 ? boxMax : boxMin) - position) / direction;
                float scalar = min(min(factors.x, factors.y), factors.z);
                direction = direction * scalar + (position - cubemapPosition);
            }
    #endif
        return direction;
    }

    float4 ApplyFog(float4 color, v2f i)
    {
    #if FOG_DEPTH
        float viewDistance = length(_WorldSpaceCameraPos - i.worldPos);
		    viewDistance = UNITY_Z_0_FAR_FROM_CLIPSPACE(i.worldPos.w);
        UNITY_CALC_FOG_FACTOR_RAW(viewDistance);
        color.rgb = lerp(unity_FogColor.rgb, color.rgb, saturate(unityFogFactor));
    #endif
        return color;
    }
			
    float3 CreateBinormal(float3 normal, float3 tangent, float binormalSign)
    {
        return cross(normal, tangent.xyz) * (binormalSign * unity_WorldTransformParams.w);
    }



    void InitializeFragmentNormal(inout v2f i)
    {
        float3 mainN = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);
        float3 detailN = UnpackScaleNormal(tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale);
        float3 tangentSpaceNormal = BlendNormals(mainN, detailN);

    #if defined(BINORMAL_PER_FRAGMENT)
            float3 binormal = CreateBinormal(i.normal, i.tangent.xyz, i.tangent.w);
    #else
        float3 binormal = i.binormal;
    #endif

        i.normal = normalize(
            tangentSpaceNormal.x * i.tangent +
            tangentSpaceNormal.y * binormal +
            tangentSpaceNormal.z * i.normal
        );
    }













    //========================LIGHTING FUNCRTION=======================
    UnityIndirect CreateIndirectLight(v2f i, float3 viewDir)
    {
        UnityIndirect indirectLight;
        indirectLight.diffuse = 0;
        indirectLight.specular = 0;

        #if defined(VERTEXLIGHT_ON)
            indirectLight.diffuse = i.vertexLightColor;
        #endif

        #if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
            indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
            float3 reflectionDir = reflect(-viewDir, i.normal);
            Unity_GlossyEnvironmentData envData;
            envData.roughness = 1 - GetSmoothness(i);
            envData.reflUVW = BoxProjection(
                reflectionDir, i.worldPos,
                unity_SpecCube0_ProbePosition,
                unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax
            );
            float3 probe0 = Unity_GlossyEnvironment(
                UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData
            );
            envData.reflUVW = BoxProjection(
                reflectionDir, i.worldPos,
                unity_SpecCube1_ProbePosition,
                unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax
            );
            #if UNITY_SPECCUBE_BLENDING
                float interpolator = unity_SpecCube0_BoxMin.w;
                UNITY_BRANCH
                if (interpolator < 0.99999) {
                    float3 probe1 = Unity_GlossyEnvironment(
                    UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0),
                        unity_SpecCube0_HDR, envData
                    );
                    indirectLight.specular = lerp(probe1, probe0, interpolator);
                }
                else {
                    indirectLight.specular = probe0;
                }
            #else
                indirectLight.specular = probe0;
            #endif
            float occlusion = GetOcclusion(i);
            indirectLight.diffuse *= occlusion;
            indirectLight.specular *= occlusion;
            #if defined(DEFERRED_PASS) && UNITY_ENABLE_REFLECTION_BUFFERS
                indirectLight.specular = 0;
            #endif
        #endif
        return indirectLight;
    }

    //=== BOTH DIRECT LIGHT FUNCTION (NORMAL & TRANSLUCENT)====

    UnityLight CreateLight(v2f i)
    {
        UnityLight light;
        #if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
            light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
        #else
            light.dir = _WorldSpaceLightPos0.xyz;
        #endif
        UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);
        light.color = _LightColor0.rgb * attenuation;
        light.ndotl = DotClamped(i.normal, light.dir);
        return light;
    }



    UnityLight CreateTranslucentLight(v2f i, float3 normal)
    {
        UnityLight light;
        #if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
            light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
        #else
            light.dir = _WorldSpaceLightPos0.xyz;
        #endif

        UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);
        #if !defined(SPOT)
            light.color = _LightColor0.rgb * saturate(attenuation + saturate((_SSS * 1.5) - 0.15) + 0.15);
        #else
            light.color = _LightColor0.rgb *attenuation;
        #endif
        light.ndotl = DotClamped(normal, light.dir) * (1 - _SSS) + _SSS;
        float3 viewDir = normalize(i.viewDir);
        light.ndotl = clamp(light.ndotl * 0.8 + pow((-abs(dot(normal, light.dir)) + 1), 0.5), 0, 1);
        float3 normal4view = -normal;
#if defined(FORWARD_BACK_PASS)
            normal4view *= -1;
        #endif
        #if defined(_INVERTNORMAL)
            normal4view *= -1;
        #endif
    float scale = _TranslucencyScale * (1+dot(normal4view, viewDir)*0.5);
        float4 specular = 0;
        if (_TranslucencyPower > 0)
        {
            specular = pow(max(0, dot(viewDir, -light.dir)), _TranslucencyPower * 50 + 1) * _TranslucencyPower + pow(max(0, dot(viewDir, -light.dir)), _TranslucencyPower * 2000 + 1) * _TranslucencyPower + pow(max(0, dot(viewDir, -light.dir)), _TranslucencyPower * 10000 + 1);
            specular *= attenuation;
        }
                
        light.ndotl = (specular * 2 * _TranslucencyPower + light.ndotl * 0.8) * scale;
        return light;
    }

    //=== VERTEX COLOR LIGHTING ===
    void ComputeVertexLightColor (appdata v) {
        #if defined(VERTEXLIGHT_ON)
            i.vertexLightColor = Shade4PointLights(
                unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
                unity_LightColor[0].rgb, unity_LightColor[1].rgb,
                unity_LightColor[2].rgb, unity_LightColor[3].rgb,
                unity_4LightAtten0, i.worldPos, i.normal
            );
	    #endif
    }






    //==============================================================MAIN VERTEX AND FRAG FUNCTIONS==========================================================
			
    v2f vert (appdata v)
    {
        v2f i;
        i.pos = UnityObjectToClipPos(v.vertex);
        i.worldPos = mul(unity_ObjectToWorld, v.vertex);

        #if FOG_DEPTH
            i.worldPos.w = i.pos.z;
        #endif
        i.normal = UnityObjectToWorldNormal(v.normal);
            
        #if defined(BINORMAL_PER_FRAGMENT)
            i.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
        #else
            i.tangent = UnityObjectToWorldDir(v.tangent.xyz);
            i.binormal = CreateBinormal(i.normal, i.tangent, v.tangent.w);
        #endif

        i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
        i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);

	    TRANSFER_SHADOW(i);
        #if defined(FORWARD_BACK_PASS)
            i.normal *= -1;
        #endif
        #if defined(_INVERTNORMAL)
            i.normal *= -1;
        #endif
        i.viewDir = WorldSpaceViewDir (v.vertex);

        ComputeVertexLightColor(v);
        return i;
    }


    float3 TranslucentLightFrag(v2f i){
        float3 inversedNormal = i.normal;

        #if defined(_INVERTNORMALTRANSLUCENT)
            inversedNormal *= -1;
        #endif
        UnityLight Light = CreateTranslucentLight (i,inversedNormal);

        float3 lightImpact = pow(tex2D(_TranslucencyMap, i.uv.xy) * Light.ndotl * float4(Light.color,1),2)*_TranslucencyColor;
        return lightImpact;
    }

    float4 NormalLightFrag(v2f i){
        InitializeFragmentNormal(i);
        float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

        float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Tint.rgb;
	        albedo *= tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
        ;
        float Metallic = tex2D(_MetallicMap, i.uv.xy) * _Metallic;

        float3 specularTint;
        float oneMinusReflectivity;
        albedo = DiffuseAndSpecularFromMetallic(
            albedo, Metallic, specularTint, oneMinusReflectivity
        );
				

        float alpha = GetAlpha(i);
        #if defined(_RENDERING_CUTOUT)
            clip(alpha - _AlphaCutoff);
        #endif
    
        float4 color = UNITY_BRDF_PBS(
            albedo, specularTint,
            oneMinusReflectivity, GetSmoothness(i),
            i.normal, viewDir,
            CreateLight(i), CreateIndirectLight(i, viewDir)
        );
        #if defined(_RENDERING_TRANSPARENT)
            color *= alpha;
            alpha = 1 - oneMinusReflectivity + alpha * oneMinusReflectivity;
        #endif
        #if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
            color.a=alpha;
        #endif
    
        return color;

    }

    FragmentOutput frag(v2f i) : SV_Target
    {
        float4 BaseLight = NormalLightFrag(i);
        float3 TLight = TranslucentLightFrag(i);

        float4 finalLight = float4(BaseLight.rgb + TLight+GetEmission(i).rgb, BaseLight.a);

        FragmentOutput output;
        output.color = ApplyFog(finalLight, i);
        return output;
    }
#endif