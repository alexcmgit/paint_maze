import 'package:maze_paint/maze_paint.dart';

void main() {
  // Define difficulty settings (size, numWalls)
  final settings = {'size': 6, 'walls': 7}; // Medium difficulty

  print(
      'Generating a maze (Size: ${settings['size']}x${settings['size']}, Walls: ${settings['walls']})...');

  var result = generateMaze(settings['size']!, settings['walls']!);

  print('\n🎯 Minimum swipes required to solve: ${result.moves}');
  print('🏁 Start Coordinates: (${result.start.x}, ${result.start.y})\n');

  // Format the grid nicely for the console
  for (var row in result.grid) {
    print(row.join(' '));
  }
}
