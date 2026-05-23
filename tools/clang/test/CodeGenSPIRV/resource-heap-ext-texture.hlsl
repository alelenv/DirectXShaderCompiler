// RUN: %dxc -T cs_6_6 -E main -fspv-use-descriptor-heap -fspv-target-env=vulkan1.3 -spirv %s | FileCheck %s

// Tests Buffer<T> and RWBuffer<T> from descriptor heap (dim=Buffer image types).

// CHECK: OpCapability DescriptorHeapEXT
// CHECK-NOT: OpCapability UntypedPointersKHR
// CHECK: OpExtension "SPV_EXT_descriptor_heap"
// CHECK: OpExtension "SPV_KHR_untyped_pointers"

// CHECK-DAG: OpDecorate %[[ResourceHeap:[a-zA-Z0-9_]+]] BuiltIn ResourceHeapEXT
// CHECK-DAG: OpDecorate {{%[a-zA-Z0-9_]+}} ArrayStride 32

// CHECK-DAG: %[[UntypedPtrType:[a-zA-Z0-9_]+]] = OpTypeUntypedPointerKHR UniformConstant
// CHECK-DAG: %[[BufferType:[a-zA-Z0-9_]+]] = OpTypeImage %float Buffer 2 0 0 1 Rgba32f
// CHECK-DAG: %[[RWBufferType:[a-zA-Z0-9_]+]] = OpTypeImage %float Buffer 2 0 0 2 Rgba32f

// CHECK-DAG: %[[RA_BufferType:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[BufferType]]{{$}}
// CHECK-DAG: %[[RA_RWBufferType:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[RWBufferType]]{{$}}

// CHECK: %[[ResourceHeap]] = OpUntypedVariableKHR %[[UntypedPtrType]] UniformConstant

[numthreads(1, 1, 1)]
void main(uint3 tid : SV_DispatchThreadID) {
    Buffer<float4> myBuf = ResourceDescriptorHeap[0];
    // CHECK: %[[BufIndex:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtrType]] %[[RA_BufferType]] %[[ResourceHeap]] %uint_0
    // CHECK: %[[BufHandle:[a-zA-Z0-9_]+]] = OpLoad %[[BufferType]] %[[BufIndex]]

    RWBuffer<float4> myRWBuf = ResourceDescriptorHeap[1];
    // CHECK: %[[RWBufIndex:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtrType]] %[[RA_RWBufferType]] %[[ResourceHeap]] %uint_1
    // CHECK: %[[RWBufHandle:[a-zA-Z0-9_]+]] = OpLoad %[[RWBufferType]] %[[RWBufIndex]]

    // CHECK: %[[BufResult:[a-zA-Z0-9_]+]] = OpImageFetch %v4float %[[BufHandle]]
    float4 bufVal = myBuf.Load(tid.x);

    // CHECK: OpImageWrite %[[RWBufHandle]]
    myRWBuf[tid.x] = bufVal;
}
