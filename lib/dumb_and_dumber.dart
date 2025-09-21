import 'dart:math' as math;
import 'package:dumb_and_dumber/Levels/level.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';
import 'package:flame/components.dart';

class DumbandDumber extends FlameGame {
  final VoidCallback onShowMainMenu;
  final VoidCallback onPauseGame;
  final VoidCallback onResumeGame;
  String playerName;
  bool isGamePaused = false;
  late CameraComponent cam;

  late final JoystickComponent joystick;

  DumbandDumber({
    required this.onShowMainMenu,
    required this.onPauseGame,
    required this.onResumeGame,
    required this.playerName,
  });

  @override
  Future<void> onLoad() async {
    await images.loadAllImages();

    await _loadLevel();
    _loadButtons();
    _addJoystick();
  }

  void startLevel() {
    resumeEngine();
    isGamePaused = false;
  }

  void pauseGame() {
    pauseEngine();
    isGamePaused = true;
  }

  void resumeGame() {
    resumeEngine();
    isGamePaused = false;
  }

  @override
  Color backgroundColor() => Color(0xFF2C3E50); // Dark blue-gray background

  Future<void> _loadLevel() async {
    Level world = Level();
    cam = CameraComponent.withFixedResolution(
      world: world,
      width: 1080,
      height: 500,
    );
    cam.viewfinder.anchor = Anchor.topLeft;

    final bgSprite = await loadSprite('level-01.jpg');
    final Vector2 imageSize = bgSprite.srcSize;
    final Vector2 targetSize = Vector2(1080, 500);
    final double scale = math.max(
      targetSize.x / imageSize.x,
      targetSize.y / imageSize.y,
    );

    final SpriteComponent background = SpriteComponent(
      sprite: bgSprite,
      size: imageSize * scale,
      anchor: Anchor.center,
      position: targetSize / 2,
      priority: -10,
    );

    world.add(background);
    await addAll([cam, world]);
  }

  void _loadButtons() {
    final pauseButton = ButtonComponent(
      button: RectangleComponent(
        size: Vector2(100, 45),
        paint: Paint()..color = Colors.amber,
      ),
      buttonDown: RectangleComponent(
        size: Vector2(100, 45),
        paint: Paint()..color = Colors.amber.withOpacity(0.7),
      ),
      onPressed: () {
        pauseGame();
        onPauseGame();
      },
      position: Vector2(20, 20),
    );

    final pauseText = TextComponent(
      text: 'PAUSE',
      position: Vector2(35, 35),
      textRenderer: TextPaint(
        style: TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    // Exit Button
    final exitButton = ButtonComponent(
      button: RectangleComponent(
        size: Vector2(100, 45),
        paint: Paint()..color = Colors.redAccent,
      ),
      buttonDown: RectangleComponent(
        size: Vector2(100, 45),
        paint: Paint()..color = Colors.redAccent.withOpacity(0.7),
      ),
      onPressed: onShowMainMenu,
      position: Vector2(140, 20),
    );

    final exitText = TextComponent(
      text: 'EXIT',
      position: Vector2(165, 35),
      textRenderer: TextPaint(
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    // Add buttons to the game
    cam.viewport.addAll([pauseButton, pauseText, exitButton, exitText]);

    // Optional: Add player name display
    if (playerName.isNotEmpty) {
      final playerNameText = TextComponent(
        text: 'Player: $playerName',
        textRenderer: TextPaint(
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black),
            ],
          ),
        ),
      );

      final playerNameHud = HudMarginComponent(
        margin: const EdgeInsets.only(top: 80, left: 20),
      )..add(playerNameText);

      add(playerNameHud);
    }
  }

  void _addJoystick() {
    final knobPaint = BasicPalette.green.withAlpha(200).paint();
    final backgroundPaint = BasicPalette.green.withAlpha(100).paint();
    joystick = JoystickComponent(
      knob: CircleComponent(radius: 15, paint: knobPaint),
      background: CircleComponent(radius: 50, paint: backgroundPaint),
      margin: const EdgeInsets.only(left: 20, bottom: 20),
    );
    joystick.priority = 1000;
    cam.viewport.add(joystick);
  }
}
