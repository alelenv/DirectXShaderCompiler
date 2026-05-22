// RUN: %dxc -T cs_6_6 -E main -Od -fspv-use-descriptor-heap -fspv-target-env=vulkan1.3 -spirv %s | FileCheck %s

// CHECK: OpCapability DescriptorHeapEXT
// CHECK-NOT: OpCapability UntypedPointersKHR
// CHECK: OpExtension "SPV_EXT_descriptor_heap"
// CHECK: OpExtension "SPV_KHR_untyped_pointers"

// CHECK-DAG: OpDecorate %[[ResourceHeap:[a-zA-Z0-9_]+]] BuiltIn ResourceHeapEXT
// CHECK-DAG: OpDecorate %type_ConstantBuffer_Constants Block

// CHECK-DAG: %[[UntypedPtr:[a-zA-Z0-9_]+]] = OpTypeUntypedPointerKHR UniformConstant
// CHECK-DAG: %[[BufferDesc:[a-zA-Z0-9_]+]] = OpTypeBufferEXT Uniform
// CHECK-DAG: %[[BufferArray:[a-zA-Z0-9_]+]] = OpTypeRuntimeArray %[[BufferDesc]]
// CHECK-DAG: %[[CBPtr:[a-zA-Z0-9_]+]] = OpTypePointer Uniform %type_ConstantBuffer_Constants

// CHECK: %[[ResourceHeap]] = OpUntypedVariableKHR %[[UntypedPtr]] UniformConstant

struct Constants
{
    uint a;
    uint b;
    uint c;
};

RWByteAddressBuffer outputBytes : register(u0);

[numthreads(1, 1, 1)]
void main(uint3 tid : SV_DispatchThreadID)
{
    uint idx = tid.x;
    uint cond = tid.y;

    ConstantBuffer<Constants> constants = ResourceDescriptorHeap[idx];

    // CHECK: %[[Idx:[a-zA-Z0-9_]+]] = OpLoad %uint
    // CHECK: %[[Cond:[a-zA-Z0-9_]+]] = OpLoad %uint
    // CHECK: %[[InitDesc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[BufferArray]] %[[ResourceHeap]] %[[Idx]]
    // CHECK: OpBufferPointerEXT %[[CBPtr]] %[[InitDesc]]
    // CHECK: %[[ADesc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[BufferArray]] %[[ResourceHeap]] %[[Idx]]
    // CHECK: %[[APtr:[a-zA-Z0-9_]+]] = OpBufferPointerEXT %[[CBPtr]] %[[ADesc]]
    // CHECK: %[[AAccess:[a-zA-Z0-9_]+]] = OpAccessChain %{{[a-zA-Z0-9_]+}} %[[APtr]] %int_0
    // CHECK: %[[A:[a-zA-Z0-9_]+]] = OpLoad %uint %[[AAccess]]
    uint value = constants.a;

    constants = ResourceDescriptorHeap[idx + 2];

    // CHECK: %[[IdxPlus2:[a-zA-Z0-9_]+]] = OpIAdd %uint %[[Idx]] %uint_2
    // CHECK: %[[AssignDesc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[BufferArray]] %[[ResourceHeap]] %[[IdxPlus2]]
    // CHECK: OpBufferPointerEXT %[[CBPtr]] %[[AssignDesc]]
    // CHECK: %[[BDesc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[BufferArray]] %[[ResourceHeap]] %[[IdxPlus2]]
    // CHECK: %[[BPtr:[a-zA-Z0-9_]+]] = OpBufferPointerEXT %[[CBPtr]] %[[BDesc]]
    // CHECK: %[[BUseDesc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[BufferArray]] %[[ResourceHeap]] %[[IdxPlus2]]
    // CHECK: %[[BUsePtr:[a-zA-Z0-9_]+]] = OpBufferPointerEXT %[[CBPtr]] %[[BUseDesc]]
    // CHECK: %[[BAccess:[a-zA-Z0-9_]+]] = OpAccessChain %{{[a-zA-Z0-9_]+}} %[[BUsePtr]] %int_1
    // CHECK: %[[B:[a-zA-Z0-9_]+]] = OpLoad %uint %[[BAccess]]
    // CHECK: %[[AB:[a-zA-Z0-9_]+]] = OpIAdd %uint %[[A]] %[[B]]
    value += constants.b;

    if (cond > 4) {
        constants = ResourceDescriptorHeap[idx - 2];

        // CHECK: %[[CondCmp:[a-zA-Z0-9_]+]] = OpUGreaterThan %bool %[[Cond]] %uint_4
        // CHECK: OpBranchConditional %[[CondCmp]]
        // CHECK: %[[IdxMinus2:[a-zA-Z0-9_]+]] = OpISub %uint %[[Idx]] %uint_2
        // CHECK: %[[BranchDesc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[BufferArray]] %[[ResourceHeap]] %[[IdxMinus2]]
        // CHECK: OpBufferPointerEXT %[[CBPtr]] %[[BranchDesc]]
        // CHECK: %[[CDesc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[BufferArray]] %[[ResourceHeap]] %[[IdxMinus2]]
        // CHECK: %[[CPtr:[a-zA-Z0-9_]+]] = OpBufferPointerEXT %[[CBPtr]] %[[CDesc]]
        // CHECK: %[[CUseDesc:[a-zA-Z0-9_]+]] = OpUntypedAccessChainKHR %[[UntypedPtr]] %[[BufferArray]] %[[ResourceHeap]] %[[IdxMinus2]]
        // CHECK: %[[CUsePtr:[a-zA-Z0-9_]+]] = OpBufferPointerEXT %[[CBPtr]] %[[CUseDesc]]
        // CHECK: %[[CAccess:[a-zA-Z0-9_]+]] = OpAccessChain %{{[a-zA-Z0-9_]+}} %[[CUsePtr]] %int_2
        // CHECK: %[[C:[a-zA-Z0-9_]+]] = OpLoad %uint %[[CAccess]]
        // CHECK: OpIAdd %uint %[[AB]] %[[C]]
        value += constants.c;
    }

    outputBytes.Store(0, value);
}
