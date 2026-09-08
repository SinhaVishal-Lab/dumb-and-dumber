import 'dart:async';
import 'dart:ui' hide TextStyle;

import 'package:dumb_and_dumber/characters/enemy.dart';
import 'package:dumb_and_dumber/characters/player.dart';
import 'package:dumb_and_dumber/components/placeholder.dart';
import 'package:dumb_and_dumber/dialogue/dialogue.dart';
import 'package:dumb_and_dumber/dumb_and_dumber.dart';
import 'package:dumb_and_dumber/state/game_state.dart';
import 'package:flame/components.dart';

/// Thrown inside a level script when the level is torn down mid-await, so a
/// half-finished cutscene never keeps running against a dead world.
class LevelAborted implements Exception {
  const LevelAborted();
}

/// Base for every level.
///
/// A level is two things: [build], which lays out the world, and [script],
/// which is the level's director written as a straight-line async function.
/// Because [wait] and [waitUntil] tick off the game clock rather than wall
/// time, pausing the engine pauses the story too.
abstract class GameLevel extends World with HasGameReference<DumbandDumber> {
  GameLevel({required this.id, required this.player});

  final LevelId id;
  final Player player;

  /// The ground plane the design doc was written against.
  static const double groundY = 400;
  static const double viewW = 1080;
  static const double viewH = 500;

  final List<Platform> platforms = [];
  final List<TriggerZone> triggers = [];
  final List<Creature> creatures = [];

  double levelWidth = viewW;
  double levelHeight = viewH;
  bool cameraFollows = false;

  /// Shrines refill health and are the only checkpoints. Death costs nothing
  /// but the walk back.
  Vector2 checkpoint = Vector2.zero();

  bool _aborted = false;
  final List<_PendingWait> _waits = [];

  bool get alive => !_aborted && isMounted;

  // ── Construction ────────────────────────────────────────────

  Future<void> build();
  Future<void> script();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await build();
    player.onSwing = _resolveSwing;
    player.onDeath = _onPlayerDeath;
    add(player);
  }

  bool _scriptStarted = false;

  /// The director runs detached, and not before the first update: [alive]
  /// only reads true once mounting has fully completed, and onMount runs
  /// while that bit is still being set.
  void _startScriptOnce() {
    if (_scriptStarted) return;
    _scriptStarted = true;
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      await script();
    } on LevelAborted {
      // Expected on level change.
    }
  }

  @override
  void onRemove() {
    _aborted = true;
    for (final w in _waits) {
      if (!w.completer.isCompleted) {
        w.completer.completeError(const LevelAborted());
      }
    }
    _waits.clear();
    super.onRemove();
  }

  // ── Layout helpers ──────────────────────────────────────────

  Platform ground(
    double x,
    double width, {
    double top = groundY,
    Color color = const Color(0xFF3E3226),
    bool oneWay = false,
    bool visible = true,
    String? label,
  }) {
    final p = Platform(
      position: Vector2(x, top),
      size: Vector2(width, levelHeight - top + 120),
      color: color,
      oneWay: oneWay,
      visible: visible,
      label: label,
    );
    platforms.add(p);
    add(p);
    return p;
  }

  Platform ledge(
    double x,
    double y,
    double width, {
    double height = 24,
    Color color = const Color(0xFF4A3B2A),
    bool oneWay = true,
    String? label,
  }) {
    final p = Platform(
      position: Vector2(x, y),
      size: Vector2(width, height),
      color: color,
      oneWay: oneWay,
      label: label,
    );
    platforms.add(p);
    add(p);
    return p;
  }

  Platform wall(double x, double y, double w, double h) {
    final p = Platform(
      position: Vector2(x, y),
      size: Vector2(w, h),
      color: const Color(0xFF2B2419),
    );
    platforms.add(p);
    add(p);
    return p;
  }

  TriggerZone trigger(
    double x,
    double y,
    double w,
    double h, {
    void Function()? onEnter,
    void Function()? onExit,
    Color? fill,
  }) {
    final t = TriggerZone(
      position: Vector2(x, y),
      size: Vector2(w, h),
      onEnter: onEnter,
      onExit: onExit,
      fillColor: fill,
    );
    triggers.add(t);
    add(t);
    return t;
  }

  Creature spawn(Creature creature) {
    creatures.add(creature);
    add(creature);
    return creature;
  }

  void removeCreature(Creature creature) {
    creatures.remove(creature);
    creature.removeFromParent();
  }

  /// Puts the player's feet on [top] at [x].
  void placePlayer(double x, {double top = groundY}) {
    player.position = Vector2(
      x - Player.hbOffsetX,
      top - Player.hbHeight - Player.hbOffsetY,
    );
    player.velocity.setZero();
  }

  // ── Script helpers ──────────────────────────────────────────

  Future<void> say(List<Line> lines) async {
    _guard();
    await game.dialogue.say(lines);
    _guard();
  }

  Future<int> choose(List<Choice> options) async {
    _guard();
    final pick = await game.dialogue.choose(options);
    _guard();
    return pick;
  }

  /// Game-clock wait. Pausing the engine pauses this.
  Future<void> wait(double seconds) {
    _guard();
    final w = _PendingWait.timed(seconds);
    _waits.add(w);
    return w.completer.future;
  }

  Future<void> waitUntil(bool Function() test) {
    _guard();
    if (test()) return Future.value();
    final w = _PendingWait.condition(test);
    _waits.add(w);
    return w.completer.future;
  }

  /// Resolves with true if [test] passed, false if [seconds] ran out first.
  Future<bool> waitUntilOr(double seconds, bool Function() test) async {
    var passed = false;
    var elapsed = 0.0;
    await waitUntil(() {
      elapsed += _lastDt;
      if (test()) {
        passed = true;
        return true;
      }
      return elapsed >= seconds;
    });
    return passed;
  }

  void prompt(String? text) {
    if (text == null) {
      game.hud.prompt.hide();
    } else {
      game.hud.prompt.show(text);
    }
  }

  void toast(String text, {double seconds = 1.6}) =>
      game.hud.toast.show(text, seconds: seconds);

  void _guard() {
    if (!alive) throw const LevelAborted();
  }

  /// Hands the run to the next level.
  Future<void> finish() async {
    if (!alive) return;
    final next = id.next;
    if (next != null) await game.goToLevel(next);
  }

  // ── Per-frame ───────────────────────────────────────────────

  double _lastDt = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _lastDt = dt;
    _startScriptOnce();
    _tickWaits(dt);
    _tickTriggers();
    _tickCamera();
    _tickContractPrompt();
  }

  void _tickWaits(double dt) {
    if (_waits.isEmpty) return;
    final done = <_PendingWait>[];
    for (final w in _waits) {
      if (w.tick(dt)) done.add(w);
    }
    for (final w in done) {
      _waits.remove(w);
      if (!w.completer.isCompleted) w.completer.complete();
    }
  }

  void _tickTriggers() {
    final body = player.body;
    for (final t in triggers) {
      t.test(body);
    }
  }

  void _tickCamera() {
    if (!cameraFollows) return;
    final target = (player.body.center.dx - viewW / 2).clamp(
      0.0,
      (levelWidth - viewW).clamp(0.0, double.infinity),
    );
    // Whole-pixel camera snapping — no sub-pixel drift.
    game.cam.viewfinder.position = Vector2(target.roundToDouble(), 0);
  }

  /// The contract prompt only appears when something is actually offering.
  void _tickContractPrompt() {
    final target = nearestOffer();
    game.hud.contractButton.enabled = target != null && !game.dialogue.isActive;
  }

  /// §5 Contracts. Pay its toll, get passage plus one small boon, and it
  /// stays alive on the map — with no UI explanation beyond one line from
  /// Yami the first time it happens.
  Future<void> offerContract(Creature target) async {
    if (!target.offering) return;
    player.controlsLocked = true;
    try {
      if (game.state.contractCount == 0) {
        await say([
          const Line.inHead('You can just ask them for things. Like a person.'),
        ]);
      }
      await say([Line(target.displayName, 'Then pay. I want ${target.toll}.')]);
      final pick = await choose([
        const Choice('Pay it.'),
        const Choice('Finish it.'),
      ]);
      if (pick == 0) {
        target.acceptContract();
        toast('CONTRACT SEALED');
        onContractMade(target);
      } else {
        target.kill();
        await say([
          const Line('SAKAMOTO', 'I have a sword. That is the negotiation.'),
        ]);
      }
    } on LevelAborted {
      rethrow;
    } finally {
      player.controlsLocked = false;
    }
  }

  void onContractMade(Creature target) {}

  /// §5 Blood price: hitting zero from your own swings is not a game over —
  /// the wardens carry Sakamoto out and the approach restarts. Only HV1
  /// overrides this; everywhere else it is an ordinary death.
  void onBloodPriceCollapse() {
    if (!player.dead) player.takeHit(99);
  }

  Creature? nearestOffer() {
    Creature? best;
    var bestDistance = 260.0;
    final me = player.body.center;
    for (final c in creatures) {
      if (!c.offering) continue;
      final d =
          (Vector2(c.body.center.dx, c.body.center.dy) - Vector2(me.dx, me.dy))
              .length;
      if (d < bestDistance) {
        bestDistance = d;
        best = c;
      }
    }
    return best;
  }

  // ── Combat wiring ───────────────────────────────────────────

  /// Every swing asks the level what it just hit. Bosses override this to
  /// add their own bodies.
  void _resolveSwing(Rect reach, bool charged) {
    onSwing(reach, charged);
  }

  void onSwing(Rect reach, bool charged) {
    for (final c in List<Creature>.from(creatures)) {
      if (!c.active) continue;
      if (reach.overlaps(c.body)) {
        c.takeHit(charged ? 2 : 1, charged: charged);
      }
    }
  }

  void _onPlayerDeath() {
    unawaited(_respawn());
  }

  /// §5 Death: respawn at the last shrine and lose nothing. Contracts made
  /// stay made, killed enemies stay killed, cleared arenas stay cleared.
  Future<void> _respawn() async {
    try {
      await wait(1.4);
      if (!alive) return;
      game.state.refillAtShrine();
      game.hud.sync();
      player.revive(checkpoint);
      onRespawned();
    } on LevelAborted {
      // Level changed under us.
    }
  }

  void onRespawned() {}

  /// Falling out of the world is the same as dying, minus the drama.
  void onPlayerFellOut() {
    if (player.dead) return;
    game.state.health = 0;
    game.hud.sync();
    player.takeHit(99);
  }

  /// Remembers where a shrine put us.
  void setCheckpoint(double x, {double top = groundY}) {
    checkpoint = Vector2(
      x - Player.hbOffsetX,
      top - Player.hbHeight - Player.hbOffsetY,
    );
  }
}

class _PendingWait {
  _PendingWait.timed(this.seconds) : test = null;
  _PendingWait.condition(this.test) : seconds = 0;

  final double seconds;
  final bool Function()? test;
  final Completer<void> completer = Completer<void>();

  double _elapsed = 0;

  bool tick(double dt) {
    if (test != null) return test!();
    _elapsed += dt;
    return _elapsed >= seconds;
  }
}
