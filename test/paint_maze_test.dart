import 'dart:math';

import 'package:maze_paint/maze_paint.dart';
import 'package:test/test.dart';

void main() {
  group('slide', () {
    test('paints every cell the ball passes through, excluding start', () {
      var grid = [
        ['S', '.', '.', '.']
      ];
      var result = slide(grid, Point(0, 0), Point(0, 1));
      expect(result.position, Point(0, 3));
      expect(result.painted, {Point(0, 1), Point(0, 2), Point(0, 3)});
    });

    test('stops at a wall and does not paint the wall cell', () {
      var grid = [
        ['S', '.', '#', '.']
      ];
      var result = slide(grid, Point(0, 0), Point(0, 1));
      expect(result.position, Point(0, 1));
      expect(result.painted, {Point(0, 1)});
    });

    test('returns the starting position when the ball cannot move', () {
      var grid = [
        ['S', '#']
      ];
      var result = slide(grid, Point(0, 0), Point(0, 1));
      expect(result.position, Point(0, 0));
      expect(result.painted, isEmpty);
    });
  });

  group('solveMaze', () {
    test('returns 0 when start is the only paintable cell', () {
      expect(
          solveMaze([
            ['S']
          ], 0, 0),
          0);
    });

    test('one swipe paints a full row', () {
      expect(
          solveMaze([
            ['S', '.', '.', '.']
          ], 0, 0),
          1);
    });

    test('one swipe paints a full column', () {
      expect(
          solveMaze([
            ['S'],
            ['.'],
            ['.']
          ], 0, 0),
          1);
    });

    test('2x2 grid requires three swipes', () {
      expect(
          solveMaze([
            ['S', '.'],
            ['.', '.']
          ], 0, 0),
          3);
    });

    test('returns -1 when a cell is unreachable behind a wall', () {
      // Ball slides right, hits the wall at (0,2); (0,3) cannot be reached.
      expect(
          solveMaze([
            ['S', '.', '#', '.']
          ], 0, 0),
          -1);
    });

    test('S marker in the grid is treated like a start cell', () {
      // solveMaze should accept either '.' or 'S' at the start position.
      expect(
          solveMaze([
            ['S', '.', '.']
          ], 0, 0),
          1);
    });

    test('walls deflect the ball into a longer path', () {
      // 3x3 with a wall blocking the direct down-slide from start.
      // S . .
      // . # .
      // . . .
      var grid = [
        ['S', '.', '.'],
        ['.', '#', '.'],
        ['.', '.', '.'],
      ];
      // Sanity: the maze is solvable (positive swipe count).
      expect(solveMaze(grid, 0, 0), greaterThan(0));
    });
  });

  group('generateMaze', () {
    test('produces a grid of the requested size', () {
      var result = generateMaze(5, 3);
      expect(result.grid.length, 5);
      expect(result.grid.every((row) => row.length == 5), isTrue);
    });

    test('places exactly the requested number of walls', () {
      var result = generateMaze(5, 4);
      var walls =
          result.grid.expand((row) => row).where((c) => c == '#').length;
      expect(walls, 4);
    });

    test('marks exactly one S at the reported start position', () {
      var result = generateMaze(5, 3);
      expect(result.grid[result.start.x][result.start.y], 'S');

      var sCount =
          result.grid.expand((row) => row).where((c) => c == 'S').length;
      expect(sCount, 1);
    });

    test('reported moves count matches the solver', () {
      var result = generateMaze(5, 3);
      expect(result.moves, greaterThan(0));
      expect(
        solveMaze(result.grid, result.start.x, result.start.y),
        result.moves,
      );
    });
  });
}
