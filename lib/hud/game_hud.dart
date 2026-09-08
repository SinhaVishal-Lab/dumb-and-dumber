import 'dart:math' as math;
import 'dart:ui' hide TextStyle;

import 'package:dumb_and_dumber/dialogue/dialogue_box.dart';
import 'package:dumb_and_dumber/state/game_state.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' show Colors, TextStyle;

/// §5 HUD: bottom-left joystick and health pips, bottom-right jump and ATK,
/// top-left the player name, guard pips under the health. Nothing else, ever
/// — no clock, no objective marker, no minimap.

/// A press-and-hold touch button. At least 44px on a phone screen, thumb-side.
class TouchButton extends PositionComponent with TapCallbacks {
  TouchButton({
    required Vector2 center,
    required this.radius,
    required this.label,
    required this.color,
    this.onPressed,
    this.onReleased,
    super.priority = 800,
  }) : super(
         position: center,
         size: Vector2.all(radius * 2),
         anchor: Anchor.center,
       );

  final double radius;
  final String label;
  final Color color;
  final void Function()? onPressed;
  final void Function()? onReleased;

  bool _down = false;
  bool enabled = true;

  static final _text = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
    ),
  );

  @override
  bool containsLocalPoint(Vector2 point) {
    if (!enabled) return false;
    return (point - Vector2.all(radius)).length <= radius;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!enabled) return;
    _down = true;
    onPressed?.call();
  }

  @override
  void onTapUp(TapUpEvent event) => _release();

  @override
  void onTapCancel(TapCancelEvent event) => _release();

  void _release() {
    if (!_down) return;
    _down = false;
    onReleased?.call();
  }

  @override
  void render(Canvas canvas) {
    if (!enabled) return;
    final c = Offset(radius, radius);
    canvas.drawCircle(
      c,
      radius,
      Paint()..color = color.withValues(alpha: _down ? 0.85 : 0.45),
    );
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _text.render(canvas, label, Vector2(radius, radius), anchor: Anchor.center);
  }
}

/// Health and guard pips. Guard sits under the health, as specified.
class PipRow extends PositionComponent {
  PipRow({
    required super.position,
    required this.max,
    required this.color,
    this.pipWidth = 22,
    this.pipHeight = 9,
    this.gap = 5,
    super.priority = 800,
  });

  final int max;
  final Color color;
  final double pipWidth;
  final double pipHeight;
  final double gap;

  /// Fractional so the guard meter can drain smoothly.
  double value = 0;

  @override
  void render(Canvas canvas) {
    for (var i = 0; i < max; i++) {
      final x = i * (pipWidth + gap);
      final rect = Rect.fromLTWH(x, 0, pipWidth, pipHeight);
      final fill = (value - i).clamp(0.0, 1.0);
      canvas.drawRect(
        rect,
        Paint()..color = Colors.black.withValues(alpha: 0.45),
      );
      if (fill > 0) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, pipWidth * fill, pipHeight),
          Paint()..color = color,
        );
      }
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }
}

/// The one-line button prompt the prologue leans on ("walk to Yami", "jump",
/// "attack"). Sits top-centre so it never overlaps the dialogue box.
class PromptBanner extends PositionComponent {
  PromptBanner({required Vector2 viewSize, super.priority = 850})
    : super(position: Vector2(viewSize.x / 2, 92), anchor: Anchor.center);

  String? text;
  double _pulse = 0;

  static final _painter = TextPaint(
    style: const TextStyle(
      color: Color(0xFF1B1A17),
      fontSize: 17,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.1,
      fontFamily: 'monospace',
    ),
  );

  void show(String value) => text = value;
  void hide() => text = null;

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt;
  }

  @override
  void render(Canvas canvas) {
    final value = text;
    if (value == null) return;
    final w = _painter.getLineMetrics(value).width + 36;
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: 34);
    final glow = 0.75 + math.sin(_pulse * 4) * 0.25;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(17)),
      Paint()..color = UiPalette.gold.withValues(alpha: glow),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(17)),
      Paint()
        ..color = UiPalette.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _painter.render(canvas, value, Vector2.zero(), anchor: Anchor.center);
  }
}

/// Boss lifebar. Doubles as HV1's distance-to-the-drain bar, which fills
/// instead of emptying — same furniture, opposite meaning.
class BossBar extends PositionComponent {
  BossBar({required Vector2 viewSize, super.priority = 850})
    : super(position: Vector2(viewSize.x / 2, 44), anchor: Anchor.center);

  String label = '';
  double value = 1.0;
  bool visible = false;
  Color color = UiPalette.blood;

  static const double barWidth = 560;

  static final _painter = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      letterSpacing: 2,
      fontFamily: 'monospace',
    ),
  );

  void show(String name, {Color barColor = UiPalette.blood}) {
    label = name;
    color = barColor;
    value = 1;
    visible = true;
  }

  void hide() => visible = false;

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    _painter.render(canvas, label, Vector2(0, -18), anchor: Anchor.center);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: barWidth,
      height: 14,
    );
    canvas.drawRect(rect, Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawRect(
      Rect.fromLTWH(
        rect.left,
        rect.top,
        barWidth * value.clamp(0.0, 1.0),
        rect.height,
      ),
      Paint()..color = color,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

/// The name card that slams in before a boss.
class NameCard extends PositionComponent {
  NameCard({required this.viewSize, super.priority = 880})
    : super(position: Vector2.zero(), size: viewSize);

  final Vector2 viewSize;

  String _name = '';
  String _sub = '';
  double _t = 0;
  bool _running = false;

  static const double _slam = 0.25;
  static const double _hold = 1.5;
  static const double _out = 0.4;

  static final _big = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 54,
      fontWeight: FontWeight.bold,
      letterSpacing: 8,
      fontFamily: 'monospace',
    ),
  );
  static final _small = TextPaint(
    style: const TextStyle(
      color: Color(0xFFD8A44A),
      fontSize: 16,
      letterSpacing: 5,
      fontFamily: 'monospace',
    ),
  );

  Future<void> slam(String name, {String sub = ''}) async {
    _name = name;
    _sub = sub;
    _t = 0;
    _running = true;
    await Future<void>.delayed(
      Duration(milliseconds: ((_slam + _hold + _out) * 1000).round()),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_running) return;
    _t += dt;
    if (_t > _slam + _hold + _out) _running = false;
  }

  @override
  void render(Canvas canvas) {
    if (!_running) return;
    final double alpha;
    double slide = 0;
    if (_t < _slam) {
      final k = _t / _slam;
      alpha = k;
      slide = (1 - k) * 120;
    } else if (_t < _slam + _hold) {
      alpha = 1;
    } else {
      alpha = 1 - (_t - _slam - _hold) / _out;
    }
    final a = alpha.clamp(0.0, 1.0);
    final cy = viewSize.y / 2;
    canvas.drawRect(
      Rect.fromLTWH(0, cy - 60, viewSize.x, 120),
      Paint()..color = Colors.black.withValues(alpha: 0.72 * a),
    );
    _big.render(
      canvas,
      _name,
      Vector2(viewSize.x / 2 + slide, cy - 8),
      anchor: Anchor.center,
    );
    if (_sub.isNotEmpty) {
      _small.render(
        canvas,
        _sub,
        Vector2(viewSize.x / 2 - slide, cy + 34),
        anchor: Anchor.center,
      );
    }
  }
}

/// One frame of white. Used exactly once for the third hit, and again for
/// each portal.
class ScreenFlash extends PositionComponent {
  ScreenFlash({required this.viewSize, super.priority = 890})
    : super(position: Vector2.zero(), size: viewSize);

  final Vector2 viewSize;
  double _t = 0;
  double _duration = 0;
  Color _color = Colors.white;

  Future<void> flash({
    double duration = 0.9,
    Color color = Colors.white,
  }) async {
    _color = color;
    _duration = duration;
    _t = duration;
    await Future<void>.delayed(
      Duration(milliseconds: (duration * 1000).round()),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_t > 0) _t -= dt;
  }

  @override
  void render(Canvas canvas) {
    if (_t <= 0) return;
    final a = (_t / _duration).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, viewSize.x, viewSize.y),
      Paint()..color = _color.withValues(alpha: a),
    );
  }
}

/// Transient centre text — "CONTRACT SEALED", "SEEN", "ARENA CLEARED".
/// Deliberately not a system the player has to read; it fades on its own.
class Toast extends PositionComponent {
  Toast({required Vector2 viewSize, super.priority = 860})
    : super(position: Vector2(viewSize.x / 2, 150), anchor: Anchor.center);

  String _text = '';
  double _t = 0;

  static final _painter = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 22,
      fontWeight: FontWeight.bold,
      letterSpacing: 3,
      fontFamily: 'monospace',
      shadows: [
        Shadow(color: Colors.black, blurRadius: 6, offset: Offset(1, 1)),
      ],
    ),
  );

  void show(String text, {double seconds = 1.6}) {
    _text = text;
    _t = seconds;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_t > 0) _t -= dt;
  }

  @override
  void render(Canvas canvas) {
    if (_t <= 0) return;
    _painter.render(canvas, _text, Vector2.zero(), anchor: Anchor.center);
  }
}

/// Groups every viewport-space widget so a level change can re-mount the lot
/// in one call.
class GameHud extends PositionComponent {
  GameHud({required this.viewSize, required this.state}) : super(priority: 800);

  final Vector2 viewSize;
  final GameState state;

  late final PipRow health;
  late final PipRow guard;
  late final PromptBanner prompt;
  late final BossBar bossBar;
  late final NameCard nameCard;
  late final ScreenFlash flash;
  late final Toast toast;

  late final TouchButton jumpButton;
  late final TouchButton attackButton;
  late final TouchButton guardButton;
  late final TouchButton contractButton;

  // Wired by the game once the player exists.
  void Function()? onJump;
  void Function()? onAttackDown;
  void Function()? onAttackUp;
  void Function()? onGuardDown;
  void Function()? onGuardUp;
  void Function()? onContract;

  static final _nameText = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
      shadows: [
        Shadow(color: Colors.black, blurRadius: 3, offset: Offset(1, 1)),
      ],
    ),
  );

  @override
  Future<void> onLoad() async {
    health = PipRow(
      position: Vector2(40, 312),
      max: GameState.maxHealthPips,
      color: UiPalette.blood,
    )..value = state.health.toDouble();
    guard = PipRow(
      position: Vector2(40, 330),
      max: GameState.maxGuardPips,
      color: UiPalette.guard,
      pipHeight: 6,
    )..value = state.guard;

    prompt = PromptBanner(viewSize: viewSize);
    bossBar = BossBar(viewSize: viewSize);
    nameCard = NameCard(viewSize: viewSize);
    flash = ScreenFlash(viewSize: viewSize);
    toast = Toast(viewSize: viewSize);

    // Thumb-side, right to left: JUMP, ATK, GUARD. Long-press ATK is the
    // charged draw-cut; GUARD is a hold. Every one is over 44px.
    jumpButton = TouchButton(
      center: Vector2(1006, 398),
      radius: 40,
      label: 'JUMP',
      color: const Color(0xFF4FC3F7),
      onPressed: () => onJump?.call(),
    );
    attackButton = TouchButton(
      center: Vector2(916, 444),
      radius: 38,
      label: 'ATK',
      color: const Color(0xFFEF5350),
      onPressed: () => onAttackDown?.call(),
      onReleased: () => onAttackUp?.call(),
    );
    guardButton = TouchButton(
      center: Vector2(826, 444),
      radius: 34,
      label: 'GUARD',
      color: const Color(0xFF5C8FD6),
      onPressed: () => onGuardDown?.call(),
      onReleased: () => onGuardUp?.call(),
    );
    contractButton = TouchButton(
      center: Vector2(916, 348),
      radius: 36,
      label: 'OFFER',
      color: const Color(0xFF7BB661),
      onPressed: () => onContract?.call(),
    )..enabled = false;

    await addAll([
      health,
      guard,
      prompt,
      bossBar,
      toast,
      jumpButton,
      attackButton,
      guardButton,
      contractButton,
      nameCard,
      flash,
    ]);
  }

  /// Pull the pip rows back in line with the run state.
  void sync() {
    health.value = state.health.toDouble();
    guard.value = state.guard;
  }

  /// Hidden while the dialogue box owns the screen — §5 touch rules say the
  /// buttons never overlap it.
  void setControlsVisible(bool visible) {
    for (final b in [jumpButton, attackButton, guardButton]) {
      b.enabled = visible;
    }
    if (!visible) contractButton.enabled = false;
  }

  @override
  void render(Canvas canvas) {
    _nameText.render(canvas, state.playerName, Vector2(20, 92));
  }
}
