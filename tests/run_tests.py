#!/usr/bin/env python3
"""Run reproducible Serpent KAT, streaming, reset/rekey and packed-lane tests.

No Python dependencies. Needs Icarus Verilog; IVERILOG and VVP can name alternate
executables. Generated traces and simulator binaries live in tests/.build/.
Run from any directory: python3 tests/run_tests.py
Use --reference-only to check the oracle against all stored external KATs.
"""

import argparse
import json
import os
from pathlib import Path
import random
import shutil
import subprocess
import sys

from reference_serpent import encrypt_block

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent


def known_answers():
    return json.loads((HERE / "kat_vectors.json").read_text())["vectors"]


def check_reference(vectors):
    for item in vectors:
        got = encrypt_block(bytes.fromhex(item["key"]),
                            bytes.fromhex(item["plaintext"]))
        expected = bytes.fromhex(item["ciphertext"])
        if got != expected:
            raise AssertionError("Reference failed NESSIE {key_bits}-bit set "
                                 "{set} vector {vector}: {got}".format(
                                     **item, got=got.hex()))
    print("PASS independent reference: {} external NESSIE KATs".format(len(vectors)),
          flush=True)


def make_trace(bits, blocks, latency, kats, seed):
    """Independent cycle oracle; accepted at cycle n -> output at n+latency."""
    rng = random.Random(seed + 1000 * bits + blocks)
    rows = []
    pending = {}
    key = None
    accepted = emitted = flushed = 0

    def random_bytes(count):
        return bytes(rng.getrandbits(8) for _ in range(count))

    def step(rst=0, load=0, valid=0, new_key=None, data=None, expected=None):
        nonlocal key, accepted, emitted, flushed
        n = len(rows)
        bus_key = new_key if new_key is not None else random_bytes(bits // 8)
        bus_data = data if data is not None else random_bytes(16 * blocks)
        ready_before = int(key is not None and not (rst or load))
        out = bytes(16 * blocks)
        out_valid = 0
        if rst:
            flushed += len(pending)
            pending.clear()
            key = None
        elif load:
            flushed += len(pending)
            pending.clear()
            key = bus_key
        else:
            if n in pending:
                out = pending.pop(n)
                out_valid = 1
                emitted += 1
            if valid and ready_before:
                accepted += 1
                if expected is None:
                    expected = b"".join(encrypt_block(key, bus_data[i:i + 16])
                                        for i in range(0, len(bus_data), 16))
                pending[n + latency] = expected
        rows.append("{} {} {} {:0{}x} {:0{}x} {} {} {} {:0{}x}".format(
            rst, load, valid, int.from_bytes(bus_key, "little"), bits // 4,
            int.from_bytes(bus_data, "little"), 32 * blocks, ready_before,
            int(key is not None), out_valid, int.from_bytes(out, "little"),
            32 * blocks))

    # Synchronous reset wins over simultaneous load/valid. No pre-key inputs
    # may enter the pipeline, even if in_valid remains high beyond its latency.
    step(rst=1, load=1, valid=1)
    step(rst=1)
    for _ in range(latency + 2):
        step(valid=1)

    # KAT lane 0 uses the external ciphertext directly; further lanes are
    # distinct random plaintexts so lane swaps/replication cannot be hidden.
    for item in kats:
        kat_key = bytes.fromhex(item["key"])
        plaintext = bytes.fromhex(item["plaintext"])
        ciphertext = bytes.fromhex(item["ciphertext"])
        extra = random_bytes(16 * (blocks - 1))
        expected = ciphertext + b"".join(encrypt_block(kat_key, extra[i:i + 16])
                                        for i in range(0, len(extra), 16))
        step(load=1, valid=1, new_key=kat_key)
        step(valid=1, data=plaintext + extra, expected=expected)
        for _ in range(latency + 1):
            step()

    # A long II=1 stream tests every pipeline bank concurrently; toggling the
    # unloaded key bus on every cycle detects accidental combinational key use.
    step(load=1)
    for _ in range(96):
        step(valid=1)
    for n in range(60):
        step(valid=int(n % 7 in (0, 2, 3, 6)))
    for _ in range(latency + 2):
        step()

    # Reset alone cancels an otherwise-due output and all in-flight blocks.
    for _ in range(latency + 3):
        step(valid=1)
    step(rst=1, valid=1)
    for _ in range(latency + 2):
        step(valid=1)
    step(load=1, valid=1)

    # Reset cancels in-flight blocks and removes the old key. Traffic is
    # deliberately asserted during reset and throughout the unkeyed interval.
    for _ in range(latency // 2):
        step(valid=1)
    step(rst=1, load=1, valid=1)
    for _ in range(latency + 3):
        step(valid=1)
    step(load=1, valid=1)
    for _ in range(latency + 7):
        step(valid=1)

    # Rekey with a full pipeline, including an output otherwise due that edge.
    # Two consecutive loads must leave only the second key in force.
    step(load=1, valid=1)
    step(load=1, valid=1)
    for n in range(73):
        step(valid=int(n % 5 != 2))
    for _ in range(latency + 3):
        step()
    if pending:
        raise AssertionError("trace ended before its pipeline drained")
    if accepted != emitted + flushed:
        raise AssertionError("cycle oracle accounting mismatch")
    return rows, {"accepted": accepted, "emitted": emitted, "flushed": flushed}


def executable(name, environment):
    candidate = os.environ.get(environment, name)
    resolved = shutil.which(candidate)
    if not resolved:
        raise RuntimeError("Cannot find {}; install Icarus Verilog or set {}".format(
            name, environment))
    return resolved


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-only", action="store_true")
    parser.add_argument("--variant", choices=("all", "1-s", "2-s"), default="all")
    parser.add_argument("--key-bits", type=int, choices=(128, 192, 256))
    parser.add_argument("--seed", type=int, default=0x5E4F3E17)
    args = parser.parse_args()
    vectors = known_answers()
    check_reference(vectors)
    if args.reference_only:
        return
    compiler = executable("iverilog", "IVERILOG")
    simulator = executable("vvp", "VVP")
    build = HERE / ".build"
    build.mkdir(exist_ok=True)
    variants = ("1-s", "2-s") if args.variant == "all" else (args.variant,)
    key_sizes = (128, 192, 256) if args.key_bits is None else (args.key_bits,)
    report = {"seed": args.seed, "external_kats": len(vectors),
              "smoke_tests": [], "runs": []}
    for variant in variants:
        latency = 32 if variant == "1-s" else 16
        sources = sorted(str(p) for p in (ROOT / variant).glob("serpent_*.v"))
        # Keep the static-at-time-zero key test in every run: a changing key
        # bus in the larger random trace would miss initialization bugs.
        smoke_binary = build / ("smoke-" + variant + ".vvp")
        print("Testing {} static-zero-key smoke ...".format(variant), flush=True)
        subprocess.run([compiler, "-g2012", "-s", "tb_serpent_pipelined", "-o",
                        str(smoke_binary)] + sources +
                       [str(ROOT / variant / "tb_serpent.v")],
                       check=True, cwd=ROOT, timeout=120)
        smoke = subprocess.run([simulator, str(smoke_binary)], check=True, cwd=ROOT,
                               text=True, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, timeout=30)
        print(smoke.stdout.strip(), flush=True)
        report["smoke_tests"].append(variant)
        for bits in key_sizes:
            kats = [v for v in vectors if v["key_bits"] == bits]
            for ecb, blocks in ((0, 1), (1, 1), (1, 2), (1, 3)):
                label = "{}-k{}-{}{}".format(variant, bits, "ecb" if ecb else "core", blocks)
                trace, counts = make_trace(bits, blocks, latency, kats, args.seed)
                trace_path, binary = build / (label + ".txt"), build / (label + ".vvp")
                trace_path.write_text("\n".join(trace) + "\n")
                command = [compiler, "-g2012", "-s", "tb_pipeline", "-o", str(binary)]
                if variant == "2-s":
                    command.append("-DTWO_ROUNDS")
                for name, value in (("KEY_BITS", bits), ("BLOCKS", blocks),
                                    ("USE_ECB", ecb), ("LATENCY", latency)):
                    command.extend(["-Ptb_pipeline.{}={}".format(name, value)])
                command += [str(HERE / "tb_pipeline.sv")] + sources
                print("Testing {} ...".format(label), flush=True)
                subprocess.run(command, check=True, cwd=ROOT, timeout=120)
                run = subprocess.run([simulator, str(binary), "+vectors=" + str(trace_path)],
                                     check=True, cwd=ROOT, text=True,
                                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                     timeout=180)
                print(run.stdout.strip(), flush=True)
                report["runs"].append(dict(variant=variant, key_bits=bits, blocks=blocks,
                                           ecb=bool(ecb), cycles=len(trace), **counts))
    (build / "results.json").write_text(json.dumps(report, indent=2) + "\n")
    print("PASS {} simulation configurations + {} static-key smoke tests; seed={}".format(
        len(report["runs"]), len(report["smoke_tests"]), args.seed))


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        if exc.stdout:
            print(exc.stdout, file=sys.stderr)
        raise SystemExit(exc.returncode)
