"""Compose disposable checkouts for graphical compatibility tests, never merge a PR.

Usage: python3 tools/compose_pr75_check.py BASE OURS PR75 OUTPUT
BASE and PR75 must be exact clean snapshots at the SHAs recorded in the report.
"""
import json
import pathlib
import shutil
import subprocess
import sys

base, ours, theirs, destination = (pathlib.Path(value).resolve() for value in sys.argv[1:])
if destination.exists():
    raise SystemExit("Output must be a new disposable directory")
shutil.copytree(ours, destination, ignore=shutil.ignore_patterns(".git", ".godot", "*.import"))
changed = []
conflicts = []
for scope in ("scripts", "scenes", "assets", "tests"):
    for incoming in sorted((theirs / scope).rglob("*")):
        if not incoming.is_file() or incoming.name.endswith(".import"):
            continue
        relative = incoming.relative_to(theirs)
        ancestor = base / relative
        if ancestor.is_file() and incoming.read_bytes() == ancestor.read_bytes():
            continue
        local = ours / relative
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if ancestor.is_file() and local.is_file() and local.read_bytes() != ancestor.read_bytes():
            result = subprocess.run(
                ["git", "merge-file", "-p", str(local), str(ancestor), str(incoming)],
                capture_output=True,
            )
            target.write_bytes(result.stdout)
            if result.returncode:
                conflicts.append(str(relative))
        else:
            shutil.copyfile(incoming, target)
        changed.append(str(relative))
report = {"base": "fe60848a90226ec604c46e90dda280de762abfc9",
          "pr75": "20897068e64f6c6710c56d81c102237f1a8f56da",
          "changed_in_disposable_checkout": changed, "conflicts": conflicts}
(destination / "compatibility-composition.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report))
if conflicts:
    raise SystemExit("Three-way composition has conflicts; graphical compatibility is unverified")
