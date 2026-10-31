# Changelog

## 0.1.0

- Initial release.
- `RubiksCubeState` — 3x3 cube model: 12 outer + 6 slice moves, scrambling,
  solved-state detection, deep copy, JSON (de)serialisation and per-sticker
  painting.
- `CubeController` + `Cube` — interactive 3D widget with orbit, tap-to-select,
  and finger-following drag-to-turn (snaps to the nearest quarter-turn), plus
  queued/animated moves and `playSequence`.
- `CubeColorValidator` — validates whether a colouring is a real, solvable cube.

## 0.1.1

- Fix bug in example for drag to move not working
- Map to public Github Repository
- Adding gif

## 0.1.2

- Fix the demo gif in the README.

## 0.2.0

- Renamed `RubiksCubeState` to `PuzzleCubeState`.
- Added pub.dev `topics` and dropped the `rubiks-cube` topic.
- Added `applyMoveInstant` to table

## 0.2.1

- Fix `isSolved` always returning false for a `PuzzleCubeState.fromJson`
  restored cube: stickers are now compared by ARGB value instead of `Color`
  equality (the solved reference uses `MaterialColor` constants, whose `==`
  is runtimeType-sensitive).
## 0.2.1+rubik-app (vendored fork)

- Replaced the flat DiTreDi viewport in `Cube` with `RealisticCubeRenderer`:
  per-face lighting (Lambert + Blinn-Phong), rounded glossy stickers, rounded
  plastic bodies with seams, and a soft contact shadow. Faces are drawn as
  anti-aliased paths, so the triangle seams of the old renderer are gone.
- The projection (perspective · scale(s, -s, -s) · view · slice) and the
  fit-to-viewport scale (`cubeViewScale`) are unchanged, so the tap and
  drag-to-turn hit tests behave exactly as before.
- Exported `RealisticCubeRenderer`, `CubieDraw`, `CubieFaceDraw`,
  `CubeRenderStyle` and `cubeViewScale` for reuse by other puzzles.
- `CubeController.moveDuration` is now mutable and is re-read before every
  animated turn, so the app's player can switch between 1×, 2× and 4×.
