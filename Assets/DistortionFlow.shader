Shader "Custom/DistortionFlow"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
		[NoScaleOffset]_FlowMap("Flow (RG, A noise)",2D) = "black" {}
		[NoScaleOffset]_NorlMap("Normal",2D) = "bump" {}
		[NoScaleOffset] _DerivHeightMap("Deriv (AG) Height (B)", 2D) = "black" {}//
		_Glossiness("Smoothness", Range(0,1)) = 0.5
		_Metallic("Metallic", Range(0,1)) = 0.0
		_UJump("UJump",Range(-0.25,0.25)) = 0.1
		_VJump("VJump", Range(-0.25, 0.25)) = 0.1
		_Tiling("Tiling",Float) = 1
		_Speed("Speed", Float) = 1
		_FlowStrength("Flow Strength", Float) = 1
		_FlowOffect("Flow Offset",Float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        sampler2D _MainTex,_FlowMap,_NorlMap;

        struct Input
        {
            float2 uv_MainTex;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;
		half _UJump, _VJump, _Tiling,_Speed, _FlowStrength, _FlowOffect;
#if !defined(FLOW_INCLUDED)
#define FLOW_INCLUDE
		float3 FlowUV(float2 uv,float2 flowVector, float time,bool flowB,half2 jump,half tilling,half flowOffect)
		{
			float phaseOffect = flowB ? 0.5 : 0;
			float progress = frac(time + phaseOffect);
			float3 uvw;
			uvw.xy = uv - flowVector * (progress + flowOffect);
			uvw.xy *= tilling;
			uvw.xy += phaseOffect;
			uvw.xy += (time - progress) * jump;
			uvw.z = 1 - abs(1 - 2 * progress);
			return uvw;
		}
#endif
        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // Albedo comes from a texture tinted by color
			float2 flowVector = tex2D(_FlowMap, IN.uv_MainTex).rgb;
			flowVector.xy = flowVector.xy * 2 - 1;
			flowVector *= _FlowStrength;
			float noise = tex2D(_FlowMap, IN.uv_MainTex).a;
		
			half2 jump = float2(_UJump, _VJump);
			float3 uvw = FlowUV(IN.uv_MainTex, flowVector.xy,_Time.y * _Speed + noise,true, jump, _Tiling, _FlowOffect);
			float3 uvw2 = FlowUV(IN.uv_MainTex, flowVector.xy, _Time.y * _Speed + noise,false, jump, _Tiling, _FlowOffect);
            fixed4 tex1 = tex2D (_MainTex, uvw.xy) * uvw .z;
			fixed4 tex2 = tex2D(_MainTex, uvw2.xy) * uvw2.z;
			float3 normal1 = UnpackNormal(tex2D(_NorlMap, uvw.xy) * uvw.z);
			float3 normal2 = UnpackNormal(tex2D(_NorlMap, uvw2.xy) * uvw2.z);
			fixed4 c = (tex1 + tex2) * _Color;
            o.Albedo = c.rgb;
			o.Normal = normalize(normal1 + normal2);
            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
