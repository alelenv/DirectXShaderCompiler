// RUN: not %dxc -T cs_6_6 -E main -fspv-use-descriptor-heap -fspv-target-env=vulkan1.3 -spirv %s 2>&1 | FileCheck %s

// CHECK: append/consume structured buffers are not supported with SPV_EXT_descriptor_heap

[numthreads(1, 1, 1)]
void main() {
  AppendStructuredBuffer<uint> output = ResourceDescriptorHeap[0];
  output.Append(1);
}
