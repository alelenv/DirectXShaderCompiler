// RUN: %dxc -T cs_6_6 -E main -Od -fspv-use-descriptor-heap -fspv-target-env=vulkan1.3 -spirv %s | FileCheck %s
//
// [[vk::resource_heap_stride_constant_id(N)]] / [[vk::sampler_heap_stride_constant_id(M)]]
// emit an OpSpecConstant (decorated SpecId) per heap and replace the literal
// ArrayStride with ArrayStrideIdEXT %sc on every runtime array of that heap.
//
// Verifies:
//   (a) Each attribute produces one OpSpecConstant %uint <default> + SpecId.
//   (b) The resource spec constant decorates ALL resource-heap arrays
//       (StructuredBuffer/ByteAddressBuffer share one, ConstantBuffer + image
//       each get their own) via OpDecorateId ArrayStrideIdEXT.
//   (c) The sampler spec constant decorates the sampler-heap array.
//   (d) No literal ArrayStride survives when both heaps are overridden.

// CHECK: OpCapability DescriptorHeapEXT
// CHECK-NOT: OpCapability UntypedPointersKHR
// CHECK: OpExtension "SPV_EXT_descriptor_heap"

// ---- One spec constant per heap, with the requested SpecId and default ----
// CHECK-DAG: OpDecorate %[[RSC:[a-zA-Z0-9_]+]] SpecId 2
// CHECK-DAG: OpDecorate %[[SSC:[a-zA-Z0-9_]+]] SpecId 3
// CHECK-DAG: %[[RSC]] = OpSpecConstant %uint 64
// CHECK-DAG: %[[SSC]] = OpSpecConstant %uint 32

// ---- ArrayStrideIdEXT references the spec-constant <id>, never a literal ----
// Resource heap: StructuredBuffer/ByteAddressBuffer array, ConstantBuffer array, image array.
// CHECK-DAG: OpDecorateId %[[SBArr:[a-zA-Z0-9_]+]]  ArrayStrideIdEXT %[[RSC]]
// CHECK-DAG: OpDecorateId %[[UBArr:[a-zA-Z0-9_]+]]  ArrayStrideIdEXT %[[RSC]]
// CHECK-DAG: OpDecorateId %[[TexArr:[a-zA-Z0-9_]+]] ArrayStrideIdEXT %[[RSC]]
// Sampler heap.
// CHECK-DAG: OpDecorateId %[[SampArr:[a-zA-Z0-9_]+]] ArrayStrideIdEXT %[[SSC]]

// ---- Both heaps overridden => no literal ArrayStride anywhere ----
// CHECK-NOT: OpDecorate %{{[a-zA-Z0-9_]+}} ArrayStride {{[0-9]+}}

struct CBData { uint value; };

[[vk::resource_heap_stride_constant_id(2)]] const uint kResourceHeapStride = 64;
[[vk::sampler_heap_stride_constant_id(3)]]  const uint kSamplerHeapStride  = 32;

RWByteAddressBuffer outputBytes : register(u0);

[numthreads(1, 1, 1)]
void main(uint3 tid : SV_DispatchThreadID) {
    StructuredBuffer<uint>  sb  = ResourceDescriptorHeap[0];
    ByteAddressBuffer       bab = ResourceDescriptorHeap[1];
    ConstantBuffer<CBData>  cb  = ResourceDescriptorHeap[2];
    Texture2D<float4>       tex = ResourceDescriptorHeap[3];
    SamplerState           samp = SamplerDescriptorHeap[0];

    uint v = sb.Load(tid.x) + bab.Load(tid.x * 4) + cb.value;
    outputBytes.Store(0, v);
    outputBytes.Store(4, (uint)tex.SampleLevel(samp, float2(0, 0), 0).r);
}
