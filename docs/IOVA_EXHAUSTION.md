# RK3588 NPU IOMMU/IOVA Exhaustion Issue

## Problem

Qwen3.5-9B-Q8_0 fails to run on Rock 5C with RKNPU2 backend due to IOVA allocation failure:

```
RKNPU: failed to allocate IOVA: -12
RKNPU: rknn_gem_get_pages: dma map 11272192 fail
```

## Root Cause

The RK3588 NPU uses IOMMU for address translation. When running Qwen 9B:

1. NPU needs ~11-17MB contiguous IOVA for B-matrix segment
2. Other devices (RGA, VPU, JPEG decoder, video encoders) have already fragmented the IOVA address space
3. No large contiguous block available → ENOMEM

## Solution: RKNN_SPLIT_FACTOR

The `RKNN_SPLIT_FACTOR` environment variable splits B-matrix segments into smaller pieces:

- With 3 cores and `RKNN_SPLIT_FACTOR=4`, segments are split 12 ways (vs 3 normally)
- Each segment requires ~4x less contiguous IOVA memory
- Round-robin core assignment maintains parallelization

```bash
# Example: Run Qwen 9B with split factor of 4
RKNN_SPLIT_FACTOR=4 ./build/bin/llama-cli -m Qwen3.5-9B-Q8_0.gguf -p 'Hello' -n 64
```

## Why TinyLlama Works

TinyLlama's smaller matrices fit within existing IOVA holes. Qwen 9B's larger allocations cannot find space.

## System State (dmesg)

```
RKNPU fdab0000.npu: RKNPU: rknn iommu is enabled, using iommu mode
[Many IOMMU groups for RGA, VPU, JPEG, etc.]
RKNPU: failed to allocate IOVA: -12
```

## Current Kernel

```
Linux rock-5c 6.1.115-vendor-rk35xx #1 SMP Thu Feb 12 18:35:01 UTC 2026 aarch64
cma=256M
```

Note: Kernel still shows "vendor" despite Armbian install - may need reboot or different install method.

## Workarounds

1. **Use RKNN_SPLIT_FACTOR** - splits allocations to fit IOVA constraints
2. **Reboot and immediately test NPU** - fresh IOVA space
3. **Try mainline kernel** - may have larger IOVA aperture
4. **Use smaller models** - that fit within IOVA constraints

## Files

- Model: `/home/radxa/hf_models/Qwen3.5-9B-Q8_0.gguf`
- Build: `/home/radxa/rk-llama.cpp/build/bin/llama-cli`

## Date: 2026-03-19

## Related Issues

- Resolves: https://github.com/KHAEntertainment/rk-llama.cpp/issues/2