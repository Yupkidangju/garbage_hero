"""Build and package Garbage Hero using the official Godot desktop exporter."""

import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"
ENGINE = "4.7.2.stable.official.ed1daf0bf"
TARGETS = {
    "windows": ("Windows x86_64", "GarbageHero.exe", ".zip"),
    "linux": ("Linux x86_64", "GarbageHero.x86_64", ".tar.gz"),
}
QA = ["game/tests/session_test.gd", "game/tests/progression_test.gd",
      "game/tests/equipment_test.gd", "game/tests/quest_book_test.gd",
      "game/tests/expansion_session_test.gd", "game/tests/arsenal_test.gd", "game/tests/world_test.gd",
      "game/tests/player_test.gd", "game/tests/enemy_test.gd",
      "tests/retry_cleave.gd", "tests/mixed_groups.gd", "tests/forest_paths.gd", "tests/progression_input.gd"]


def version():
    setting = re.search(r'^config/version="(\d+\.\d+\.\d+)"$', (GAME / "project.godot").read_text("utf-8"), re.M)
    if not setting:
        raise ValueError("Missing numeric config/version in game/project.godot")
    return setting.group(1)


def run(args, *, cwd=ROOT, env=None, timeout=600, log=None):
    process = subprocess.run(args, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             encoding="utf-8", errors="replace", timeout=timeout)
    print(process.stdout, end="", flush=True)
    output = process.stdout
    if log is not None and log.is_file():
        output += "\n" + log.read_text("utf-8", errors="replace")
    errors = re.findall(r'^\s*(?:SCRIPT ERROR|ERROR):.*$', output, re.M)
    if process.returncode or errors:
        raise RuntimeError(f"{args[0]} failed ({process.returncode}): " + "\n".join(errors[:5]))
    return process.stdout.strip()


def package(target, godot, dist, release):
    preset, executable, extension = TARGETS[target]
    stem = f"GarbageHero-v{release}-{target}-x86_64"
    with tempfile.TemporaryDirectory(dir=dist, prefix=".build-") as temporary:
        work = Path(temporary)
        app = work / stem
        app.mkdir()
        run([godot, "--headless", "--path", GAME, "--export-release", preset, app / executable])
        for name in [executable, "GarbageHero.pck"]:
            if not (app / name).is_file() or not (app / name).stat().st_size:
                raise RuntimeError(f"Missing exported {name}")
        for name in ["LICENSE", "NOTICE"]:
            shutil.copy2(ROOT / name, app / name)
        shutil.copytree(ROOT / "licenses", app / "licenses")
        shutil.copy2(GAME / "assets/fonts/OFL.txt", app / "licenses/NotoSansKR-OFL.txt")
        archive = work / (stem + extension)
        if target == "windows":
            with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=5) as bundle:
                for path in sorted(app.rglob("*")):
                    if path.is_file():
                        bundle.write(path, path.relative_to(work))
        else:
            with tarfile.open(archive, "w:gz", compresslevel=5) as bundle:
                for path in sorted(app.rglob("*")):
                    if path.is_file():
                        info = bundle.gettarinfo(str(path), str(path.relative_to(work)).replace(os.sep, "/"))
                        info.mode = 0o755 if path.name == executable else 0o644
                        info.uid = info.gid = 0
                        info.uname = info.gname = ""
                        with path.open("rb") as source:
                            bundle.addfile(info, source)
        result = dist / archive.name
        os.replace(archive, result)
        print(result, flush=True)
        return result


def native_target():
    return {"win32": "windows", "linux": "linux"}.get(sys.platform)


def smoke(archive, target, release):
    if native_target() != target:
        raise RuntimeError("Run the package smoke test on its target operating system.")
    _, executable, _ = TARGETS[target]
    with tempfile.TemporaryDirectory(prefix="garbagehero-smoke-") as temporary:
        work = Path(temporary)
        # 이 단계는 방금 만든 패키지를 별도 디렉터리에 풀어 그 안의 실행 파일로 검증한다.
        if target == "windows":
            with zipfile.ZipFile(archive) as bundle:
                bundle.extractall(work)
        else:
            with tarfile.open(archive) as bundle:
                bundle.extractall(work, filter="data")
        app = work / f"GarbageHero-v{release}-{target}-x86_64"
        save = work / "save"
        log = work / "startup.log"
        env = {**os.environ, "GARBAGEHERO_SAVE_DIR": str(save),
               "GARBAGEHERO_SETTINGS_PATH": str(work / "settings.cfg")}
        run([app / executable, "--headless", "--fixed-fps", "60", "--quit-after", "120",
             "--log-file", log], cwd=app, env=env, timeout=120, log=log)
        for slot in save.glob("slot-*.sav"):
            content = slot.read_bytes()
            if content[:4] == b"GH01" and hashlib.sha256(content[36:]).digest() == content[4:36]:
                print(f"Packaged {target} game started and created a valid save.", flush=True)
                return
        raise RuntimeError("The packaged main scene did not create a valid save.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", choices=[*TARGETS, "all"], default=native_target() or "all")
    parser.add_argument("--godot", default=os.environ.get("GODOT_PATH", "godot"))
    parser.add_argument("--output", type=Path, default=ROOT / "dist")
    parser.add_argument("--test", action="store_true", help="run the source regression suite before export")
    parser.add_argument("--smoke", action="store_true", help="run the native package after extracting it")
    args = parser.parse_args()
    if args.smoke and args.target != native_target():
        parser.error("--smoke requires the single native --target")
    godot = shutil.which(args.godot)
    if not godot:
        parser.error("Godot was not found. Set GODOT_PATH or pass --godot.")
    godot = str(Path(godot).resolve())
    if run([godot, "--version"]) != ENGINE:
        parser.error(f"Expected Godot {ENGINE}")
    release = version()
    if os.environ.get("GITHUB_REF_TYPE") == "tag" and os.environ.get("GITHUB_REF_NAME") != "v" + release:
        parser.error("Release tag must match game/project.godot config/version")
    dist = args.output.resolve()
    dist.mkdir(parents=True, exist_ok=True)
    run([godot, "--headless", "--path", GAME, "--import"])
    if args.test:
        for test in QA:
            run([godot, "--headless", "--fixed-fps", "60", "--path", GAME, "--script", ROOT / test])
    for target in TARGETS if args.target == "all" else [args.target]:
        artifact = package(target, godot, dist, release)
        if args.smoke:
            smoke(artifact, target, release)


if __name__ == "__main__":
    main()
