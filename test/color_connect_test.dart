import 'dart:math';

import 'package:minimal_puzzles/src/color_connect_base.dart';
import 'package:test/test.dart';

const _directions = [
  Point(-1, 0),
  Point(1, 0),
  Point(0, -1),
  Point(0, 1),
];

/// Collects positions in [level] grouped by color id, ignoring walls/empties.
Map<int, Set<Point<int>>> _cellsByColor(Level level) {
  final out = <int, Set<Point<int>>>{};
  for (var r = 0; r < level.rows; r++) {
    for (var c = 0; c < level.cols; c++) {
      final cell = level.grid[r][c];
      if (cell is PathCell) {
        out.putIfAbsent(cell.colorId, () => {}).add(Point(r, c));
      }
    }
  }
  return out;
}

/// Returns true when every position in [cells] is reachable from any one of
/// them via 4-connected steps that stay within [cells].
bool _isFourConnected(Set<Point<int>> cells) {
  if (cells.isEmpty) return true;
  final start = cells.first;
  final visited = <Point<int>>{start};
  final queue = <Point<int>>[start];
  while (queue.isNotEmpty) {
    final curr = queue.removeLast();
    for (final dir in _directions) {
      final n = curr + dir;
      if (cells.contains(n) && visited.add(n)) {
        queue.add(n);
      }
    }
  }
  return visited.length == cells.length;
}

void main() {
  group('Cell equality', () {
    test('empty constant equals a fresh EmptyCell', () {
      expect(empty == const EmptyCell(), isTrue);
      expect(empty.hashCode, const EmptyCell().hashCode);
    });

    test('wall constant equals a fresh WallCell', () {
      expect(wall == const WallCell(), isTrue);
      expect(wall.hashCode, const WallCell().hashCode);
    });

    test('empty and wall are distinct', () {
      expect(empty == wall, isFalse);
    });

    test('PathCell equality is keyed by colorId', () {
      expect(const PathCell(1) == const PathCell(1), isTrue);
      expect(const PathCell(1) == const PathCell(2), isFalse);
      expect(const PathCell(1).hashCode, const PathCell(1).hashCode);
    });

    test('PathCell is distinct from empty and wall', () {
      expect(const PathCell(0) == empty, isFalse);
      expect(const PathCell(0) == wall, isFalse);
    });
  });

  group('Cell pattern matching', () {
    String render(Cell cell) => switch (cell) {
          EmptyCell() => '.',
          WallCell() => '#',
          PathCell(:final colorId) => '$colorId',
        };

    test('switch over a sealed Cell is exhaustive', () {
      expect(render(empty), '.');
      expect(render(wall), '#');
      expect(render(const PathCell(0)), '0');
      expect(render(const PathCell(7)), '7');
    });
  });

  group('LevelEngine.generateLevel', () {
    test('returns a Level with the requested dimensions', () {
      final engine = LevelEngine(random: Random(1));
      final level = engine.generateLevel(
        rows: 6,
        cols: 5,
        numColors: 3,
        wallDensity: 0.0,
      );
      expect(level, isNotNull);
      expect(level!.rows, 6);
      expect(level.cols, 5);
      expect(level.grid.every((row) => row.length == 5), isTrue);
      expect(level.numColors, 3);
    });

    test('places no walls when wallDensity is 0', () {
      final engine = LevelEngine(random: Random(2));
      final level = engine.generateLevel(
        rows: 5,
        cols: 5,
        numColors: 2,
        wallDensity: 0.0,
      )!;
      final wallCount =
          level.grid.expand((row) => row).where((c) => c == wall).length;
      expect(wallCount, 0);
    });

    test('every color id from 0..numColors-1 appears at least once', () {
      final engine = LevelEngine(random: Random(3));
      final level = engine.generateLevel(
        rows: 6,
        cols: 6,
        numColors: 4,
        wallDensity: 0.05,
      )!;
      expect(_cellsByColor(level).keys.toSet(), {0, 1, 2, 3});
    });

    test('each color path is a single 4-connected region', () {
      final engine = LevelEngine(random: Random(4));
      final level = engine.generateLevel(
        rows: 6,
        cols: 6,
        numColors: 4,
        wallDensity: 0.05,
      )!;
      _cellsByColor(level).forEach((colorId, cells) {
        expect(_isFourConnected(cells), isTrue,
            reason: 'color $colorId is not connected');
      });
    });

    test('every non-wall cell is part of a color path (full coverage)', () {
      final engine = LevelEngine(random: Random(11));
      final level = engine.generateLevel(
        rows: 6,
        cols: 6,
        numColors: 4,
        wallDensity: 0.1,
      )!;
      for (final row in level.grid) {
        for (final cell in row) {
          expect(cell, isNot(equals(empty)),
              reason: 'a returned Level should never contain EmptyCells');
        }
      }
    });

    test('every color path has at least minPathLength cells', () {
      final engine = LevelEngine(random: Random(12));
      final level = engine.generateLevel(
        rows: 5,
        cols: 5,
        numColors: 3,
        wallDensity: 0.0,
        minPathLength: 4,
      )!;
      _cellsByColor(level).forEach((colorId, cells) {
        expect(cells.length, greaterThanOrEqualTo(4),
            reason: 'color $colorId has only ${cells.length} cells');
      });
    });

    test('minPathLength: 1 still works (most permissive setting)', () {
      final engine = LevelEngine(random: Random(13));
      final level = engine.generateLevel(
        rows: 5,
        cols: 5,
        numColors: 3,
        wallDensity: 0.0,
        minPathLength: 1,
      );
      expect(level, isNotNull);
    });

    test('returns null when minPathLength is unsatisfiable', () {
      // 3x3 = 9 cells, 4 colors, min 5 cells each → impossible (need >= 20).
      final engine = LevelEngine(random: Random(14));
      final level = engine.generateLevel(
        rows: 3,
        cols: 3,
        numColors: 4,
        wallDensity: 0.0,
        minPathLength: 5,
        maxAttempts: 3,
      );
      expect(level, isNull);
    });

    test('symmetric mode produces left/right mirrored walls', () {
      final engine = LevelEngine(random: Random(5));
      final level = engine.generateLevel(
        rows: 6,
        cols: 6,
        numColors: 2,
        wallDensity: 0.2,
        isSymmetric: true,
      )!;
      for (var r = 0; r < level.rows; r++) {
        for (var c = 0; c < level.cols; c++) {
          if (level.grid[r][c] == wall) {
            expect(level.grid[r][level.cols - 1 - c], wall,
                reason: 'wall at ($r,$c) has no mirror partner');
          }
        }
      }
    });

    test('seeded Random produces deterministic output', () {
      Level genWith(int seed) {
        final engine = LevelEngine(random: Random(seed));
        return engine.generateLevel(
          rows: 5,
          cols: 5,
          numColors: 3,
          wallDensity: 0.1,
        )!;
      }

      final a = genWith(7);
      final b = genWith(7);
      expect(a.rows, b.rows);
      expect(a.cols, b.cols);
      for (var r = 0; r < a.rows; r++) {
        for (var c = 0; c < a.cols; c++) {
          expect(a.grid[r][c], b.grid[r][c],
              reason: 'cell ($r,$c) differs between identically-seeded runs');
        }
      }
    });

    test('the grid contains only Cell instances of the sealed types', () {
      final engine = LevelEngine(random: Random(8));
      final level = engine.generateLevel(
        rows: 4,
        cols: 4,
        numColors: 2,
        wallDensity: 0.1,
      )!;
      for (final row in level.grid) {
        for (final cell in row) {
          expect(cell is EmptyCell || cell is WallCell || cell is PathCell,
              isTrue);
        }
      }
    });
  });

  group('LevelEngine configuration errors', () {
    final engine = LevelEngine();

    test('rows < 1 throws', () {
      expect(
        () => engine.generateLevel(rows: 0, cols: 5, numColors: 1),
        throwsA(isA<LevelConfigurationError>()),
      );
    });

    test('cols < 1 throws', () {
      expect(
        () => engine.generateLevel(rows: 5, cols: 0, numColors: 1),
        throwsA(isA<LevelConfigurationError>()),
      );
    });

    test('numColors < 1 throws', () {
      expect(
        () => engine.generateLevel(rows: 5, cols: 5, numColors: 0),
        throwsA(isA<LevelConfigurationError>()),
      );
    });

    test('wallDensity outside [0, 1) throws', () {
      expect(
        () => engine.generateLevel(
            rows: 5, cols: 5, numColors: 1, wallDensity: -0.1),
        throwsA(isA<LevelConfigurationError>()),
      );
      expect(
        () => engine.generateLevel(
            rows: 5, cols: 5, numColors: 1, wallDensity: 1.0),
        throwsA(isA<LevelConfigurationError>()),
      );
    });

    test('minPathLength < 1 throws', () {
      expect(
        () => engine.generateLevel(
            rows: 5, cols: 5, numColors: 1, minPathLength: 0),
        throwsA(isA<LevelConfigurationError>()),
      );
    });

    test('pathStopProbability outside [0, 1] throws', () {
      expect(
        () => engine.generateLevel(
            rows: 5, cols: 5, numColors: 1, pathStopProbability: -0.01),
        throwsA(isA<LevelConfigurationError>()),
      );
      expect(
        () => engine.generateLevel(
            rows: 5, cols: 5, numColors: 1, pathStopProbability: 1.01),
        throwsA(isA<LevelConfigurationError>()),
      );
    });
  });
}
