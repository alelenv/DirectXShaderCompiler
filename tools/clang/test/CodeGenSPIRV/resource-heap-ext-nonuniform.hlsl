// RUN: %dxc -T ps_6_6 -E main -fspv-use-descriptor-heap -fspv-target-env=vulkan1.3 -spirv %s | FileCheck %s

// CHECK: OpCapability DescriptorHeapEXT
// CHECK: OpCapability UntypedPointersKHR

// CHECK-DAG: OpDecorate %[[ResourceHeap:[a-zA-Z0-9_]+]] BuiltIn ResourceHeapEXT
// CHECK-DAG: OpDecorate %[[SamplerHeap:[a-zA-Z0-9_]+]] BuiltIn SamplerHeapEXT
// CHECK-DAG: %[[UntypedPtrType:[a-zA-Z0-9_]+]] = OpTypeUntypedPointerKHR UniformConstant
// CHECK-DAG: %[[Tex2DType:[a-zA-Z0-9_]+]] = OpTypeImage %float 2D 2 0 0 1 Unknown
// CHECK-DAG: %[[SamplerType:[a-zA-Z0-9_]+]] = OpTypeSampler
// CHECK-DAG: %[[RA_Tex2DType:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[Tex2DType]]
// CHECK-DAG: %[[RA_SamplerType:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[SamplerType]]
// CHECK-DAG: %[[TexIndex:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtrType]] %[[RA_Tex2DType]] %[[ResourceHeap]]
// CHECK-DAG: %[[SamplerIndex:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtrType]] %[[RA_SamplerType]] %[[SamplerHeap]]
// CHECK-DAG: OpDecorate %[[TexIndex]] NonUniform
// CHECK-DAG: OpDecorate %[[SamplerIndex]] NonUniform

float4 main(uint idx : A) : SV_Target {
  Texture2D<float4> tex = ResourceDescriptorHeap[NonUniformResourceIndex(idx)];
  SamplerState samp = SamplerDescriptorHeap[NonUniformResourceIndex(idx + 1)];

  return tex.SampleLevel(samp, float2(0.0, 0.0), 0.0);
}
