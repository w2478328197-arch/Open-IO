"""Build a separate offline cue-card candidate; never changes FOCUS-04 pins or flashes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from zipfile import ZipFile

HERE = Path(__file__).resolve().parent
FOCUS = HERE.parent / "focus"
TOOLCHAIN_LOCK = HERE / "toolchain.lock.json"

def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ("stock", "out", "llvm"):
        parser.add_argument("--" + key, type=Path, required=True)
    parser.add_argument("--workout", action="store_true", help="Include isolated TWK1 outdoor workout page")
    args = parser.parse_args()
    output, llvm = args.out.resolve(), args.llvm.resolve()
    if output.exists():
        raise SystemExit("A new output directory is required")
    version = subprocess.check_output([llvm / "clang", "--version"], text=True)
    toolchains = json.loads(TOOLCHAIN_LOCK.read_text())
    compiler_line = version.splitlines()[0] if version.splitlines() else ""
    selected = next((entry for entry in toolchains["toolchains"] if compiler_line == entry["version"]), None)
    if not selected:
        raise SystemExit("Compiler does not match a pinned toolchain entry")
    if selected["verifyToolHashes"]:
        for name, expected in selected["toolSHA256"].items():
            if sha256(llvm / name) != expected:
                raise SystemExit("Pinned tool hash mismatch: " + name)
    environment = dict(os.environ, PATH=str(llvm) + os.pathsep + os.environ.get("PATH", ""))
    def run(*command):
        subprocess.run([str(value) for value in command], env=environment, check=True)
    shutil.copytree(FOCUS / "src", output)
    baseline = output / "firmware-inspection/StrixOS-1.0.4.12"
    run(sys.executable, HERE.parent.parent / "src/prepare-baseline.py", args.stock.resolve(), "--output", baseline)
    shutil.copyfile(FOCUS / "symbols.json", baseline / "symbols.json")
    artwork = output / "official-addon/build/turbo-photo-png-10412-20260921/turbo-photo-gray16-rgba-88x98.png"
    artwork.parent.mkdir(parents=True)
    shutil.copyfile(HERE.parent.parent / "assets/turbo-photo-firmware.png", artwork)
    source = output / "official-addon/research"
    for name in ("reader.c", "reader_view.c", "reader_service.c"):
        shutil.copyfile(HERE / name, source / "weread-v1" / name)
    run(sys.executable, HERE / "prepare_menu13.py", "--source", source)
    if args.workout:
        run(sys.executable, HERE.parent / "workout/prepare.py", "--source", source)
        run(sys.executable, HERE.parent / "workout/prepare_menu14.py", "--source", source)
    run("xcrun", "clang", "-std=c11", "-Wall", "-Wextra", "-Werror", "-fsanitize=address,undefined",
        "-I", source / "weread-v1",
        source / "weread-v1/reader.c", source / "weread-v1/reader_view.c", HERE / "cue_view_test.c", "-o", output / "cue-view")
    run(output / "cue-view")
    candidate = output / "candidate"
    run(sys.executable, source / "music-runtime-v1/build_candidate.py", "--out", candidate)
    # Inherited non-card behavior must still pass, including offline long press.
    for script in ("focus-v1/test_menu_quad_arm.py", "focus-v1/test_menu12_arm.py", "focus-v1/test_service_arm.py",
                   "weread-v1/test_reader_arm.py", "weread-v1/test_open_lifecycle_arm.py", "weread-v1/test_back_offline_arm.py",
                   "music-runtime-v1/test_music_arm.py", "navigation-runtime-v1/test_service_arm.py",
                   "diagnostics-v1/test_service_arm.py"):
        run(sys.executable, source / script, candidate)
    run(sys.executable, source / "display-runtime-v1/test_linked_arm.py", candidate, "--candidate")
    run(sys.executable, source / "focus-v1/audit_candidate.py", candidate, "--out", candidate / "independent-audit.json")
    run(sys.executable, HERE / "test_cue_open_arm.py", candidate)
    if args.workout:
        run(sys.executable, HERE.parent / "workout/test_workout_arm.py", candidate)
        run("xcrun", "clang", "-std=c11", "-Wall", "-Wextra", "-Werror", "-fsanitize=address,undefined",
            "-I", source / "navigation-runtime-v1",
            source / "navigation-runtime-v1/nav_runtime.c", source / "navigation-runtime-v1/nav_visual.c",
            source / "navigation-runtime-v1/nav_view.c", HERE.parent / "workout/workout_view_test.c", "-o", output / "workout-view")
        run(output / "workout-view")
    for name, units in (("focus", ("focus.c", "test_focus.c")),
                        ("focus-view", ("focus.c", "focus_view.c", "test_view.c"))):
        run("xcrun", "clang", "-std=c11", "-Wall", "-Wextra", "-Werror", "-fsanitize=address,undefined",
            *(source / "focus-v1" / unit for unit in units), "-o", output / name)
        run(output / name)
    if (candidate / "payload/nuttx_ap.bin").stat().st_size > 9_600_000:
        raise SystemExit("AP exceeds the existing 9,600,000-byte ceiling")
    manifest = json.loads((candidate / "report.json").read_text())
    old_archive = candidate / manifest["archive"]["name"]
    archive = candidate / ("Turbo-Workout-TWK1-CANDIDATE-NOT-DEVICE-VERIFIED.zip" if args.workout else "Turbo-CueCards-CANDIDATE-NOT-DEVICE-VERIFIED.zip")
    old_archive.rename(archive)
    if args.workout:
        # Match the validated TWK1 archive, independent of the local build time.
        # Payload bytes remain subject to the existing AP and 13-stock-file audit.
        normalized = archive.with_suffix('.normalized.zip')
        with ZipFile(archive) as original, ZipFile(normalized, 'w') as stable:
            for info in original.infolist():
                info.date_time = (2026, 9, 28, 14, 13, 10)
                stable.writestr(info, original.read(info), compresslevel=6)
        normalized.replace(archive)
        if sha256(archive) != 'c9f441bced48ff56782f23ccdcc42c0545bda5ac719f8c6fa8429d8c24a619a4':
            raise SystemExit('Rebuilt TWK1 archive does not match the validated candidate')
        manifest['archive']['sha256'] = sha256(archive)
    manifest["archive"]["name"] = archive.name
    manifest["cueCards"] = {"status": "OFFLINE_CANDIDATE", "deviceVerified": False, "flashAuthorized": False,
                            "homeMenuEntry": "提词卡", "homeMenuIndex": 12, "homeMenuCount": 14 if args.workout else 13,
                            "contentKind": 3, "waitScreen": True, "menuRegressionTest": True,
                            "alwaysOnInhibitRequest": True, "screenWakeRequest": True, "cueIdleCloseDisabled": True,
                            "compiler": compiler_line,
                            "toolchainArchiveSHA256": selected.get("archiveSHA256"),
                            "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
                            "releaseGate": "Existing FOCUS-04 gates intentionally reject this new candidate"}
    if args.workout:
        manifest["workout"] = {"protocol": "TWK1", "layout": "540x180-two-columns", "homeMenuEntry": "运动看板", "homeMenuIndex": 13, "homeMenuCount": 14, "menuBoundStart": True, "status": "OFFLINE_CANDIDATE", "flashAuthorized": False, "deviceVerified": False}
    (candidate / "report.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("Cue-card candidate built and inherited ARM regressions passed; not installed or device-verified.")

if __name__ == "__main__":
    main()
