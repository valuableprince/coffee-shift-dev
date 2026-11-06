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

1. **P0 addressed on 06.11.2026:** source-untraceable radio #09/#10 and possible underlying composition risk in previous radio #01 removed and replaced by directly authored CC0 selections with SHA-256 pinned. The remaining radio #02–07 Freesound entries still merit a final source/derivative audit.
2. Final MUSIC-25 audio master checks: target 44.1 kHz stereo / 160–192 kbps, measured loudness and peak, seamless loops; re-encoding source material requires listening review and does not improve inherent source quality.
3. Native Windows Godot playback, radio attenuation/interaction in the scene, Alt+Tab behavior, subjective genre balance, audible transition seams and audio levels.
4. Before shipping on VK Play, confirm that each license/attribution included in `docs/AUDIO01_LICENSES.md` is legally adequate and redistribute relevant notices.

**Integration status:** functional implementation candidate; passing CI alone does not close commercial-release blockers. Keep Draft PR pending acceptance and do not merge without instruction.

## Verified CI status — 2026-11-06

- [AUDIO-01 CI, PR run 42211536649](https://github.com/valuableprince/coffee-shift-dev/actions/runs/42211536649): **SUCCESS**. Python audio validation: 15/15; Godot 4.3 resource import successful; AUDIO-01 smoke **259 checks, 0 failures**; both real 3D scenes launched under Xvfb with GL Compatibility and no logged engine errors.
- [Public Godot CI, PR run 42211536654](https://github.com/valuableprince/coffee-shift-dev/actions/runs/42211536654): **SUCCESS**. Domain test **773 checks, 0 failures**; career transactions **231 checks, 0 failures**; prototype music smoke passes both streams.
- Initial CI failures on the earlier commit arose from running mesh-heavy 3D scenes with Godot's headless **dummy rendering backend** (`mesh_get_surface_count(m=null)`); the validation was corrected to Xvfb/GL, not suppressed.
- Native Windows audio/GPU and listening were not tested. The P0 replacement candidate is documented separately; MUSIC-25 mastering, full catalog provenance and Windows listening are still open.

## P0 license clearance record — 2026-11-06

- **01:** Replaced `radio_01_jazz.ogg` (Freesound #770969 openly describes a performance of `Blue in Green`, raising underlying composition-rights uncertainty) with `radio_01_jazz_improv.ogg`, author Alex McCulloch's *Jazz Improvisation (Looped)*, original author source [OpenGameArt](https://opengameart.org/content/jazz-improvisation-looped) CC0 and traceable derivative [Deadwood Reblooms asset library](https://github.com/MaplebirchLeaf/Deadwood-Reblooms/blob/29a343a208f5df6f504167fcf32d9ef13835457f/audio-pack/audio/assets.json). SHA-256 `e0125d6efee5cec8c5c10745ed884530e42c33bde36922ea880df3c1d22220dd`.
- **09:** Replaced `radio_09_ambient_space.ogg` with KiluaBoy's *Sunset Walk*, original author CC0 [OpenGameArt page](https://opengameart.org/content/sunset-walk-ambient-quiet-sweet-loop), SHA-256 `1d230721e6200276065b913e44943d0e0503af88fc2dd793be1249738e06d98c`.
- **10:** Replaced `radio_10_dreamy.ogg` with Kistol's original *Etirwer (Looped)*, CC0 [OpenGameArt page](https://opengameart.org/content/etirwer) and original-asset [evidence manifest](https://github.com/norinori1/audio-selector/blob/fc0d98e70c11d1f7afeba45e1a76def912e5176f/benchmark/manifest.json), SHA-256 `382c02bfb3d9abe1c9f432606dd95f27bcef28ac22097ccdcef12a8c608b421b`.
- Source bytes fetched in narrow, temporary GitHub Actions workflow and compared by SHA-256 before publication. Workflow removed from release candidate; byte-check and banned old names persist in `tools/ci/check_audio_assets.py`.
- **Remaining QA:** remaining #02–07 Freesound original metadata and derivatives, MUSIC-25 music mastering, real Windows listening and final redistribution/credit package are **not** claimed complete.
