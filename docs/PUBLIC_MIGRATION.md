# Public repository bootstrap — 2026-11-06

- Private source: `valuableprince/coffee-shift`, main at `9ec7659bb0b10486d1267d9b921788b760599cbd`.
- Destination: `valuableprince/coffee-shift-dev`; initial branch `feat/public-bootstrap-20261106`.
- Scope: complete executable Godot core under `project.godot`, `assets/`, `data/`, `scenes/`, `scripts/`, `shaders/`, `tests/`, `tools/`, plus ignore/attributes rules.
- Not transferred: private GDD, project reports and screenshots, private workflow configurations, original repository history and any unpublished AUDIO-01 commits/files. CI is configured independently for this public development repository.
- Integrity: all transferred source files were compared using Git blob SHA; unmodified assets and scripts retained their SHA.
- Exception: `assets/audio/footsteps/footstep_concrete_004.ogg` could not be transferred through the connector; it remains in the private source. `scripts/trade/shift_audio.gd` checks existence before loading optional clips, and `assets/audio/footsteps/README.md` reflects nine published recordings. This does not substitute for a verified in-engine test.
- Third-party assets: Kenney Impact Sounds 1.0 CC0 footstep clips and renamed DejaVu fonts with retained license notices. Original game-specific GLB assets are described by source maintainers as authored for this project.
- Security: `docs/` audit records, large GDD, private workflows and any credentials are intentionally outside this public copy. High-confidence secret patterns were scanned across migrated text source files.
- Pending validation: GitHub Actions CI completion, Linux headless import/tests, native Windows checks, and a later optional restoration of the absent footstep file after approved transfer.
