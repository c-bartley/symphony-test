#!/usr/bin/env bash
# gpu_check.sh — report GPU availability on this server via nvidia-smi.
#
# For each GPU prints: index, name, memory used/total, utilisation, and
# whether any compute processes are running. The same report is written to
# /exp/exp5/acp24csb/experiments/symphony-test/<ISSUE_ID>/gpu_check.txt
# (ISSUE_ID defaults to CHR-5; override with the ISSUE_ID env var).
set -euo pipefail

ISSUE_ID="${ISSUE_ID:-CHR-5}"
OUT_DIR="/exp/exp5/acp24csb/experiments/symphony-test/${ISSUE_ID}"
OUT_FILE="${OUT_DIR}/gpu_check.txt"

trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

report() {
    echo "GPU availability report"
    echo "Host: $(hostname)"
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo

    if ! command -v nvidia-smi >/dev/null 2>&1; then
        echo "nvidia-smi not found — no NVIDIA driver/GPUs available on this host."
        return
    fi

    local gpu_query compute_apps
    if ! gpu_query=$(nvidia-smi --query-gpu=index,name,uuid,memory.used,memory.total,utilization.gpu \
                                --format=csv,noheader,nounits); then
        echo "nvidia-smi failed — could not query GPUs."
        return
    fi
    compute_apps=$(nvidia-smi --query-compute-apps=gpu_uuid,pid,process_name,used_memory \
                              --format=csv,noheader,nounits 2>/dev/null || true)

    local idx name uuid mem_used mem_total util nprocs
    while IFS=',' read -r idx name uuid mem_used mem_total util; do
        idx=$(trim "$idx"); name=$(trim "$name"); uuid=$(trim "$uuid")
        mem_used=$(trim "$mem_used"); mem_total=$(trim "$mem_total"); util=$(trim "$util")
        nprocs=0
        if [[ -n "$compute_apps" ]]; then
            nprocs=$(grep -c "$uuid" <<<"$compute_apps" || true)
        fi
        echo "GPU ${idx}: ${name}"
        echo "  Memory      : ${mem_used} MiB / ${mem_total} MiB"
        echo "  Utilisation : ${util} %"
        if (( nprocs > 0 )); then
            echo "  Compute procs: yes (${nprocs} running)"
        else
            echo "  Compute procs: none"
        fi
    done <<<"$gpu_query"
}

mkdir -p "$OUT_DIR"
report | tee "$OUT_FILE"
echo
echo "Report written to ${OUT_FILE}"
