// RUN: %dxc -T cs_6_6 -E main -Od -fspv-use-descriptor-heap -fspv-target-env=vulkan1.3 -spirv %s | FileCheck %s
//
// Comprehensive ArrayStride test for descriptor heap OpTypeRuntimeArray instances.
//
// Verifies:
//   (a) Each distinct descriptor element type gets exactly one OpTypeRuntimeArray,
//       with the stride decoration tightly bound to that array's result id.
//   (b) StructuredBuffer / RWStructuredBuffer / ByteAddressBuffer share ONE
//       OpTypeRuntimeArray (OpTypeBufferEXT StorageBuffer) — single decoration.
//   (c) ConstantBuffer uses a separate OpTypeRuntimeArray (OpTypeBufferEXT Uniform).
//   (d) Each image element type gets its own OpTypeRuntimeArray.
//   (e) Sampler heap uses ArrayStride 32; resource heap uses ArrayStride 64.
//
// NOTE: Checks (a)-(e) reflect the TARGET state after the resource-heap stride
// change (resource heap 32 -> 64).  All resource-heap arrays are expected to carry
// ArrayStride 64; sampler-heap array carries ArrayStride 32.
// Update the stride literals below if testing prior to that implementation.

// CHECK: OpCapability DescriptorHeapEXT
// CHECK-NOT: OpCapability UntypedPointersKHR
// CHECK: OpExtension "SPV_EXT_descriptor_heap"
// CHECK: OpExtension "SPV_KHR_untyped_pointers"

// ============================================================
// Heap variable builtin decorations
// ============================================================

// CHECK-DAG: OpDecorate %[[ResourceHeap:[a-zA-Z0-9_]+]] BuiltIn ResourceHeapEXT
// CHECK-DAG: OpDecorate %[[SamplerHeap:[a-zA-Z0-9_]+]]  BuiltIn SamplerHeapEXT

// ============================================================
// Type declarations
// ============================================================

// CHECK-DAG: %[[UntypedPtr:[a-zA-Z0-9_]+]] = OpTypeUntypedPointerKHR UniformConstant

// Buffer descriptor element types (SPV_EXT_descriptor_heap §2)
// CHECK-DAG: %[[SBDesc:[a-zA-Z0-9_]+]]  = OpTypeBufferEXT StorageBuffer
// CHECK-DAG: %[[UBDesc:[a-zA-Z0-9_]+]]  = OpTypeBufferEXT Uniform

// Image element type (read-only Texture2D<float4>)
// CHECK-DAG: %[[Tex2DType:[a-zA-Z0-9_]+]] = OpTypeImage %float 2D 2 0 0 1 Unknown

// RWTexture2D<uint> written with [[vk::image_format("r32ui")]]
// CHECK-DAG: %[[RWTexType:[a-zA-Z0-9_]+]] = OpTypeImage %uint 2D 2 0 0 2 R32ui

// Sampler (SamplerDescriptorHeap)
// CHECK-DAG: %[[SamplerType:[a-zA-Z0-9_]+]] = OpTypeSampler

// ============================================================
// Runtime arrays — one per distinct element type
// ============================================================

// StructuredBuffer / RWStructuredBuffer / ByteAddressBuffer share this array.
// CHECK-DAG: %[[SBArray:[a-zA-Z0-9_]+]]      = OpTypeRuntimeArray %[[SBDesc]]{{$}}
// ConstantBuffer uses the Uniform descriptor, separate array.
// CHECK-DAG: %[[UBArray:[a-zA-Z0-9_]+]]      = OpTypeRuntimeArray %[[UBDesc]]{{$}}
// Image arrays — each image type is its own element type.
// CHECK-DAG: %[[Tex2DArray:[a-zA-Z0-9_]+]]   = OpTypeRuntimeArray %[[Tex2DType]]{{$}}
// CHECK-DAG: %[[RWTexArray:[a-zA-Z0-9_]+]]   = OpTypeRuntimeArray %[[RWTexType]]{{$}}
// Sampler array.
// CHECK-DAG: %[[SamplerArray:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[SamplerType]]{{$}}

// ============================================================
// ArrayStride decorations — stride tightly bound to each array id
// ============================================================

// Resource heap: ArrayStride 64 on all resource-heap runtime arrays.
// CHECK-DAG: OpDecorate %[[SBArray]]    ArrayStride 64
// CHECK-DAG: OpDecorate %[[UBArray]]    ArrayStride 64
// CHECK-DAG: OpDecorate %[[Tex2DArray]] ArrayStride 64
// CHECK-DAG: OpDecorate %[[RWTexArray]] ArrayStride 64

// Sampler heap: ArrayStride 32 (sampler descriptors are smaller; independent of resource stride).
// CHECK-DAG: OpDecorate %[[SamplerArray]] ArrayStride 32

// Sanity: no degenerate or legacy strides.
// CHECK-NOT: ArrayStride 0
// CHECK-NOT: ArrayStride 8
// CHECK-NOT: ArrayStride 16

// ============================================================
// Heap variable declarations
// ============================================================

// CHECK-DAG: %[[ResourceHeap]] = OpUntypedVariableKHR %[[UntypedPtr]] UniformConstant
// CHECK-DAG: %[[SamplerHeap]]  = OpUntypedVariableKHR %[[UntypedPtr]] UniformConstant

// ============================================================
// Buffer pointer types (used by OpBufferPointerEXT)
// ============================================================

// CHECK-DAG: %[[SBPtr:[a-zA-Z0-9_]+]]   = OpTypePointer StorageBuffer %type_StructuredBuffer_{{.*}}
// CHECK-DAG: %[[RWSBPtr:[a-zA-Z0-9_]+]] = OpTypePointer StorageBuffer %type_RWStructuredBuffer_{{.*}}
// CHECK-DAG: %[[BABPtr:[a-zA-Z0-9_]+]]  = OpTypePointer StorageBuffer %type_ByteAddressBuffer{{$}}
// CHECK-DAG: %[[CBPtr:[a-zA-Z0-9_]+]]   = OpTypePointer Uniform %type_ConstantBuffer_{{.*}}

// ============================================================
// HLSL shader
// ============================================================

struct CBData { uint value; };

RWByteAddressBuffer outputBytes : register(u0);

[numthreads(1, 1, 1)]
void main(uint3 tid : SV_DispatchThreadID) {

  // ----------------------------------------------------------
  // (b) Buffer path (SpirvEmitter.cpp:6932): OpTypeBufferEXT StorageBuffer
  //     StructuredBuffer / RWStructuredBuffer / ByteAddressBuffer must all
  //     produce OpUntypedAccessChainKHR against %[[SBArray]] — one array, one stride.
  // ----------------------------------------------------------
  StructuredBuffer<uint>   sb   = ResourceDescriptorHeap[0];
  RWStructuredBuffer<uint> rwsb = ResourceDescriptorHeap[1];
  ByteAddressBuffer        bab  = ResourceDescriptorHeap[2];

  // SB — storageBuffer descriptor path
  // CHECK: %[[SBDesc0:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[SBArray]] %[[ResourceHeap]] %uint_0
  // CHECK: OpBufferPointerEXT %[[SBPtr]] %[[SBDesc0]]

  // RWSB — same SBArray (dedup: same OpTypeBufferEXT StorageBuffer element type)
  // CHECK: %[[RWSBDesc1:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[SBArray]] %[[ResourceHeap]] %uint_1
  // CHECK: OpBufferPointerEXT %[[RWSBPtr]] %[[RWSBDesc1]]

  // BAB — same SBArray (ByteAddressBuffer also maps to StorageBuffer descriptor)
  // CHECK: %[[BABDesc2:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[SBArray]] %[[ResourceHeap]] %uint_2
  // CHECK: OpBufferPointerEXT %[[BABPtr]] %[[BABDesc2]]

  // ----------------------------------------------------------
  // (c) Constant buffer path (SpirvEmitter.cpp:6932): OpTypeBufferEXT Uniform
  //     Separate UBArray — different element type, independent stride.
  // ----------------------------------------------------------
  ConstantBuffer<CBData> cb = ResourceDescriptorHeap[3];

  // CHECK: %[[CBDesc3:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[UBArray]] %[[ResourceHeap]] %uint_3
  // CHECK: OpBufferPointerEXT %[[CBPtr]] %[[CBDesc3]]

  // ----------------------------------------------------------
  // (d) Image path (SpirvEmitter.cpp:6958): image element types
  //     Each distinct image type gets its own RuntimeArray.
  // ----------------------------------------------------------
  Texture2D<float4>                         tex   = ResourceDescriptorHeap[4];
  [[vk::image_format("r32ui")]]
  RWTexture2D<uint>                         rwtex = ResourceDescriptorHeap[5];

  // Tex2D — image path, read-only
  // CHECK: %[[TexDesc4:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[Tex2DArray]] %[[ResourceHeap]] %uint_4
  // CHECK: %[[TexHandle:[a-zA-Z0-9_]+]] = OpLoad %[[Tex2DType]] %[[TexDesc4]]

  // RWTexture2D — image path, storage image, separate array from Tex2DArray
  // CHECK: %[[RWTexDesc5:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[RWTexArray]] %[[ResourceHeap]] %uint_5
  // CHECK: %[[RWTexHandle:[a-zA-Z0-9_]+]] = OpLoad %[[RWTexType]] %[[RWTexDesc5]]

  // ----------------------------------------------------------
  // (e) Sampler heap: SamplerDescriptorHeap uses %[[SamplerArray]] with stride 32.
  //     Access chain goes through %[[SamplerHeap]], not %[[ResourceHeap]].
  // ----------------------------------------------------------
  SamplerState samp = SamplerDescriptorHeap[0];

  // CHECK: %[[SampDesc0:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[SamplerArray]] %[[SamplerHeap]] %uint_0
  // CHECK: %[[SampHandle:[a-zA-Z0-9_]+]] = OpLoad %[[SamplerType]] %[[SampDesc0]]

  // ----------------------------------------------------------
  // Use all resources to prevent DCE.
  // ----------------------------------------------------------
  uint bufVal  = sb.Load(tid.x) + bab.Load(tid.x * 4) + cb.value;
  rwsb[tid.x]  = bufVal;
  float4 texVal = tex.SampleLevel(samp, float2(0, 0), 0);
  rwtex[tid.xy] = texVal.r;
  outputBytes.Store(0, rwsb.Load(tid.x));
}
