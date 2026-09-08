import 'dart:async';
import 'dart:ui' hide TextStyle;

import 'package:dumb_and_dumber/dialogue/dialogue.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' show Colors, TextStyle;
import 'package:flutter/services.dart';

/// The bottom text box (§5 "Dialogue box").
///
/// Full width, 110px tall at the 1080×500 camera, hard border, no
/// transparency, name plate tabbed above the left corner. One or two lines at
/// a time, tap or advance-button to continue, no auto-advance. Choices
/// replace the box with a stacked list at full-thumb height.
///
/// Lives in the camera viewport and owns its own async control flow, so a
/// level script can be written as a straight-line async function:
///
/// ```dart
/// await dialogue.say([Line('YAMI', 'I thought we were friends.')]);
/// final pick = await dialogue.choose([Choice('Sorry.'), Choice('You moved.')]);
/// ```
class DialogueBox extends PositionComponent with TapCallbacks, KeyboardHandler {
  DialogueBox({required this.viewSize})
    : super(position: Vector2.zero(), size: viewSize, priority: 900);

  final Vector2 viewSize;

  static const double boxHeight = 110;
  static const double margin = 10;
  static const double sidePad = 26;
  static const double charsPerSecond = 55;
  static const double choiceRowHeight = 46;

  // ── Live state ──────────────────────────────────────────────
  final List<Line> _queue = [];
  Line? _current;
  List<String> _wrapped = const [];
  double _revealed = 0;
  Completer<void>? _sayCompleter;

  List<Choice> _choices = const [];
  Completer<int>? _choiceCompleter;
  int _hovered = -1;

  double _blink = 0;

  /// True whenever the box owns the player's input.
  bool get isActive => _current != null || _choices.isNotEmpty;

  /// Set by the game so `requiresContract` choices can be greyed out.
  bool Function(String id) hasContract = (_) => false;

  // ── Painters ────────────────────────────────────────────────
  static final _body = TextPaint(
    style: const TextStyle(
      color: Color(0xFF1B1A17),
      fontSize: 19,
      height: 1.35,
      fontFamily: 'monospace',
    ),
  );
  static final _bodyInHead = TextPaint(
    style: const TextStyle(
      color: Color(0xFF3B3168),
      fontSize: 19,
      height: 1.35,
      fontStyle: FontStyle.italic,
      fontFamily: 'monospace',
    ),
  );
  static final _bodyNarration = TextPaint(
    style: const TextStyle(
      color: Color(0xFF5A5952),
      fontSize: 18,
      height: 1.35,
      fontStyle: FontStyle.italic,
      fontFamily: 'monospace',
    ),
  );
  static final _plate = TextPaint(
    style: const TextStyle(
      color: Color(0xFFF6F3EA),
      fontSize: 15,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.2,
      fontFamily: 'monospace',
    ),
  );
  static final _choiceText = TextPaint(
    style: const TextStyle(
      color: Color(0xFF1B1A17),
      fontSize: 18,
      fontFamily: 'monospace',
    ),
  );
  static final _choiceTextLocked = TextPaint(
    style: const TextStyle(
      color: Color(0x661B1A17),
      fontSize: 18,
      fontStyle: FontStyle.italic,
      fontFamily: 'monospace',
    ),
  );
  static final _hint = TextPaint(
    style: const TextStyle(
      color: Color(0x881B1A17),
      fontSize: 13,
      fontFamily: 'monospace',
    ),
  );

  // ── Public API ──────────────────────────────────────────────

  /// Shows [lines] one at a time; completes when the last one is dismissed.
  Future<void> say(List<Line> lines) {
    if (lines.isEmpty) return Future.value();
    _queue.addAll(lines);
    _sayCompleter ??= Completer<void>();
    if (_current == null) _advance();
    return _sayCompleter!.future;
  }

  Future<void> line(String speaker, String text) => say([Line(speaker, text)]);

  /// Replaces the box with a stacked option list. Completes with the index
  /// picked. Options whose contract is missing are shown but unpickable —
  /// the player should see what they could have said.
  Future<int> choose(List<Choice> options) {
    assert(options.isNotEmpty && options.length <= 4);
    _choices = options;
    _hovered = -1;
    _choiceCompleter = Completer<int>();
    return _choiceCompleter!.future;
  }

  /// Advance one line, exactly as tapping the box does. Public so tests and
  /// any future accessibility path can drive the box without a pointer.
  void advance() => _confirm();

  /// Pick option [index], exactly as tapping that row does.
  void pick(int index) => _pick(index);

  /// Drops everything without completing — used when a level is torn down.
  void clear() {
    _queue.clear();
    _current = null;
    _wrapped = const [];
    _choices = const [];
    _sayCompleter = null;
    _choiceCompleter = null;
  }

  bool _pickable(Choice c) =>
      c.requiresContract == null || hasContract(c.requiresContract!);

  // ── Flow ────────────────────────────────────────────────────

  void _advance() {
    if (_queue.isEmpty) {
      _current = null;
      _wrapped = const [];
      final completer = _sayCompleter;
      _sayCompleter = null;
      completer?.complete();
      return;
    }
    _current = _queue.removeAt(0);
    _revealed = 0;
    _wrapped = _wrap(_current!.text, viewSize.x - sidePad * 2 - 40);
  }

  void _confirm() {
    if (_choices.isNotEmpty) return;
    if (_current == null) return;
    final total = _current!.text.length.toDouble();
    if (_revealed < total) {
      _revealed = total; // First press completes the reveal, second advances.
    } else {
      _advance();
    }
  }

  void _pick(int index) {
    if (index < 0 || index >= _choices.length) return;
    if (!_pickable(_choices[index])) return;
    _choices = const [];
    _hovered = -1;
    final completer = _choiceCompleter;
    _choiceCompleter = null;
    completer?.complete(index);
  }

  // ── Input ───────────────────────────────────────────────────

  @override
  void onTapDown(TapDownEvent event) {
    if (!isActive) return;
    final p = event.localPosition;
    if (_choices.isNotEmpty) {
      final rects = _choiceRects();
      for (var i = 0; i < rects.length; i++) {
        if (rects[i].contains(Offset(p.x, p.y))) {
          _pick(i);
          return;
        }
      }
      return;
    }
    _confirm();
  }

  @override
  bool containsLocalPoint(Vector2 point) => isActive;

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (!isActive || event is! KeyDownEvent) return true;
    final key = event.logicalKey;

    if (_choices.isNotEmpty) {
      const digits = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
      ];
      final digit = digits.indexOf(key);
      if (digit >= 0) {
        _pick(digit);
        return false;
      }
      if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.keyS) {
        _hovered = (_hovered + 1).clamp(0, _choices.length - 1);
        return false;
      }
      if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
        _hovered = _hovered <= 0 ? 0 : _hovered - 1;
        return false;
      }
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
        _pick(_hovered < 0 ? 0 : _hovered);
        return false;
      }
      return false;
    }

    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.keyZ) {
      _confirm();
      return false;
    }
    return false;
  }

  // ── Update / render ─────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    _blink += dt;
    if (_current != null) {
      _revealed = (_revealed + charsPerSecond * dt).clamp(
        0,
        _current!.text.length.toDouble(),
      );
    }
  }

  List<Rect> _choiceRects() {
    final n = _choices.length;
    final h = n * choiceRowHeight + (n - 1) * 8;
    final top = viewSize.y - margin - h;
    return [
      for (var i = 0; i < n; i++)
        Rect.fromLTWH(
          sidePad,
          top + i * (choiceRowHeight + 8),
          viewSize.x - sidePad * 2,
          choiceRowHeight,
        ),
    ];
  }

  @override
  void render(Canvas canvas) {
    if (_choices.isNotEmpty) {
      _renderChoices(canvas);
      return;
    }
    if (_current == null) return;
    _renderBox(canvas);
  }

  void _renderBox(Canvas canvas) {
    final line = _current!;
    final rect = Rect.fromLTWH(
      margin,
      viewSize.y - boxHeight - margin,
      viewSize.x - margin * 2,
      boxHeight,
    );

    // Hard border, no transparency.
    canvas.drawRect(rect, Paint()..color = const Color(0xFFF4F1E8));
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF1B1A17)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Name plate, tabbed above the left corner.
    if (line.speaker != null) {
      final label = line.inHead
          ? '${line.speaker} (in your head)'
          : line.speaker!;
      final w = _plate.getLineMetrics(label).width + 24;
      final plateRect = Rect.fromLTWH(rect.left + 16, rect.top - 24, w, 24);
      canvas.drawRect(
        plateRect,
        Paint()
          ..color = line.inHead
              ? const Color(0xFF3B3168)
              : const Color(0xFF1B1A17),
      );
      _plate.render(
        canvas,
        label,
        Vector2(plateRect.left + 12, plateRect.top + 12),
        anchor: Anchor.centerLeft,
      );
    }

    // Body, revealed a character at a time. No auto-advance.
    final painter = line.speaker == null
        ? _bodyNarration
        : (line.inHead ? _bodyInHead : _body);
    var budget = _revealed.floor();
    var y = rect.top + 22;
    for (final row in _wrapped) {
      if (budget <= 0) break;
      final shown = row.length <= budget ? row : row.substring(0, budget);
      budget -= row.length + 1;
      painter.render(canvas, shown, Vector2(rect.left + sidePad, y));
      y += 26;
    }

    // Advance caret — blinks only once the line is fully out.
    if (_revealed >= line.text.length && _blink % 1.0 < 0.6) {
      _hint.render(
        canvas,
        '▾  tap / space',
        Vector2(rect.right - 18, rect.bottom - 16),
        anchor: Anchor.bottomRight,
      );
    }
  }

  void _renderChoices(Canvas canvas) {
    final rects = _choiceRects();
    for (var i = 0; i < _choices.length; i++) {
      final choice = _choices[i];
      final r = rects[i];
      final open = _pickable(choice);
      canvas.drawRect(
        r,
        Paint()
          ..color = i == _hovered
              ? const Color(0xFFFFF6D6)
              : const Color(0xFFF4F1E8),
      );
      canvas.drawRect(
        r,
        Paint()
          ..color = open ? const Color(0xFF1B1A17) : const Color(0x551B1A17)
          ..style = PaintingStyle.stroke
          ..strokeWidth = open ? 3 : 1.5,
      );
      (open ? _choiceText : _choiceTextLocked).render(
        canvas,
        '${i + 1}.  ${choice.text}',
        Vector2(r.left + 18, r.center.dy),
        anchor: Anchor.centerLeft,
      );
      if (!open) {
        _hint.render(
          canvas,
          '— you never met them',
          Vector2(r.right - 16, r.center.dy),
          anchor: Anchor.centerRight,
        );
      }
    }
  }

  // ── Word wrap ───────────────────────────────────────────────

  List<String> _wrap(String text, double maxWidth) {
    final words = text.split(' ');
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      final candidate = current.isEmpty ? word : '$current $word';
      if (_body.getLineMetrics(candidate).width > maxWidth &&
          current.isNotEmpty) {
        lines.add(current);
        current = word;
      } else {
        current = candidate;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    // The box holds three rows comfortably; anything longer is a script bug.
    return lines.take(3).toList();
  }
}

/// Colour constants shared by the HUD so the box and the pips agree.
class UiPalette {
  static const ink = Color(0xFF1B1A17);
  static const paper = Color(0xFFF4F1E8);
  static const blood = Color(0xFFB4423A);
  static const guard = Color(0xFF4F7FC3);
  static const gold = Color(0xFFD8A44A);
  static const dim = Color(0x66FFFFFF);
  static final scrim = Colors.black.withValues(alpha: 0.45);
}
