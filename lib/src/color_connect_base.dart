import 'dart:collection';
import 'dart:math';

/// A cell in a generated [Level]: [empty], [wall], or a [PathCell] tagged
/// with a color id in `0..numColors-1`.
sealed class Cell {
  const Cell();
}

/// An unfilled cell. Appears only during intermediate generation state; a
/// [Level] returned by [LevelEngine.generateLevel] never contains
/// [EmptyCell]s — every non-wall cell is part of a color path.
final class EmptyCell extends Cell {
  const EmptyCell();

  @override
  bool operator ==(Object other) => other is EmptyCell;
  @override
  int get hashCode => 0;
  @override
  String toString() => 'EmptyCell';
}

/// An impassable wall.
final class WallCell extends Cell {
  const WallCell();

  @override
  bool operator ==(Object other) => other is WallCell;
  @override
  int get hashCode => 1;
  @override
  String toString() => 'WallCell';
}

/// A cell belonging to color path [colorId] (range: `0..numColors-1`).
final class PathCell extends Cell {
  final int colorId;
  const PathCell(this.colorId);

  @override
  bool operator ==(Object other) =>
      other is PathCell && other.colorId == colorId;
  @override
  int get hashCode => Object.hash(PathCell, colorId);
  @override
  String toString() => 'PathCell($colorId)';
}

/// Canonical empty cell.
const Cell empty = EmptyCell();

/// Canonical wall cell.
const Cell wall = WallCell();

/// Thrown when [LevelEngine.generateLevel] receives invalid arguments.
class LevelConfigurationError extends ArgumentError {
  LevelConfigurationError(super.message);
}

/// A generated level: a grid of [Cell]s plus the number of distinct colors
/// placed during generation.
class Level {
  /// Indexed as `grid[row][col]`, i.e. `grid[point.x][point.y]`.
  final List<List<Cell>> grid;

  /// Number of distinct color ids placed (paths use ids `0..numColors-1`).
  final int numColors;

  const Level(this.grid, this.numColors);

  int get rows => grid.length;
  int get cols => grid[0].length;
}

const List<Point<int>> _directions = [
  Point(-1, 0), // up
  Point(1, 0), // down
  Point(0, -1), // left
  Point(0, 1), // right
];

/// Generates color-path puzzle levels.
///
/// Each level is an `rows × cols` grid of [Cell]s. Walls are scattered first,
/// then the empty region is partitioned into one connected path per color via
/// randomized backtracking. A returned [Level] always satisfies two
/// invariants:
///
/// - **Full coverage** — every non-wall cell belongs to exactly one
///   [PathCell] (no leftover [EmptyCell]s).
/// - **Minimum path length** — every color path contains at least
///   `minPathLength` cells.
///
/// Layouts that cannot satisfy both invariants are rejected and a new
/// blueprint is tried, up to `maxAttempts` times.
///
/// ## Usage
///
/// ```dart
/// import 'dart:math';
///
/// final engine = LevelEngine(random: Random(42)); // seed for determinism
/// final level = engine.generateLevel(
///   rows: 6,
///   cols: 6,
///   numColors: 4,
///   wallDensity: 0.1,
/// );
/// if (level == null) {
///   print('generation failed within maxAttempts');
///   return;
/// }
/// for (final row in level.grid) {
///   final line = row.map((cell) => switch (cell) {
///     WallCell() => '#',
///     EmptyCell() => '.',
///     PathCell(:final colorId) => '$colorId',
///   }).join(' ');
///   print(line);
/// }
/// ```
///
/// ## Algorithm
///
/// 1. **Blueprint** — scatter walls at the requested density (optionally
///    mirrored left/right for symmetry), then verify every empty cell is
///    reachable from every other. Retried until a connected layout is found
///    or an inner attempt cap is reached.
/// 2. **Path filling** — pick a random empty cell, depth-first-grow a path of
///    the current color into adjacent empties, then advance to the next
///    color. Each step has a configurable chance of stopping the current
///    path even if it could grow further. Dead ends backtrack.
///
/// ## Coordinates
///
/// Coordinates follow the `maze_paint` convention: `Point.x` is the row and
/// `Point.y` is the column, so a cell is `grid[point.x][point.y]`.
class LevelEngine {
  final Random _random;

  /// Pass a seeded [Random] for deterministic output.
  LevelEngine({Random? random}) : _random = random ?? Random();

  /// Generates a level.
  ///
  /// - [rows], [cols] — grid dimensions, both `>= 1`.
  /// - [numColors] — number of distinct paths to place, `>= 1`.
  /// - [wallDensity] — per-cell wall probability in `[0, 1)`.
  /// - [isSymmetric] — when true, walls are mirrored left/right.
  /// - [pathStopProbability] — per-step chance a growing path stops once it
  ///   has reached [minPathLength], in `[0, 1]`. Lower values produce longer
  ///   paths.
  /// - [minPathLength] — minimum number of cells per color path, `>= 1`.
  ///   Larger values produce harder puzzles by forbidding trivial paths.
  /// - [maxAttempts] — caps the number of full blueprint+fill attempts.
  ///
  /// Returns the generated [Level], or `null` if no valid level was found
  /// within [maxAttempts]. Throws [LevelConfigurationError] on invalid args.
  Level? generateLevel({
    required int rows,
    required int cols,
    required int numColors,
    double wallDensity = 0.1,
    bool isSymmetric = true,
    double pathStopProbability = 0.1,
    int minPathLength = 3,
    int maxAttempts = 20,
  }) {
    if (rows < 1 || cols < 1) {
      throw LevelConfigurationError('rows and cols must be >= 1');
    }
    if (numColors < 1) {
      throw LevelConfigurationError('numColors must be >= 1');
    }
    if (wallDensity < 0 || wallDensity >= 1) {
      throw LevelConfigurationError('wallDensity must be in [0, 1)');
    }
    if (pathStopProbability < 0 || pathStopProbability > 1) {
      throw LevelConfigurationError('pathStopProbability must be in [0, 1]');
    }
    if (minPathLength < 1) {
      throw LevelConfigurationError('minPathLength must be >= 1');
    }

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final blueprint =
          _generateBlueprint(rows, cols, wallDensity, isSymmetric);
      if (blueprint == null) continue;

      final grid = _fillPaths(
          blueprint, numColors, pathStopProbability, minPathLength);
      if (grid != null) return Level(grid, numColors);
    }
    return null;
  }

  // Blueprint generation ---------------------------------------------------

  List<List<Cell>>? _generateBlueprint(
      int rows, int cols, double density, bool symmetric) {
    const innerAttempts = 50;
    for (var i = 0; i < innerAttempts; i++) {
      final map = List.generate(rows, (_) => List<Cell>.filled(cols, empty));
      if (density > 0) {
        final halfCols = symmetric ? (cols / 2).ceil() : cols;
        for (var r = 0; r < rows; r++) {
          for (var c = 0; c < halfCols; c++) {
            if (_random.nextDouble() < density) {
              map[r][c] = wall;
              if (symmetric) map[r][cols - 1 - c] = wall;
            }
          }
        }
      }
      if (_isConnected(map)) return map;
    }
    return null;
  }

  bool _isConnected(List<List<Cell>> map) {
    final rows = map.length;
    final cols = map[0].length;
    Point<int>? start;
    var emptyCount = 0;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (map[r][c] == empty) {
          emptyCount++;
          start ??= Point(r, c);
        }
      }
    }
    if (start == null) return false;

    final visited = <Point<int>>{start};
    final queue = Queue<Point<int>>()..add(start);

    while (queue.isNotEmpty) {
      final curr = queue.removeFirst();
      for (final dir in _directions) {
        final n = curr + dir;
        if (n.x >= 0 &&
            n.x < rows &&
            n.y >= 0 &&
            n.y < cols &&
            map[n.x][n.y] == empty &&
            visited.add(n)) {
          queue.add(n);
        }
      }
    }
    return visited.length == emptyCount;
  }

  // Path filling -----------------------------------------------------------

  List<List<Cell>>? _fillPaths(List<List<Cell>> blueprint, int totalColors,
      double stopProb, int minLen) {
    final grid =
        List.generate(blueprint.length, (r) => List<Cell>.from(blueprint[r]));
    // Bound search work per blueprint. Some seeds drive the backtracker into
    // huge subtrees; capping forces a quick give-up so the outer loop can try
    // a fresh blueprint instead of hanging.
    final budget = _Budget(
        (grid.length * grid[0].length * 500).clamp(10000, 250000));
    return _placeNextColor(grid, 0, totalColors, stopProb, minLen, budget)
        ? grid
        : null;
  }

  bool _placeNextColor(List<List<Cell>> grid, int colorId, int totalColors,
      double stopProb, int minLen, _Budget budget) {
    // Full-coverage invariant: succeed only when every non-wall cell has
    // been assigned to a color path.
    if (colorId == totalColors) return !_hasAnyEmpty(grid);

    final start = _pickStartCell(grid);
    if (start == null) return false;

    return _grow(grid, start, colorId, totalColors, stopProb, minLen, 0, budget);
  }

  bool _grow(List<List<Cell>> grid, Point<int> curr, int colorId,
      int totalColors, double stopProb, int minLen, int lenBefore,
      _Budget budget) {
    if (budget.remaining <= 0) return false;
    budget.remaining--;

    grid[curr.x][curr.y] = PathCell(colorId);
    final lenNow = lenBefore + 1;

    final neighbors = _emptyNeighbors(grid, curr);
    final reachedMin = lenNow >= minLen;

    // Only consider ending this path if it has reached the minimum length.
    if (reachedMin) {
      final endHere = neighbors.isEmpty || _random.nextDouble() < stopProb;
      if (endHere &&
          _placeNextColor(
              grid, colorId + 1, totalColors, stopProb, minLen, budget)) {
        return true;
      }
    }

    // Stuck before reaching the minimum length — this branch is doomed.
    if (neighbors.isEmpty) {
      grid[curr.x][curr.y] = empty;
      return false;
    }

    // Warnsdorff-style heuristic: try low-degree neighbors first. This
    // greatly reduces fragmentation — we extend into tight corners before
    // they get stranded, instead of leaving them as orphan dead-ends.
    final ordered = _warnsdorffOrder(grid, neighbors);
    for (final next in ordered) {
      if (_grow(grid, next, colorId, totalColors, stopProb, minLen, lenNow,
          budget)) {
        return true;
      }
    }

    grid[curr.x][curr.y] = empty;
    return false;
  }

  List<Point<int>> _emptyNeighbors(List<List<Cell>> grid, Point<int> p) {
    final rows = grid.length;
    final cols = grid[0].length;
    final result = <Point<int>>[];
    for (final dir in _directions) {
      final n = p + dir;
      if (n.x >= 0 &&
          n.x < rows &&
          n.y >= 0 &&
          n.y < cols &&
          grid[n.x][n.y] == empty) {
        result.add(n);
      }
    }
    return result;
  }

  /// Counts how many of [p]'s four neighbors are currently [empty].
  int _emptyNeighborCount(List<List<Cell>> grid, Point<int> p) {
    final rows = grid.length;
    final cols = grid[0].length;
    var count = 0;
    for (final dir in _directions) {
      final n = p + dir;
      if (n.x >= 0 &&
          n.x < rows &&
          n.y >= 0 &&
          n.y < cols &&
          grid[n.x][n.y] == empty) {
        count++;
      }
    }
    return count;
  }

  /// Orders [neighbors] by ascending empty-neighbor count, with random
  /// tie-breaking. Used by [_grow] to grow into tight spots first.
  List<Point<int>> _warnsdorffOrder(
      List<List<Cell>> grid, List<Point<int>> neighbors) {
    if (neighbors.length <= 1) return neighbors;
    final ranked = neighbors
        .map((n) =>
            (_emptyNeighborCount(grid, n), _random.nextInt(1 << 30), n))
        .toList()
      ..sort((a, b) {
        final byDegree = a.$1.compareTo(b.$1);
        return byDegree != 0 ? byDegree : a.$2.compareTo(b.$2);
      });
    return [for (final r in ranked) r.$3];
  }

  /// True iff any cell is still [empty]. Fast scan that short-circuits.
  bool _hasAnyEmpty(List<List<Cell>> grid) {
    for (final row in grid) {
      for (final cell in row) {
        if (cell == empty) return true;
      }
    }
    return false;
  }

  /// Picks a random empty cell preferring those with the fewest empty
  /// neighbors (corners and bottlenecks first). Returns `null` if no empty
  /// cell exists.
  Point<int>? _pickStartCell(List<List<Cell>> grid) {
    var minDegree = 5; // larger than the max real degree of 4
    final candidates = <Point<int>>[];
    for (var r = 0; r < grid.length; r++) {
      for (var c = 0; c < grid[0].length; c++) {
        if (grid[r][c] == empty) {
          final p = Point(r, c);
          final degree = _emptyNeighborCount(grid, p);
          if (degree < minDegree) {
            minDegree = degree;
            candidates
              ..clear()
              ..add(p);
          } else if (degree == minDegree) {
            candidates.add(p);
          }
        }
      }
    }
    if (candidates.isEmpty) return null;
    return candidates[_random.nextInt(candidates.length)];
  }
}

/// Mutable counter threaded through the backtracker to bound search work.
/// When [remaining] hits zero the current fill attempt bails out, letting the
/// outer loop try a fresh blueprint instead of hanging on a pathological one.
class _Budget {
  int remaining;
  _Budget(this.remaining);
}
