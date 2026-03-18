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

### Fixed
- RKNPU2 backend struct compatibility with upstream API changes
- Backend registration for NPU device discovery

### Known Issues
- **RKNN SDK version mismatch**: Bundled `librknnrt.so` may be outdated
  - Symptoms: "failed to convert fd to handle", "failed to submit!, op name: MatMul"
  - **Runtime fix**: Update librknnrt.so to v2.3.2+ from [airockchip/rknn-llm](https://github.com/airockchip/rknn-llm)
  - **Kernel driver fix**: Also requires updated NPU kernel driver from `rknn-llm/rknpu-driver/`
  
  ```bash
  # 1. Update runtime library
  cp ~/rknn-llm/examples/multimodal_model_demo/deploy/3rdparty/librknnrt/Linux/librknn_api/aarch64/librknnrt.so \
     ~/rk-llama-src/ggml/src/ggml-rknpu2/libs/
  
  # 2. Install kernel driver (requires sudo + reboot)
  cd ~/rknn-llm/rknpu-driver
  tar xjf rknpu_driver_0.9.8_20241009.tar.bz2
  cd rknpu_driver_0.9.8
  sudo ./install.sh  # Follow driver-specific instructions
  sudo reboot
  ```

---

## [Pre-sync] - Original Fork

### Features
- RKNPU2 backend for RK3588/RK3588S NPU acceleration
- Hardware support for 6 TOPS INT8 inference
- Integration with ggml tensor operations