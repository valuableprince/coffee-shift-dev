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

See [Public migration notes](docs/PUBLIC_MIGRATION.md). The migration is based on private `coffee-shift` commit `9ec7659bb0b10486d1267d9b921788b760599cbd`. One optional concrete footstep OGG is excluded, with a safe runtime fallback. No externally licensed commercial soundtrack is included.

## Licensing

Copyright in the original Coffee Shift code and artwork is retained by their respective owners; public visibility **does not constitute an open-source license**. Third-party content keeps its own notices: Kenney CC0 footsteps under `assets/audio/footsteps/LICENSE.txt` and renamed DejaVu fonts under `assets/fonts/LICENSE.txt`. Do not remove these notices.
