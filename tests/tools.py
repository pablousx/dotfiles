#!/usr/bin/env python3
"""Check the portable, pinned tool contract without installing anything."""
from pathlib import Path
import re
import tomllib

root = Path(__file__).resolve().parents[1]
config = tomllib.loads((root / "tools/mise.toml").read_text())
lock = tomllib.loads((root / "tools/mise.lock").read_text())
expected = {"node", "python", "pnpm", "yarn", "rtk", "shellcheck", "rulesync", "pnpm-shell-completion",
            "gh", "aws", "gcloud"}
assert set(config["tools"]) == set(lock["tools"]) == expected
for name, request in config["tools"].items():
    version = request["version"] if isinstance(request, dict) else request
    assert re.fullmatch(r"\d+\.\d+\.\d+", version), name
    entry, = lock["tools"][name]
    assert entry["version"] == version, name
    assert entry["backend"] == config["tool_alias"][name], name
    for platform in ("linux-x64", "linux-arm64", "macos-x64", "macos-arm64"):
        artifact = entry[f"platforms.{platform}"]
        assert artifact["url"].startswith("https://"), (name, platform)
        assert re.fullmatch(r"sha256:[a-f0-9]{64}", artifact["checksum"]), (name, platform)
        if name == "rtk":
            assert "/rtk-oss-" in artifact["url"]
print(f"ok - all {len(expected)} tool pins have SHA-256 locks for all four platforms")
