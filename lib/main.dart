import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.getInstance().then((prefs) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SnakeGamePage(),
    );
  }
}

enum Direction { up, down, left, right }

class SnakeGamePage extends StatefulWidget {
  const SnakeGamePage({super.key});

  @override
  _SnakeGamePageState createState() => _SnakeGamePageState();
}

class _SnakeGamePageState extends State<SnakeGamePage> {
  final int rows = 22;
  final int columns = 12;

  static const int speed = 200; // milliseconds
  double cellSize = 25; // yeh ab dynamic hoga

  List<Point<int>> snake = [const Point(5, 5)];
  Point<int> food = const Point(10, 10);
  Direction direction = Direction.right;
  Timer? timer;
  bool isGameOver = false;
  bool isPaused = true;

  int score = 0;
  int highScore = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await loadHighScore();
      setupCellSize();
    });
  }

  void setupCellSize() {
    final size = MediaQuery.of(context).size;

    // available game area
    double gameAreaHeight = size.height * 0.6;
    double gameAreaWidth = size.width;

    // calculate cell size so 12x24 fit
    double cellH = gameAreaHeight / rows;
    double cellW = gameAreaWidth / columns;

    setState(() {
      cellSize = min(cellH, cellW);
    });
  }

  Future<void> loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      highScore = prefs.getInt("highScore") ?? 0;
    });
  }

  Future<void> saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("highScore", highScore);
  }

  void startGame() {
    setState(() {
      snake = [Point(columns ~/ 2, rows ~/ 2)];
      food = getRandomFood();
      direction = Direction.right;
      isGameOver = false;
      score = 0;
      isPaused = false;
    });
    timer?.cancel();
    timer = Timer.periodic(
      const Duration(milliseconds: speed),
      (_) => updateGame(),
    );
  }

  void pauseGame() {
    timer?.cancel();
    setState(() => isPaused = true);
  }

  void resumeGame() {
    if (!isGameOver) {
      setState(() => isPaused = false);
      timer = Timer.periodic(
        const Duration(milliseconds: speed),
        (_) => updateGame(),
      );
    }
  }

  void endGame() {
    timer?.cancel();
    setState(() {
      isGameOver = true;
      isPaused = true;
    });

    if (score > highScore) {
      setState(() => highScore = score);
      saveHighScore();
    }
  }

  void updateGame() {
    setState(() {
      Point<int> newHead;

      switch (direction) {
        case Direction.up:
          newHead = Point(snake.first.x, snake.first.y - 1);
          break;
        case Direction.down:
          newHead = Point(snake.first.x, snake.first.y + 1);
          break;
        case Direction.left:
          newHead = Point(snake.first.x - 1, snake.first.y);
          break;
        case Direction.right:
          newHead = Point(snake.first.x + 1, snake.first.y);
          break;
      }

      // Collision
      if (newHead.x < 0 ||
          newHead.y < 0 ||
          newHead.x >= columns ||
          newHead.y >= rows ||
          snake.contains(newHead)) {
        endGame();
        return;
      }

      snake.insert(0, newHead);

      if (newHead == food) {
        food = getRandomFood();
        score++;
      } else {
        snake.removeLast();
      }
    });
  }

  Point<int> getRandomFood() {
    Random random = Random();
    Point<int> newFood;
    do {
      newFood = Point(random.nextInt(columns), random.nextInt(rows));
    } while (snake.contains(newFood));
    return newFood;
  }

  void changeDirection(Direction newDirection) {
    if ((direction == Direction.up && newDirection == Direction.down) ||
        (direction == Direction.down && newDirection == Direction.up) ||
        (direction == Direction.left && newDirection == Direction.right) ||
        (direction == Direction.right && newDirection == Direction.left)) {
      return;
    }
    direction = newDirection;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Fixed heights
    double scoreboardHeight = size.height * 0.1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Scoreboard
          Container(
            height: scoreboardHeight,
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade900,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(
                  "Score: $score",
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                Text(
                  "High Score: $highScore",
                  style: const TextStyle(color: Colors.yellow, fontSize: 18),
                ),
              ],
            ),
          ),

          // Game area
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red, width: 2),
              // borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              // margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
              height: cellSize * rows,
              width: cellSize * columns,
              alignment: Alignment.center,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  if (details.delta.dy < 0) changeDirection(Direction.up);
                  if (details.delta.dy > 0) changeDirection(Direction.down);
                },
                onHorizontalDragUpdate: (details) {
                  if (details.delta.dx < 0) changeDirection(Direction.left);
                  if (details.delta.dx > 0) changeDirection(Direction.right);
                },
                child: GridView.builder(
                  padding: const EdgeInsets.all(0),
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,

                    // childAspectRatio: 1,
                  ),
                  itemCount: rows * columns,
                  itemBuilder: (context, index) {
                    int x = index % columns;
                    int y = index ~/ columns;
                    Point<int> point = Point(x, y);

                    Color color;
                    if (snake.contains(point)) {
                      color = Colors.green;
                    } else if (point == food) {
                      color = Colors.red;
                    } else {
                      color = Colors.grey.shade900;
                    }

                    return Container(
                      margin: const EdgeInsets.all(0.5),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Divider + Controls (fixed at bottom)

          // Divider + Controls (fixed at bottom)
          SizedBox(height: 20),
          if (isGameOver)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                children: [
                  Text(
                    "Game Over!",
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Your Score: $score",
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),

          // Controls
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: startGame,
                  child: const Text("Restart"),
                ),
                ElevatedButton(
                  onPressed: isPaused ? resumeGame : pauseGame,
                  child: Text(isPaused ? "Play" : "Pause"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
