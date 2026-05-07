import 'dart:math';
import 'dart:collection';

class SlideResult {
  final Point<int> position;
  final Set<Point<int>> painted;

  const SlideResult(this.position, this.painted);
}

class MazeResult {
  final List<List<String>> grid;
  final int moves;
  final Point<int> start;

  const MazeResult(this.grid, this.moves, this.start);
}

class _SearchState {
  final Point<int> position;
  final Set<Point<int>> unpainted;
  final int moves;

  const _SearchState(this.position, this.unpainted, this.moves);
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

/// Validates a maze and finds the shortest path to solve it.
/// Returns the minimum number of swipes, or -1 if unsolvable.
int solveMaze(List<List<String>> grid, int startX, int startY) {
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
  if (allEmpty.isEmpty) return 0;

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

  while (queue.isNotEmpty) {
    var state = queue.removeFirst();

    for (var dir in directions) {
      var result = slide(grid, state.position, dir);

      if (result.position != state.position) {
        Set<Point<int>> newUnpainted =
            state.unpainted.difference(result.painted);
        if (newUnpainted.isEmpty) return state.moves + 1;

        String key = stateKey(result.position, newUnpainted);
        if (visitedStates.add(key)) {
          queue.add(
              _SearchState(result.position, newUnpainted, state.moves + 1));
        }
      }
    }
  }
  return -1;
}

/// Generates a valid, solvable maze.
MazeResult generateMaze(int size, int numWalls) {
  var random = Random();

  while (true) {
    List<List<String>> grid =
        List.generate(size, (_) => List.filled(size, '.'));
    int wallsPlaced = 0;

    while (wallsPlaced < numWalls) {
      int x = random.nextInt(size);
      int y = random.nextInt(size);
      if (grid[x][y] == '.') {
        grid[x][y] = '#';
        wallsPlaced++;
      }
    }

    List<Point<int>> emptyCells = [];
    for (int x = 0; x < size; x++) {
      for (int y = 0; y < size; y++) {
        if (grid[x][y] == '.') {
          emptyCells.add(Point(x, y));
        }
      }
    }

    if (emptyCells.isEmpty) continue;

    Point<int> start = emptyCells[random.nextInt(emptyCells.length)];
    int moves = solveMaze(grid, start.x, start.y);

    if (moves > 0) {
      grid[start.x][start.y] = 'S';
      return MazeResult(grid, moves, start);
    }
  }
}
