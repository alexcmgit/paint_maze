# maze_paint

A Dart library for generating and solving "paint maze" puzzles — a sliding-ball
grid game where the ball travels in straight lines until it hits a wall or the
edge of the board, painting every cell it passes through. The puzzle is solved
when every reachable cell has been painted.

## The puzzle

Given an `N x N` grid of empty cells (`.`), walls (`#`), and a start position
(`S`), the player issues swipes in one of four directions: up, down, left, or
right. On each swipe, the ball slides from its current position until it can no
longer advance, painting the cells it passes through. The goal is to paint
every empty cell using as few swipes as possible.

## Features

- `generateMaze(size, numWalls)` — generates a random, guaranteed-solvable maze
  of the given dimensions with the requested number of walls.
- `solveMaze(grid, startX, startY)` — runs a BFS over `(position, unpainted-set)`
  states and returns the minimum number of swipes needed, or `-1` if the maze
  is unsolvable.

## Getting started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  maze_paint: ^1.0.0
```

Then import it:

```dart
import 'package:maze_paint/maze_paint.dart';
```

## Usage

### Generating a maze

```dart
import 'package:maze_paint/maze_paint.dart';

void main() {
  final result = generateMaze(6, 7); // 6x6 grid, 7 walls

  print('Minimum swipes: ${result.moves}');
  print('Start: (${result.start.x}, ${result.start.y})');

  for (final row in result.grid) {
    print(row.join(' '));
  }
}
```

Sample output:

```text
Minimum swipes: 12
Start: (4, 1)

. # . . . #
. . . . . .
. . # # . #
. . . . . .
. S . # . .
. . . # . .
```

### Solving a hand-crafted maze

```dart
final grid = [
  ['S', '.', '.'],
  ['.', '#', '.'],
  ['.', '.', '.'],
];

final swipes = solveMaze(grid, 0, 0);
print(swipes); // minimum number of swipes, or -1 if unsolvable
```

## Grid format

Grids are `List<List<String>>` where each cell is a single character:

| Cell | Meaning                                                 |
| ---- | ------------------------------------------------------- |
| `.`  | Empty cell — needs to be painted.                       |
| `#`  | Wall — blocks the ball; never painted.                  |
| `S`  | Start position — counts as already painted.             |

`solveMaze` accepts grids that either mark the start cell with `S` or leave it
as `.`; the start coordinates are passed explicitly via `startX` / `startY`.

## Coordinates

The library uses `dart:math.Point<int>` for coordinates, with the convention:

- `point.x` → row index (the first index into the grid)
- `point.y` → column index (the second index into the grid)

So `grid[point.x][point.y]` reads the cell at `point`.

## API reference

### `MazeResult generateMaze(int size, int numWalls)`

Generates a `size × size` grid populated with `numWalls` randomly placed walls
and a randomly chosen start cell (marked with `S`). Loops internally until it
produces a solvable layout, so the returned maze is always valid.

Returns a `MazeResult` with:

- `grid` — the populated `List<List<String>>`.
- `moves` — the minimum number of swipes required to solve it (always `> 0`).
- `start` — the start position as a `Point<int>`.

### `int solveMaze(List<List<String>> grid, int startX, int startY)`

Runs a breadth-first search over the state space and returns the minimum number
of swipes required to paint every empty cell, or `-1` if the maze cannot be
solved from the given start.

### `SlideResult slide(List<List<String>> grid, Point<int> from, Point<int> dir)`

Simulates a single swipe. Slides from `from` in direction `dir` until the ball
hits a wall or the edge of the grid, and returns a `SlideResult` with the
resting position and the cells the ball passed through. The starting cell is
not included in `painted`.

`dir` should be a unit vector along one axis: `Point(-1, 0)` for up,
`Point(1, 0)` for down, `Point(0, -1)` for left, or `Point(0, 1)` for right.

### `class SlideResult`

Returned by `slide`. Contains:

- `position` — where the ball came to rest (`Point<int>`).
- `painted` — the set of cells the ball passed through (`Set<Point<int>>`).

## Running the example

```sh
dart run example/maze_paint_example.dart
```

## Running the tests

```sh
dart test
```
