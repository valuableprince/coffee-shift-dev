# Coffee Shift — public development copy

Coffee Shift is a single-player first-person coffee-trailer simulator set in Russia in the early 2010s. Engine: Godot 4.3+ (GDScript). Platform: Windows. Art direction: PS2+ / Cozy Realism.

This repository is the **public development and CI copy** of Coffee Shift, not a complete commercial release. The full GDD, historical evidence, release assets, and unpublished AUDIO-01 work remain private.

## Run locally

1. Open `project.godot` in Godot 4.3 or newer.
2. Let Godot import all 3D assets and fonts.
3. Press F5 to launch `scenes/first_shift.tscn`; the garage prototype is `scenes/main.tscn`.
4. Use WASD, mouse, E (interact), Tab (orders), N (notebook), and Esc (pause).

## CI

`.github/workflows/godot-ci.yml` imports resources and runs fast headless regression tests against Godot 4.3 on pull requests and supported pushes. This does not replace native Windows playtesting.

## Provenance and limitations

See [Public migration notes](docs/PUBLIC_MIGRATION.md). The migration is based on private `coffee-shift` commit `9ec7659bb0b10486d1267d9b921788b760599cbd`. One optional concrete footstep OGG is excluded, with a safe runtime fallback. AUDIO-01 adds third-party CC0-claimed musical recordings with an explicit provenance register and unresolved source-evidence checks; see AUDIO01_LICENSES.md.

## Licensing

Copyright in the original Coffee Shift code and artwork is retained by their respective owners; public visibility **does not constitute an open-source license**. Third-party content keeps its own notices: Kenney CC0 footsteps under `assets/audio/footsteps/LICENSE.txt` and renamed DejaVu fonts under `assets/fonts/LICENSE.txt`. Do not remove these notices.

## AUDIO-01 (development candidate)

Spatial radio with ten actual OGG tracks (including CC0 Bossa Nova), menu/garage/end-of-shift themes, two original one-shot WAV cues, save-aware music events, focus mute, and 1.5-second crossfades. Interact with the radio using **E**. See [AUDIO-01 report](docs/AUDIO01_REPORT.md) and [music provenance](docs/AUDIO01_LICENSES.md). The three identified P0-risk radio tracks (#01, #09, #10) were replaced with traceable CC0 compositions and SHA-256 release guards; the remaining Freesound source chain, MUSIC-25 mastering and Windows listening still require acceptance before commercial release.

Run `bash tools/ci/audio01_local.sh` with Godot 4.3 or review the dedicated AUDIO-01 CI workflow for automated checks.

## DEV-05 — equipment inspection

Before each shift, aim at the coffee machine, grinder, fridge and register, then press **E — Осмотреть**. Each device has its own short first-person hand animation. Completed tasks fade and strike through in the text-only sidebar; the list folds away after all four checks. Open the serving window and use the shift switch to start service. Checks reset after successfully closing the shift.

Esc or F6 cancels an unfinished inspection; completed checks survive career saves and loads. Checked equipment retains its normal recipe, milk-access and cash-drawer actions. See the [DEV-05 report and real Godot screenshots](docs/dev05/REPORT.md).

Run `godot --headless --path . --script tests/dev05_inspection.gd -- --test-mode` after importing resources. Use GL Compatibility without `--headless` and add `--screenshots=/absolute/output/path` for real viewport evidence. Windows playtest remains part of PR acceptance.
