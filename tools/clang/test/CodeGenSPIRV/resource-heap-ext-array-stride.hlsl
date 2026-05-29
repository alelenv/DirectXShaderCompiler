// RUN: %dxc -T cs_6_6 -E main -Od -fspv-use-descriptor-heap -fspv-target-env=vulkan1.3 -fvk-resource-heap-stride 64 -fvk-sampler-heap-stride 32 -spirv %s | FileCheck %s
//
// Comprehensive ArrayStride test for descriptor-heap OpTypeRuntimeArray instances.
// The strides are pinned via the command line (resource 64 / sampler 32) so the
// CHECK values are independent of the built-in defaults. Verifies that each
// distinct descriptor element type gets exactly one runtime array, that
// StructuredBuffer / RWStructuredBuffer / ByteAddressBuffer share one
// StorageBuffer array, that ConstantBuffer uses a separate Uniform array, and
// that the stride is bound to each array id (resource 64, sampler 32 —
// independent per heap).

// CHECK: OpCapability DescriptorHeapEXT
// CHECK-NOT: OpCapability UntypedPointersKHR
// CHECK: OpExtension "SPV_EXT_descriptor_heap"
// CHECK: OpExtension "SPV_KHR_untyped_pointers"

// CHECK-DAG: OpDecorate %[[ResourceHeap:[a-zA-Z0-9_]+]] BuiltIn ResourceHeapEXT
// CHECK-DAG: OpDecorate %[[SamplerHeap:[a-zA-Z0-9_]+]]  BuiltIn SamplerHeapEXT

// CHECK-DAG: %[[UntypedPtr:[a-zA-Z0-9_]+]] = OpTypeUntypedPointerKHR UniformConstant
// CHECK-DAG: %[[SBDesc:[a-zA-Z0-9_]+]]  = OpTypeBufferEXT StorageBuffer
// CHECK-DAG: %[[UBDesc:[a-zA-Z0-9_]+]]  = OpTypeBufferEXT Uniform
// CHECK-DAG: %[[Tex2DType:[a-zA-Z0-9_]+]] = OpTypeImage %float 2D 2 0 0 1 Unknown
// CHECK-DAG: %[[RWTexType:[a-zA-Z0-9_]+]] = OpTypeImage %uint 2D 2 0 0 2 R32ui
// CHECK-DAG: %[[SamplerType:[a-zA-Z0-9_]+]] = OpTypeSampler

// One runtime array per distinct element type.
// CHECK-DAG: %[[SBArray:[a-zA-Z0-9_]+]]      = OpTypeRuntimeArray %[[SBDesc]]{{$}}
// CHECK-DAG: %[[UBArray:[a-zA-Z0-9_]+]]      = OpTypeRuntimeArray %[[UBDesc]]{{$}}
// CHECK-DAG: %[[Tex2DArray:[a-zA-Z0-9_]+]]   = OpTypeRuntimeArray %[[Tex2DType]]{{$}}
// CHECK-DAG: %[[RWTexArray:[a-zA-Z0-9_]+]]   = OpTypeRuntimeArray %[[RWTexType]]{{$}}
// CHECK-DAG: %[[SamplerArray:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[SamplerType]]{{$}}

// Stride bound to each array id: resource 64, sampler 32.
// CHECK-DAG: OpDecorate %[[SBArray]]    ArrayStride 64
// CHECK-DAG: OpDecorate %[[UBArray]]    ArrayStride 64
// CHECK-DAG: OpDecorate %[[Tex2DArray]] ArrayStride 64
// CHECK-DAG: OpDecorate %[[RWTexArray]] ArrayStride 64
// CHECK-DAG: OpDecorate %[[SamplerArray]] ArrayStride 32

// CHECK-DAG: %[[ResourceHeap]] = OpUntypedVariableKHR %[[UntypedPtr]] UniformConstant
// CHECK-DAG: %[[SamplerHeap]]  = OpUntypedVariableKHR %[[UntypedPtr]] UniformConstant

struct CBData { uint value; };

RWByteAddressBuffer outputBytes : register(u0);

[numthreads(1, 1, 1)]
void main(uint3 tid : SV_DispatchThreadID) {
  // StructuredBuffer / RWStructuredBuffer / ByteAddressBuffer share one
  // StorageBuffer array (same OpTypeBufferEXT StorageBuffer element type).
  StructuredBuffer<uint>   sb   = ResourceDescriptorHeap[0];
  RWStructuredBuffer<uint> rwsb = ResourceDescriptorHeap[1];
  ByteAddressBuffer        bab  = ResourceDescriptorHeap[2];

  // CHECK: OpUntypedAccessChainKHR %[[UntypedPtr]] %[[SBArray]] %[[ResourceHeap]] %uint_0
  // CHECK: OpBufferPointerEXT %{{[a-zA-Z0-9_]+}}
  // CHECK: OpUntypedAccessChainKHR %[[UntypedPtr]] %[[SBArray]] %[[ResourceHeap]] %uint_1
  // CHECK: OpBufferPointerEXT %{{[a-zA-Z0-9_]+}}
  // CHECK: OpUntypedAccessChainKHR %[[UntypedPtr]] %[[SBArray]] %[[ResourceHeap]] %uint_2
  // CHECK: OpBufferPointerEXT %{{[a-zA-Z0-9_]+}}

  // ConstantBuffer uses a separate Uniform array.
  ConstantBuffer<CBData> cb = ResourceDescriptorHeap[3];
  // CHECK: OpUntypedAccessChainKHR %[[UntypedPtr]] %[[UBArray]] %[[ResourceHeap]] %uint_3
  // CHECK: OpBufferPointerEXT %{{[a-zA-Z0-9_]+}}

  // Distinct image element types get their own arrays.
  Texture2D<float4> tex   = ResourceDescriptorHeap[4];
  RWTexture2D<uint> rwtex = ResourceDescriptorHeap[5];

  // CHECK: OpUntypedAccessChainKHR %[[UntypedPtr]] %[[Tex2DArray]] %[[ResourceHeap]] %uint_4
  // CHECK: OpLoad %[[Tex2DType]]

  // Sampler heap: access chain goes through %[[SamplerHeap]], stride 32.
  SamplerState samp = SamplerDescriptorHeap[0];
  // CHECK: OpUntypedAccessChainKHR %[[UntypedPtr]] %[[SamplerArray]] %[[SamplerHeap]] %uint_0
  // CHECK: OpLoad %[[SamplerType]]

  uint bufVal = sb.Load(tid.x) + bab.Load(tid.x * 4) + cb.value;
  rwsb[tid.x] = bufVal;
  float4 texVal = tex.SampleLevel(samp, float2(0, 0), 0);

  // RWTexture2D<uint> via an atomic: storage-image path (R32ui inferred, no format attr).
  // CHECK: OpUntypedAccessChainKHR %[[UntypedPtr]] %[[RWTexArray]] %[[ResourceHeap]] %uint_5
  // CHECK: OpUntypedImageTexelPointerEXT {{%[a-zA-Z0-9_]+}} %[[RWTexType]]
  uint rwOrig;
  InterlockedAdd(rwtex[tid.xy], 1, rwOrig);
  outputBytes.Store(0, rwsb.Load(tid.x) + asuint(texVal.r) + rwOrig);
}
