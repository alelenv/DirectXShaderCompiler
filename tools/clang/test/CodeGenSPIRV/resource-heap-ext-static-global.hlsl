// RUN: %dxc -T cs_6_6 -E main -Od -fspv-use-descriptor-heap -fspv-target-env=vulkan1.3 -spirv %s | FileCheck %s

// Validates the UE bindless idiom: static const resources initialized from
// runtime uint indices at global scope, plus a literal-index sampler.

// CHECK: OpCapability DescriptorHeapEXT
// CHECK-NOT: OpCapability UntypedPointersKHR
// CHECK: OpExtension "SPV_EXT_descriptor_heap"
// CHECK: OpExtension "SPV_KHR_untyped_pointers"

// CHECK-DAG: OpDecorate %[[ResourceHeap:[a-zA-Z0-9_]+]] BuiltIn ResourceHeapEXT
// CHECK-DAG: OpDecorate %[[SamplerHeap:[a-zA-Z0-9_]+]] BuiltIn SamplerHeapEXT

// CHECK-DAG: %[[UntypedPtr:[a-zA-Z0-9_]+]] = OpTypeUntypedPointerKHR UniformConstant
// CHECK-DAG: %[[Tex2DType:[a-zA-Z0-9_]+]] = OpTypeImage %float 2D 2 0 0 1 Unknown
// CHECK-DAG: %[[SamplerType:[a-zA-Z0-9_]+]] = OpTypeSampler
// CHECK-DAG: %[[SBBufDesc:[a-zA-Z0-9_]+]] = OpTypeBufferEXT StorageBuffer
// CHECK-DAG: %[[RWTex2DType:[a-zA-Z0-9_]+]] = OpTypeImage %float 2D 2 0 0 2 Rgba32f

// CHECK-DAG: %[[RA_Tex2D:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[Tex2DType]]{{$}}
// CHECK-DAG: %[[RA_Sampler:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[SamplerType]]{{$}}
// CHECK-DAG: %[[RA_SBBuf:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[SBBufDesc]]{{$}}
// CHECK-DAG: %[[RA_RWTex2D:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[RWTex2DType]]{{$}}

// CHECK-DAG: %[[ResourceHeap]] = OpUntypedVariableKHR %[[UntypedPtr]] UniformConstant
// CHECK-DAG: %[[SamplerHeap]]  = OpUntypedVariableKHR %[[UntypedPtr]] UniformConstant

// Runtime uint indices (placed in $Globals cbuffer by DXC).
uint BindlessSRV_ColorTex;
uint BindlessSRV_DataBuf;
uint BindlessUAV_OutTex;

// UE bindless pattern: static const from runtime heap index.
static const Texture2D<float4> ColorTex = ResourceDescriptorHeap[BindlessSRV_ColorTex];
static const StructuredBuffer<float4> DataBuf = ResourceDescriptorHeap[BindlessSRV_DataBuf];
static const RWTexture2D<float4> OutTex = ResourceDescriptorHeap[BindlessUAV_OutTex];

// Literal-index sampler (common UE pattern for global bilinear/point samplers).
static const SamplerState BilinearSamp = SamplerDescriptorHeap[2];

[numthreads(8, 8, 1)]
void main(uint3 tid : SV_DispatchThreadID) {
  // Heap indices are dynamic (loaded from $Globals), not literal constants.
  // CHECK: %[[TexIdx:[a-zA-Z0-9_]+]] = OpLoad %uint
  // CHECK: %[[TexDesc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[RA_Tex2D]] %[[ResourceHeap]] %[[TexIdx]]
  // CHECK: OpLoad %[[Tex2DType]] %[[TexDesc]]

  // CHECK: %[[BufIdx:[a-zA-Z0-9_]+]] = OpLoad %uint
  // CHECK: OpUntypedAccessChainKHR %[[UntypedPtr]] %[[RA_SBBuf]] %[[ResourceHeap]] %[[BufIdx]]
  // CHECK: OpBufferPointerEXT

  // CHECK: %[[OutIdx:[a-zA-Z0-9_]+]] = OpLoad %uint
  // CHECK: %[[OutDesc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[RA_RWTex2D]] %[[ResourceHeap]] %[[OutIdx]]
  // CHECK: OpLoad %[[RWTex2DType]] %[[OutDesc]]

  // Literal sampler index.
  // CHECK: OpUntypedAccessChainKHR %[[UntypedPtr]] %[[RA_Sampler]] %[[SamplerHeap]] %uint_2
  // CHECK: OpLoad %[[SamplerType]]

  float2 uv = float2(tid.xy) / 512.0;

  // CHECK: OpSampledImage
  // CHECK: OpImageSampleExplicitLod
  float4 color = ColorTex.SampleLevel(BilinearSamp, uv, 0);

  float4 data = DataBuf[tid.x];

  // CHECK: OpImageWrite %{{[a-zA-Z0-9_]+}}
  OutTex[tid.xy] = color + data;
}
