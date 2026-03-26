# Dual-Upstream Sync Workflow

This document describes the official workflow for keeping the `rknpu2` branch in sync with two upstreams:

| Remote | Repository | Role |
|--------|-----------|------|
| `origin` | `KHAEntertainment/rk-llama.cpp` | This fork (push target) |
| `ggml` | `ggml-org/llama.cpp` | Primary upstream — llama.cpp core |
| `invisi` | `InvisiOfficial/rk-llama.cpp` | Secondary upstream — Rockchip NPU patches |

**Merge order:** `ggml` (primary) → `invisi` (secondary) → `rknpu2`

`ggml` is the source of truth for all core llama.cpp changes. `invisi` contributes Rockchip NPU backend work that may not yet be in `ggml`. Merging `ggml` first ensures that any NPUspecific backports are applied on top of the latest core.

---

## Setup

Run once to normalize remote names and enable `git rerere` (records conflict resolutions for reuse):

```bash
./scripts/sync-upstream-setup.sh
```

This script will:
- Rename `upstream` → `ggml` (llama.cpp core)
- Rename `invisiofficial` → `invisi` (Rockchip NPU patches)
- Enable `rerere` in local repo config
- Fetch all remotes

---

## Day-to-Day Sync

### Full Sync (creates a review branch, runs tests, merges into rknpu2)

```bash
./scripts/sync-dual-upstream.sh --merge
```

This will:
1. Fetch all remotes
2. Create a short-lived `sync/YYYYMMDD-HHMMSS` branch from `rknpu2`
3. Merge `ggml/rknpu2` (or `ggml/master` if rknpu2 doesn't exist)
4. Run `ggml-tests` if the build is configured
5. Merge `invisi/rknpu2`
6. Run `ggml-tests` again
7. Print a git graph summary
8. Merge the sync branch back into `rknpu2`

### Dry Run

```bash
./scripts/sync-dual-upstream.sh --dry-run
```

Shows every git command that would run without making any changes.

### Review Before Merging

Omit `--merge` to keep the sync branch on disk for manual review before merging:

```bash
./scripts/sync-dual-upstream.sh
# review the sync branch...
git checkout rknpu2 && git merge sync/YYYYMMDD-HHMMSS
```

### Resume After Resolving Conflicts

If a merge had conflicts you resolved manually:

```bash
git add <resolved-files>
git commit
./scripts/sync-dual-upstream.sh --merge-only
```

---

## Ancestry and Unrelated Histories

The `invisi/rknpu2` branch shares commit history with the local `rknpu2` branch — they are **not unrelated histories**. Routine syncs use a standard `git merge` with no special flags.

On the **initial bridge** (first connection between these repos), `sync-dual-upstream.sh` will detect the unrelated-histories case and exit with a clear error:

```
INVISI ANCESTRY CHECK: UNRELATED HISTORIES DETECTED
```

To proceed with an initial bridge, use `--force-invisi`:

```bash
./scripts/sync-dual-upstream.sh --force-invisi --merge
```

This passes `--allow-unrelated-histories` to the invisi merge. After the initial bridge, subsequent syncs do not need this flag.

---

## Testing

The sync script runs `test-backend-ops` from an existing `build/` directory after each merge. This exercises the standard llama.cpp test infrastructure. There are currently **no RKNN-specific tests** in the repo — RKNN correctness is verified manually on device.

The existing `build/` directory was configured without tests; to include tests:

```bash
cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_RKNPU2=OFF \
    -DLLAMA_BUILD_TESTS=ON
cmake --build build --target test-backend-ops -j$(nproc)
```

---

## Remote Policy

| Remote | Purpose | Push? |
|--------|---------|-------|
| `origin` | This fork (`KHAEntertainment/rk-llama.cpp`) | Yes — PRs and direct pushes to feature branches |
| `ggml` | Primary upstream (`ggml-org/llama.cpp`) | No — read-only |
| `invisi` | Secondary upstream (`InvisiOfficial/rk-llama.cpp`) | No — read-only |

Do **not** push to `ggml` or `invisi`. All changes flow in via the sync workflow above.

---

## Troubleshooting

### "remote 'ggml' not configured"

Run `./scripts/sync-upstream-setup.sh` first.

### "invisi ancestry: UNRELATED HISTORIES DETECTED"

This is expected only for the **initial bridge**. Re-run with `--force-invisi`. If you see this on a routine sync, the invisi remote has been force-pushed — do not use `--force-invisi`; investigate the divergence first.

### Merge conflicts

`git rerere` (enabled by setup) will replay recorded resolutions. For new conflicts:
1. `git status` to see conflicting files
2. Edit each file to resolve conflicts
3. `git add <files>` and `git commit`

### Build/test failures after merge

Fix the build issues in the sync branch before merging into `rknpu2`. The sync branch is yours to experiment on.

---

## Related Documentation

- [CONTRIBUTING.md](../CONTRIBUTING.md) — general contribution guidelines
- [docs/build.md](./build.md) — building llama.cpp
- [ci/README.md](../ci/README.md) — running CI locally
