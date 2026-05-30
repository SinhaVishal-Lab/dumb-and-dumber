import 'dart:async';

import 'package:dumb_and_dumber/dumb_and_dumber.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

enum PlayerState { idle, running, jumping, falling, hit, attacking }

class Player extends SpriteAnimationGroupComponent
    with HasGameReference<DumbandDumber>, KeyboardHandler, CollisionCallbacks {
  final String character;

  Player({super.position, this.character = 'Samurai'})
    : super(size: Vector2.all(384)); // 96 × 4 = 384

  static const double _gravity = 900.0;
  static const double _jumpForce = -420.0;
  static const double _moveSpeed = 200.0;
  static const double _stepTime = 0.05;

  // Must match Level.platformY (400). The hitbox sits at y+40 and is 320 tall,
  // so the feet are at position.y + 360.
  static const double _platformY = 400.0;
  static const double _hitboxBottom = 360.0; // hitbox offset(40) + height(320)

  // ATTACK: 672 px / 96 px = 7 frames
  static const int _attackFrames = 7;

  final Vector2 _velocity = Vector2.zero();
  bool _isOnGround = false;
  bool _facingRight = true;

  // Keyboard
  bool _leftPressed = false;
  bool _rightPressed = false;

  Vector2 startingPosition = Vector2.zero();

  // ── Lifecycle ────────────────────────────────────────────────
  @override
  FutureOr<void> onLoad() {
    _loadAllAnimations();
    startingPosition = Vector2(position.x, position.y);
    // Hitbox: 192×320 centered in the 384×384 sprite cell (4× scaled)
    add(RectangleHitbox(size: Vector2(192, 320), position: Vector2(96, 40)));
    return super.onLoad();
  }

  void _loadAllAnimations() {
    final idle = _anim('IDLE', 10);
    final run = _anim('RUN', 16);
    final hurt = _anim('HURT', 4)..loop = false;
    final attack = _anim('ATTACK', _attackFrames)..loop = false;

    // No separate JUMP/FALL sheets — reuse RUN for now
    animations = {
      PlayerState.idle: idle,
      PlayerState.running: run,
      PlayerState.jumping: run,
      PlayerState.falling: run,
      PlayerState.hit: hurt,
      PlayerState.attacking: attack,
    };
    current = PlayerState.idle;
  }

  SpriteAnimation _anim(String state, int amount) {
    return SpriteAnimation.fromFrameData(
      game.images.fromCache('Characters/$character/$state.png'),
      SpriteAnimationData.sequenced(
        amount: amount,
        stepTime: _stepTime,
        textureSize: Vector2.all(96),
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _applyGravity(dt);
    _readJoystick();
    _readKeyboard();
    position += _velocity * dt;
    _resolveGround();
    // Clamp to viewport bounds (1080 × 500 fixed resolution, player 384 wide)
    position.x = position.x.clamp(0.0, 1080.0 - 384.0);
    _updateAnimation();
  }

  void _applyGravity(double dt) {
    if (!_isOnGround) {
      _velocity.y = (_velocity.y + _gravity * dt).clamp(-1000.0, 800.0);
    }
  }

  /// Y-clamp ground resolution — works regardless of Flame's collision system.
  void _resolveGround() {
    final feetY = position.y + _hitboxBottom;
    if (feetY >= _platformY) {
      position.y = _platformY - _hitboxBottom; // snap feet to platform surface
      _velocity.y = 0;
      _isOnGround = true;
    } else {
      _isOnGround = false;
    }
  }

  void _readJoystick() {
    final dx = game.joystick.relativeDelta.x;
    if (dx.abs() > 0.1) {
      _velocity.x = dx * _moveSpeed;
      _setFacing(dx > 0);
    } else if (!_leftPressed && !_rightPressed) {
      _velocity.x = 0;
    }
  }

  void _readKeyboard() {
    if (_leftPressed) {
      _velocity.x = -_moveSpeed;
      _setFacing(false);
    } else if (_rightPressed) {
      _velocity.x = _moveSpeed;
      _setFacing(true);
    }
  }

  void _setFacing(bool right) {
    if (right == _facingRight) return;
    _facingRight = right;
    flipHorizontallyAroundCenter();
  }

  void jump() {
    if (_isOnGround) {
      _velocity.y = _jumpForce;
      _isOnGround = false;
    }
  }

  void attack() {
    current = PlayerState.attacking;
    animationTicker?.reset();
  }

  void _updateAnimation() {
    final s = current as PlayerState;
    // Don't interrupt non-looping animations until their last frame
    if (s == PlayerState.hit || s == PlayerState.attacking) {
      if (!(animationTicker?.isLastFrame ?? true)) return;
    }

    if (!_isOnGround) {
      current = _velocity.y < 0 ? PlayerState.jumping : PlayerState.falling;
    } else if (_velocity.x.abs() > 10) {
      current = PlayerState.running;
    } else {
      current = PlayerState.idle;
    }
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _leftPressed =
        keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA);
    _rightPressed =
        keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD);

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.keyW ||
          event.logicalKey == LogicalKeyboardKey.space) {
        jump();
      }
      if (event.logicalKey == LogicalKeyboardKey.keyZ ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        attack();
      }
    }
    return true;
  }

  // CollisionCallbacks kept for future use (enemies, pickups, etc.).
  // Ground is resolved by _resolveGround() Y-clamp instead.
}
