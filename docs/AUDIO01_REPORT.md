# Coffee Shift — AUDIO-01 integration report (public development, 2026-11-06)

## Source and scope

Source: private Coffee Shift draft PR #84 (branch `feat/audio01-music-integration`, head `40efa7fe4e0a7e863178a402c177114e7c587b41`). Destination: `valuableprince/coffee-shift-dev`, feature branch of the same name, based on public bootstrap `e0b0e3d470357a93220aa242c4e585dae5fc0d1a`.

Copied existing code and recordings — **not recreated** — to retain the original integration, including:
- `Audio01Director`: 3D radio, E toggle, ten-track shuffle without immediate repeat, mute without stopping playback, volume via shared Music/Radio buses;
- scene contexts: menu, garage, trade and end-of-day, 1.5-second background crossfade;
- first-shift and achievement WAV cues with career-save flags, legacy-save fallback, Alt+Tab mute;
- 10 radio OGGs, 3 background theme OGGs, 2 original WAV stings, asset validator, Godot smoke tests and CI.

Radio slot 08 was replaced by Cleyton Kauffman's **Buy Something! / Shop Theme** (CC0 Bossa Nova) from an identified re-encoded GitHub copy, instead of the source bundle's `radio_08_fields.ogg`, whose primary Freesound ID was missing. The re-encoded copy's source and SHA-256 are recorded in `docs/AUDIO01_LICENSES.md`.

## Integrity

Git blob SHA verification was performed for original imported audio. All imported source file blobs were reused without modification except for project-specific integrations. Retain this record alongside the separate original source repository; do not alter original WAV/OGG bytes without an explicit new artifact version.

## Automated verification

Dedicated workflow `.github/workflows/audio01-music.yml` performs structural checks on all 15 audio files, imports the project with official Godot 4.3, runs `tests/audio01_smoke.gd`, and starts both game scenes. The existing public `godot-ci.yml` also runs regression checks. The actual CI results must be taken from GitHub Actions after the branch is published; local container currently lacks Godot.

## Release blockers / remaining QA

1. Two radio tracks (`radio_09_ambient_space.ogg`, `radio_10_dreamy.ogg`) retain only a secondary CC0 assertion; find primary evidence or replace before commercial distribution.
2. Final MUSIC-25 audio master checks: target 44.1 kHz stereo / 160–192 kbps, measured loudness and peak, seamless loops; re-encoding source material requires listening review and does not improve inherent source quality.
3. Native Windows Godot playback, radio attenuation/interaction in the scene, Alt+Tab behavior, subjective genre balance, audible transition seams and audio levels.
4. Before shipping on VK Play, confirm that each license/attribution included in `docs/AUDIO01_LICENSES.md` is legally adequate and redistribute relevant notices.

**Integration status:** functional implementation candidate; passing CI alone does not close commercial-release blockers. Keep Draft PR pending acceptance and do not merge without instruction.
