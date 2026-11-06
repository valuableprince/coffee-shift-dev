#!/usr/bin/env bash
# AUDIO-01: reproduce the Godot 4.3 checks locally or on a GitHub runner.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ENGINE=godot
OUT="$ROOT/.godot/audio01-logs"
if [[ -v GODOT_BIN ]]; then ENGINE="$GODOT_BIN"; fi
if [[ -v AUDIO01_LOG_DIR ]]; then OUT="$AUDIO01_LOG_DIR"; fi
mkdir -p "$OUT"
if ! command -v "$ENGINE" >/dev/null 2>&1 && [[ ! -x "$ENGINE" ]]; then
  echo "Godot 4.3 executable is missing; set GODOT_BIN before running." >&2
  exit 127
fi
"$ENGINE" --version | tee "$OUT/version.log"
if ! grep -q '^4\.3\.' "$OUT/version.log"; then
  echo "Wrong engine version: expected Godot 4.3.x" >&2
  exit 1
fi
python3 tools/ci/check_audio_assets.py | tee "$OUT/assets.log"
export GODOT_SILENCE_ROOT_WARNING=1
"$ENGINE" --headless --path . --editor --import --quit 2>&1 | tee "$OUT/import.log"
"$ENGINE" --headless --audio-driver Dummy --path . --script tests/audio01_smoke.gd -- --test-mode 2>&1 | tee "$OUT/smoke.log"
for scene in scenes/first_shift.tscn scenes/main.tscn; do
  name="$(basename "$scene" .tscn)"
  "$ENGINE" --headless --audio-driver Dummy --path . --quit-after 12 "$scene" -- --test-mode 2>&1 | tee "$OUT/$name.log"
done
if grep -Ein 'SCRIPT ERROR|Parse Error|ERROR:|FAIL AUDIO-01:' "$OUT"/import.log "$OUT"/smoke.log "$OUT"/first_shift.log "$OUT"/main.log; then
  echo "Godot reported errors. See AUDIO01_LOG_DIR for evidence." >&2
  exit 1
fi
echo "PASS: AUDIO-01 source check, Godot import, smoke and scene startup"
