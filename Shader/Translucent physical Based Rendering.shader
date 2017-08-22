Shader "Translucent PBR"
{
	
	
	
	Properties
	{
		_Tint ("Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Albedo", 2D) = "white" {}
		_AlphaCutoff ("Alpha Cutoff", Range(0, 1)) = 0.5
		_Smoothness ("Smoothness", Range(0, 1)) = 0.1
		_SmoothnessMap ("Smoothness Map", 2D) = "white" {}

		[NoScaleOffset]_NormalMap ("Normals", 2D) = "bump" {}
		_BumpScale ("Bump Scale", Float) = 1
		 
		[Gamma]_Metallic ("Metallic", Range(0, 1)) = 0.1
		_MetallicMap ("Metallic Map", 2D) = "white" {}

		[NoScaleOffset] _EmissionMap ("Emission", 2D) = "white" {}
		[HDR]_Emission ("Emission", Color) = (0, 0, 0)

		[NoScaleOffset] _OcclusionMap ("Occlusion", 2D) = "white" {}
		_OcclusionStrength("Occlusion Strength", Range(0, 1)) = 1

		[HDR]_TranslucencyColor ("Translucency Color", Color) = (1, 1, 1, 1)
		_TranslucencyMap ("Translucency Map", 2D) = "black" {}
		_TranslucencyScale ("Translucency Scale", Range(0, 2)) = 1
		_TranslucencyPower ("Specular", Range(0, 4)) = 1
		_SSS ("SSS", Range(0, 1)) = 0.2

		_DetailTex ("Detail Albedo", 2D) = "gray" {}
		[NoScaleOffset] _DetailNormalMap ("Detail Normals", 2D) = "bump" {}
		_DetailBumpScale ("Detail Bump Scale", Float) = 1

		[HideInInspector] _SrcBlend ("_SrcBlend", Float) = 1
		[HideInInspector] _DstBlend ("_DstBlend", Float) = 0
		[HideInInspector] _ZWrite ("_ZWrite", Float) = 1
	}
	CustomEditor "TranslucentShaderGUI"
	CGINCLUDE

	#define BINORMAL_PER_FRAGMENT

	ENDCG

	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			Tags {
				"LightMode" = "ForwardBase" 
			}
			Blend [_SrcBlend] [_DstBlend]
			ZWrite [_ZWrite]
			Cull Off
			CGPROGRAM
			
			#pragma target 3.0
			#pragma multi_compile _ SHADOWS_SCREEN
			#pragma multi_compile _ VERTEXLIGHT_ON
			#pragma multi_compile_fog

			#pragma vertex vert
			#pragma fragment frag
			#pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT

			#define FORWARD_BASE_PASS

			#include "Translucent.cginc"

			ENDCG
		}
		Pass {
			Tags {
				"LightMode" = "ForwardAdd"
			}
			Blend [_SrcBlend] One
			ZWrite Off
			Cull Off
			CGPROGRAM
			
			#pragma target 3.0
			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog
			#pragma vertex vert
			#pragma fragment frag
			#pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
			#include "Translucent.cginc"

			ENDCG

		}

		/* Deferred is a mess for Translucency >.>
		Pass {
			Tags {
				"LightMode" = "Deferred"
			}
			Cull Off
			CGPROGRAM
			#pragma target 3.0
			#pragma exclude_renderers nomrt
			#pragma multi_compile_fwdadd_fullshadows
			#pragma vertex vert
			#pragma fragment frag

			#pragma shader_feature _ _RENDERING_CUTOUT
			#pragma multi_compile _ UNITY_HDR_ON

			#define DEFERRED_PASS


			#include "Translucent.cginc"
			ENDCG
		}
		*/
		Pass {
			Tags {
				"LightMode" = "ShadowCaster"
			}
			Cull Off
			CGPROGRAM

			#pragma target 3.0

			#pragma multi_compile_shadowcaster

			#pragma vertex vert
			#pragma fragment frag
			#pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT

			#include "TranslucentShadow.cginc"

			ENDCG
		}

	}
}
