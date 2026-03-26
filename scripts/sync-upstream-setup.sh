#!/usr/bin/env bash
#
# sync-upstream-setup.sh — Normalize remotes and enable rerere for dual-upstream sync
#
# Remote policy after this script runs:
#   origin  — KHAEntertainment/rk-llama.cpp  (this fork)
#   ggml    — ggml-org/llama.cpp             (primary upstream)
#   invisi  — InvisiOfficial/rk-llama.cpp    (secondary upstream, Rockchip NPU patches)
#
# Usage:
#   ./scripts/sync-upstream-setup.sh [--dry-run]
#

set -e

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
    echo "[dry-run] would:"
fi

echo "=== Dual-Upstream Remote Setup ==="

# --- 1. Rename 'upstream' → 'ggml' ---
if git remote get-url upstream &>/dev/null; then
    UPSTREAM_URL=$(git remote get-url upstream)
    if [[ "$UPSTREAM_URL" == *"ggml-org/llama.cpp"* ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            echo "  git remote rename upstream ggml"
        else
            git remote rename upstream ggml
            echo "  ✓ renamed 'upstream' → 'ggml'"
        fi
    else
        echo "  ⚠ 'upstream' exists but points elsewhere ($UPSTREAM_URL)"
        echo "    skipping rename; verify manually"
    fi
else
    echo "  ✓ 'upstream' remote already absent (or already renamed)"
fi

# --- 2. Rename 'invisiofficial' → 'invisi' ---
if git remote get-url invisiofficial &>/dev/null; then
    INVISI_URL=$(git remote get-url invisiofficial)
    if [[ "$INVISI_URL" == *"invisiofficial/rk-llama.cpp"* ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            echo "  git remote rename invisiofficial invisi"
        else
            git remote rename invisiofficial invisi
            echo "  ✓ renamed 'invisiofficial' → 'invisi'"
        fi
    fi
elif git remote get-url invisi &>/dev/null; then
    echo "  ✓ 'invisi' remote already present"
else
    echo "  ⚠ neither 'invisiofficial' nor 'invisi' remote found"
    echo "    InvisiOfficial/rk-llama.cpp remote may need to be added manually:"
    echo "    git remote add invisi https://github.com/InvisiOfficial/rk-llama.cpp.git"
fi

# --- 3. Verify final remote state ---
echo ""
echo "=== Remote state ==="
git remote -v

# --- 4. Enable rerere ---
echo ""
echo "=== Rerere ==="
if [[ $DRY_RUN -eq 1 ]]; then
    echo "  git config rerere.enabled true"
else
    git config rerere.enabled true
    echo "  ✓ rerere enabled"
fi

# --- 5. Fetch all remotes ---
echo ""
echo "=== Fetching all remotes ==="
if [[ $DRY_RUN -eq 1 ]]; then
    echo "  git fetch --all --tags"
else
    git fetch --all --tags
    echo "  ✓ all remotes fetched"
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Remote naming is now:"
echo "  origin  — KHAEntertainment/rk-llama.cpp"
echo "  ggml    — ggml-org/llama.cpp (primary upstream)"
echo "  invisi  — InvisiOfficial/rk-llama.cpp (secondary upstream)"
echo ""
echo "Run './scripts/sync-dual-upstream.sh --help' for the sync workflow."
