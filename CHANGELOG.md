# Changelog

## 2.0.0

- **Breaking**: `solveMaze` now returns `List<Point<int>>?` — the optimal
  sequence of swipe directions, or `null` if the maze is unsolvable. An empty
  list means the maze is already solved. Previously returned an `int` swipe
  count with `-1` for unsolvable.
- **Breaking**: `MazeResult` now exposes `solution` (the `List<Point<int>>`
  returned by `solveMaze`); `moves` is preserved as a getter that returns
  `solution.length`. The constructor now takes `solution` in place of the old
  `moves` int.
- Replay a solution by feeding each direction to `slide` starting from
  `Point(startX, startY)`.

## 1.1.0

- Expose `slide(grid, from, dir)` as a public function so downstream game
  engines can reuse the canonical slide simulation instead of reimplementing
  it. Returns a `SlideResult` with the resting position and the cells painted
  along the way.

## 1.0.0

- Initial version.
