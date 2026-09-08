import 'dart:math' as math;
import 'dart:ui' hide TextStyle;

import 'package:dumb_and_dumber/Levels/level.dart';
import 'package:dumb_and_dumber/characters/bosses.dart';
import 'package:dumb_and_dumber/characters/enemy.dart';
import 'package:dumb_and_dumber/characters/player.dart';
import 'package:dumb_and_dumber/components/placeholder.dart';
import 'package:dumb_and_dumber/dialogue/dialogue.dart';
import 'package:dumb_and_dumber/state/game_state.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;

/// E1 · THE ROAD TO THE SAINT — Earth · platforming.
///
/// About six screen-widths of left-to-right travel that begins as farmland
/// and ends above the clouds. This is where kill-or-bargain is introduced,
/// and where it has to feel expensive.
class RoadLevel extends GameLevel {
  RoadLevel({required super.player}) : super(id: LevelId.road);

  static const double zone1 = 0;
  static const double zone2 = 1500;
  static const double zone3 = 2600;
  static const double zone4 = 3700;
  static const double climbStart = 5100;
  static const double ringStart = 6100;

  late final SaintBoss saint;
  late final Darkness darkness;
  late final WindGusts wind;

  Creature? widow;
  Creature? dog;
  final List<Creature> _moths = [];

  bool _crossingResolved = false;
  bool _saintFightRunning = false;

  @override
  Future<void> build() async {
    levelWidth = 6900;
    levelHeight = GameLevel.viewH;
    cameraFollows = true;

    add(
      PlaceholderParallax(
        sky: const Color(0xFF9FB6C4),
        mid: const Color(0xFF5C6E63),
        near: const Color(0xFF3E4B45),
        size: Vector2(levelWidth, levelHeight),
        caption: 'PARALLAX — mountains / mist / canopy (existing plx set)',
      ),
    );

    await _buildRiceTerraces();
    await _buildDeadPines();
    await _buildCrossing();
    await _buildDarkStretch();
    await _buildClimb();
    await _buildRing();

    darkness = Darkness(
      area: Rect.fromLTWH(zone4, 0, climbStart - zone4, levelHeight),
      player: player,
    );
    add(darkness);

    wind = WindGusts(
      area: Rect.fromLTWH(climbStart, 0, ringStart - climbStart, levelHeight),
      player: player,
    );
    add(wind);

    placePlayer(120);
    setCheckpoint(120);
  }

  // ── Zone 1 — rice terraces ──────────────────────────────────
  // Flooded steps as staggered platforms, gentle jump spacing, no death pits.

  Future<void> _buildRiceTerraces() async {
    ground(0, zone2 + 80, color: const Color(0xFF4B5B3A));
    ledge(360, 330, 220, label: 'RICE TERRACE');
    ledge(660, 262, 200);
    ledge(980, 320, 240);

    // Bell-toads sit on posts and ring when they see you, calling a second.
    for (final x in [520.0, 1040.0]) {
      final toad = spawn(Creature.bellToad(Vector2(x, 352)));
      toad.onRing = _callSecondToad;
    }
  }

  void _callSecondToad(Creature source) {
    // Teaches that noise recruits.
    final at = Vector2(source.position.x + 260, 352);
    if (at.x > zone2) return;
    spawn(Creature.bellToad(at));
  }

  // ── Zone 2 — dead pines ─────────────────────────────────────
  // Vertical. Roll under falling branches on a two-second telegraph.
  // Shrine at the bottom; shrines refill health and are the only checkpoints.

  Future<void> _buildDeadPines() async {
    ground(zone2, zone3 - zone2, color: const Color(0xFF3B3A31));
    ledge(zone2 + 120, 300, 180, label: 'SPLIT TRUNK');
    ledge(zone2 + 400, 232, 160);
    ledge(zone2 + 680, 300, 180);

    for (final offset in [340.0, 620.0, 880.0]) {
      add(
        FallingBranch(
          atX: zone2 + offset,
          groundTop: GameLevel.groundY,
          level: this,
        ),
      );
    }

    add(
      Prop(
        position: Vector2(zone3 - 220, 300),
        size: Vector2(90, 100),
        color: const Color(0xFFB0894F),
        label: 'SHRINE',
      ),
    );
    trigger(
      zone3 - 240,
      200,
      130,
      200,
      onEnter: () {
        setCheckpoint(zone3 - 175);
        game.state.refillAtShrine();
        game.hud.sync();
        toast('SHRINE');
      },
    );
  }

  // ── Zone 3 — the crossing ───────────────────────────────────
  // A ravine with the stilt-widow standing in it.

  Future<void> _buildCrossing() async {
    ground(zone3, 300, color: const Color(0xFF3B3A31));
    // The ravine itself: no floor between here and the far lip.
    ground(zone4 - 240, 240, color: const Color(0xFF3B3A31));
    widow = spawn(Creature.stiltWidow(Vector2(zone3 + 380, 200)));
  }

  // ── Zone 4 — the dark stretch and the dog ───────────────────

  Future<void> _buildDarkStretch() async {
    ground(zone4, climbStart - zone4, color: const Color(0xFF2E2A26));
    ledge(zone4 + 320, 320, 200);
    ledge(zone4 + 700, 280, 200);

    for (final offset in [420.0, 760.0, 1020.0]) {
      final moth = spawn(Creature.mouthMoth(Vector2(zone4 + offset, 220)));
      _moths.add(moth);
    }
    dog = spawn(Creature.twoHeadedDog(Vector2(climbStart - 320, 290)));
  }

  // ── The climb ───────────────────────────────────────────────
  // Wind gusts on a four-second cycle. No enemies for two full minutes.

  Future<void> _buildClimb() async {
    ground(climbStart, 200, color: const Color(0xFF6E7580));
    var y = 340.0;
    var x = climbStart + 260;
    while (x < ringStart - 200) {
      ledge(x, y, 150, color: const Color(0xFF7C838C), label: 'LEDGE');
      x += 250;
      y -= 26;
      if (y < 180) y = 340;
    }
    ground(ringStart - 220, 220, color: const Color(0xFF6E7580));
  }

  // ── The saint's ring ────────────────────────────────────────

  Future<void> _buildRing() async {
    ground(ringStart, levelWidth - ringStart, color: const Color(0xFF8A8E96));
    add(
      Prop(
        position: Vector2(ringStart + 120, 360),
        size: Vector2(620, 40),
        color: const Color(0xFFB8BCC4),
        label: 'THE RING IN THE DIRT',
      ),
    );
    saint = SaintBoss(
      position: Vector2(
        ringStart + 620,
        GameLevel.groundY - SaintBoss.bodyHeight,
      ),
    );
    add(saint);
  }

  // ── Swings ──────────────────────────────────────────────────

  @override
  void onSwing(Rect reach, bool charged) {
    super.onSwing(reach, charged);
    // Landing a hit on the saint is the one thing this fight punishes.
    if (_saintFightRunning && reach.overlaps(saint.body)) {
      saint.onHitByPlayer();
    }
  }

  @override
  void onContractMade(Creature target) {
    if (target.creatureId == CreatureId.mouthMoth) {
      // Contracted moths stop eating the light.
      darkness.lanternRadius = 340;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_saintFightRunning) {
      // The bar that appears on screen is Sakamoto's guard stamina.
      game.hud.bossBar.value = game.state.guard / GameState.maxGuardPips;
    }
    // Moths eat your light unless they were contracted.
    for (final moth in _moths) {
      if (!moth.active) continue;
      final d = (moth.position.x - player.body.center.dx).abs();
      if (d < 200) darkness.feed(dt);
    }
  }

  // ── Director ────────────────────────────────────────────────

  @override
  Future<void> script() async {
    await wait(0.6);
    await say([
      const Line.inHead('You are going the wrong way. That is a rice field.'),
      const Line('SAKAMOTO', 'It is on the way.'),
      const Line.inHead('To what? Rice?'),
    ]);

    // Zone 1 — the first thing you meet dies in one hit.
    await waitUntil(() => player.body.center.dx > 560);
    await say([const Line.inHead('It rang. Now there are two. Well done.')]);

    // Zone 2 — telegraphed branches, then the shrine.
    await waitUntil(() => player.body.center.dx > zone2 + 200);
    prompt('ROLL  (↓ / joystick down)');
    await wait(4);
    prompt(null);

    // Zone 3 — the first contract prompt, with one line from Yami and no UI
    // explanation.
    await waitUntil(() => player.body.center.dx > zone3 + 120);
    await say([
      const Line('SAKAMOTO', 'It is standing in the only road.'),
      const Line.inHead(
        'It is standing in the only road because it lives here.',
      ),
    ]);
    await _resolveCrossing();

    // Zone 4 — the dark stretch.
    await waitUntil(() => player.body.center.dx > zone4 + 60);
    await say([
      const Line.inHead('Something is eating your lantern.'),
      const Line('SAKAMOTO', 'I will eat it back.'),
    ]);

    await waitUntil(
      () => player.body.center.dx > climbStart - 520 || (dog?.dying ?? false),
    );
    if (dog != null && dog!.active) {
      await say([const Line.inHead('That one cannot be parried. Roll. Roll!')]);
    }

    // The climb — two full minutes of wind and no enemies.
    await waitUntil(() => player.body.center.dx > climbStart + 80);
    wind.active = true;
    await say([
      const Line.inHead('Do souls have weight?'),
      const Line.inHead(
        'Because if they do, you are about to find out on a ledge.',
      ),
    ]);
    await wait(14);
    await say([
      const Line.inHead('Would you have blocked?'),
      const Line.inHead(
        'If it had been the other way round. Would you have blocked?',
      ),
      const Line.narration(
        'He is climbing. He cannot look away and cannot answer.',
      ),
    ]);

    // Boss — the wrong greeting.
    await waitUntil(() => player.body.center.dx > ringStart + 200);
    wind.active = false;
    await say([
      const Line('SAKAMOTO', 'Hey! Old man! Which hole is my friend in?'),
      const Line('SAINT', 'Eleven years of silence, and it ends with you.'),
    ]);
    await _saintFight();

    // The calm, the conversation, the door.
    await say([
      const Line('SAINT', 'Who taught you to hold a guard like that?'),
      const Line('SAKAMOTO', 'Nobody.'),
      const Line('SAINT', 'It shows. Sit.'),
    ]);

    final topic = await choose([
      const Choice('"How does fetching a soul work?"'),
      const Choice('"What happens to the body?"'),
      const Choice('"Whose fault was this?"'),
    ]);
    await say([
      switch (topic) {
        0 => const Line(
          'SAINT',
          'A fetcher who is alive, an anchor who is dying, and a door.',
        ),
        1 => const Line(
          'SAINT',
          'It waits. Badly. Do not take the scenic route.',
        ),
        _ => const Line('SAINT', 'That is the one question I will not answer.'),
      },
      const Line('SAKAMOTO', 'I need to fetch a soul. Which hole is his?'),
      const Line('SAINT', 'There are three, and you should hear all of the—'),
      const Line.narration('[SAKAMOTO JUMPS]'),
    ]);

    player.controlsLocked = true;
    await game.hud.flash.flash(duration: 1.2, color: const Color(0xFFFFC246));
    await finish();
  }

  /// Contract her and she carries you across. Kill her and the crossing
  /// becomes a hard three-jump sequence in the dark. Both work; one is four
  /// minutes shorter.
  Future<void> _resolveCrossing() async {
    await waitUntil(
      () => (widow?.contracted ?? false) || (widow?.dying ?? true),
    );
    if (_crossingResolved) return;
    _crossingResolved = true;

    if (widow?.contracted ?? false) {
      await say([
        const Line(
          'STILT-WIDOW',
          'Hold on. Do not look down, you will scream.',
        ),
      ]);
      player.controlsLocked = true;
      await game.hud.flash.flash(duration: 0.8);
      placePlayer(zone4 - 160);
      player.controlsLocked = false;
      toast('SHE CARRIES YOU ACROSS');
    } else {
      await say([const Line.inHead('Right. We are jumping it, then.')]);
      // Three jumps, unlit.
      ledge(zone3 + 420, 330, 130, color: const Color(0xFF2A2A2A));
      ledge(zone3 + 700, 290, 130, color: const Color(0xFF2A2A2A));
      ledge(zone3 + 960, 330, 130, color: const Color(0xFF2A2A2A));
      darkness.area = Rect.fromLTWH(
        zone3 + 320,
        0,
        climbStart - zone3 - 320,
        levelHeight,
      );
    }
  }

  Future<void> _saintFight() async {
    setCheckpoint(ringStart + 240);
    await game.hud.nameCard.slam('THE SAINT', sub: 'DO NOT HIT HIM');
    game.hud.bossBar.show('GUARD STAMINA', barColor: const Color(0xFF4F7FC3));
    _saintFightRunning = true;
    saint.fighting = true;
    saint.phase = 0;
    saint.phaseTime = 0;

    prompt('GUARD AND PARRY  —  do not swing');
    await waitUntil(() => saint.defeated);
    prompt(null);

    _saintFightRunning = false;
    saint.fighting = false;
    game.hud.bossBar.hide();
    await wait(0.5);
  }

  @override
  void onRespawned() {
    // Cleared arenas stay cleared: the saint restarts at his current phase,
    // never the whole fight.
    if (_saintFightRunning) {
      saint.fighting = true;
      saint.phaseTime = 0;
    }
  }
}

/// A lantern-limited corridor. The darkness is a world-space overlay with a
/// hole cut around the player; moths shrink the hole.
class Darkness extends PositionComponent {
  Darkness({required this.area, required this.player}) : super(priority: 400);

  Rect area;
  final PositionComponent player;

  double lanternRadius = 260;
  static const double minRadius = 90;

  void feed(double dt) {
    lanternRadius = (lanternRadius - 40 * dt).clamp(minRadius, 340);
  }

  @override
  void render(Canvas canvas) {
    final cx = player.position.x + 192;
    final cy = player.position.y + 200;
    if (cx < area.left - 600 || cx > area.right + 600) return;

    final paint = Paint()
      ..shader = Gradient.radial(
        Offset(cx, cy),
        lanternRadius * 1.9,
        [
          const Color(0x00000000),
          const Color(0xCC050505),
          const Color(0xF2000000),
        ],
        [0.0, 0.45, 1.0],
      );
    canvas.drawRect(area, paint);
  }
}

/// Wind gusts on a four-second cycle push Sakamoto off ledges.
class WindGusts extends PositionComponent {
  WindGusts({required this.area, required this.player}) : super(priority: 300);

  final Rect area;
  final Player player;

  bool active = false;
  double _t = 0;

  double get strength {
    final phase = _t % 4.0;
    if (phase < 2.4) return 0;
    return math.sin((phase - 2.4) / 1.6 * math.pi) * 150;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!active) return;
    _t += dt;
    final gust = strength;
    if (gust == 0) return;
    player.position.x += gust * dt;
  }

  @override
  void render(Canvas canvas) {
    if (!active) return;
    final gust = strength;
    if (gust == 0) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28 * (gust / 150))
      ..strokeWidth = 2;
    for (var i = 0; i < 22; i++) {
      final y = area.top + (i * 23.0) % area.height;
      final x = area.left + ((_t * 420 + i * 137) % area.width);
      canvas.drawLine(Offset(x, y), Offset(x + 70, y), paint);
    }
  }
}

/// Falling branches on a two-second telegraph — the thing the roll is for.
class FallingBranch extends PositionComponent {
  FallingBranch({
    required this.atX,
    required this.groundTop,
    required this.level,
  }) : super(priority: 6);

  final double atX;
  final double groundTop;
  final GameLevel level;

  double _timer = 0;
  double _dropY = -80;
  bool _falling = false;

  @override
  void update(double dt) {
    super.update(dt);
    final player = level.player;
    final near = (player.body.center.dx - atX).abs() < 420;
    if (!near) {
      _timer = 0;
      _falling = false;
      _dropY = -80;
      return;
    }

    if (!_falling) {
      _timer += dt;
      if (_timer >= 2.0) {
        _falling = true;
        _timer = 0;
      }
      return;
    }

    _dropY += 620 * dt;
    final hit = Rect.fromLTWH(atX - 40, _dropY, 80, 40);
    if (hit.overlaps(player.body)) {
      player.takeHit(1, knockback: 60, parryable: false);
      _falling = false;
      _dropY = -80;
    }
    if (_dropY > groundTop) {
      _falling = false;
      _dropY = -80;
    }
  }

  @override
  void render(Canvas canvas) {
    final player = level.player;
    if ((player.body.center.dx - atX).abs() > 420) return;
    if (!_falling) {
      // The telegraph.
      final progress = (_timer / 2.0).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(atX - 40, 0, 80, groundTop),
        Paint()
          ..color = const Color(
            0xFFB4423A,
          ).withValues(alpha: 0.1 + progress * 0.2),
      );
      return;
    }
    PlaceholderArt.box(
      canvas
        ..save()
        ..translate(atX - 40, _dropY),
      Vector2(80, 40),
      color: const Color(0xFF4A3421),
      label: 'BRANCH',
      lightText: true,
    );
    canvas.restore();
  }
}
