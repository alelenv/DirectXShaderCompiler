// RUN: %dxc -T ps_6_6 -E main -fspv-use-descriptor-heap -fspv-target-env=vulkan1.3 -spirv %s | FileCheck %s

// CHECK: OpCapability DescriptorHeapEXT
// CHECK: OpExtension "SPV_EXT_descriptor_heap"
// CHECK: OpExtension "SPV_KHR_untyped_pointers"

// CHECK-DAG: OpDecorate %[[ResourceHeap:[a-zA-Z0-9_]+]] BuiltIn ResourceHeapEXT
// CHECK-DAG: OpDecorate %[[SamplerHeap:[a-zA-Z0-9_]+]] BuiltIn SamplerHeapEXT

// CHECK-DAG: %[[UntypedPtr:[a-zA-Z0-9_]+]] = OpTypeUntypedPointerKHR UniformConstant
// CHECK-DAG: %[[Tex2DType:[a-zA-Z0-9_]+]] = OpTypeImage %float 2D 2 0 0 1 Unknown
// CHECK-DAG: %[[SamplerType:[a-zA-Z0-9_]+]] = OpTypeSampler
// CHECK-DAG: %[[RA_Tex2D:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[Tex2DType]]{{$}}
// CHECK-DAG: %[[RA_Sampler:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[SamplerType]]{{$}}

float4 main(float2 uv : TEXCOORD0) : SV_Target {
  Texture2D<float4> tex = ResourceDescriptorHeap[0];
  SamplerState samp = SamplerDescriptorHeap[0];

  // CHECK: OpUntypedAccessChainKHR %[[UntypedPtr]] %[[RA_Tex2D]] %[[ResourceHeap]] %uint_0
  // CHECK: OpUntypedAccessChainKHR %[[UntypedPtr]] %[[RA_Sampler]] %[[SamplerHeap]] %uint_0

  // CHECK: OpImageSampleExplicitLod %v4float %{{[a-zA-Z0-9_]+}} %{{[a-zA-Z0-9_]+}} Grad
  float4 a = tex.SampleGrad(samp, uv, ddx(uv), ddy(uv));

  // CHECK: OpImageSampleImplicitLod %v4float %{{[a-zA-Z0-9_]+}} %{{[a-zA-Z0-9_]+}} Bias
  float4 b = tex.SampleBias(samp, uv, -1.0);

  return a + b;
}
