# Changelog

All notable changes to this fork will be documented in this file.

## [Unreleased]

### Added
- **Qwen3.5-MoE architecture support** - Synced from upstream commit `f211220a`
  - New `qwen35moe` model architecture
  - Enables Qwen3.5-35B-A3B and Qwen3.5-9B models
- **MoE CPU-pinning** - `--cpu-moe` flag for routing expert layers to CPU
- Documentation for RKNPU2 backend setup and SDK requirements

### Changed
- Synced with upstream ggml-org/llama.cpp (March 2026)
- Updated GGML backend API to version 2
- `ggml_backend_buffer_i` now has 9 fields
- `ggml_backend_i` now has 14 fields
- **DMA heap allocation** - Now tries CMA heap first, falls back to system heap
- **B-matrix allocation** - Uses SDK-managed memory (`rknn_create_mem`) instead of
  external fd wrapping (`rknn_create_mem_from_fd`) for better SDK 2.3.x compatibility

### Fixed
- RKNPU2 backend struct compatibility with upstream API changes
- Backend registration for NPU device discovery

### Requirements
- **RKNN Runtime:** v2.3.0+ from [airockchip/rknn-llm](https://github.com/airockchip/rknn-llm)
- **Kernel driver:** Matching NPU driver version 0.9.8+

### Known Issues
- **SDK 2.3.x GEM handle allocation fails during inference** - Memory allocation
  works during model load but fails during inference with "failed to allocate handle,
  errno: 14". Root cause under investigation - appears to be driver/SDK state issue
  when matmul contexts are destroyed and recreated with different batch sizes.
- NPU workloads may cause board instability on some configurations
- Recommend disabling auto-suspend: `sudo systemctl mask sleep.target suspend.target`

---

## [Pre-sync] - Original Fork

### Features
- RKNPU2 backend for RK3588/RK3588S NPU acceleration
- Hardware support for 6 TOPS INT8 inference
- Integration with ggml tensor operations