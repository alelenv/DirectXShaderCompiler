// RUN: %dxc -T ps_6_6 -E main -fspv-use-descriptor-heap -fspv-target-env=vulkan1.3 -spirv %s | FileCheck %s

// Validates that explicitly-bound resources coexist with heap resources.

// CHECK: OpCapability DescriptorHeapEXT
// CHECK: OpExtension "SPV_EXT_descriptor_heap"
// CHECK: OpExtension "SPV_KHR_untyped_pointers"

// CHECK-DAG: OpDecorate %[[ResourceHeap:[a-zA-Z0-9_]+]] BuiltIn ResourceHeapEXT
// CHECK-DAG: OpDecorate %[[SamplerHeap:[a-zA-Z0-9_]+]] BuiltIn SamplerHeapEXT

// The bound texture gets a normal OpVariable with DescriptorSet/Binding.
// CHECK-DAG: OpDecorate %[[BoundTex:[a-zA-Z0-9_]+]] DescriptorSet
// CHECK-DAG: OpDecorate %[[BoundTex]] Binding

// CHECK-DAG: %[[UntypedPtr:[a-zA-Z0-9_]+]] = OpTypeUntypedPointerKHR UniformConstant
// CHECK-DAG: %[[Tex2DType:[a-zA-Z0-9_]+]] = OpTypeImage %float 2D 2 0 0 1 Unknown
// CHECK-DAG: %[[SamplerType:[a-zA-Z0-9_]+]] = OpTypeSampler
// CHECK-DAG: %[[RA_Tex2D:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[Tex2DType]]{{$}}
// CHECK-DAG: %[[RA_Sampler:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[SamplerType]]{{$}}
// CHECK-DAG: %[[PtrTex:[a-zA-Z0-9_]+]] = OpTypePointer UniformConstant %[[Tex2DType]]

// Bound texture: normal OpVariable.
// CHECK: %[[BoundTex]] = OpVariable %[[PtrTex]] UniformConstant
// Heap variables.
// CHECK-DAG: %[[ResourceHeap]] = OpUntypedVariableKHR %[[UntypedPtr]] UniformConstant
// CHECK-DAG: %[[SamplerHeap]]  = OpUntypedVariableKHR %[[UntypedPtr]] UniformConstant

[[vk::binding(0, 0)]]
Texture2D<float4> boundTex : register(t0);

float4 main(float2 uv : TEXCOORD0) : SV_Target {
  Texture2D<float4> heapTex = ResourceDescriptorHeap[1];
  SamplerState samp = SamplerDescriptorHeap[0];

  // Heap texture: OpUntypedAccessChainKHR through heap.
  // CHECK: %[[HeapDesc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[RA_Tex2D]] %[[ResourceHeap]] %uint_1
  // CHECK: %[[HeapVal:[a-zA-Z0-9_]+]] = OpLoad %[[Tex2DType]] %[[HeapDesc]]

  // Bound texture: plain OpLoad from OpVariable.
  // CHECK: %[[BoundVal:[a-zA-Z0-9_]+]] = OpLoad %[[Tex2DType]] %[[BoundTex]]

  // CHECK: OpSampledImage %{{.*}} %[[BoundVal]]
  // CHECK: OpImageSampleImplicitLod
  float4 a = boundTex.Sample(samp, uv);

  // CHECK: OpSampledImage %{{.*}} %[[HeapVal]]
  // CHECK: OpImageSampleImplicitLod
  float4 b = heapTex.Sample(samp, uv + 0.5);

  return a + b;
}
