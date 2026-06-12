#!/usr/bin/env python3
"""Dummy training job for pipeline verification.

Simulates a short training run: prints a loss curve, then writes a small
checkpoint and a final metrics file to --out. Simulates GPU memory use as
batch_size * 1.5 GB against a 24 GB budget when running on a GPU
(CUDA_VISIBLE_DEVICES set), like a real model would.
"""
import argparse
import json
import os
import sys
import time
from pathlib import Path

GPU_MEM_GB = 24
GB_PER_SAMPLE = 1.5


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--steps", type=int, default=20)
    ap.add_argument("--batch-size", type=int, default=32)
    ap.add_argument("--step-seconds", type=float, default=6.0)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    on_gpu = bool(os.environ.get("CUDA_VISIBLE_DEVICES"))
    device = f"cuda:{os.environ.get('CUDA_VISIBLE_DEVICES')}" if on_gpu else "cpu"
    print(f"device={device} batch_size={args.batch_size} steps={args.steps}",
          flush=True)

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    loss = 4.0
    for step in range(1, args.steps + 1):
        time.sleep(args.step_seconds)
        if on_gpu:
            need = args.batch_size * GB_PER_SAMPLE
            if need > GPU_MEM_GB and step >= 2:
                print(f"step {step}: allocating activation buffers "
                      f"({need:.1f} GB requested)", flush=True)
                print("RuntimeError: CUDA out of memory. Tried to allocate "
                      f"{need - GPU_MEM_GB:.2f} GiB (GPU 0; {GPU_MEM_GB}.00 GiB "
                      "total capacity)", file=sys.stderr, flush=True)
                return 1
        loss *= 0.88
        print(f"step {step}/{args.steps} loss={loss:.4f}", flush=True)

    (out / "checkpoint.pt").write_bytes(os.urandom(1024))
    (out / "final.json").write_text(json.dumps(
        {"final_loss": round(loss, 4), "steps": args.steps,
         "batch_size": args.batch_size, "device": device}) + "\n")
    print(f"done. final_loss={loss:.4f} checkpoint written to {out}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
