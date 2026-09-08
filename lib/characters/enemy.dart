import 'dart:math' as math;
import 'dart:ui' hide TextStyle;

import 'package:dumb_and_dumber/characters/player.dart';
import 'package:dumb_and_dumber/components/placeholder.dart';
import 'package:dumb_and_dumber/dumb_and_dumber.dart';
import 'package:dumb_and_dumber/state/game_state.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart' show Colors, TextStyle;

/// How a creature moves and picks its moment.
enum Behaviour {
  /// Sits on a post until it sees you, then rings and hops. (Bell-toad)
  post,

  /// Walks the ground toward you and swings in range. (Clerk, warden, saint-lite)
  walker,

  /// Very slow, very long reach — reaches over cover. (Stilt-widow)
  strider,

  /// Fast, flanks, cannot be parried. (Two-headed dog, ash hound)
  hound,

  /// Drifts in the air and feeds on your light. (Mouth-moth)
  flyer,

  /// Rises from the soul river on a tell, grabs, sinks. (Agony hand)
  riser,
}

/// THE CREATURES — roadside things between Sakamoto and everywhere else.
/// Each one wants something. Every want is a contract.
class Creature extends PositionComponent with HasGameReference<DumbandDumber> {
  Creature({
    required super.position,
    required super.size,
    required this.creatureId,
    required this.displayName,
    required this.maxHealth,
    required this.color,
    required this.behaviour,
    this.speed = 60,
    this.damage = 1,
    this.reach = 90,
    this.windupTime = 0.9,
    this.recoverTime = 0.9,
    this.parryable = true,
    this.armoured = false,
    this.contractable = true,
    this.toll = 'something you will miss',
    this.patrolRange = 220,
    super.priority = 5,
  }) : health = maxHealth;

  // ── Identity ────────────────────────────────────────────────
  final String creatureId;
  final String displayName;
  final String toll;
  final double maxHealth;
  final Color color;
  final Behaviour behaviour;

  // ── Numbers ─────────────────────────────────────────────────
  final double speed;
  final double damage;
  final double reach;
  final double windupTime;
  final double recoverTime;
  final double patrolRange;

  /// The two-headed dog cannot be parried — it must be rolled.
  final bool parryable;

  /// Clerks' shields only the charged draw-cut opens.
  final bool armoured;

  final bool contractable;

  // ── State ───────────────────────────────────────────────────
  double health;
  bool contracted = false;
  bool dying = false;
  bool asleep = false;

  /// A contracted creature that turns up later on your side.
  bool ally = false;

  /// Suppresses the attack loop — used for set pieces where a creature is
  /// present but not fighting.
  bool passive = false;

  double _windup = 0;
  double _recover = 0;
  double _stagger = 0;
  double _flash = 0;
  double _phase = 0;
  late final double _homeX = position.x;
  bool _facingRight = false;
  bool _hasRung = false;

  /// Bell-toads ring when they see you, calling a second toad.
  void Function(Creature source)? onRing;
  void Function(Creature victim)? onDeath;
  void Function(Creature partner)? onContracted;

  static final _label = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
    ),
  );
  static final _offer = TextPaint(
    style: const TextStyle(
      color: Color(0xFF1B1A17),
      fontSize: 11,
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
    ),
  );

  Rect get body => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  /// §5 Contracts: bring a creature under 30% health and it flashes and stops
  /// attacking. Offer instead of finishing.
  bool get offering =>
      contractable && !contracted && !dying && health <= maxHealth * 0.3;

  bool get active => !dying && !contracted && !asleep && !ally;

  // ── Combat ──────────────────────────────────────────────────

  void takeHit(double amount, {bool charged = false}) {
    if (dying || contracted || ally) return;
    if (armoured && !charged) {
      _flash = 0.2;
      game.hud.toast.show('SHIELD HOLDS — HOLD ATK', seconds: 0.9);
      return;
    }
    health = (health - amount).clamp(0, maxHealth);
    _flash = 0.25;
    _windup = 0;
    _stagger = 0.25;
    if (health <= 0) kill();
  }

  void kill() {
    if (dying) return;
    dying = true;
    game.state.recordKill();
    onDeath?.call(this);
    add(RemoveEffect(delay: 0.45));
  }

  /// The contract: pay its toll, get passage plus one small boon, and it stays
  /// alive on the map.
  void acceptContract() {
    if (contracted) return;
    contracted = true;
    passive = true;
    game.state.recordContract(creatureId);
    onContracted?.call(this);
  }

  void stagger([double seconds = 0.9]) => _stagger = seconds;

  // ── Update ──────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    _phase += dt;
    if (_flash > 0) _flash -= dt;
    if (_stagger > 0) _stagger -= dt;
    if (dying) return;

    final player = game.level?.player;
    if (player == null || player.dead) return;

    if (contracted || ally || passive || asleep || offering) {
      _idleDrift(dt);
      return;
    }
    if (game.dialogue.isActive) return;
    if (_stagger > 0) return;

    _think(dt, player);
  }

  void _idleDrift(double dt) {
    if (behaviour == Behaviour.flyer) {
      position.y += math.sin(_phase * 2.2) * 12 * dt;
    }
  }

  void _think(double dt, Player player) {
    final target = Vector2(player.body.center.dx, player.body.center.dy);
    final me = Vector2(body.center.dx, body.center.dy);
    final toPlayer = target.x - me.x;
    final distance = (target - me).length;
    _facingRight = toPlayer > 0;

    // Mid-swing: the tell runs, then the hit lands.
    if (_windup > 0) {
      _windup -= dt;
      if (_windup <= 0) _strike(player);
      return;
    }
    if (_recover > 0) {
      _recover -= dt;
      return;
    }

    switch (behaviour) {
      case Behaviour.post:
        if (distance < 420) {
          if (!_hasRung) {
            _hasRung = true;
            onRing?.call(this);
            game.hud.toast.show(
              '${displayName.toUpperCase()} RINGS',
              seconds: 1.0,
            );
          }
          _walkToward(toPlayer, dt, speed);
        }
      case Behaviour.walker:
      case Behaviour.hound:
        _walkToward(toPlayer, dt, speed);
      case Behaviour.strider:
        // Long legs that reach over cover: closes slowly, hits from far away.
        _walkToward(toPlayer, dt, speed);
      case Behaviour.flyer:
        position.x += toPlayer.sign * speed * dt;
        position.y += (target.y - 120 - position.y).sign * speed * 0.6 * dt;
      case Behaviour.riser:
        // Stays put; the tell is the whole threat.
        position.x = _homeX;
    }

    if (distance < reach) _windup = windupTime;
  }

  void _walkToward(double toPlayer, double dt, double rate) {
    if (toPlayer.abs() < reach * 0.6) return;
    final next = position.x + toPlayer.sign * rate * dt;
    // Wanderers stay near their post so a screen never empties itself.
    if ((next - _homeX).abs() > patrolRange) return;
    position.x = next;
  }

  void _strike(Player player) {
    _recover = recoverTime;
    final hitBox = _facingRight
        ? Rect.fromLTWH(body.right, body.top, reach, body.height)
        : Rect.fromLTWH(body.left - reach, body.top, reach, body.height);
    if (!hitBox.overlaps(player.body)) return;

    final result = player.takeHit(damage, knockback: 120);
    if (result == HitResult.parried) {
      if (parryable) {
        stagger(1.2);
        game.hud.toast.show('STAGGERED');
      } else {
        // Cannot be parried — it goes through and hurts anyway.
        game.hud.toast.show('TOO FAST TO PARRY');
      }
    }
  }

  // ── Render ──────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final telegraphing = _windup > 0;
    var body = color;
    if (_flash > 0) body = Color.lerp(color, Colors.white, 0.7)!;
    if (telegraphing) body = Color.lerp(color, const Color(0xFFFFC246), 0.55)!;
    if (contracted || ally) body = Color.lerp(color, Colors.white, 0.35)!;
    if (dying) body = Color.lerp(color, Colors.black, 0.5)!;

    PlaceholderArt.box(
      canvas,
      size,
      color: body,
      label: displayName,
      lightText: true,
    );

    // Facing pip, so a flank reads before it lands.
    canvas.drawCircle(
      Offset(_facingRight ? size.x - 12 : 12, 14),
      5,
      Paint()..color = Colors.white,
    );

    if (offering) {
      // Flashes and stops attacking — the game never explains this in UI.
      final pulse = (math.sin(_phase * 8) * 0.5 + 0.5);
      final w = size.x + 28;
      final rect = Rect.fromLTWH(size.x / 2 - w / 2, -26, w, 20);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        Paint()
          ..color = const Color(
            0xFF7BB661,
          ).withValues(alpha: 0.55 + pulse * 0.45),
      );
      _offer.render(
        canvas,
        'OFFER  [C]',
        Vector2(size.x / 2, -16),
        anchor: Anchor.center,
      );
    } else if (contracted) {
      _label.render(
        canvas,
        'CONTRACTED',
        Vector2(size.x / 2, -12),
        anchor: Anchor.center,
      );
    } else if (health < maxHealth) {
      final w = size.x;
      canvas.drawRect(
        Rect.fromLTWH(0, -10, w, 5),
        Paint()..color = Colors.black.withValues(alpha: 0.6),
      );
      canvas.drawRect(
        Rect.fromLTWH(0, -10, w * (health / maxHealth), 5),
        Paint()..color = const Color(0xFFB4423A),
      );
    }

    if (telegraphing) {
      _label.render(
        canvas,
        '!',
        Vector2(size.x / 2, size.y / 2),
        anchor: Anchor.center,
      );
    }
    if (armoured && !contracted) {
      canvas.drawRect(
        Rect.fromLTWH(
          _facingRight ? size.x - 8 : 0,
          size.y * 0.3,
          8,
          size.y * 0.5,
        ),
        Paint()..color = const Color(0xFFB0B7C3),
      );
    }
  }

  // ── The roster (§11) ────────────────────────────────────────
  // Sizes follow the asset checklist so swapping a sprite in changes nothing
  // about the fight.

  factory Creature.bellToad(Vector2 at) => Creature(
    position: at,
    size: Vector2.all(48),
    creatureId: CreatureId.bellToad,
    displayName: 'BELL-TOAD',
    maxHealth: 1, // The first thing you meet dies in one hit.
    color: const Color(0xFF6E8B4A),
    behaviour: Behaviour.post,
    speed: 55,
    reach: 70,
    windupTime: 0.8,
    toll: 'a song you will not remember',
  );

  factory Creature.stiltWidow(Vector2 at) => Creature(
    position: at,
    size: Vector2(128, 200),
    creatureId: CreatureId.stiltWidow,
    displayName: 'STILT-WIDOW',
    maxHealth: 8,
    color: const Color(0xFF4A3E52),
    behaviour: Behaviour.strider,
    speed: 26, // Very slow.
    damage: 2, // High damage.
    reach: 210, // Legs that reach over cover.
    windupTime: 1.1,
    recoverTime: 1.3,
    toll: 'the name of someone you loved',
  );

  factory Creature.mouthMoth(Vector2 at) => Creature(
    position: at,
    size: Vector2.all(32),
    creatureId: CreatureId.mouthMoth,
    displayName: 'MOTH',
    maxHealth: 1,
    color: const Color(0xFF8E7CA8),
    behaviour: Behaviour.flyer,
    speed: 90,
    damage: 0,
    reach: 60,
    windupTime: 0.5,
    recoverTime: 0.6,
    toll: 'the light you are carrying',
  );

  factory Creature.twoHeadedDog(Vector2 at) => Creature(
    position: at,
    size: Vector2(96, 110),
    creatureId: CreatureId.twoHeadedDog,
    displayName: 'TWO-HEADED DOG',
    maxHealth: 7,
    color: const Color(0xFF7A3B2E),
    behaviour: Behaviour.hound,
    speed: 175, // Fast, flanks.
    damage: 1,
    reach: 100,
    windupTime: 0.45,
    recoverTime: 0.7,
    parryable: false, // Must be rolled.
    patrolRange: 900,
    toll: 'your left glove',
  );

  factory Creature.ashHound(Vector2 at) => Creature(
    position: at,
    size: Vector2(96, 100),
    creatureId: 'ash-hound',
    displayName: 'ASH HOUND',
    maxHealth: 4,
    color: const Color(0xFF9A3B22),
    behaviour: Behaviour.hound,
    speed: 150,
    reach: 95,
    windupTime: 0.5,
    recoverTime: 0.75,
    parryable: false,
    contractable: false, // Hell's dogs are not taking offers.
    patrolRange: 900,
  );

  factory Creature.agonyHand(Vector2 at) => Creature(
    position: at,
    size: Vector2(64, 90),
    creatureId: 'agony-hand',
    displayName: 'HAND',
    maxHealth: 2,
    color: const Color(0xFF5B2C3A),
    behaviour: Behaviour.riser,
    damage: 1,
    reach: 120,
    windupTime: 3.0, // A three-second tell.
    recoverTime: 1.2,
    contractable: false,
  );

  factory Creature.clerk(Vector2 at) => Creature(
    position: at,
    size: Vector2(96, 150),
    creatureId: 'clerk',
    displayName: 'CLERK',
    maxHealth: 4,
    color: const Color(0xFF6B4A2F),
    behaviour: Behaviour.walker,
    speed: 70,
    reach: 110,
    windupTime: 0.85,
    armoured: true, // Only the charged draw-cut opens it.
    toll: 'a signature',
  );

  factory Creature.warden(Vector2 at) => Creature(
    position: at,
    size: Vector2(96, 160),
    creatureId: 'warden',
    displayName: 'WARDEN',
    maxHealth: 6,
    color: const Color(0xFFB9C4D8),
    behaviour: Behaviour.walker,
    speed: 80,
    reach: 110,
    windupTime: 0.9,
    contractable: false,
  );
}
