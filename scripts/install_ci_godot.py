"""Install a verified, self-contained Godot editor for the native CI target."""

import hashlib
from pathlib import Path
import shutil
import sys
import tempfile
from urllib.request import urlopen
from zipfile import ZipFile


TAG = "4.7.2-stable"
BASE = f"https://github.com/godotengine/godot-builds/releases/download/{TAG}/Godot_v{TAG}_"
CHECKSUMS = {
    "linux.x86_64.zip": "cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4",
    "win64.exe.zip": "731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953",
    "export_templates.tpz": "f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011",
}
INSTALL = Path(__file__).resolve().parents[1] / ".tools/godot"


def download(name, folder):
    dest = folder / name
    digest = hashlib.sha256()
    with urlopen(BASE + name, timeout=120) as response, dest.open("wb") as output:
        while chunk := response.read(1024 * 1024):
            digest.update(chunk)
            output.write(chunk)
    if digest.hexdigest() != CHECKSUMS[name]:
        raise ValueError(f"Invalid SHA-256 for {name}")
    return dest


def unpack(bundle, member, dest):
    dest.parent.mkdir(parents=True, exist_ok=True)
    with bundle.open(member) as source, dest.open("wb") as output:
        shutil.copyfileobj(source, output)


def main():
    if sys.platform not in ("win32", "linux"):
        raise SystemExit("This bootstrap supports Windows and Linux x86_64 CI runners.")
    windows = sys.platform == "win32"
    editor_name = "win64.exe" if windows else "linux.x86_64"
    binary = INSTALL / ("godot.exe" if windows else "godot")
    templates = INSTALL / "editor_data/export_templates/4.7.2.stable"
    files = ["windows_release_x86_64.exe", "windows_release_x86_64_console.exe"] if windows else ["linux_release.x86_64"]
    with tempfile.TemporaryDirectory() as temp:
        with ZipFile(download(editor_name + ".zip", Path(temp))) as archive:
            unpack(archive, f"Godot_v{TAG}_{editor_name}", binary)
        binary.chmod(0o755)
        with ZipFile(download("export_templates.tpz", Path(temp))) as archive:
            for filename in [*files, "icudt_godot.dat"]:
                unpack(archive, "templates/" + filename, templates / filename)
    (INSTALL / "_sc_").touch()


if __name__ == "__main__":
    main()
