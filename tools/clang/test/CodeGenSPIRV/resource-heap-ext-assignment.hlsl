// RUN: %dxc -T cs_6_6 -E main -fspv-use-descriptor-heap -fspv-target-env=vulkan1.3 -spirv %s | FileCheck %s

// CHECK: OpCapability DescriptorHeapEXT
// CHECK: OpCapability UntypedPointersKHR
// CHECK: OpExtension "SPV_EXT_descriptor_heap"
// CHECK: OpExtension "SPV_KHR_untyped_pointers"

// CHECK-DAG: OpDecorate %[[ResourceHeap:[a-zA-Z0-9_]+]] BuiltIn ResourceHeapEXT
// CHECK-DAG: OpDecorate %[[RWTexArray:[a-zA-Z0-9_]+]] ArrayStride 32
// CHECK-DAG: OpDecorate %{{[a-zA-Z0-9_]+}} ArrayStride 32

// CHECK-DAG: %[[UntypedUniformConstant:[a-zA-Z0-9_]+]] = OpTypeUntypedPointerKHR UniformConstant
// CHECK-DAG: %[[BufferDescType:[a-zA-Z0-9_]+]] = OpTypeBufferEXT Uniform
// CHECK-DAG: %[[BufferDescArray:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[BufferDescType]]
// CHECK-DAG: %[[RWTexType:[a-zA-Z0-9_]+]] = OpTypeImage %uint 2D 2 0 0 2 R32ui
// CHECK-DAG: %[[RWTexArray]] = OpTypeRuntimeArray %[[RWTexType]]
// CHECK-DAG: %[[UntypedImage:[a-zA-Z0-9_]+]] = OpTypeUntypedPointerKHR Image

// CHECK: %[[ResourceHeap]] = OpUntypedVariableKHR %[[UntypedUniformConstant]] UniformConstant

RWByteAddressBuffer outputBytes : register(u0);

struct Constants {
  uint value;
};

[numthreads(1, 1, 1)]
void main(uint3 tid : SV_DispatchThreadID) {
  RWTexture2D<uint> tex = ResourceDescriptorHeap[0];
  tex = ResourceDescriptorHeap[1];

  StructuredBuffer<uint> input = ResourceDescriptorHeap[2];
  input = ResourceDescriptorHeap[3];

  ConstantBuffer<Constants> constants = ResourceDescriptorHeap[4];
  constants = ResourceDescriptorHeap[5];

  // CHECK-DAG: OpUntypedAccessChainKHR %[[UntypedUniformConstant]] %[[BufferDescArray]] %[[ResourceHeap]] %uint_3
  // CHECK-DAG: OpUntypedAccessChainKHR %[[UntypedUniformConstant]] %[[BufferDescArray]] %[[ResourceHeap]] %uint_5
  uint original;
  // CHECK: %[[AssignedDesc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedUniformConstant]] %[[RWTexArray]] %[[ResourceHeap]] %uint_1
  // CHECK-NOT: OpImageTexelPointer
  // CHECK: OpUntypedImageTexelPointerEXT %[[UntypedImage]] %[[RWTexType]] %[[AssignedDesc]]
  // CHECK: OpAtomicIAdd
  InterlockedAdd(tex[tid.xy], 1, original);

  uint value = input.Load(0) + constants.value;

  outputBytes.Store(0, original);
  outputBytes.Store(4, value);
}
