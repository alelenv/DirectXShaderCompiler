// RUN: %dxc -T cs_6_6 -E main -fspv-use-descriptor-heap -fspv-target-env=vulkan1.3 -spirv %s | FileCheck %s

// CHECK: OpCapability DescriptorHeapEXT
// CHECK-NOT: OpCapability UntypedPointersKHR
// CHECK: OpExtension "SPV_EXT_descriptor_heap"
// CHECK: OpExtension "SPV_KHR_untyped_pointers"

// CHECK-DAG: OpDecorate %[[ResourceHeap:[a-zA-Z0-9_]+]] BuiltIn ResourceHeapEXT
// One ArrayStride 32 per heap descriptor array (StorageBuffer and Uniform).
// CHECK-DAG: OpDecorate %{{[a-zA-Z0-9_]+}} ArrayStride 32
// CHECK-DAG: OpDecorate %{{[a-zA-Z0-9_]+}} ArrayStride 32

// CHECK-DAG: %[[UntypedPtrType:[a-zA-Z0-9_]+]] = OpTypeUntypedPointerKHR UniformConstant
// CHECK-DAG: %[[SBBufDesc:[a-zA-Z0-9_]+]] = OpTypeBufferEXT StorageBuffer
// CHECK-DAG: %[[SBBufArray:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[SBBufDesc]]
// CHECK-DAG: %[[UBufDesc:[a-zA-Z0-9_]+]] = OpTypeBufferEXT Uniform
// CHECK-DAG: %[[UBufArray:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[UBufDesc]]
// Anchor each pointer type to its struct-type prefix to prevent FileCheck from
// binding all three StorageBuffer captures to the scalar %_ptr_StorageBuffer_uint.
// CHECK-DAG: %[[SBInputPtr:[a-zA-Z0-9_]+]] = OpTypePointer StorageBuffer %type_StructuredBuffer_{{.*}}
// CHECK-DAG: %[[SBOutputPtr:[a-zA-Z0-9_]+]] = OpTypePointer StorageBuffer %type_RWStructuredBuffer_{{.*}}
// CHECK-DAG: %[[SBBytesPtr:[a-zA-Z0-9_]+]] = OpTypePointer StorageBuffer %type_ByteAddressBuffer{{$}}
// CHECK-DAG: %[[UConstPtr:[a-zA-Z0-9_]+]] = OpTypePointer Uniform %type_ConstantBuffer_{{.*}}

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


  // CHECK: %[[InputDesc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtrType]] %[[SBBufArray]] %[[ResourceHeap]] %uint_0
  // CHECK: OpBufferPointerEXT %[[SBInputPtr]] %[[InputDesc]]
  // CHECK: %[[OutputDesc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtrType]] %[[SBBufArray]] %[[ResourceHeap]] %uint_1
  // CHECK: OpBufferPointerEXT %[[SBOutputPtr]] %[[OutputDesc]]
  // CHECK: %[[InputBytesDesc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtrType]] %[[SBBufArray]] %[[ResourceHeap]] %uint_2
  // CHECK: OpBufferPointerEXT %[[SBBytesPtr]] %[[InputBytesDesc]]
  // CHECK: %[[ConstantsDesc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtrType]] %[[UBufArray]] %[[ResourceHeap]] %uint_3
  // CHECK: OpBufferPointerEXT %[[UConstPtr]] %[[ConstantsDesc]]
  output[tid.x] = input.Load(tid.x) + inputBytes.Load(tid.x * 4) + constants.value;
  outputBytes.Store(tid.x * 4, output[tid.x]);
}
