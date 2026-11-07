# Coffee Shift — public development copy

Coffee Shift is a single-player first-person coffee-trailer simulator set in Russia in the early 2010s. Engine: Godot 4.3+ (GDScript). Platform: Windows. Art direction: PS2+ / Cozy Realism.

This repository is the **public development and CI copy** of Coffee Shift, not a complete commercial release. The full GDD, historical evidence, release assets, and unpublished AUDIO-01 work remain private.

## Run locally (Godot 4.3+)

**This is the source project, not a standalone Windows .exe.** The GitHub `main.zip` includes the original `.glb` models and `.ttf` fonts but deliberately does **not** include the generated `.godot/` import cache. You must import resources after every fresh ZIP extraction.

### Windows — recommended

1. Extract the **entire** ZIP to a writable local folder, such as `C:\\Games\\CoffeeShiftDev\\`. Do not run from the ZIP preview.
2. In Godot Project Manager select **Import**, browse to the extracted `project.godot`, and let the editor finish importing the models and fonts.
3. Press **F5** in the editor to run `scenes/first_shift.tscn`.
4. Use WASD, mouse, E (interact), Tab (orders), N (notebook), and Esc (pause).

Alternatively, drag your **Godot 4.3+ executable** onto `START_COFFEE_SHIFT_WINDOWS.bat`. The batch script imports the raw resources first and only then launches the game. For repeat double-click use, set a `GODOT_EXE` environment variable pointing to the executable or put Godot on `PATH`. No Godot executable is bundled with the project.

### Troubleshooting missing `.glb` / `.ttf` loader

Errors such as `No loader found for resource ...coffee_shift_radio_receiver.glb`, `paper_regular.ttf has no resource loaders`, or `shift_world.gd: Parse Error` on a freshly downloaded ZIP typically mean **the Godot import step was skipped**, not that the original model or font is absent.

Close running copies of Godot, then reopen `project.godot` in the editor and allow imports to finish. If the editor reports persistent import problems, close it, delete only the generated `.godot/` directory in the extracted project, and repeat the Project Manager import. Do **not** delete `assets/` or `project.godot`. Use Godot **4.3 or newer**, not Godot 3.x.

For command-line development, run these **in this order** from the extracted root:

```powershell
& "C:\\path\\to\\Godot_v4.3-stable_win64.exe" --headless --path . --editor --import --quit
& "C:\\path\\to\\Godot_v4.3-stable_win64.exe" --path .
```

Running `--script tests/...`, opening a `.tscn` directly, or running the project before the first editor import is **not** a valid clean-ZIP startup test. The garage prototype is `scenes/main.tscn`.

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

Esc or F6 cancels an unfinished inspection; completed checks survive career saves and loads. Checked equipment retains its normal recipe, milk-access and cash-drawer actions. See the [DEV-05 report](docs/dev05/REPORT.md).

Run `godot --headless --path . --script tests/dev05_inspection.gd -- --test-mode` after importing resources. Use GL Compatibility without `--headless` and add `--screenshots=/absolute/output/path` for real viewport evidence. Windows playtest remains part of PR acceptance.
