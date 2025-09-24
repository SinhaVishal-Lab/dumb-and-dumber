import 'dart:async';

import 'package:dumb_and_dumber/dumb_and_dumber.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

enum PlayerState { idle, running, jumping, falling, hit }

class Player extends SpriteAnimationGroupComponent
    with HasGameRef<DumbandDumber>, KeyboardHandler, CollisionCallbacks {
  String character;
  Player({position, this.character = 'Samurai'}) : super(position: position);

  final double stepTime = 0.05;
  late final SpriteAnimation idleAnimation;
  late final SpriteAnimation runningAnimation;
  late final SpriteAnimation jumpingAnimation;
  late final SpriteAnimation fallingAnimation;
  late final SpriteAnimation hitAnimation;
  late final SpriteAnimation appearingAnimation;
  late final SpriteAnimation disappearingAnimation;
  late final SpriteAnimation attackAnimation;

  Vector2 startingPosition = Vector2.zero();

  @override
  FutureOr<void> onLoad() {
    _loadAllAnimations();

    startingPosition = Vector2(position.x, position.y);

    return super.onLoad();
  }

  void _loadAllAnimations() {
    idleAnimation = _spriteAnimation('IDLE', 10);
    runningAnimation = _spriteAnimation('RUN', 16);
    jumpingAnimation = _spriteAnimation('RUN', 16);
    fallingAnimation = _spriteAnimation('RUN', 16);
    hitAnimation = _spriteAnimation('HURT', 4)..loop = false;

    // List of all animations
    animations = {
      PlayerState.idle: idleAnimation,
      PlayerState.running: runningAnimation,
      PlayerState.jumping: jumpingAnimation,
      PlayerState.falling: fallingAnimation,
      PlayerState.hit: hitAnimation,
    };

    // Set current animation
    current = PlayerState.idle;
  }

  SpriteAnimation _spriteAnimation(String state, int amount) {
    return SpriteAnimation.fromFrameData(
      game.images.fromCache('Characters/$character/$state.png'),
      SpriteAnimationData.sequenced(
        amount: amount,
        stepTime: stepTime,
        textureSize: Vector2.all(96),
      ),
    );
  }
}
