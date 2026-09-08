import 'dart:async';
import 'dart:ui' hide TextStyle;

import 'package:dumb_and_dumber/components/placeholder.dart';
import 'package:dumb_and_dumber/dumb_and_dumber.dart';
import 'package:dumb_and_dumber/state/game_state.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors, TextStyle;
import 'package:flutter/services.dart';

enum PlayerState {
  idle,
  running,
  jumping,
  falling,
  hit,
  attacking,
  charging,
  guarding,
  rolling,
  carrying,
  dying,
  standStill,
}

/// SAKAMOTO. Loud, fast, allergic to reading instructions.
///
/// Movement numbers are the ones the design doc was written against: gravity
/// 900, jump force −420, move speed 200. Everything after that (guard, parry,
/// roll, the charged draw-cut, carrying, the blood price) is new.
class Player extends SpriteAnimationGroupComponent<PlayerState>
    with HasGameReference<DumbandDumber>, KeyboardHandler {
  Player({super.position, this.character = 'Samurai'})
    : super(size: Vector2.all(cell * spriteScale));

  final String character;

  /// 96px source cells at 4× — the Samurai set already in the repo.
  static const double cell = 96;
  static const double spriteScale = 4;

  // ── Physics ─────────────────────────────────────────────────
  static const double gravity = 900;
  static const double jumpForce = -420;
  static const double moveSpeed = 200;
  static const double rollSpeed = 340;
  static const double carrySlow = 0.8; // Carrying Yami is 20% slower.
  static const double terminalVelocity = 900;
  static const double stepTime = 0.05;

  /// The body inside the 384×384 cell. Everything — platforms, hits, triggers
  /// — is resolved against this, never the sprite bounds.
  ///
  /// Measured from the sheets rather than guessed: across IDLE, RUN, HURT and
  /// ATTACK the samurai occupies rows 47–81 and columns 34–57 of the 96px
  /// cell (ATTACK reaches column 92, but that is the sword, not the body).
  /// At 4× that is a 96×140 body sitting 188px down the cell — the cell is
  /// mostly padding, which is why a box drawn to the cell left him hovering.
  static const double hbOffsetX = 140;
  static const double hbOffsetY = 188;
  static const double hbWidth = 96;
  static const double hbHeight = 140;

  /// Distance from the sprite's top-left to the soles of his feet.
  static const double feetOffset = hbOffsetY + hbHeight;

  // ── Timings ─────────────────────────────────────────────────
  static const int attackFrames = 7; // 672px sheet / 96px cells
  static const double attackDuration = attackFrames * stepTime; // 0.35s
  static const double attackActiveStart = 2 * stepTime; // frames 3–4
  static const double attackActiveEnd = 4 * stepTime;
  static const double chargeThreshold = 0.45;
  static const double parryWindow = 0.1; // 6 frames
  static const double rollDuration = 0.4;
  static const double rollInvuln = 0.167; // 10 frames
  static const double hitInvuln = 0.8;
  static const double guardDrainPerSecond = 1.0;

  // ── Runtime ─────────────────────────────────────────────────
  final Vector2 velocity = Vector2.zero();
  bool onGround = false;
  bool facingRight = true;

  bool carrying = false;

  /// HV1's dead man's route: the player must hold no input at all. Any input
  /// while this is set trips [onInputWhileStill].
  bool mustStandStill = false;
  void Function()? onInputWhileStill;

  /// Set by cutscenes — reads input as if nothing were pressed.
  bool controlsLocked = false;

  bool dead = false;
  void Function()? onDeath;

  /// Fires when a swing's active window opens, with the reach rectangle.
  void Function(Rect reach, bool charged)? onSwing;
  void Function()? onParrySuccess;

  double _attackTimer = 0;
  bool _attackDidHit = false;
  bool _attackCharged = false;
  double _chargeHeld = -1; // ≥0 while the ATK button is down
  double _parryTimer = 0;
  double _rollTimer = 0;
  double _invulnTimer = 0;
  double _hurtTimer = 0;
  bool _guardHeld = false;

  // Keyboard latches
  bool _leftKey = false;
  bool _rightKey = false;
  bool _downKey = false;

  // ── Queries ─────────────────────────────────────────────────

  Rect get body => Rect.fromLTWH(
    position.x + hbOffsetX,
    position.y + hbOffsetY,
    hbWidth,
    hbHeight,
  );

  Vector2 get bodyCenter => Vector2(body.center.dx, body.center.dy);

  bool get isAttacking => _attackTimer > 0;
  bool get isRolling => _rollTimer > 0;
  bool get isGuarding => _guardHeld && !isAttacking && !isRolling && !dead;
  bool get isParrying => _parryTimer > 0;
  bool get invulnerable =>
      dead ||
      _invulnTimer > 0 ||
      (isRolling && _rollTimer > rollDuration - rollInvuln);
  bool get isCharging => _chargeHeld >= chargeThreshold;
  bool get busy => isAttacking || isRolling || _hurtTimer > 0;

  /// The swing's reach, in front of the body. Null unless the active window
  /// is open.
  Rect? get attackReach {
    if (!isAttacking) return null;
    final t = attackDuration - _attackTimer;
    if (t < attackActiveStart || t > attackActiveEnd) return null;
    // The sweep starts inside Sakamoto's own front half, not at his leading
    // edge: at this sprite scale a target can easily be standing on top of
    // him, and a swing that only covers the space in front would miss it.
    const reach = 160.0;
    final b = body;
    final width = b.width * 0.65 + reach;
    // Facing right the sweep runs [body.left + 35%, body.right + reach];
    // facing left it is the mirror of that.
    final left = facingRight ? b.left + b.width * 0.35 : b.left - reach;
    return Rect.fromLTWH(left, b.top + 16, width, b.height - 32);
  }

  // ── Lifecycle ───────────────────────────────────────────────

  @override
  FutureOr<void> onLoad() {
    _loadAnimations();
    current = PlayerState.idle;
    return super.onLoad();
  }

  /// PLACEHOLDER MAP — the repo has IDLE 10, RUN 16, ATTACK 7, HURT 4.
  /// JUMP, FALL, GUARD, ROLL, CARRY, DEATH and SHEATHE are still on the
  /// buy list (§11), so each one borrows the closest sheet we own. Swapping
  /// in real art means changing only the right-hand side of this map.
  void _loadAnimations() {
    final idle = _sheet('IDLE', 10);
    final run = _sheet('RUN', 16);
    final hurt = _sheet('HURT', 4)..loop = false;
    final attack = _sheet('ATTACK', attackFrames)..loop = false;

    animations = {
      PlayerState.idle: idle,
      PlayerState.running: run,
      PlayerState.jumping: run, // PLACEHOLDER — needs JUMP (3)
      PlayerState.falling: run, // PLACEHOLDER — needs FALL (3)
      PlayerState.hit: hurt,
      PlayerState.attacking: attack,
      PlayerState.charging: _sheet('IDLE', 10, step: 0.12), // PLACEHOLDER
      PlayerState.guarding: _sheet(
        'IDLE',
        2,
        step: 0.4,
      ), // PLACEHOLDER — GUARD (2)
      PlayerState.rolling: _sheet(
        'RUN',
        16,
        step: 0.025,
      ), // PLACEHOLDER — ROLL (5)
      PlayerState.carrying: _sheet(
        'IDLE',
        10,
        step: 0.09,
      ), // PLACEHOLDER — CARRY
      PlayerState.dying: _sheet('HURT', 4, step: 0.16)..loop = false,
      PlayerState.standStill: _sheet(
        'IDLE',
        1,
        step: 1,
      ), // PLACEHOLDER — SHEATHE
    };
  }

  SpriteAnimation _sheet(String state, int amount, {double? step}) {
    return SpriteAnimation.fromFrameData(
      game.images.fromCache('Characters/$character/$state.png'),
      SpriteAnimationData.sequenced(
        amount: amount,
        stepTime: step ?? stepTime,
        textureSize: Vector2.all(cell),
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────

  void jump() {
    if (_blocked) return;
    if (!onGround || isRolling || isAttacking) return;
    velocity.y = jumpForce;
    onGround = false;
  }

  /// ATK pressed. Held past [chargeThreshold] it becomes the draw-cut.
  void attackDown() {
    if (_blocked) return;
    _chargeHeld = 0;
  }

  /// ATK released — a tap swings immediately, a hold releases the charge.
  void attackUp() {
    if (_blocked) {
      _chargeHeld = -1;
      return;
    }
    final charged = _chargeHeld >= chargeThreshold;
    _chargeHeld = -1;
    _startSwing(charged: charged);
  }

  void _startSwing({required bool charged}) {
    if (carrying) return; // Hands full.
    if (isAttacking || isRolling || _hurtTimer > 0 || dead) return;
    _attackTimer = charged ? attackDuration * 1.6 : attackDuration;
    _attackCharged = charged;
    _attackDidHit = false;
    current = PlayerState.attacking;
    animationTicker?.reset();

    // §5 Blood price — Heaven only. Every swing costs a pip, and there are
    // no shrines to refill it.
    if (game.state.bloodPrice) {
      game.damagePlayerFromOwnSword();
    }
  }

  void guardDown() {
    if (_blocked || carrying) return;
    _guardHeld = true;
  }

  void guardUp() {
    if (!_guardHeld) return;
    _guardHeld = false;
    // Releasing into an incoming hit within 6 frames is a parry.
    _parryTimer = parryWindow;
  }

  void roll() {
    if (_blocked || carrying) return;
    if (!onGround || isRolling || isAttacking || _hurtTimer > 0) return;
    _rollTimer = rollDuration;
    current = PlayerState.rolling;
  }

  bool get _blocked =>
      dead || controlsLocked || game.dialogue.isActive || game.isGamePaused;

  /// Returns how the hit resolved so enemies can react (a parry staggers).
  ///
  /// [parryable] and [guardable] are how an attack says "the roll is the only
  /// answer" — the two-headed dog and the saint's spinning flurry both come
  /// through guard and parry untouched.
  HitResult takeHit(
    double amount, {
    double knockback = 0,
    bool parryable = true,
    bool guardable = true,
  }) {
    if (dead) return HitResult.ignored;
    if (invulnerable) return HitResult.ignored;

    if (parryable && isParrying) {
      _parryTimer = 0;
      onParrySuccess?.call();
      game.hud.toast.show('PARRY');
      return HitResult.parried;
    }

    if (guardable && isGuarding) {
      game.state.guard = (game.state.guard - 1).clamp(
        0.0,
        GameState.maxGuardPips.toDouble(),
      );
      game.hud.sync();
      if (game.state.guard <= 0) {
        // Guard broken — the hit lands anyway.
        _guardHeld = false;
      } else {
        return HitResult.blocked;
      }
    }

    _hurtTimer = 0.45;
    _invulnTimer = hitInvuln;
    current = PlayerState.hit;
    animationTicker?.reset();
    velocity.x = knockback * (facingRight ? -1 : 1);
    velocity.y = -160;
    onGround = false;

    game.state.health = (game.state.health - amount.round()).clamp(0, 99);
    game.hud.sync();
    if (game.state.health <= 0) _die();
    return HitResult.hurt;
  }

  void _die() {
    dead = true;
    current = PlayerState.dying;
    animationTicker?.reset();
    velocity.setZero();
    onDeath?.call();
  }

  void revive(Vector2 at) {
    dead = false;
    _hurtTimer = 0;
    _invulnTimer = 1.0;
    _attackTimer = 0;
    _rollTimer = 0;
    _guardHeld = false;
    velocity.setZero();
    position = at.clone();
    current = PlayerState.idle;
  }

  // ── Update ──────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    if (dead) {
      _applyGravity(dt);
      _integrate(dt);
      return;
    }

    _tickTimers(dt);
    _readInput(dt);
    _applyGravity(dt);
    _integrate(dt);
    _fireSwing();
    _updateAnimation();
  }

  void _tickTimers(double dt) {
    if (_attackTimer > 0) _attackTimer -= dt;
    if (_parryTimer > 0) _parryTimer -= dt;
    if (_rollTimer > 0) _rollTimer -= dt;
    if (_invulnTimer > 0) _invulnTimer -= dt;
    if (_hurtTimer > 0) _hurtTimer -= dt;
    if (_chargeHeld >= 0) _chargeHeld += dt;

    if (isGuarding) {
      game.state.guard = (game.state.guard - guardDrainPerSecond * dt).clamp(
        0.0,
        GameState.maxGuardPips.toDouble(),
      );
      if (game.state.guard <= 0) _guardHeld = false;
      game.hud.sync();
    } else if (game.state.guard < GameState.maxGuardPips) {
      game.state.guard = (game.state.guard + guardDrainPerSecond * 0.55 * dt)
          .clamp(0.0, GameState.maxGuardPips.toDouble());
      game.hud.sync();
    }
  }

  void _readInput(double dt) {
    if (isRolling) {
      velocity.x = rollSpeed * (facingRight ? 1 : -1);
      return;
    }
    if (_blocked || _hurtTimer > 0) {
      if (_hurtTimer <= 0) velocity.x = 0;
      return;
    }

    final stick = game.joystick.relativeDelta;
    var dx = 0.0;
    if (stick.x.abs() > 0.2) dx = stick.x;
    if (_leftKey) dx = -1;
    if (_rightKey) dx = 1;

    final wantsRoll = _downKey || stick.y > 0.75;

    if (mustStandStill) {
      if (dx != 0 || wantsRoll || isAttacking) onInputWhileStill?.call();
      velocity.x = 0;
      return;
    }

    if (wantsRoll && onGround && !isAttacking) {
      roll();
      return;
    }

    if (isAttacking) {
      // Non-interruptible: no steering mid-swing. Mashing loses.
      velocity.x = 0;
      return;
    }

    if (isGuarding) {
      velocity.x = 0;
      return;
    }

    final speed = moveSpeed * (carrying ? carrySlow : 1.0);
    velocity.x = dx * speed;
    if (dx != 0) _face(dx > 0);
  }

  /// Facing is a render-time mirror, never a transform change: Flame's
  /// flipHorizontallyAroundCenter shifts position.x by the sprite width for a
  /// top-left anchor, which would move the collision body every time
  /// Sakamoto turned around.
  void _face(bool right) => facingRight = right;

  /// A resting body sits exactly on the platform's top edge, where an
  /// overlap test reads false and ground contact flickers off every other
  /// frame. A small downward stick force keeps the two boxes intersecting.
  static const double groundStick = 40;

  void _applyGravity(double dt) {
    if (onGround && velocity.y >= 0) {
      velocity.y = groundStick;
      return;
    }
    velocity.y = (velocity.y + gravity * dt).clamp(
      -terminalVelocity,
      terminalVelocity,
    );
  }

  /// Axis-separated AABB resolution against the level's solid rectangles.
  void _integrate(double dt) {
    final level = game.level;
    if (level == null) {
      position += velocity * dt;
      return;
    }
    final solids = level.platforms;

    // X first.
    position.x += velocity.x * dt;
    var b = body;
    for (final solid in solids) {
      final r = solid.rect;
      if (!r.overlaps(b)) continue;
      // Ignore one-way platforms horizontally — they are floors, not walls.
      if (solid.oneWay) continue;
      if (velocity.x > 0) {
        position.x = r.left - hbWidth - hbOffsetX;
      } else if (velocity.x < 0) {
        position.x = r.right - hbOffsetX;
      }
      velocity.x = 0;
      b = body;
    }

    // Then Y.
    final previousBottom = b.bottom;
    position.y += velocity.y * dt;
    b = body;
    onGround = false;
    for (final solid in solids) {
      final r = solid.rect;
      if (!r.overlaps(b)) continue;
      if (velocity.y >= 0) {
        // One-way platforms only catch you from above.
        if (solid.oneWay && previousBottom > r.top + 8) continue;
        position.y = r.top - hbHeight - hbOffsetY;
        velocity.y = 0;
        onGround = true;
      } else if (!solid.oneWay) {
        position.y = r.bottom - hbOffsetY;
        velocity.y = 0;
      }
      b = body;
    }

    // Level bounds.
    position.x = position.x.clamp(
      -hbOffsetX,
      level.levelWidth - hbWidth - hbOffsetX,
    );
    if (b.top > level.levelHeight + 200) level.onPlayerFellOut();
  }

  void _fireSwing() {
    if (_attackDidHit) return;
    final reach = attackReach;
    if (reach == null) return;
    _attackDidHit = true;
    onSwing?.call(reach, _attackCharged);
  }

  void _updateAnimation() {
    if (_hurtTimer > 0) {
      current = PlayerState.hit;
      return;
    }
    if (isAttacking) {
      current = PlayerState.attacking;
      return;
    }
    if (isRolling) {
      current = PlayerState.rolling;
      return;
    }
    if (mustStandStill) {
      current = PlayerState.standStill;
      return;
    }
    if (isGuarding) {
      current = PlayerState.guarding;
      return;
    }
    if (isCharging) {
      current = PlayerState.charging;
      return;
    }
    if (!onGround) {
      current = velocity.y < 0 ? PlayerState.jumping : PlayerState.falling;
      return;
    }
    if (velocity.x.abs() > 10) {
      current = carrying ? PlayerState.carrying : PlayerState.running;
      return;
    }
    current = carrying ? PlayerState.carrying : PlayerState.idle;
  }

  // ── Keyboard (§5: keyboard as a supported second) ────────────

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _leftKey =
        keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA);
    _rightKey =
        keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD);
    _downKey =
        keysPressed.contains(LogicalKeyboardKey.arrowDown) ||
        keysPressed.contains(LogicalKeyboardKey.keyS);

    final holdingGuard =
        keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyX);
    if (holdingGuard && !_guardHeld) {
      guardDown();
    } else if (!holdingGuard && _guardHeld) {
      guardUp();
    }

    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.keyW ||
          key == LogicalKeyboardKey.space) {
        jump();
      }
      if (key == LogicalKeyboardKey.keyZ || key == LogicalKeyboardKey.enter) {
        attackDown();
      }
      if (key == LogicalKeyboardKey.keyC) {
        game.tryContract();
      }
    }
    if (event is KeyUpEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.keyZ || key == LogicalKeyboardKey.enter) {
        attackUp();
      }
    }
    return true;
  }

  // ── Render ──────────────────────────────────────────────────

  static final _tag = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.bold,
      letterSpacing: 1,
      fontFamily: 'monospace',
    ),
  );

  @override
  void render(Canvas canvas) {
    // Invulnerability flicker, drawn by skipping frames rather than tinting.
    final hidden =
        _invulnTimer > 0 && !dead && ((_invulnTimer * 20).floor() % 2 == 0);
    if (!hidden) {
      canvas.save();
      if (!facingRight) {
        canvas.translate(size.x, 0);
        canvas.scale(-1, 1);
      }
      super.render(canvas);
      canvas.restore();
    }

    // While the real GUARD/ROLL/CARRY sheets are missing, say so on screen so
    // playtesting is not guesswork.
    final label = switch (current) {
      PlayerState.guarding => 'GUARD',
      PlayerState.rolling => 'ROLL',
      PlayerState.carrying => 'CARRYING YAMI',
      PlayerState.charging => 'DRAW-CUT…',
      PlayerState.standStill => 'STILL',
      _ => null,
    };
    if (label != null) {
      final w = _tag.getLineMetrics(label).width + 14;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.x / 2 - w / 2, hbOffsetY - 22, w, 18),
          const Radius.circular(9),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.65),
      );
      _tag.render(
        canvas,
        label,
        Vector2(size.x / 2, hbOffsetY - 13),
        anchor: Anchor.center,
      );
    }

    // Guard face: a plate in front of the body until the real sheet lands.
    if (isGuarding) {
      final x = facingRight ? hbOffsetX + hbWidth - 12 : hbOffsetX - 22;
      PlaceholderArt.box(
        canvas
          ..save()
          ..translate(x, hbOffsetY + 18),
        Vector2(34, 104),
        color: const Color(0xFF5C8FD6),
        radius: 8,
      );
      canvas.restore();
    }
  }
}

enum HitResult { ignored, blocked, parried, hurt }
