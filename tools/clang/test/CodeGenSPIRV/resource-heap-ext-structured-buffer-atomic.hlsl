// RUN: %dxc -T cs_6_6 -E main -fspv-use-descriptor-heap -fspv-target-env=vulkan1.3 -spirv %s | FileCheck %s

// CHECK: OpCapability DescriptorHeapEXT
// CHECK: OpExtension "SPV_EXT_descriptor_heap"
// CHECK: OpExtension "SPV_KHR_untyped_pointers"

// CHECK-DAG: OpDecorate %[[ResourceHeap:[a-zA-Z0-9_]+]] BuiltIn ResourceHeapEXT
// CHECK-DAG: %[[UntypedPtr:[a-zA-Z0-9_]+]] = OpTypeUntypedPointerKHR UniformConstant
// CHECK-DAG: %[[SBBufDesc:[a-zA-Z0-9_]+]] = OpTypeBufferEXT StorageBuffer
// CHECK-DAG: %[[SBBufArray:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[SBBufDesc]]
// CHECK: %[[ResourceHeap]] = OpUntypedVariableKHR %[[UntypedPtr]] UniformConstant

[numthreads(64, 1, 1)]
void main(uint3 tid : SV_DispatchThreadID) {
  RWStructuredBuffer<uint> counter = ResourceDescriptorHeap[0];

  // CHECK: %[[Desc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[SBBufArray]] %[[ResourceHeap]] %uint_0
  // CHECK: OpBufferPointerEXT
  uint original;
  // CHECK: OpAtomicIAdd %uint
  InterlockedAdd(counter[0], 1, original);

  // CHECK: OpAtomicCompareExchange %uint
  uint cmp;
  InterlockedCompareExchange(counter[1], original, original + 1, cmp);
}
