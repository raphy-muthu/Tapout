#!/usr/bin/env python3
"""Cut Tapout's static Fraunces fonts from the variable source and copy its license.

Fraunces is licensed under the SIL OFL 1.1 with no Reserved Font Name. The source is pinned to a
google/fonts commit and checked against its SHA-256, so re-running gives the same fonts. Needs fontTools; see the plan for the venv.
"""
import hashlib
import os
import pathlib
import shutil
import sys
import urllib.request

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

COMMIT = "4024282d9b0cffcdb8e3024560862746178d741f"
SOURCE_SHA256 = "177ff6c0f14e5550a3c624247cd1189611d4eb65d000b14944c63d967958abbb"
LICENSE_SHA256 = "bdf4c22802eaf804f998195871c6b8938aac2ac14b2d78a8bd66a6f1eced833b"
BASE = f"https://raw.githubusercontent.com/google/fonts/{COMMIT}/ofl/fraunces"
SOURCE_URL = f"{BASE}/Fraunces%5BSOFT%2CWONK%2Copsz%2Cwght%5D.ttf"
LICENSE_URL = f"{BASE}/OFL.txt"

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "Tapout" / "DesignSystem" / "Fonts"
CACHE = ROOT / "build" / "fonts"

# name: (weight class, axis locations)
FACES = {
    "Display": (300, {"opsz": 144, "wght": 300, "SOFT": 100, "WONK": 0}),
    "Number": (400, {"opsz": 36, "wght": 400, "SOFT": 100, "WONK": 0}),
    "Title": (600, {"opsz": 36, "wght": 600, "SOFT": 100, "WONK": 0}),
    # Heavier cuts for iOS's Bold Text setting; see FrauncesFace.resolved.
    "DisplayBold": (450, {"opsz": 144, "wght": 450, "SOFT": 100, "WONK": 0}),
    "NumberBold": (600, {"opsz": 36, "wght": 600, "SOFT": 100, "WONK": 0}),
    "TitleBold": (800, {"opsz": 36, "wght": 800, "SOFT": 100, "WONK": 0}),
}


def rename(font, face):
    family = f"Fraunces Tapout {face}"
    postscript = f"Fraunces-Tapout{face}"
    name = font["name"]
    # Drop typographic and variation names left over from the variable font.
    name.names = [record for record in name.names if record.nameID not in (1, 2, 3, 4, 6, 16, 17, 21, 22, 25)]
    for name_id, value in {1: family, 2: "Regular", 3: postscript, 4: family, 6: postscript}.items():
        name.setName(value, name_id, 3, 1, 0x409)
        name.setName(value, name_id, 1, 0, 0)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fetch(url, path, digest):
    # Reuse the cached file only if its hash matches the pin; otherwise download beside it and verify first.
    if path.exists() and sha256(path) == digest:
        return path
    tmp = path.with_name(path.name + ".part")
    urllib.request.urlretrieve(url, tmp)
    if sha256(tmp) != digest:
        tmp.unlink()
        sys.exit(f"gen-fonts: SHA-256 mismatch for {path.name}; expected {digest}")
    os.replace(tmp, path)
    return path


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    source = fetch(SOURCE_URL, CACHE / "Fraunces-variable.ttf", SOURCE_SHA256)
    license_file = fetch(LICENSE_URL, CACHE / "OFL.txt", LICENSE_SHA256)
    shutil.copyfile(license_file, OUTPUT / "OFL.txt")

    for face, (weight, axes) in FACES.items():
        # recalcTimestamp=False keeps head.modified from the pinned source, so output bytes are stable.
        font = instancer.instantiateVariableFont(TTFont(source, recalcTimestamp=False), axes)
        rename(font, face)
        font["OS/2"].usWeightClass = weight
        if "STAT" in font:
            del font["STAT"]
        path = OUTPUT / f"Fraunces-Tapout{face}.ttf"
        font.save(path)
        print(f"{path.name}: {path.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
