import 'dart:math' as math;
import 'package:dumb_and_dumber/Levels/level.dart';
import 'package:dumb_and_dumber/characters/player.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';
import 'package:flame/components.dart';

class DumbandDumber extends FlameGame
    with HasCollisionDetection, HasKeyboardHandlerComponents {
  final VoidCallback onShowMainMenu;
  final VoidCallback onPauseGame;
  final VoidCallback onResumeGame;
  String playerName;
  bool isGamePaused = false;
  late CameraComponent cam;
  Player player = Player();

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
  Color backgroundColor() => Color(0xFF2C3E50);

  Future<void> _loadLevel() async {
    Level world = Level(levelName: 'level-01', player: player);
    cam = CameraComponent.withFixedResolution(
      world: world,
      width: 1080,
      height: 500,
    );
    cam.viewfinder.anchor = Anchor.topLeft;

    final bgSprite = await loadSprite('level-01.jpg');
    final Vector2 imageSize = bgSprite.srcSize;
    final Vector2 viewSize = Vector2(1080, 500);
    final double scale = math.max(
      viewSize.x / imageSize.x,
      viewSize.y / imageSize.y,
    );

    world.add(
      SpriteComponent(
        sprite: bgSprite,
        size: imageSize * scale,
        anchor: Anchor.center,
        position: viewSize / 2,
        priority: -10,
      ),
    );

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
        paint: Paint()..color = Colors.amber.withValues(alpha: 0.7),
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

    final exitButton = ButtonComponent(
      button: RectangleComponent(
        size: Vector2(100, 45),
        paint: Paint()..color = Colors.redAccent,
      ),
      buttonDown: RectangleComponent(
        size: Vector2(100, 45),
        paint: Paint()..color = Colors.redAccent.withValues(alpha: 0.7),
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

    final jumpBtn = ButtonComponent(
      button: CircleComponent(
        radius: 38,
        paint: Paint()..color = const Color(0x884FC3F7),
      ),
      buttonDown: CircleComponent(
        radius: 38,
        paint: Paint()..color = const Color(0xCC4FC3F7),
      ),
      onPressed: player.jump,
      position: Vector2(1000, 440),
      anchor: Anchor.center,
    );
    final jumpLabel = TextComponent(
      text: '↑',
      position: Vector2(1000, 440),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    final attackBtn = ButtonComponent(
      button: CircleComponent(
        radius: 32,
        paint: Paint()..color = const Color(0x88EF5350),
      ),
      buttonDown: CircleComponent(
        radius: 32,
        paint: Paint()..color = const Color(0xCCEF5350),
      ),
      onPressed: player.attack,
      position: Vector2(920, 455),
      anchor: Anchor.center,
    );
    final attackLabel = TextComponent(
      text: 'ATK',
      position: Vector2(920, 455),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    cam.viewport.addAll([
      pauseButton,
      pauseText,
      exitButton,
      exitText,
      jumpBtn,
      jumpLabel,
      attackBtn,
      attackLabel,
    ]);

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
    final knobPaint = BasicPalette.red.withAlpha(100).paint();
    final backgroundPaint = BasicPalette.darkGray.withAlpha(100).paint();
    joystick = JoystickComponent(
      knob: CircleComponent(radius: 20, paint: knobPaint),
      background: CircleComponent(radius: 60, paint: backgroundPaint),
      margin: const EdgeInsets.only(left: 40, bottom: 20),
    );
    joystick.priority = 1000;
    cam.viewport.add(joystick);
  }
}
