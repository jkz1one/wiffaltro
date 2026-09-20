#!/usr/bin/env python3
"""Install pinned verification tools under ignored builds/tooling (Linux/macOS)."""
import hashlib
from pathlib import Path
import platform
import shutil
import subprocess
import urllib.request
import venv
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "builds" / "tooling"
VERSION = "4.7.2"
BASE = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable"


def main():
    system = platform.system()
    machine = platform.machine().lower()
    if system == "Darwin":
        package = f"Godot_v{VERSION}-stable_macos.universal.zip"
        binary = DEST / "Godot.app" / "Contents" / "MacOS" / "Godot"
    elif system == "Linux" and machine in ("x86_64", "amd64"):
        package = f"Godot_v{VERSION}-stable_linux.x86_64.zip"
        binary = DEST / package.removesuffix(".zip")
    else:
        raise SystemExit("Use an installed Godot 4.7.2 via GODOT_BIN on this platform.")
    DEST.mkdir(parents=True, exist_ok=True)
    archive = DEST / package
    sums = urllib.request.urlopen(f"{BASE}/SHA512-SUMS.txt", timeout=60).read().decode()
    expected = next(line.split()[0] for line in sums.splitlines()
                    if line.split()[-1].lstrip("*") == package)
    if not archive.exists() or hashlib.sha512(archive.read_bytes()).hexdigest() != expected:
        print(f"Downloading Godot {VERSION}...", flush=True)
        with urllib.request.urlopen(f"{BASE}/{package}", timeout=60) as response:
            with archive.open("wb") as output:
                shutil.copyfileobj(response, output)
    if hashlib.sha512(archive.read_bytes()).hexdigest() != expected:
        raise SystemExit("Godot download checksum mismatch; refusing to install.")
    with zipfile.ZipFile(archive) as bundle:
        bundle.extractall(DEST)
    binary.chmod(binary.stat().st_mode | 0o111)
    environment = DEST / "python"
    venv.EnvBuilder(with_pip=True).create(environment)
    subprocess.run([str(environment / "bin" / "python"), "-m", "pip", "install",
                    "gdtoolkit==4.3.4"], check=True)
    (DEST / "godot-path.txt").write_text(str(binary) + "\n")
    print("Ready. Run: python3 tools/verify.py")


if __name__ == "__main__":
    main()
