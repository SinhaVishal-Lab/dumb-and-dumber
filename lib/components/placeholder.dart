import 'dart:math' as math;
import 'dart:ui' hide TextStyle;

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors, TextStyle;

/// Every asset the design doc lists as "Need" is drawn by this file.
///
/// Placeholders use a diagonal hatch and a caption so it is never ambiguous
/// what is real art and what is waiting for the bought pack. Replacing one is
/// a matter of swapping the component for a SpriteComponent at the same
/// position and size — nothing else reads these classes.
class PlaceholderArt {
  static final TextPaint _caption = TextPaint(
    style: const TextStyle(
      color: Color(0xCC1A1A1A),
      fontSize: 12,
      fontFamily: 'monospace',
      fontWeight: FontWeight.bold,
    ),
  );

  static final TextPaint _captionLight = TextPaint(
    style: const TextStyle(
      color: Color(0xEEFFFFFF),
      fontSize: 12,
      fontFamily: 'monospace',
      fontWeight: FontWeight.bold,
    ),
  );

  /// Draws a hatched, captioned box filling [size] at the canvas origin.
  static void box(
    Canvas canvas,
    Vector2 size, {
    required Color color,
    String? label,
    double hatchOpacity = 0.35,
    bool lightText = false,
    double radius = 4,
  }) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    canvas.drawRRect(rrect, Paint()..color = color);

    // Diagonal hatch, clipped to the body.
    canvas.save();
    canvas.clipRRect(rrect);
    final hatch = Paint()
      ..color = Colors.black.withValues(alpha: hatchOpacity * 0.5)
      ..strokeWidth = 2;
    for (double x = -size.y; x < size.x; x += 10) {
      canvas.drawLine(Offset(x, size.y), Offset(x + size.y, 0), hatch);
    }
    canvas.restore();

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    if (label != null) {
      final painter = lightText ? _captionLight : _caption;
      painter.render(
        canvas,
        label,
        Vector2(size.x / 2, size.y / 2),
        anchor: Anchor.center,
      );
    }
  }
}

/// Static scenery: woodpiles, shrines, desks, record stacks, gate wells.
/// Non-solid by default; pass [solid] to make it stand on.
class Prop extends PositionComponent {
  Prop({
    required super.position,
    required super.size,
    required this.color,
    this.label,
    this.solid = false,
    this.lightText = false,
    super.priority,
  });

  final Color color;
  final String? label;
  final bool solid;
  final bool lightText;

  @override
  void render(Canvas canvas) {
    PlaceholderArt.box(
      canvas,
      size,
      color: color,
      label: label,
      lightText: lightText,
    );
  }
}

/// A solid surface. Levels keep these in a list and the player resolves
/// against them directly — Flame's collision system is not involved, which
/// keeps ground contact deterministic at any frame rate.
class Platform extends PositionComponent {
  Platform({
    required super.position,
    required super.size,
    this.color = const Color(0xFF3E3226),
    this.visible = true,
    this.label,
    this.oneWay = false,
    super.priority = -1,
  });

  final Color color;
  final bool visible;
  final String? label;

  /// One-way platforms catch you from above and are ignored otherwise, so a
  /// jump can pass up through a rice terrace step.
  final bool oneWay;

  Rect get rect => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    final r = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(r, Paint()..color = color);
    // Lip so the standable edge reads at a glance.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, 4),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    if (label != null) {
      PlaceholderArt._caption.render(
        canvas,
        label!,
        Vector2(size.x / 2, size.y / 2),
        anchor: Anchor.center,
      );
    }
  }
}

/// A hazard or trigger region. Invisible by default; [onEnter] fires once per
/// entry. Used for zone boundaries, the soul river, wind gusts and the drain.
class TriggerZone extends PositionComponent {
  TriggerZone({
    required super.position,
    required super.size,
    this.onEnter,
    this.onExit,
    this.fillColor,
  });

  final void Function()? onEnter;
  final void Function()? onExit;
  final Color? fillColor;

  bool _inside = false;

  Rect get rect => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  /// Called by the level each frame with the player's collision box.
  void test(Rect body) {
    final hit = rect.overlaps(body);
    if (hit && !_inside) {
      _inside = true;
      onEnter?.call();
    } else if (!hit && _inside) {
      _inside = false;
      onExit?.call();
    }
  }

  @override
  void render(Canvas canvas) {
    if (fillColor == null) return;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = fillColor!,
    );
  }
}

/// Decorative animated backdrop band — stands in for the parallax sets Hell
/// and Heaven still need. Three layers of drifting shapes over a flat sky.
class PlaceholderParallax extends PositionComponent {
  PlaceholderParallax({
    required this.sky,
    required this.mid,
    required this.near,
    required Vector2 size,
    this.caption,
  }) : super(size: size, position: Vector2.zero(), priority: -100);

  final Color sky;
  final Color mid;
  final Color near;
  final String? caption;

  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = sky);

    // Back layer at 0.2x, mid at 0.5x — the doc's scroll ratios.
    _band(canvas, mid, size.y * 0.55, 90, _t * 6, 0.35);
    _band(canvas, near, size.y * 0.72, 60, _t * 14, 0.5);

    if (caption != null) {
      PlaceholderArt._captionLight.render(canvas, caption!, Vector2(16, 16));
    }
  }

  void _band(
    Canvas canvas,
    Color color,
    double top,
    double height,
    double offset,
    double alpha,
  ) {
    final paint = Paint()..color = color.withValues(alpha: alpha);
    const step = 260.0;
    final start = -(offset % step) - step;
    for (double x = start; x < size.x + step; x += step) {
      final path = Path()
        ..moveTo(x, top + height)
        ..lineTo(x + step * 0.5, top)
        ..lineTo(x + step, top + height)
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, top + height, size.x, size.y - top - height),
      paint,
    );
  }
}

/// A crowd strip: identical white souls, used by the Hell queue and the
/// Heaven choir. Individually pointless, collectively the whole point.
class CrowdStrip extends PositionComponent {
  CrowdStrip({
    required super.position,
    required super.size,
    this.color = const Color(0xFFEFEFF5),
    this.count = 24,
    this.seed = 7,
    super.priority = -2,
  });

  final Color color;
  final int count;
  final int seed;

  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    final rng = math.Random(seed);
    final paint = Paint()..color = color.withValues(alpha: 0.75);
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.x;
      final phase = rng.nextDouble() * math.pi * 2;
      final bob = math.sin(_t * 1.6 + phase) * 4;
      final h = size.y * (0.6 + rng.nextDouble() * 0.4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.y - h + bob, 26, h),
          const Radius.circular(13),
        ),
        paint,
      );
    }
  }
}
