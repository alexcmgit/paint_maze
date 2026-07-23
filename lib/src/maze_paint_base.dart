import 'dart:math';
import 'dart:collection';

class SlideResult {
  final Point<int> position;
  final Set<Point<int>> painted;

  const SlideResult(this.position, this.painted);
}

class MazeResult {
  final List<List<String>> grid;

  /// The optimal sequence of swipe directions that paints every empty cell.
  /// Each element is a unit vector along one axis: `Point(-1, 0)` for up,
  /// `Point(1, 0)` for down, `Point(0, -1)` for left, `Point(0, 1)` for right.
  final List<Point<int>> solution;

  final Point<int> start;

  const MazeResult(this.grid, this.solution, this.start);

  /// Number of swipes in [solution].
  int get moves => solution.length;
}

class _SearchState {
  final Point<int> position;
  final Set<Point<int>> unpainted;
  final int moves;
  final _SearchState? parent;
  final Point<int>? lastDir;

  const _SearchState(
    this.position,
    this.unpainted,
    this.moves, {
    this.parent,
    this.lastDir,
  });
}

/// Simulates the ball sliding from [from] in direction [dir] until it hits a
/// wall or the edge of [grid]. The resulting [SlideResult] reports the resting
/// position and the cells the ball passed through (which are now painted). The
/// starting cell is not included in `painted`.
///
/// [dir] should be a unit vector along one axis: `Point(-1, 0)` (up),
/// `Point(1, 0)` (down), `Point(0, -1)` (left), or `Point(0, 1)` (right).
SlideResult slide(List<List<String>> grid, Point<int> from, Point<int> dir) {
  int xMax = grid.length;
  int yMax = grid[0].length;
  Set<Point<int>> painted = {};
  Point<int> curr = from;

  while (true) {
    Point<int> next = curr + dir;
    if (next.x >= 0 &&
        next.x < xMax &&
        next.y >= 0 &&
        next.y < yMax &&
        grid[next.x][next.y] != '#') {
      curr = next;
      painted.add(curr);
    } else {
      break;
    }
  }
  return SlideResult(curr, painted);
}

/// Finds the shortest sequence of swipes that paints every empty cell.
///
/// Returns the list of swipe directions to play, in order. An empty list means
/// the maze is already solved (the start was the only paintable cell). Returns
/// `null` if the maze cannot be solved from the given start.
///
/// Each direction in the returned list is a unit vector along one axis:
/// `Point(-1, 0)` (up), `Point(1, 0)` (down), `Point(0, -1)` (left), or
/// `Point(0, 1)` (right). Replay them with [slide] starting from
/// `Point(startX, startY)` to recover the ball's trajectory.
List<Point<int>>? solveMaze(List<List<String>> grid, int startX, int startY) {
  int xMax = grid.length;
  int yMax = grid[0].length;
  Point<int> start = Point(startX, startY);
  Set<Point<int>> allEmpty = {};

  for (int x = 0; x < xMax; x++) {
    for (int y = 0; y < yMax; y++) {
      if (grid[x][y] == '.' || grid[x][y] == 'S') {
        allEmpty.add(Point(x, y));
      }
    }
  }

  allEmpty.remove(start);
  if (allEmpty.isEmpty) return const [];

  var queue = Queue<_SearchState>();
  queue.add(_SearchState(start, allEmpty, 0));

  // State is canonicalized as a string for use as a hash key.
  Set<String> visitedStates = {};

  String stateKey(Point<int> pos, Set<Point<int>> unpainted) {
    var sorted = unpainted.map((p) => '${p.x},${p.y}').toList()..sort();
    return '${pos.x},${pos.y}|${sorted.join('-')}';
  }

  visitedStates.add(stateKey(start, allEmpty));

  const directions = [
    Point(-1, 0),
    Point(1, 0),
    Point(0, -1),
    Point(0, 1),
  ];

  List<Point<int>> reconstructPath(_SearchState goal) {
    var path = <Point<int>>[];
    for (var s = goal; s.lastDir != null; s = s.parent!) {
      path.add(s.lastDir!);
    }
    return path.reversed.toList();
  }

  while (queue.isNotEmpty) {
    var state = queue.removeFirst();

    for (var dir in directions) {
      var result = slide(grid, state.position, dir);

      if (result.position != state.position) {
        Set<Point<int>> newUnpainted =
            state.unpainted.difference(result.painted);
        var next = _SearchState(
          result.position,
          newUnpainted,
          state.moves + 1,
          parent: state,
          lastDir: dir,
        );

        if (newUnpainted.isEmpty) return reconstructPath(next);

        String key = stateKey(result.position, newUnpainted);
        if (visitedStates.add(key)) {
          queue.add(next);
        }
      }
    }
  }
  return null;
}

/// Generates a valid, solvable maze.
///
/// Throws [ArgumentError] when:
///   - `size < 2` (need at least 2×2 for a non-trivial puzzle),
///   - `numWalls` is outside `[0, size² - 2]` (must leave at least the start
///     cell and one paintable cell), or
///   - `maxAttempts < 1`.
///
/// Throws [StateError] when no solvable layout is found within [maxAttempts]
/// blueprint attempts — typically a sign that `numWalls` is too high for the
/// given `size`.
MazeResult generateMaze(int size, int numWalls, {int maxAttempts = 1000}) {
  if (size < 2) {
    throw ArgumentError.value(size, 'size', 'must be >= 2');
  }
  final maxWalls = size * size - 2;
  if (numWalls < 0 || numWalls > maxWalls) {
    throw ArgumentError.value(
        numWalls, 'numWalls', 'must be in [0, $maxWalls] for a $size×$size grid');
  }
  if (maxAttempts < 1) {
    throw ArgumentError.value(maxAttempts, 'maxAttempts', 'must be >= 1');
  }

  var random = Random();

  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final grid = List.generate(size, (_) => List.filled(size, '.'));
    var wallsPlaced = 0;

    // Bounded: numWalls <= size² - 2, so we always have empty cells available.
    while (wallsPlaced < numWalls) {
      final x = random.nextInt(size);
      final y = random.nextInt(size);
      if (grid[x][y] == '.') {
        grid[x][y] = '#';
        wallsPlaced++;
      }
    }

    final emptyCells = <Point<int>>[];
    for (var x = 0; x < size; x++) {
      for (var y = 0; y < size; y++) {
        if (grid[x][y] == '.') {
          emptyCells.add(Point(x, y));
        }
      }
    }

    final start = emptyCells[random.nextInt(emptyCells.length)];
    final solution = solveMaze(grid, start.x, start.y);

    if (solution != null && solution.isNotEmpty) {
      grid[start.x][start.y] = 'S';
      return MazeResult(grid, solution, start);
    }
  }
  throw StateError(
    'Could not generate a solvable $size×$size maze with $numWalls walls in '
    '$maxAttempts attempts. Try fewer walls.',
  );
}
