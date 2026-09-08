import 'dart:math' as math;
import 'dart:ui' hide TextStyle;

import 'package:dumb_and_dumber/characters/player.dart';
import 'package:dumb_and_dumber/components/placeholder.dart';
import 'package:dumb_and_dumber/dumb_and_dumber.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors, TextStyle;

/// Shared body for the three bosses the asset pack will not cover (§11: the
/// Registrar's four arms and the six-winged angel are commissions).
abstract class BossActor extends PositionComponent
    with HasGameReference<DumbandDumber> {
  BossActor({
    required super.position,
    required super.size,
    required this.name,
    required this.color,
    super.priority = 6,
  });

  final String name;
  final Color color;

  /// Set by the level when the fight actually starts.
  bool fighting = false;

  double flash = 0;
  double staggerTimer = 0;
  double phaseTime = 0;
  bool facingRight = false;

  Rect get body => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  Player? get player => game.level?.player;

  static final tag = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.bold,
      letterSpacing: 1,
      fontFamily: 'monospace',
    ),
  );

  void stagger([double seconds = 1.0]) => staggerTimer = seconds;

  @override
  void update(double dt) {
    super.update(dt);
    if (flash > 0) flash -= dt;
    if (staggerTimer > 0) staggerTimer -= dt;
    if (!fighting || game.dialogue.isActive) return;
    final target = player;
    if (target == null || target.dead) return;
    facingRight = target.body.center.dx > body.center.dx;
    phaseTime += dt;
    if (staggerTimer > 0) return;
    think(dt, target);
  }

  void think(double dt, Player target);

  Color get bodyColor {
    if (flash > 0) return Color.lerp(color, Colors.white, 0.7)!;
    if (staggerTimer > 0) return Color.lerp(color, Colors.black, 0.35)!;
    return color;
  }

  @override
  void render(Canvas canvas) {
    PlaceholderArt.box(
      canvas,
      size,
      color: bodyColor,
      label: name,
      lightText: true,
    );
    canvas.drawCircle(
      Offset(facingRight ? size.x - 16 : 16, 20),
      6,
      Paint()..color = Colors.white,
    );
    if (staggerTimer > 0) {
      tag.render(
        canvas,
        'STAGGERED',
        Vector2(size.x / 2, -12),
        anchor: Anchor.center,
      );
    }
  }

  /// Draws a telegraphed strike zone so a tell is readable without VFX art.
  void drawTell(Canvas canvas, Rect zone, double progress, {Color? tint}) {
    final local = zone.translate(-position.x, -position.y);
    canvas.drawRect(
      local,
      Paint()
        ..color = (tint ?? const Color(0xFFFFC246)).withValues(
          alpha: 0.18 + progress * 0.4,
        ),
    );
    canvas.drawRect(
      local,
      Paint()
        ..color = (tint ?? const Color(0xFFFFC246)).withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// THE SAINT — E1. Won by not attacking. Guard and parry only.
// ─────────────────────────────────────────────────────────────

/// Firm but fair: a real skill check a persistent player clears in three or
/// four attempts, never a wall. The bar on screen is Sakamoto's guard
/// stamina, not the saint's health.
class SaintBoss extends BossActor {
  /// Half a head taller than Sakamoto — he is better at this, and it shows
  /// before he moves.
  static const double bodyWidth = 110;
  static const double bodyHeight = 180;

  SaintBoss({required Vector2 position})
    : super(
        position: position,
        size: Vector2(bodyWidth, bodyHeight),
        name: 'THE SAINT',
        color: const Color(0xFF7C6E52),
      );

  /// 0 — single overheads, 1 — the four-hit string, 2 — the spinning flurry.
  int phase = 0;

  /// Cleared when all three phases are survived.
  bool defeated = false;

  /// Parry windows widen slightly after each failed attempt.
  double parryBonus = 0;

  static const List<double> phaseLength = [26, 30, 34];

  double _windup = 0;
  double _cooldown = 1.2;
  int _stringIndex = 0;
  int _flurriesRolled = 0;
  Rect? _tellZone;
  bool _tellParryable = true;
  bool _tellGuardable = true;

  void Function(int phase)? onPhaseChanged;
  void Function()? onDefeated;

  double get phaseProgress => (phaseTime / phaseLength[phase]).clamp(0.0, 1.0);

  /// The fight punishes attacking — the only thing the game has taught so far.
  void onHitByPlayer() {
    if (defeated) return;
    game.hud.toast.show('HE STOPS RESPECTING YOU', seconds: 1.4);
    phaseTime = 0;
    _stringIndex = 0;
    _flurriesRolled = 0;
    _windup = 0;
    _cooldown = 1.6;
    parryBonus = (parryBonus + 0.12).clamp(0, 0.5);
  }

  @override
  void think(double dt, Player target) {
    if (defeated) return;

    if (_windup > 0) {
      _windup -= dt;
      if (_windup <= 0) _land(target);
      return;
    }
    if (_cooldown > 0) {
      _cooldown -= dt;
      return;
    }

    // Close the distance, but never crowd — this is a reading fight.
    final gap = target.body.center.dx - body.center.dx;
    if (gap.abs() > 220) {
      position.x += gap.sign * 70 * dt;
    }

    switch (phase) {
      case 0:
        _begin(windup: 1.25 + parryBonus, guardable: true, parryable: true);
      case 1:
        // Only the flashing fourth can be parried.
        final fourth = _stringIndex == 3;
        _begin(
          windup: fourth ? 0.85 + parryBonus : 0.4,
          guardable: true,
          parryable: fourth,
        );
      case 2:
        // A spinning flurry that must be rolled.
        _begin(windup: 1.0, guardable: false, parryable: false, wide: true);
    }

    if (phase < 2 && phaseTime >= phaseLength[phase]) _advancePhase();
  }

  void _begin({
    required double windup,
    required bool guardable,
    required bool parryable,
    bool wide = false,
  }) {
    _windup = windup;
    _tellGuardable = guardable;
    _tellParryable = parryable;
    final reach = wide ? 420.0 : 230.0;
    _tellZone = facingRight
        ? Rect.fromLTWH(body.right - 20, body.top + 40, reach, body.height)
        : Rect.fromLTWH(
            body.left - reach + 20,
            body.top + 40,
            reach,
            body.height,
          );
  }

  void _land(Player target) {
    final zone = _tellZone;
    _tellZone = null;
    _cooldown = phase == 1 ? 0.35 : 1.1;
    if (phase == 1) _stringIndex = (_stringIndex + 1) % 4;

    if (zone == null || !zone.overlaps(target.body)) {
      if (phase == 2) _flurrySurvived();
      return;
    }

    final result = target.takeHit(
      1,
      knockback: 150,
      parryable: _tellParryable,
      guardable: _tellGuardable,
    );

    if (result == HitResult.parried) {
      stagger(1.1);
      game.hud.toast.show('HE FEELS THAT');
    } else if (result == HitResult.ignored && phase == 2) {
      // Rolled through it.
      _flurrySurvived();
    }
  }

  void _flurrySurvived() {
    if (phase != 2) return;
    _flurriesRolled++;
    game.hud.toast.show('ROLLED  $_flurriesRolled/2');
    if (_flurriesRolled >= 2) {
      defeated = true;
      fighting = false;
      onDefeated?.call();
    }
  }

  void _advancePhase() {
    phase++;
    phaseTime = 0;
    _stringIndex = 0;
    _cooldown = 1.4;
    onPhaseChanged?.call(phase);
    game.hud.toast.show(switch (phase) {
      1 => 'HE STRINGS THEM TOGETHER',
      2 => 'HE SPINS — ROLL',
      _ => '',
    }, seconds: 1.6);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final zone = _tellZone;
    if (zone != null) {
      final total = phase == 2 ? 1.0 : 1.25;
      drawTell(
        canvas,
        zone,
        1 - (_windup / total).clamp(0.0, 1.0),
        tint: phase == 2 ? const Color(0xFFE05A4F) : null,
      );
      if (phase == 1 && _stringIndex == 3) {
        BossActor.tag.render(
          canvas,
          'PARRY THIS ONE',
          Vector2(size.x / 2, -30),
          anchor: Anchor.center,
        );
      }
      if (phase == 2) {
        BossActor.tag.render(
          canvas,
          'ROLL',
          Vector2(size.x / 2, -30),
          anchor: Anchor.center,
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────
// THE REGISTRAR — H1. Won by attacking until he asks a question.
// ─────────────────────────────────────────────────────────────

/// Four arms, one ledger, no patience. Not evil — behind schedule.
class RegistrarBoss extends BossActor {
  static const double bodyWidth = 150;
  static const double bodyHeight = 250;

  RegistrarBoss({required Vector2 position})
    : super(
        position: position,
        size: Vector2(bodyWidth, bodyHeight),
        name: 'THE REGISTRAR',
        color: const Color(0xFF8A2F2A),
      );

  static const double maxHealth = 16;
  double health = maxHealth;

  /// 1 — the ledger, 2 — the shelves, 3 — the question.
  int phase = 1;
  bool contractable = false;
  bool finished = false;

  /// Three arms attack on independent timers; the fourth keeps writing.
  final List<double> _armTimers = [1.4, 2.6, 3.9];
  final List<Rect?> _armZones = [null, null, null];
  double _throwTimer = 3;

  void Function()? onQuestion;
  void Function()? onDefeated;

  double get healthFraction => health / maxHealth;

  void takeHit(double amount, {bool charged = false}) {
    if (finished || phase == 3) return;
    health = (health - amount).clamp(0, maxHealth);
    flash = 0.25;
    game.hud.bossBar.value = healthFraction;

    if (phase == 1 && healthFraction <= 0.6) {
      phase = 2;
      game.hud.toast.show('HE CLOSES THE BOOK', seconds: 1.6);
    } else if (phase == 2 && healthFraction <= 0.2) {
      phase = 3;
      fighting = false;
      contractable = true;
      onQuestion?.call();
    }
  }

  @override
  void think(double dt, Player target) {
    if (finished || phase == 3) return;

    final gap = target.body.center.dx - body.center.dx;
    if (gap.abs() > 260) position.x += gap.sign * 46 * dt;

    for (var i = 0; i < _armTimers.length; i++) {
      _armTimers[i] -= dt;
      if (_armTimers[i] <= 0.55 && _armZones[i] == null) {
        // Generous parry windows — he does not look at you once.
        final reach = 200.0 + i * 40;
        _armZones[i] = facingRight
            ? Rect.fromLTWH(body.right - 20, body.top + 30.0 * i, reach, 130)
            : Rect.fromLTWH(
                body.left - reach + 20,
                body.top + 30.0 * i,
                reach,
                130,
              );
      }
      if (_armTimers[i] <= 0) {
        _swingArm(i, target);
        _armTimers[i] = 2.4 + i * 0.9;
      }
    }

    if (phase == 2) {
      _throwTimer -= dt;
      if (_throwTimer <= 0) {
        _throwTimer = 2.8;
        // Souls that stagger rather than damage — chip only.
        if ((target.body.center.dx - body.center.dx).abs() < 620) {
          final result = target.takeHit(
            0,
            knockback: 240,
            parryable: true,
            guardable: true,
          );
          if (result == HitResult.parried) stagger(0.9);
          game.hud.toast.show('A THROWN SOUL', seconds: 0.8);
        }
      }
    }
  }

  void _swingArm(int index, Player target) {
    final zone = _armZones[index];
    _armZones[index] = null;
    if (zone == null || !zone.overlaps(target.body)) return;
    final result = target.takeHit(1, knockback: 160);
    if (result == HitResult.parried) stagger(1.0);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Four arms: three that attack, one that keeps writing.
    for (var i = 0; i < 3; i++) {
      final armY = 40.0 + i * 48;
      canvas.drawRect(
        Rect.fromLTWH(facingRight ? size.x - 6 : -30, armY, 34, 14),
        Paint()..color = const Color(0xFFD98C6A),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(facingRight ? -26 : size.x - 10, size.y - 90, 34, 12),
      Paint()..color = const Color(0xFFE0C9A0),
    );
    BossActor.tag.render(
      canvas,
      phase == 3 ? 'STILL FILING' : 'FILING',
      Vector2(size.x / 2, size.y - 22),
      anchor: Anchor.center,
    );

    for (final zone in _armZones) {
      if (zone != null) drawTell(canvas, zone, 0.6);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// THE GATE ANGEL — HV1. Won by neither. Running, with your hands full.
// ─────────────────────────────────────────────────────────────

enum AngelMode { idle, beams, colonnade, drain }

/// The game's only boss with no health bar on her side: the bar on screen is
/// the distance to the drain, and it fills as Sakamoto moves.
class GateAngelBoss extends BossActor {
  static const double bodyWidth = 140;
  static const double bodyHeight = 230;

  GateAngelBoss({required Vector2 position})
    : super(
        position: position,
        size: Vector2(bodyWidth, bodyHeight),
        name: 'THE GATE ANGEL',
        color: const Color(0xFF3E5C9A),
      );

  AngelMode mode = AngelMode.idle;

  /// Caught in any phase drops back to the phase start, never a game over.
  void Function()? onCaught;

  double _beamTimer = 2;
  Rect? _beam;
  double _grabTimer = 3;
  Rect? _grab;
  int grabsDodged = 0;

  /// Phase two: hide inside the choir and she sweeps past. Set by the level
  /// when the player is standing still inside a crowd strip.
  bool playerHidden = false;

  @override
  void think(double dt, Player target) {
    switch (mode) {
      case AngelMode.idle:
        return;

      case AngelMode.beams:
        // Light beams sweeping across the floor on a two-second telegraph.
        _beamTimer -= dt;
        if (_beamTimer <= 0.7 && _beam == null) {
          final x = target.body.center.dx - 90;
          _beam = Rect.fromLTWH(x, 0, 180, 500);
        }
        if (_beamTimer <= 0) {
          _beamTimer = 2.0;
          final beam = _beam;
          _beam = null;
          if (beam != null && beam.overlaps(target.body)) {
            // The only tool left is the roll, and it costs distance.
            final result = target.takeHit(
              1,
              knockback: 200,
              parryable: false,
              guardable: false,
            );
            if (result != HitResult.ignored) onCaught?.call();
          }
        }

      case AngelMode.colonnade:
        // She overtakes and sweeps past. Standing still while she walks
        // toward you is the whole ask.
        final gap = target.body.center.dx - body.center.dx;
        position.x += gap.sign * 90 * dt;
        if ((gap).abs() < 150 && !playerHidden) {
          onCaught?.call();
        }

      case AngelMode.drain:
        // One step behind, three grab attempts on a clear wind-up.
        final gap = target.body.center.dx - body.center.dx;
        position.x += gap.sign * 150 * dt;
        _grabTimer -= dt;
        if (_grabTimer <= 0.9 && _grab == null) {
          _grab = Rect.fromLTWH(
            body.center.dx - 160,
            body.top,
            320,
            body.height,
          );
        }
        if (_grabTimer <= 0) {
          _grabTimer = 3.2;
          final grab = _grab;
          _grab = null;
          if (grab != null && grab.overlaps(target.body)) {
            if (target.invulnerable) {
              grabsDodged++;
            } else {
              onCaught?.call();
            }
          } else {
            grabsDodged++;
          }
        }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Six wings with eyes on all of them.
    for (var i = 0; i < 6; i++) {
      final angle = -0.9 + i * 0.36;
      final wx = size.x / 2 + math.cos(angle) * (size.x * 0.7);
      final wy = size.y * 0.35 + math.sin(angle) * 60;
      canvas.drawCircle(
        Offset(wx, wy),
        9,
        Paint()..color = const Color(0xFFF2E9C9),
      );
    }
    final beam = _beam;
    if (beam != null) {
      drawTell(canvas, beam, 0.7, tint: const Color(0xFFFFF3C4));
    }
    final grab = _grab;
    if (grab != null) {
      drawTell(canvas, grab, 0.8, tint: const Color(0xFFFFF3C4));
    }
  }
}
