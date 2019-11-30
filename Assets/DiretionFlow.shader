Shader "Custom/DirectionFlow"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
		[NoScaleOffset]_FlowMap("Flow (RG, A noise)",2D) = "black" {}
		[NoScaleOffset]_NorlMap("Normal",2D) = "bump" {}
		[NoScaleOffset] _MainTex("Deriv (AG) Height (B)", 2D) = "black" {}//包含法线数据和高度数据的dxt5mn图
		_Glossiness("Smoothness", Range(0,1)) = 0.5
		_Metallic("Metallic", Range(0,1)) = 0.0
		_Tiling("Tiling,Const",Float) = 1
		_Speed("Speed", Float) = 1
		_FlowStrength("Flow Strength", Float) = 1
		_FlowOffect("Flow Offset",Float) = 0
		_HeightScale("HeightScale,Const",Float) = 1//常量
		_HeightScale2("HeightScale2,Modulated",Float) = 1//控制波浪速度
		_GridResolution("Grid Resolution", Float) = 10
		_TilingModulated("Tiling, Modulated", Float) = 1
		[Toggle(_DUAL_GRID)] _DualGrid("Dual Grid", Int) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows
		#pragma shader_feature _DUAL_GRID
        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        sampler2D _MainTex,_FlowMap,_NorlMap,_DerivHeightMap;

        struct Input
        {
            float2 uv_MainTex;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;
		half  _Tiling,_Speed, _FlowStrength, _FlowOffect, _HeightScale, _HeightScale2, _GridResolution, _TilingModulated;
		float3 UnpackDerHeight(float4 textureData)
		{
			//dxt5mn格式x在A通道
			float3 dh = textureData.agb;
			dh.xy = dh.xy * 2 - 1;
			return dh;
		}
		float2 DirectionalFlowUV(float2 uv, float3 flowVectorAndSpeed, float tiling, float time, out float2x2 rotation)
		{
			float2 dir = normalize(flowVectorAndSpeed.xy);
			rotation = float2x2(dir.y, dir.x, -dir.x, dir.y);
			uv = mul(float2x2(dir.y, -dir.x, dir.x, dir.y), uv);
			uv.y -= time * flowVectorAndSpeed.z;
			return uv * tiling;
		}
		float3 FlowCell(float2 uv, float time, float2 offset, bool gridB)
		{
			offset *= 0.5;
			float2 shift = 1 - offset;
			shift *= 0.5;
			if (gridB) {
				offset += 0.25;
				shift -= 0.25;
			}
			float2x2 derivRotation;
			float2 uvTiled = (floor(uv * _GridResolution + offset) + shift) / _GridResolution;
			float3 flow = tex2D(_FlowMap, uvTiled * 0.1).rgb;
			flow.xy = flow.xy * 2 - 1;
			flow.z *= _FlowStrength;
			float tiling = flow.z * _TilingModulated + _Tiling;
			float2 uvFlow = DirectionalFlowUV(uv + offset, flow, tiling, time,derivRotation);
			float3 dh = UnpackDerHeight(tex2D(_MainTex, uvFlow));
			dh.xy = mul(derivRotation, dh.xy);
			dh *= flow.z * _HeightScale2 + _HeightScale;
			return dh;
		}
		float3 FlowGrid(float2 uv, float time, bool gridB) {
			float3 dhA = FlowCell(uv, time, float2(0, 0), gridB);

			float3 dhB = FlowCell(uv, time, float2(1, 0), gridB);

			float3 dhC = FlowCell(uv, time, float2(0, 1), gridB);
			float3 dhD = FlowCell(uv, time, float2(1, 1), gridB);

			float2 t = uv * _GridResolution;
			if (gridB) {
				t += 0.25;
			}
			t = abs(2 * frac(uv * _GridResolution) - 1);
			float wA = (1 - t.x) * (1 - t.y);
			float wB = t.x * (1 - t.y);
			float wC = (1 - t.x) * t.y;
			float wD = t.x * t.y;

			return dhA * wA + dhB * wB + dhC * wC + dhD * wD;
		}

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
			float time = _Time.y * _Speed;
			
		
			float2 uv = IN.uv_MainTex;
			
			

			float3 dh = FlowGrid(uv, time, false);
			#if defined(_DUAL_GRID)
				dh = (dh + FlowGrid(uv, time, true)) * 0.5;
			#endif
			
			
			fixed4 c = dh.z * dh.z * _Color;
			o.Albedo = c.rgb;
			o.Normal = normalize(float3(-dh.xy, 1));
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
