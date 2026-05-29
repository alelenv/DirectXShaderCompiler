// RUN: %dxc -T cs_6_6 -E main -fspv-use-descriptor-heap -fspv-target-env=vulkan1.3 -spirv %s | FileCheck %s

// CHECK: OpCapability DescriptorHeapEXT
// CHECK-NOT: OpCapability UntypedPointersKHR
// CHECK: OpExtension "SPV_EXT_descriptor_heap"
// CHECK: OpExtension "SPV_KHR_untyped_pointers"

// CHECK-DAG: OpDecorate %[[ResourceHeap:[a-zA-Z0-9_]+]] BuiltIn ResourceHeapEXT

// CHECK-DAG: %[[UntypedPtr:[a-zA-Z0-9_]+]] = OpTypeUntypedPointerKHR UniformConstant

// Texture2D<uint>  — R32ui, sampled
// CHECK-DAG: %[[TexUintType:[a-zA-Z0-9_]+]] = OpTypeImage %uint 2D 2 0 0 1 Unknown
// CHECK-DAG: %[[RA_TexUint:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[TexUintType]]{{$}}

// RWTexture2D<float2> — Rg32f, storage
// CHECK-DAG: %[[RWTexF2Type:[a-zA-Z0-9_]+]] = OpTypeImage %float 2D 2 0 0 2 Rg32f
// CHECK-DAG: %[[RA_RWTexF2:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[RWTexF2Type]]{{$}}

// RWTexture2D<uint2> — Rg32ui, storage
// CHECK-DAG: %[[RWTexU2Type:[a-zA-Z0-9_]+]] = OpTypeImage %uint 2D 2 0 0 2 Rg32ui
// CHECK-DAG: %[[RA_RWTexU2:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[RWTexU2Type]]{{$}}

// RWTexture2D<int> — R32i, storage
// CHECK-DAG: %[[RWTexIType:[a-zA-Z0-9_]+]] = OpTypeImage %int 2D 2 0 0 2 R32i
// CHECK-DAG: %[[RA_RWTexI:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[RWTexIType]]{{$}}

// CHECK: %[[ResourceHeap]] = OpUntypedVariableKHR %[[UntypedPtr]] UniformConstant

RWByteAddressBuffer output : register(u0);

[numthreads(1, 1, 1)]
void main(uint3 tid : SV_DispatchThreadID) {
  Texture2D<uint> texUint = ResourceDescriptorHeap[0];
  // CHECK: %[[TexUintChain:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[RA_TexUint]] %[[ResourceHeap]] %uint_0
  // CHECK: %[[TexUintH:[a-zA-Z0-9_]+]] = OpLoad %[[TexUintType]] %[[TexUintChain]]

  RWTexture2D<float2> rwTexF2 = ResourceDescriptorHeap[1];
  // CHECK: %[[RWTexF2Chain:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[RA_RWTexF2]] %[[ResourceHeap]] %uint_1
  // CHECK: %[[RWTexF2H:[a-zA-Z0-9_]+]] = OpLoad %[[RWTexF2Type]] %[[RWTexF2Chain]]

  RWTexture2D<uint2> rwTexU2 = ResourceDescriptorHeap[2];
  // CHECK: %[[RWTexU2Chain:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[RA_RWTexU2]] %[[ResourceHeap]] %uint_2
  // CHECK: %[[RWTexU2H:[a-zA-Z0-9_]+]] = OpLoad %[[RWTexU2Type]] %[[RWTexU2Chain]]

  RWTexture2D<int> rwTexI = ResourceDescriptorHeap[3];
  // CHECK: %[[RWTexIChain:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[RA_RWTexI]] %[[ResourceHeap]] %uint_3
  // CHECK: %[[RWTexIH:[a-zA-Z0-9_]+]] = OpLoad %[[RWTexIType]] %[[RWTexIChain]]

  // CHECK: OpImageFetch %v4uint %[[TexUintH]]
  uint val = texUint.Load(int3(tid.xy, 0)).x;

  // CHECK: OpImageWrite %[[RWTexF2H]]
  rwTexF2[tid.xy] = float2(val, val);
  // CHECK: OpImageWrite %[[RWTexU2H]]
  rwTexU2[tid.xy] = uint2(val, val);
  // CHECK: OpImageWrite %[[RWTexIH]]
  rwTexI[tid.xy] = int(val);

  output.Store(0, val);
}
