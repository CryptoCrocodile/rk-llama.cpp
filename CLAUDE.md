# rk-llama.cpp — Claude Code Instructions

**Fork:** [KHAEntertainment/rk-llama.cpp](https://github.com/KHAEntertainment/rk-llama.cpp)
**Purpose:** Rockchip RK3588/RK3588S/RK3576 NPU acceleration via RKNPU2 backend.

---

## Upstream Sync System

This repo maintains sync with two upstreams:

| Remote | Repository | Role |
|--------|-----------|------|
| `origin` | `KHAEntertainment/rk-llama.cpp` | This fork (push target) |
| `ggml` | `ggml-org/llama.cpp` | Primary upstream — llama.cpp core |
| `invisi` | `InvisiOfficial/rk-llama.cpp` | Secondary upstream — Rockchip NPU patches |

**Never push to `ggml` or `invisi`.** All changes flow in via the sync workflow.

### Scripts

- **`./scripts/sync-upstream-setup.sh`** — one-time setup: normalize remotes, enable `rerere`, fetch all remotes
- **`./scripts/sync-dual-upstream.sh`** — routine sync workflow (see below)

### Sync Workflow

```bash
# Dry run (see what would happen, no changes)
./scripts/sync-dual-upstream.sh --dry-run

# Full sync with merge into rknpu2
./scripts/sync-dual-upstream.sh --merge

# Review branch without merging
./scripts/sync-dual-upstream.sh
# then: git checkout rknpu2 && git merge sync/YYYYMMDD-HHMMSS
```

The sync script:
1. Fetches all remotes
2. Creates `sync/YYYYMMDD-HHMMSS` from `rknpu2`
3. Merges `ggml/master` (or `ggml/rknpu2` if it exists)
4. Runs `test-backend-ops` if available
5. Merges `invisi/rknpu2`
6. Runs `test-backend-ops` again
7. Prints a git graph summary
8. With `--merge`: merges back into `rknpu2`

For full documentation, see [docs/sync-workflow.md](docs/sync-workflow.md).

---

## Branch Structure

- **`rknpu2`** — active development branch (Rockchip NPU + merged upstream)
- **`qwen3-support`** — Qwen3.5-MoE support branch

---

## Building

```bash
# RKNPU2 backend
cmake -B build-npu -DGGML_RKNPU2=ON
cmake --build build-npu -j$(nproc)

# Tests (requires GGML_RKNPU2=OFF)
cmake -B build -DGGML_RKNPU2=OFF -DLLAMA_BUILD_TESTS=ON
cmake --build build --target test-backend-ops -j$(nproc)
```

---

## Key Constraints

- **PRs must not be AI-generated** — see [CONTRIBUTING.md](CONTRIBUTING.md)
- **No direct pushes to upstreams** — all sync via `sync-dual-upstream.sh`
- **RKNN correctness** — verified manually on device (no automated RKNN tests in repo)
- **`ggml/rknpu2` does not exist upstream** — sync uses `ggml/master` as primary target
