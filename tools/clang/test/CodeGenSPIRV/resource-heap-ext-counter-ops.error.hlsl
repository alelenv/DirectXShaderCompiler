// RUN: not %dxc -T cs_6_6 -E main -fspv-use-descriptor-heap -fspv-target-env=vulkan1.3 -spirv -DTEST_INCREMENT %s 2>&1 | FileCheck --check-prefix=INC %s
// RUN: not %dxc -T cs_6_6 -E main -fspv-use-descriptor-heap -fspv-target-env=vulkan1.3 -spirv %s 2>&1 | FileCheck --check-prefix=DEC %s

// INC: Cannot access associated counter variable for an array of buffers in a struct
// DEC: Cannot access associated counter variable for an array of buffers in a struct

RWByteAddressBuffer outputBytes : register(u0);

[numthreads(1, 1, 1)]
void main() {
  RWStructuredBuffer<uint> buffer = ResourceDescriptorHeap[0];

#ifdef TEST_INCREMENT
  uint value = buffer.IncrementCounter();
#else
  uint value = buffer.DecrementCounter();
#endif

  outputBytes.Store(0, value);
}
