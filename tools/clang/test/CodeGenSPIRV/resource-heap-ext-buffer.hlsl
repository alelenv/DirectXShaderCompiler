// RUN: %dxc -T cs_6_6 -E main -fspv-use-descriptor-heap -fspv-target-env=vulkan1.3 -spirv %s | FileCheck %s

// CHECK: OpCapability DescriptorHeapEXT
// CHECK: OpCapability UntypedPointersKHR
// CHECK: OpExtension "SPV_EXT_descriptor_heap"
// CHECK: OpExtension "SPV_KHR_untyped_pointers"

// CHECK-DAG: OpDecorate %[[ResourceHeap:[a-zA-Z0-9_]+]] BuiltIn ResourceHeapEXT
// CHECK-DAG: OpDecorate %[[RA_BufferDescType:[a-zA-Z0-9_]+]] ArrayStride 32

// CHECK-DAG: %[[UntypedPtrType:[a-zA-Z0-9_]+]] = OpTypeUntypedPointerKHR UniformConstant
// CHECK-DAG: %[[BufferDescType:[a-zA-Z0-9_]+]] = OpTypeBufferEXT Uniform
// CHECK-DAG: %[[RA_BufferDescType]] = OpTypeRuntimeArray %[[BufferDescType]]

// CHECK: %[[ResourceHeap]] = OpUntypedVariableKHR %[[UntypedPtrType]] UniformConstant

struct Constants {
  uint value;
};

RWByteAddressBuffer outputBytes : register(u0);

[numthreads(1, 1, 1)]
void main(uint3 tid : SV_DispatchThreadID) {
  StructuredBuffer<uint> input = ResourceDescriptorHeap[0];
  RWStructuredBuffer<uint> output = ResourceDescriptorHeap[1];
  ByteAddressBuffer inputBytes = ResourceDescriptorHeap[2];
  ConstantBuffer<Constants> constants = ResourceDescriptorHeap[3];

  // CHECK: %[[InputDesc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtrType]] %[[RA_BufferDescType]] %[[ResourceHeap]] %uint_0
  // CHECK: %[[InputPtr:[a-zA-Z0-9_]+]] = OpBufferPointerEXT %{{.*}} %[[InputDesc]]
  // CHECK: %[[OutputDesc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtrType]] %[[RA_BufferDescType]] %[[ResourceHeap]] %uint_1
  // CHECK: %[[OutputPtr:[a-zA-Z0-9_]+]] = OpBufferPointerEXT %{{.*}} %[[OutputDesc]]
  // CHECK: %[[InputBytesDesc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtrType]] %[[RA_BufferDescType]] %[[ResourceHeap]] %uint_2
  // CHECK: %[[InputBytesPtr:[a-zA-Z0-9_]+]] = OpBufferPointerEXT %{{.*}} %[[InputBytesDesc]]
  // CHECK: %[[ConstantsDesc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtrType]] %[[RA_BufferDescType]] %[[ResourceHeap]] %uint_3
  // CHECK: %[[ConstantsPtr:[a-zA-Z0-9_]+]] = OpBufferPointerEXT %{{.*}} %[[ConstantsDesc]]
  output[tid.x] = input.Load(tid.x) + inputBytes.Load(tid.x * 4) + constants.value;
  outputBytes.Store(tid.x * 4, output[tid.x]);
}
