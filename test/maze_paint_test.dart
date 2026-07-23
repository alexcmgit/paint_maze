import 'dart:math';

import 'package:minimal_puzzles/minimal_puzzles.dart';
import 'package:test/test.dart';

/// Replays [path] from [start] on [grid] and returns the cells painted.
Set<Point<int>> _replay(
  List<List<String>> grid,
  Point<int> start,
  List<Point<int>> path,
) {
  var pos = start;
  var painted = <Point<int>>{};
  for (final dir in path) {
    final r = slide(grid, pos, dir);
    pos = r.position;
    painted.addAll(r.painted);
  }
  return painted;
}

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
    test('returns an empty path when start is the only paintable cell', () {
      expect(
          solveMaze([
            ['S']
          ], 0, 0),
          isEmpty);
    });

    test('one swipe paints a full row', () {
      expect(
          solveMaze([
            ['S', '.', '.', '.']
          ], 0, 0),
          [Point(0, 1)]);
    });

    test('one swipe paints a full column', () {
      expect(
          solveMaze([
            ['S'],
            ['.'],
            ['.']
          ], 0, 0),
          [Point(1, 0)]);
    });

    test('2x2 grid requires three swipes', () {
      var path = solveMaze([
        ['S', '.'],
        ['.', '.']
      ], 0, 0);
      expect(path, hasLength(3));
    });

    test('returns null when a cell is unreachable behind a wall', () {
      // Ball slides right, hits the wall at (0,2); (0,3) cannot be reached.
      expect(
          solveMaze([
            ['S', '.', '#', '.']
          ], 0, 0),
          isNull);
    });

    test('S marker in the grid is treated like a start cell', () {
      expect(
          solveMaze([
            ['S', '.', '.']
          ], 0, 0),
          [Point(0, 1)]);
    });

    test('returned path replays into a valid solution', () {
      var grid = [
        ['S', '.', '.'],
        ['.', '#', '.'],
        ['.', '.', '.'],
      ];
      var path = solveMaze(grid, 0, 0)!;
      var painted = _replay(grid, Point(0, 0), path);

      // Every empty cell except the start should have been painted.
      for (var x = 0; x < grid.length; x++) {
        for (var y = 0; y < grid[0].length; y++) {
          if (grid[x][y] == '.') {
            expect(painted, contains(Point(x, y)),
                reason: 'cell ($x,$y) was not painted by the solution path');
          }
        }
      }
    });

    test('every direction in a returned path is a unit axis vector', () {
      var grid = [
        ['S', '.', '.'],
        ['.', '#', '.'],
        ['.', '.', '.'],
      ];
      var path = solveMaze(grid, 0, 0)!;
      var valid = {
        Point(-1, 0),
        Point(1, 0),
        Point(0, -1),
        Point(0, 1),
      };
      for (final dir in path) {
        expect(valid, contains(dir));
      }
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

    test('reported solution length matches the solver', () {
      var result = generateMaze(5, 3);
      expect(result.moves, greaterThan(0));
      expect(result.moves, result.solution.length);
      expect(
        solveMaze(result.grid, result.start.x, result.start.y)?.length,
        result.moves,
      );
    });

    test('the stored solution actually solves the generated maze', () {
      var result = generateMaze(5, 3);
      var painted = _replay(result.grid, result.start, result.solution);
      for (var x = 0; x < result.grid.length; x++) {
        for (var y = 0; y < result.grid[0].length; y++) {
          if (result.grid[x][y] == '.') {
            expect(painted, contains(Point(x, y)),
                reason: 'cell ($x,$y) not painted by stored solution');
          }
        }
      }
    });

    group('input validation (no infinite loops)', () {
      test('size < 2 throws ArgumentError', () {
        expect(() => generateMaze(1, 0), throwsA(isA<ArgumentError>()));
        expect(() => generateMaze(0, 0), throwsA(isA<ArgumentError>()));
      });

      test('negative numWalls throws ArgumentError', () {
        expect(() => generateMaze(5, -1), throwsA(isA<ArgumentError>()));
      });

      test('numWalls > size² - 2 throws ArgumentError', () {
        // 3×3 = 9 cells, max walls = 7. 8 and 9 must throw, not hang.
        expect(() => generateMaze(3, 8), throwsA(isA<ArgumentError>()));
        expect(() => generateMaze(3, 9), throwsA(isA<ArgumentError>()));
      });

      test('numWalls == size² - 2 is accepted (boundary)', () {
        // 3×3 with 7 walls leaves the start cell + one paintable cell.
        // Generation may exhaust attempts if the walls happen to block the
        // start, but it must NOT hang. Either result is fine here.
        try {
          generateMaze(3, 7, maxAttempts: 50);
        } on StateError {
          // Acceptable: tight params occasionally exhaust attempts.
        }
      });

      test('maxAttempts < 1 throws ArgumentError', () {
        expect(() => generateMaze(5, 3, maxAttempts: 0),
            throwsA(isA<ArgumentError>()));
      });

      test('throws StateError when no solvable layout fits within maxAttempts',
          () {
        // 3×3 with 7 walls + maxAttempts: 1 is very likely to fail.
        // We can't guarantee failure on a single attempt, but the boundary
        // test above covers the no-hang property; this exercises the
        // exhaustion code path. Run it a few times to bias toward hitting
        // exhaustion at least once.
        var sawStateError = false;
        for (var i = 0; i < 20 && !sawStateError; i++) {
          try {
            generateMaze(3, 7, maxAttempts: 1);
          } on StateError {
            sawStateError = true;
          }
        }
        expect(sawStateError, isTrue,
            reason: 'expected StateError at least once with tight params');
      });
    });
  });
}
