#!/usr/bin/env bash
#
# sync-dual-upstream.sh — Dual-upstream sync workflow for rk-llama.cpp
#
# Syncs ggml-org/llama.cpp (primary) and InvisiOfficial/rk-llama.cpp (secondary)
# into the rknpu2 integration branch via a short-lived sync branch.
#
# Merge order: ggml → invisi
# Each merge is followed by a test run. A git graph summary is printed at the end.
#
# Usage:
#   ./scripts/sync-dual-upstream.sh              # interactive (merges into integration branch)
#   ./scripts/sync-dual-upstream.sh --dry-run    # show what would happen, no changes
#   ./scripts/sync-dual-upstream.sh --help        # show this help
#   SYNC_INTEGRATION_BRANCH=rknpu2 ./scripts/sync-dual-upstream.sh --merge  # merge into rknpu2
#   ./scripts/sync-dual-upstream.sh --merge-only  # only merge pre-built sync branch, skip new sync
#

set -euo pipefail

# ---------- config ----------
INTEGRATION_BRANCH="${SYNC_INTEGRATION_BRANCH:-rknpu2}"
SYNC_BRANCH="sync/$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0
MERGE_ONLY=0
MERGE_INTEGRATION=0
FORCE_INVISI=0   # --force-invisi: allow unrelated-histories merge from invisi

# ---------- helpers ----------
usage() {
    head -36 "$0" | tail -28 | sed 's/^#//'
}

log()  { echo "[$(date +%H:%M:%S)] $*"; }
warn() { echo "[$(date +%H:%M:%S)] WARNING: $*" >&2; }
die()  { echo "[$(date +%H:%M:%S)] ERROR: $*" >&2; exit 1; }

need_cmd() {
    command -v "$1" &>/dev/null || die "required command '$1' not found"
}

# Verify a remote exists and is reachable
check_remote() {
    local r=$1
    git remote get-url "$r" &>/dev/null || die "remote '$r' not configured — run './scripts/sync-upstream-setup.sh' first"
}

# Detect whether invisi/rknpu2 has unrelated histories vs local integration branch
detect_unrelated_invisi() {
    local invisi_head=$1
    local merge_base
    merge_base=$(git merge-base "$INTEGRATION_BRANCH" "$invisi_head" 2>/dev/null) || {
        # merge-base fails when histories are truly unrelated
        echo "UNRELATED"
        return
    }
    # If the merge-base is the same as the invisi HEAD, histories are already contained
    if [[ "$merge_base" == "$invisi_head" ]]; then
        echo "ALREADY_MERGED"
    else
        echo "RELATED"
    fi
}

# Run repo-relevant tests (llama.cpp test infrastructure)
run_tests() {
    local label="$1"
    log "--- running tests after $label ---"

    # This repo is a mixed ggml/llama.cpp fork — cmake configure fails
    # when attempting to build tests in isolation. Check for an existing
    # pre-configured build directory and use it if available.
    local build_dir=""
    for dir in build build-npu; do
        if [[ -d "$dir" ]] && [[ -f "$dir/Makefile" || -f "$dir/build.ninja" ]]; then
            build_dir="$dir"
            break
        fi
    done

    if [[ -z "$build_dir" ]]; then
        log "  no configured build found — cmake configure fails in this mixed"
        log "  ggml/llama.cpp layout. run tests manually before merging:"
        log "    cmake -B build -DGGML_RKNPU2=OFF -DLLAMA_BUILD_TESTS=ON"
        log "    cmake --build build --target test-backend-ops -j\$(get_nproc)"
    else
        log "  using existing build: $build_dir"
        if cmake --build "$build_dir" --target test-backend-ops -j"$(get_nproc)" 2>&1 | tail -10; then
            log "  tests passed"
        else
            warn "some tests failed — review output above"
        fi
    fi

    log "  --- tests after $label complete ---"
}

# Print a short graph of the relevant commits
print_graph() {
    local branch="$1"
    local from="${2:-HEAD}"
    echo ""
    echo "=== commit graph (last 20 on $branch) ==="
    git log --graph --oneline --decorate \
        --boundary "${from}".."${branch}" 2>/dev/null | head -30 || \
        git log --oneline -20
    echo ""
}

# ---------- argument parsing ----------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)      DRY_RUN=1; shift ;;
        --force-invisi) FORCE_INVISI=1; shift ;;
        --merge)        MERGE_INTEGRATION=1; shift ;;
        --merge-only)   MERGE_ONLY=1; shift ;;
        --help|-h)      usage; exit 0 ;;
        *)              die "unknown argument '$1' (use --help)" ;;
    esac
done

# ---------- pre-flight ----------
need_cmd git

# nproc may not exist on macOS; fall back to sysctl
get_nproc() {
    if command -v nproc &>/dev/null; then
        nproc
    elif command -v sysctl &>/dev/null; then
        sysctl -n hw.ncpu 2>/dev/null || echo "4"
    else
        echo "4"
    fi
}

check_remote ggml
check_remote invisi
check_remote origin

git rev-parse --verify "$INTEGRATION_BRANCH" &>/dev/null || \
    die "integration branch '$INTEGRATION_BRANCH' does not exist"

# Detect staged/uncommitted changes
if ! git diff-index --quiet HEAD 2>/dev/null; then
    warn "there are uncommitted changes — sync creates a clean branch; working tree is undisturbed"
fi

# ---------- main ----------
log "=== dual-upstream sync ==="
log "  integration branch : $INTEGRATION_BRANCH"
log "  ggml remote        : ggml"
log "  invisi remote      : invisi"
log "  dry-run            : $DRY_RUN"

if [[ $DRY_RUN -eq 1 ]]; then
    log "  [dry-run mode — no changes will be made]"
fi

# --- step 1: fetch all remotes ---
log "--- fetching all remotes ---"
if [[ $DRY_RUN -eq 0 ]]; then
    git fetch --all --tags --prune 2>&1 | grep -v "^From " | head -20 || true
fi

# --- step 2: detect unrelated invisi history ---
GGML_REF="ggml/rknpu2"
INVISI_REF="invisi/rknpu2"

# Determine ggml ref — prefer rknpu2 if it exists, fall back to master
if git rev-parse --verify "$GGML_REF" &>/dev/null; then
    GGML_BRANCH="$GGML_REF"
else
    GGML_BRANCH="ggml/master"
    warn "ggml/rknpu2 not found; using ggml/master as primary upstream"
fi

if ! git rev-parse --verify "$INVISI_REF" &>/dev/null; then
    die "invisi/rknpu2 ref not found — cannot sync"
fi

INVISI_STATUS=$(detect_unrelated_invisi "invisi/rknpu2")
log "  ggml branch        : $GGML_BRANCH"
log "  invisi branch      : $INVISI_REF"
log "  invisi ancestry    : $INVISI_STATUS"

if [[ "$INVISI_STATUS" == "UNRELATED" && "$FORCE_INVISI" -eq 0 ]]; then
    echo ""
    echo "============================================================================="
    echo "  INVISI ANCESTRY CHECK: UNRELATED HISTORIES DETECTED"
    echo ""
    echo "  invisiofficial/rknpu2 shares no common commit with $INTEGRATION_BRANCH."
    echo "  This is a one-time high-conflict bridge that requires --force-invisi."
    echo ""
    echo "  If you are doing the initial bridge (first time connecting these repos),"
    echo "  run the sync again with --force-invisi to proceed:"
    echo ""
    echo "    ./scripts/sync-dual-upstream.sh --force-invisi [--merge]"
    echo ""
    echo "  If you are doing a routine sync and see this message, something is wrong"
    echo "  with the remote (e.g. force-push rewriting history)."
    echo "============================================================================="
    exit 1
fi

if [[ "$INVISI_STATUS" == "ALREADY_MERGED" ]]; then
    log "  invisi ancestry    : ALREADY MERGED — routine sync expected"
fi

# --- step 3: create sync branch ---
if [[ $MERGE_ONLY -eq 0 ]]; then
    echo ""
    log "--- creating sync branch ---"
    SYNC_BRANCH="sync/$(date +%Y%m%d-%H%M%S)"
    if [[ $DRY_RUN -eq 0 ]]; then
        git checkout -b "$SYNC_BRANCH" "$INTEGRATION_BRANCH"
        log "  created branch '$SYNC_BRANCH' from '$INTEGRATION_BRANCH'"
    else
        echo "  git checkout -b $SYNC_BRANCH $INTEGRATION_BRANCH"
    fi
fi

# --- step 4: merge ggml (primary upstream) ---
echo ""
log "--- merging ggml (primary upstream) ---"
if [[ $DRY_RUN -eq 0 ]]; then
    if git merge "$GGML_BRANCH" --no-edit; then
        log "  ggml merge: clean"
    else
        warn "ggml merge left conflicts — resolve, commit, then re-run with --merge-only"
        warn "  tip: git mergetool or manually edit conflicting files"
        warn "  tip: git add <resolved-files> && git commit"
        exit 1
    fi
else
    echo "  git merge $GGML_BRANCH --no-edit"
fi

# step 4b: tests after ggml merge
run_tests "ggml merge"

# --- step 5: merge invisi (secondary upstream) ---
echo ""
log "--- merging invisi (secondary upstream) ---"
if [[ "$INVISI_STATUS" == "UNRELATED" ]]; then
    if [[ $DRY_RUN -eq 0 ]]; then
        if git merge "$INVISI_REF" --no-edit --allow-unrelated-histories; then
            log "  invisi merge (--allow-unrelated-histories): clean"
        else
            warn "invisi merge left conflicts — resolve, commit, then re-run with --merge-only"
            exit 1
        fi
    else
        echo "  git merge $INVISI_REF --no-edit --allow-unrelated-histories"
    fi
else
    if [[ $DRY_RUN -eq 0 ]]; then
        if git merge "$INVISI_REF" --no-edit; then
            log "  invisi merge: clean"
        else
            warn "invisi merge left conflicts — resolve, commit, then re-run with --merge-only"
            exit 1
        fi
    else
        echo "  git merge $INVISI_REF --no-edit"
    fi
fi

# step 5b: tests after invisi merge
run_tests "invisi merge"

# --- step 6: graph summary ---
echo ""
print_graph "$SYNC_BRANCH" "$INTEGRATION_BRANCH"

# --- step 7: merge into integration branch ---
if [[ $MERGE_INTEGRATION -eq 1 || $MERGE_ONLY -eq 1 ]]; then
    echo ""
    log "--- merging sync branch into $INTEGRATION_BRANCH ---"
    if [[ $DRY_RUN -eq 0 ]]; then
        git checkout "$INTEGRATION_BRANCH"
        if git merge "$SYNC_BRANCH" --no-edit; then
            log "  ✓ $INTEGRATION_BRANCH updated"
        else
            warn "integration merge had conflicts"
            exit 1
        fi
        # optionally delete sync branch
        if git branch -d "$SYNC_BRANCH" 2>/dev/null; then
            log "  cleaned up sync branch '$SYNC_BRANCH'"
        fi
    else
        echo "  git checkout $INTEGRATION_BRANCH"
        echo "  git merge $SYNC_BRANCH --no-edit"
        echo "  git branch -d $SYNC_BRANCH"
    fi
else
    log "--- skipping integration merge (run with --merge to finalize) ---"
    log "  sync branch '$SYNC_BRANCH' is ready for review"
    log "  to finalize: git checkout $INTEGRATION_BRANCH && git merge $SYNC_BRANCH"
fi

echo ""
log "=== sync complete ==="
