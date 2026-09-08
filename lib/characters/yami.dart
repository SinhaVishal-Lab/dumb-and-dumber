import 'dart:ui' hide TextStyle;

import 'package:dumb_and_dumber/characters/player.dart';
import 'package:dumb_and_dumber/components/placeholder.dart';
import 'package:dumb_and_dumber/dumb_and_dumber.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors, TextStyle;

enum YamiState { idle, taunt, hurt, sitting, lying, soul }

/// YAMI — the dumber one. Died being polite.
///
/// §11: Yami reuses the Samurai rig as a recolour — different hair and sash on
/// the same skeleton. Until that recolour exists as its own sheet, the tint is
/// applied at draw time from the Samurai set the repo already has. TAUNT (6),
/// SIT-DYING (4, looping) and the lying-still pose are still missing, so they
/// borrow neighbours and label themselves.
class Yami extends SpriteAnimationGroupComponent<YamiState>
    with HasGameReference<DumbandDumber> {
  Yami({required Vector2 position, this.soulForm = false})
    : super(position: position, size: Vector2.all(384));

  /// In Heaven he is one of thousands of identical white souls.
  final bool soulForm;

  bool facingRight = true;

  /// Levels pose him during build(), which runs before onLoad has built the
  /// animation map, so the pose is remembered and applied on load.
  YamiState _pose = YamiState.idle;

  /// The prologue boss bar. He never attacks once.
  static const double maxHealth = 3;
  double health = maxHealth;

  double _flash = 0;

  static final _tag = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.bold,
      letterSpacing: 1,
      fontFamily: 'monospace',
    ),
  );

  Rect get body => Rect.fromLTWH(position.x + 96, position.y + 40, 192, 320);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    animations = {
      YamiState.idle: _sheet('IDLE', 10),
      YamiState.taunt: _sheet(
        'IDLE',
        10,
        step: 0.07,
      ), // PLACEHOLDER — TAUNT (6)
      YamiState.hurt: _sheet('HURT', 4)..loop = false,
      YamiState.sitting: _sheet(
        'HURT',
        4,
        step: 0.4,
      ), // PLACEHOLDER — SIT-DYING (4)
      YamiState.lying: _sheet(
        'HURT',
        1,
        step: 1,
      ), // PLACEHOLDER — lying-still pose
      YamiState.soul: _sheet('IDLE', 10, step: 0.12),
    };
    if (soulForm && _pose == YamiState.idle) _pose = YamiState.soul;
    current = _pose;

    // The recolour: different hair and sash on the same skeleton.
    paint = Paint()
      ..colorFilter = ColorFilter.mode(
        soulForm ? const Color(0xFFDDE4FF) : const Color(0xFF9C7BD6),
        BlendMode.modulate,
      );
  }

  SpriteAnimation _sheet(String state, int amount, {double step = 0.05}) {
    return SpriteAnimation.fromFrameData(
      game.images.fromCache('Characters/Samurai/$state.png'),
      SpriteAnimationData.sequenced(
        amount: amount,
        stepTime: step,
        textureSize: Vector2.all(96),
      ),
    );
  }

  /// See Player._face: facing is mirrored at draw time so the body never
  /// moves when he turns.
  void face(bool right) => facingRight = right;

  /// Three hits and the bar is gone. He does not defend.
  void takeHit() {
    health = (health - 1).clamp(0, maxHealth);
    _flash = 0.3;
    pose(YamiState.hurt);
    animationTicker?.reset();
  }

  void pose(YamiState state) {
    _pose = state;
    if (isLoaded) current = state;
  }

  void taunt() => pose(YamiState.taunt);
  void idle() => pose(YamiState.idle);
  void sitDown() => pose(YamiState.sitting);
  void lieStill() => pose(YamiState.lying);

  @override
  void update(double dt) {
    super.update(dt);
    if (_flash > 0) _flash -= dt;
    if (current == YamiState.hurt && (animationTicker?.done() ?? false)) {
      pose(YamiState.idle);
    }
  }

  @override
  void render(Canvas canvas) {
    if (current == YamiState.lying) {
      // No sprite rotation anywhere in this game, so the lying pose is a
      // placeholder body rather than a turned frame.
      PlaceholderArt.box(
        canvas
          ..save()
          ..translate(110, Player.feetOffset - 56),
        Vector2(170, 56),
        color: const Color(0xFF6B558F),
        label: 'YAMI — LYING STILL',
        lightText: true,
      );
      canvas.restore();
      return;
    }

    canvas.save();
    if (!facingRight) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }
    super.render(canvas);
    canvas.restore();

    final label = switch (current) {
      YamiState.taunt => 'TAUNT',
      YamiState.sitting => 'SIT-DYING',
      YamiState.soul => 'ONE OF THE CHOIR',
      _ => null,
    };
    if (label != null) {
      final w = _tag.getLineMetrics(label).width + 14;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.x / 2 - w / 2, 18, w, 18),
          const Radius.circular(9),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.6),
      );
      _tag.render(
        canvas,
        label,
        Vector2(size.x / 2, 27),
        anchor: Anchor.center,
      );
    }
  }
}
