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
# Real GL Compatibility rendering is required for 3D mesh resources.
# --headless selects Godot's dummy renderer and can emit thousands of
# mesh_get_surface_count(m=null) errors unrelated to AUDIO-01.
if command -v xvfb-run >/dev/null 2>&1; then
  DISPLAY_RUN=(xvfb-run -a)
elif [[ -n "${DISPLAY:-}" || "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* ]]; then
  DISPLAY_RUN=()
else
  echo "No display available: install xvfb/xauth, or run with a real display." >&2
  exit 127
fi
for scene in scenes/first_shift.tscn scenes/main.tscn; do
  name="$(basename "$scene" .tscn)"
  "${DISPLAY_RUN[@]}" "$ENGINE" --audio-driver Dummy --path . --rendering-method gl_compatibility --quit-after 90 "$scene" -- --test-mode 2>&1 | tee "$OUT/$name.log"
done
for test in radio01_integration new_assets_integration; do
  "${DISPLAY_RUN[@]}" "$ENGINE" --verbose --audio-driver Dummy --path . --rendering-method gl_compatibility --script "tests/$test.gd" -- --test-mode 2>&1 | tee "$OUT/$test.log"
done
if grep -Ein 'SCRIPT ERROR|Parse Error|ERROR:|FAIL AUDIO-01:|FAIL:' "$OUT"/import.log "$OUT"/smoke.log "$OUT"/first_shift.log "$OUT"/main.log "$OUT"/radio01_integration.log "$OUT"/new_assets_integration.log; then
  echo "Godot reported errors. See AUDIO01_LOG_DIR for evidence." >&2
  exit 1
fi
echo "PASS: AUDIO-01/RADIO-01 assets, import, playback state, saves and full coffee-equipment regression"
