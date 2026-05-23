// RUN: %dxc -T cs_6_6 -E main -fspv-use-descriptor-heap -fspv-target-env=vulkan1.3 -spirv %s | FileCheck %s

// CHECK: OpCapability DescriptorHeapEXT
// CHECK: OpExtension "SPV_EXT_descriptor_heap"
// CHECK: OpExtension "SPV_KHR_untyped_pointers"

// CHECK-DAG: OpDecorate %[[ResourceHeap:[a-zA-Z0-9_]+]] BuiltIn ResourceHeapEXT
// CHECK-DAG: %[[UntypedPtr:[a-zA-Z0-9_]+]] = OpTypeUntypedPointerKHR UniformConstant
// CHECK-DAG: %[[SBBufDesc:[a-zA-Z0-9_]+]] = OpTypeBufferEXT StorageBuffer
// CHECK-DAG: %[[SBBufArray:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[SBBufDesc]]

// groupshared lives in Workgroup storage class.
// CHECK-DAG: %[[WorkgroupPtr:[a-zA-Z0-9_]+]] = OpTypePointer Workgroup
// CHECK: %[[ResourceHeap]] = OpUntypedVariableKHR %[[UntypedPtr]] UniformConstant

groupshared float4 shared_data[64];

[numthreads(64, 1, 1)]
void main(uint3 tid : SV_DispatchThreadID, uint gi : SV_GroupIndex) {
  StructuredBuffer<float4> input = ResourceDescriptorHeap[0];
  RWStructuredBuffer<float4> output = ResourceDescriptorHeap[1];

  // CHECK-DAG: OpUntypedAccessChainKHR %[[UntypedPtr]] %[[SBBufArray]] %[[ResourceHeap]] %uint_0
  // CHECK-DAG: OpUntypedAccessChainKHR %[[UntypedPtr]] %[[SBBufArray]] %[[ResourceHeap]] %uint_1
  shared_data[gi] = input[tid.x];

  // CHECK: OpControlBarrier
  GroupMemoryBarrierWithGroupSync();

  uint neighbor = (gi + 1) % 64;

  // CHECK: OpBufferPointerEXT
  output[tid.x] = shared_data[gi] + shared_data[neighbor];
}
