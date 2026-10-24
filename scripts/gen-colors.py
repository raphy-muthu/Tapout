#!/usr/bin/env python3
"""Generate Colors.xcassets colour sets from design/design-system/tokens.json.

Run from anywhere: python3 scripts/gen-colors.py
Each token becomes one colour set named exactly like the token,
with Any = light value and Dark = dark value.
"""
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOKENS = ROOT / "design/design-system/tokens.json"
OUT = ROOT / "Tapout/DesignSystem/Colors.xcassets"
INFO = {"author": "xcode", "version": 1}


def components(hex_value):
    h = hex_value.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    a = int(h[6:8], 16) / 255 if len(h) == 8 else 1.0
    return {"red": f"{r:.3f}", "green": f"{g:.3f}", "blue": f"{b:.3f}", "alpha": f"{a:.3f}"}


def colour(hex_value):
    return {"color-space": "srgb", "components": components(hex_value)}


def main():
    tokens = json.loads(TOKENS.read_text(encoding="utf-8"))["color"]["tokens"]
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    (OUT / "Contents.json").write_text(json.dumps({"info": INFO}, indent=2) + "\n")
    for token in tokens:
        light, dark = token["value"]["light"], token["value"]["dark"]
        folder = OUT / f"{token['name']}.colorset"
        folder.mkdir()
        contents = {
            "colors": [
                {"idiom": "universal", "color": colour(light)},
                {
                    "idiom": "universal",
                    "appearances": [{"appearance": "luminosity", "value": "dark"}],
                    "color": colour(dark),
                },
            ],
            "info": INFO,
        }
        (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    print(f"Wrote {len(tokens)} colour sets to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
