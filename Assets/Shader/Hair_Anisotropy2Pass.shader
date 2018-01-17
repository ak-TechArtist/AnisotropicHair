// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
//Update 3.13 2nd Spe
//Update 17.4.25:2Pass
//Update 17.5.5 modify 2nd light SPECULAR
//Update 17.12.7 修改为Vextex Shader
Shader "Character/Hair/Hair_Anisotropy2Pass" 
{
	Properties 
	{
        _MainColor ("Main Color", Color) = (1,1,1,1)
		_MainTex ("Diffuse (RGB) Alpha (A)", 2D) = "white" {}
		
        _NormalTex ("Normal Map", 2D) = "Black" {}
		_NormalScale("Normal Scale", Range(0, 10)) = 1
		_Specular ("Specular Amount", Range(0, 5)) = 1.0 
        _SpecularColor ("Specular Color1", Color) = (1,1,1,1)
        _SpecularColor2 ("Specular Color2", Color) = (0.5,0.5,0.5,1)
		_SpecularMultiplier ("Specular Power1", float) = 100.0
		_SpecularMultiplier2 ("Secondary Specular Power", float) = 100.0
		
		_PrimaryShift ( "Specular Primary Shift", float) = 0.0
		_SecondaryShift ( "Specular Secondary Shift", float) = .7
		_AnisoDir ("SpecShift(G),Spec Mask (B)", 2D) = "white" {}
        _Cutoff ("Alpha Cut-Off Threshold", float) = 0.5
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull Mode", Float) = 2
	}
	
	SubShader
	{
		//在半透明之前渲染
		Tags {"Queue"="Transparent-10" "IgnoreProjector"="True" "RenderType"="TransparentCutout"}
		LOD 300
		Pass
		{
			ZWrite On
			Cull [_Cull]
			//ColorMask 0
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "Lighting.cginc"	
			#include "AutoLight.cginc"	
			#pragma target 3.0

			sampler2D _MainTex;
			float4 _MainTex_ST;
			half4 _MainColor;

			half _Cutoff;
			half _NormalScale;
			
			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};
		
			struct v2f
			{
				float2 uv : TEXCOORD0;
				float3 worldPos : TEXCOORD1;  
				float3 worldNormal : TEXCOORD2;  
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata_full v)
			{
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f,o);
				o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
				o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);

				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;  
				o.worldNormal = UnityObjectToWorldNormal(v.normal);  
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 albedo = tex2D(_MainTex, i.uv);
				clip(albedo.a -_Cutoff);

				fixed3 worldNormal = normalize(i.worldNormal);	
				float3 worldPos = i.worldPos;		
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(worldPos));
				half NdotL = saturate(dot(worldNormal, worldLightDir)); 
				
				//计算灯光衰减
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
				half4 finalColor = half4(0, 0, 0, 0);
				finalColor.rgb += (albedo.rgb * _MainColor.rgb) * (_LightColor0.rgb * NdotL * atten * 2);
				finalColor.a += albedo.a;
				return finalColor;
			};
			ENDCG

		}

		Pass
		{
			Tags { "LightMode" = "ForwardBase" }
			ZWrite Off
			Cull [_Cull]
			Blend SrcAlpha OneMinusSrcAlpha
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "Lighting.cginc"	
			#include "AutoLight.cginc"	
			#pragma target 3.0

			sampler2D _MainTex, _AnisoDir,_NormalTex;
			float4 _MainTex_ST, _AnisoDir_ST,_NormalTex_ST;

			half _SpecularMultiplier, _PrimaryShift,_Specular,_SecondaryShift,_SpecularMultiplier2;
			half4 _SpecularColor, _MainColor,_SpecularColor2;

			half _Cutoff;
			half _NormalScale;
			
			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};
		
			struct v2f
			{
				float4 uv : TEXCOORD0;
				float4 TtoW0 : TEXCOORD1;  
				float4 TtoW1 : TEXCOORD2;  
				float4 TtoW2 : TEXCOORD3;
				float4 vertex : SV_POSITION;
			};

			//获取头发高光
			fixed StrandSpecular ( fixed3 T, fixed3 V, fixed3 L, fixed exponent)
			{
				fixed3 H = normalize(L + V);
				fixed dotTH = dot(T, H);
				fixed sinTH = sqrt(1 - dotTH * dotTH);
				fixed dirAtten = smoothstep(-1, 0, dotTH);
				return dirAtten * pow(sinTH, exponent);
			}
			
			//沿着法线方向调整Tangent方向
			fixed3 ShiftTangent ( fixed3 T, fixed3 N, fixed shift)
			{
				return normalize(T + shift * N);
			}

			v2f vert (appdata_full v)
			{
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f,o);

				o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
				o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.texcoord, _NormalTex);

				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;  
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  
				fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;

				o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
				o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
				o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);  

				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 albedo = tex2D(_MainTex, i.uv);
				half3 diffuseColor = albedo.rgb * _MainColor.rgb;

				//法线相关
				fixed3 bump = UnpackScaleNormal(tex2D(_NormalTex, i.uv.zw),_NormalScale);
				fixed3 worldNormal = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				fixed3 worldTangent = normalize(half3(i.TtoW0.x, i.TtoW1.x, i.TtoW2.x));
				fixed3 worldBinormal = normalize(half3(i.TtoW0.y, i.TtoW1.y, i.TtoW2.y));			

				fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(worldPos));

				fixed3 spec = tex2D(_AnisoDir, i.uv).rgb;
				half shiftTex = spec.g;//高光的偏移度
				half3 t1 = ShiftTangent(worldBinormal, worldNormal, _PrimaryShift + shiftTex);
				half3 t2 = ShiftTangent(worldBinormal, worldNormal, _SecondaryShift + shiftTex);
				
				half3 spec1 = StrandSpecular(t1, worldViewDir, worldLightDir, _SpecularMultiplier)* _SpecularColor;
				half3 spec2 = StrandSpecular(t2, worldViewDir, worldLightDir, _SpecularMultiplier2)* _SpecularColor2;

				fixed4 finalColor = 0;
				finalColor.rgb = diffuseColor + spec1 * _Specular;
				finalColor.rgb += spec2 * _SpecularColor2 * spec.b * _Specular;
				
				finalColor.a += albedo.a;
				
				return finalColor;
			};
			ENDCG
		}

	}

	FallBack "Mobile/VertexLit"
}