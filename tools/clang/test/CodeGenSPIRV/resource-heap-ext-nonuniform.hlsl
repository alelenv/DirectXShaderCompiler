// RUN: %dxc -T ps_6_6 -E main -fspv-use-descriptor-heap -fspv-target-env=vulkan1.3 -spirv %s | FileCheck %s

// CHECK: OpCapability DescriptorHeapEXT
// CHECK-NOT: OpCapability UntypedPointersKHR

// CHECK-DAG: OpDecorate %[[ResourceHeap:[a-zA-Z0-9_]+]] BuiltIn ResourceHeapEXT
// CHECK-DAG: OpDecorate %[[SamplerHeap:[a-zA-Z0-9_]+]] BuiltIn SamplerHeapEXT

// CHECK-DAG: %[[UntypedPtrType:[a-zA-Z0-9_]+]] = OpTypeUntypedPointerKHR UniformConstant
// CHECK-DAG: %[[Tex2DType:[a-zA-Z0-9_]+]] = OpTypeImage %float 2D 2 0 0 1 Unknown
// CHECK-DAG: %[[SamplerType:[a-zA-Z0-9_]+]] = OpTypeSampler
// CHECK-DAG: %[[RA_Tex2DType:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[Tex2DType]]
// CHECK-DAG: %[[RA_SamplerType:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[SamplerType]]

// NonUniform must decorate the index, the access chain result, and the loaded value.
// CHECK-DAG: OpDecorate %[[TexIdx:[a-zA-Z0-9_]+]] NonUniform
// CHECK-DAG: OpDecorate %[[TexChain:[a-zA-Z0-9_]+]] NonUniform
// CHECK-DAG: OpDecorate %[[TexLoaded:[a-zA-Z0-9_]+]] NonUniform
// CHECK-DAG: OpDecorate %[[SampIdx:[a-zA-Z0-9_]+]] NonUniform
// CHECK-DAG: OpDecorate %[[SampChain:[a-zA-Z0-9_]+]] NonUniform
// CHECK-DAG: OpDecorate %[[SampLoaded:[a-zA-Z0-9_]+]] NonUniform

// CHECK: %[[ResourceHeap]] = OpUntypedVariableKHR %[[UntypedPtrType]] UniformConstant
// CHECK: %[[SamplerHeap]]  = OpUntypedVariableKHR %[[UntypedPtrType]] UniformConstant

float4 main(uint idx : A) : SV_Target {
  Texture2D<float4> tex = ResourceDescriptorHeap[NonUniformResourceIndex(idx)];
  SamplerState samp = SamplerDescriptorHeap[NonUniformResourceIndex(idx + 1)];

  // CHECK: %[[TexChain]] = OpUntypedAccessChainKHR %[[UntypedPtrType]] %[[RA_Tex2DType]] %[[ResourceHeap]] %[[TexIdx]]
  // CHECK: %[[TexLoaded]] = OpLoad %[[Tex2DType]] %[[TexChain]]
  // CHECK: %[[SampChain]] = OpUntypedAccessChainKHR %[[UntypedPtrType]] %[[RA_SamplerType]] %[[SamplerHeap]] %[[SampIdx]]
  // CHECK: %[[SampLoaded]] = OpLoad %[[SamplerType]] %[[SampChain]]
  // CHECK: %[[Combined:[a-zA-Z0-9_]+]] = OpSampledImage %{{.*}} %[[TexLoaded]] %[[SampLoaded]]
  // CHECK: OpImageSampleExplicitLod %v4float %[[Combined]]
  return tex.SampleLevel(samp, float2(0.0, 0.0), 0.0);
}
